-- C11-F0C — Shift Packaging Reconciliation
-- Links canonical inventory counts to shift opening/closing checkpoints.
-- Physical quantities remain inventory facts; theoretical usage remains sale snapshot facts.
-- No second cup/packaging stock engine is introduced.

alter table public.inventory_counts
    add column shift_id uuid references public.shifts(id) on delete restrict,
    add column shift_checkpoint text;

alter table public.inventory_counts
    add constraint inventory_counts_shift_checkpoint_shape
    check (
        (shift_id is null and shift_checkpoint is null)
        or
        (
            shift_id is not null
            and shift_checkpoint in ('OPENING','CLOSING')
        )
    );

create index inventory_counts_shift_checkpoint_idx
on public.inventory_counts(shift_id, shift_checkpoint, snapshot_at desc)
where shift_id is not null;

create or replace function private.guard_inventory_count_shift_link()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if new.shift_id is distinct from old.shift_id
       or new.shift_checkpoint is distinct from old.shift_checkpoint then
        raise exception using
            errcode = '55000',
            message = 'INVENTORY_COUNT_SHIFT_LINK_IMMUTABLE';
    end if;
    return new;
end;
$$;

drop trigger if exists inventory_counts_shift_link_immutable
on public.inventory_counts;

create trigger inventory_counts_shift_link_immutable
before update of shift_id, shift_checkpoint on public.inventory_counts
for each row execute function private.guard_inventory_count_shift_link();

create or replace function public.create_shift_packaging_count(
    p_shift uuid,
    p_checkpoint text,
    p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_owner boolean;
    v_checkpoint text;
    v_shift public.shifts%rowtype;
    v_payload jsonb;
    v_payload_hash text;
    v_lock record;
    v_count public.inventory_counts%rowtype;
    v_item_count integer;
    v_receipt uuid;
    v_has_sales boolean;
    v_existing_stale boolean;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id','')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id','')::uuid;
    v_owner := coalesce((v_authority ->> 'owner')::boolean,false);

    if v_business is null or v_actor is null then
        raise exception using errcode='42501', message='SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'INVENTORY_COUNT') then
        raise exception using
            errcode='42501',
            message='SJ_SHIFT_PACKAGING_COUNT_PERMISSION_DENIED';
    end if;

    v_checkpoint := upper(btrim(coalesce(p_checkpoint,'')));
    if v_checkpoint not in ('OPENING','CLOSING') then
        raise exception using
            errcode='22023',
            message='SJ_SHIFT_PACKAGING_CHECKPOINT_INVALID';
    end if;

    select *
    into v_shift
    from public.shifts s
    where s.id = p_shift
      and s.business_id = v_business
    for update;

    if not found
       or (not v_owner and v_shift.cashier_profile_id <> v_actor) then
        raise exception using
            errcode='42501',
            message='SJ_SHIFT_PACKAGING_COUNT_DENIED';
    end if;

    if v_shift.status <> 'OPEN' then
        raise exception using
            errcode='55000',
            message='SJ_SHIFT_PACKAGING_SHIFT_NOT_OPEN';
    end if;

    if not v_owner
       and not private.has_inventory_location_scope(
            v_business,
            v_actor,
            v_shift.location_id
       ) then
        raise exception using
            errcode='42501',
            message='SJ_SHIFT_PACKAGING_LOCATION_SCOPE_DENIED';
    end if;

    select exists (
        select 1
        from public.sales sale
        where sale.business_id = v_business
          and sale.shift_id = p_shift
    )
    into v_has_sales;

    select count(*)
    into v_item_count
    from public.stock_items si
    where si.business_id = v_business
      and si.item_kind = 'PACKAGING'
      and si.active
      and si.inventory_tracked;

    if v_item_count = 0 then
        raise exception using
            errcode='P0002',
            message='SJ_SHIFT_PACKAGING_ITEMS_EMPTY';
    end if;

    v_payload := jsonb_build_object(
        'shift_id', p_shift,
        'checkpoint', v_checkpoint
    );
    v_payload_hash := private.payload_sha256(v_payload);

    select *
    into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'SHIFT_PACKAGING_COUNT_CREATE',
        v_payload_hash
    );

    if v_lock.replay then
        select *
        into v_count
        from public.inventory_counts c
        where c.id = v_lock.result_id
          and c.business_id = v_business
          and c.shift_id = p_shift
          and c.shift_checkpoint = v_checkpoint;

        if not found then
            raise exception using
                errcode='P0002',
                message='SJ_SHIFT_PACKAGING_REPLAY_RESULT_MISSING';
        end if;

        return jsonb_build_object(
            'success', true,
            'replay', true,
            'count_id', v_count.id,
            'status', v_count.status,
            'checkpoint', v_checkpoint
        );
    end if;

    select *
    into v_count
    from public.inventory_counts c
    where c.business_id = v_business
      and c.shift_id = p_shift
      and c.shift_checkpoint = v_checkpoint
    order by c.snapshot_at desc, c.created_at desc
    limit 1;

    if found then
        if v_checkpoint = 'OPENING' and v_count.status = 'POSTED' then
            perform private.record_operation_success(
                v_business,
                p_idempotency_key,
                'SHIFT_PACKAGING_COUNT_CREATE',
                v_payload_hash,
                'INVENTORY_COUNT',
                v_count.id,
                v_actor
            );

            return jsonb_build_object(
                'success', true,
                'replay', true,
                'count_id', v_count.id,
                'status', v_count.status,
                'checkpoint', v_checkpoint
            );
        end if;

        if v_checkpoint = 'OPENING' and v_has_sales then
            raise exception using
                errcode='55000',
                message='SJ_SHIFT_PACKAGING_OPENING_TOO_LATE';
        end if;

        select exists (
            select 1
            from public.inventory_movements im_after
            join public.inventory_movement_lines iml_after
              on iml_after.movement_id = im_after.id
            join public.stock_items si_after
              on si_after.id = iml_after.stock_item_id
             and si_after.business_id = v_business
            where im_after.business_id = v_business
              and iml_after.location_id = v_shift.location_id
              and si_after.item_kind = 'PACKAGING'
              and im_after.created_at > v_count.snapshot_at
              and (
                  v_count.movement_id is null
                  or im_after.id <> v_count.movement_id
              )
        )
        into v_existing_stale;

        if not v_existing_stale then
            perform private.record_operation_success(
                v_business,
                p_idempotency_key,
                'SHIFT_PACKAGING_COUNT_CREATE',
                v_payload_hash,
                'INVENTORY_COUNT',
                v_count.id,
                v_actor
            );

            return jsonb_build_object(
                'success', true,
                'replay', true,
                'count_id', v_count.id,
                'status', v_count.status,
                'checkpoint', v_checkpoint
            );
        end if;
    elsif v_checkpoint = 'OPENING' and v_has_sales then
        raise exception using
            errcode='55000',
            message='SJ_SHIFT_PACKAGING_OPENING_TOO_LATE';
    end if;

    perform si.id
    from public.stock_items si
    where si.business_id = v_business
      and si.item_kind = 'PACKAGING'
      and si.active
      and si.inventory_tracked
    order by si.id
    for update of si;

    insert into public.inventory_counts (
        business_id,
        location_id,
        notes,
        created_by,
        shift_id,
        shift_checkpoint
    ) values (
        v_business,
        v_shift.location_id,
        'Shift ' || v_checkpoint || ' packaging count',
        v_actor,
        p_shift,
        v_checkpoint
    )
    returning * into v_count;

    insert into public.inventory_count_lines (
        count_id,
        line_no,
        stock_item_id,
        expected_quantity
    )
    select
        v_count.id,
        row_number() over (order by si.id)::integer,
        si.id,
        coalesce(current_balance.quantity, 0)::numeric(18,3)
    from public.stock_items si
    left join lateral (
        select coalesce(sum(iml.quantity_delta), 0)::numeric(18,3) as quantity
        from public.inventory_movements im
        join public.inventory_movement_lines iml
          on iml.movement_id = im.id
        where im.business_id = v_business
          and iml.stock_item_id = si.id
          and iml.location_id = v_shift.location_id
    ) current_balance on true
    where si.business_id = v_business
      and si.item_kind = 'PACKAGING'
      and si.active
      and si.inventory_tracked
    order by si.id;

    v_receipt := private.record_operation_success(
        v_business,
        p_idempotency_key,
        'SHIFT_PACKAGING_COUNT_CREATE',
        v_payload_hash,
        'INVENTORY_COUNT',
        v_count.id,
        v_actor
    );

    insert into public.audit_events (
        business_id,
        actor_profile_id,
        operation_receipt_id,
        event_type,
        entity_type,
        entity_id,
        metadata
    ) values (
        v_business,
        v_actor,
        v_receipt,
        'SHIFT_PACKAGING_COUNT_CREATED',
        'INVENTORY_COUNT',
        v_count.id,
        jsonb_build_object(
            'shift_id', p_shift,
            'checkpoint', v_checkpoint,
            'location_id', v_shift.location_id,
            'item_count', v_item_count
        )
    );

    return jsonb_build_object(
        'success', true,
        'replay', false,
        'count_id', v_count.id,
        'status', v_count.status,
        'checkpoint', v_checkpoint
    );
end;
$$;

revoke execute on function public.create_shift_packaging_count(uuid,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.create_shift_packaging_count(uuid,text,text)
to authenticated;

create or replace function public.shift_packaging_reconciliation(p_shift uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_owner boolean;
    v_shift public.shifts%rowtype;
    v_opening public.inventory_counts%rowtype;
    v_closing public.inventory_counts%rowtype;
    v_has_sales boolean;
    v_items jsonb;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id','')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id','')::uuid;
    v_owner := coalesce((v_authority ->> 'owner')::boolean,false);

    if v_business is null or v_actor is null then
        raise exception using
            errcode='42501',
            message='SHIFT_PACKAGING_AUTHORITY_REQUIRED';
    end if;

    select *
    into v_shift
    from public.shifts s
    where s.id = p_shift
      and s.business_id = v_business
      and (v_owner or s.cashier_profile_id = v_actor);

    if not found then
        raise exception using
            errcode='42501',
            message='SHIFT_PACKAGING_READ_DENIED';
    end if;

    select *
    into v_opening
    from public.inventory_counts c
    where c.business_id = v_business
      and c.shift_id = p_shift
      and c.shift_checkpoint = 'OPENING'
    order by c.snapshot_at desc, c.created_at desc
    limit 1;

    select *
    into v_closing
    from public.inventory_counts c
    where c.business_id = v_business
      and c.shift_id = p_shift
      and c.shift_checkpoint = 'CLOSING'
    order by c.snapshot_at desc, c.created_at desc
    limit 1;

    select exists (
        select 1
        from public.sales sale
        where sale.business_id = v_business
          and sale.shift_id = p_shift
    )
    into v_has_sales;

    select coalesce(
        jsonb_agg(
            jsonb_build_object(
                'stock_item_id', item.stock_item_id,
                'code', item.code,
                'name', item.name,
                'base_unit', item.base_unit,
                'inventory_tracked', item.inventory_tracked,
                'current_expected_quantity', item.current_expected_quantity,
                'opening_expected_quantity', item.opening_expected_quantity,
                'opening_physical_quantity', item.opening_physical_quantity,
                'theoretical_usage', item.theoretical_usage,
                'closing_expected_quantity', item.closing_expected_quantity,
                'closing_physical_quantity', item.closing_physical_quantity,
                'variance', item.variance,
                'closing_stale', item.closing_stale
            )
            order by item.name, item.code
        ),
        '[]'::jsonb
    )
    into v_items
    from (
        select
            si.id as stock_item_id,
            si.code,
            si.display_name as name,
            si.base_unit,
            si.inventory_tracked,
            coalesce(balance.quantity, 0)::numeric(18,3)
                as current_expected_quantity,
            opening_line.expected_quantity::numeric(18,3)
                as opening_expected_quantity,
            opening_line.physical_quantity::numeric(18,3)
                as opening_physical_quantity,
            coalesce(usage.theoretical_usage, 0)::numeric(18,3)
                as theoretical_usage,
            closing_line.expected_quantity::numeric(18,3)
                as closing_expected_quantity,
            closing_line.physical_quantity::numeric(18,3)
                as closing_physical_quantity,
            case
                when closing_line.physical_quantity is null then null
                else (
                    closing_line.physical_quantity
                    - closing_line.expected_quantity
                )::numeric(18,3)
            end as variance,
            case
                when v_closing.id is null then false
                else exists (
                    select 1
                    from public.inventory_movements im_after
                    join public.inventory_movement_lines iml_after
                      on iml_after.movement_id = im_after.id
                    where im_after.business_id = v_business
                      and iml_after.stock_item_id = si.id
                      and iml_after.location_id = v_shift.location_id
                      and im_after.created_at > v_closing.snapshot_at
                      and (
                          v_closing.movement_id is null
                          or im_after.id <> v_closing.movement_id
                      )
                )
            end as closing_stale
        from public.stock_items si
        left join public.inventory_count_lines opening_line
          on opening_line.count_id = v_opening.id
         and opening_line.stock_item_id = si.id
        left join public.inventory_count_lines closing_line
          on closing_line.count_id = v_closing.id
         and closing_line.stock_item_id = si.id
        left join lateral (
            select coalesce(sum(iml.quantity_delta), 0)::numeric(18,3)
                as quantity
            from public.inventory_movements im
            join public.inventory_movement_lines iml
              on iml.movement_id = im.id
            where im.business_id = v_business
              and iml.stock_item_id = si.id
              and iml.location_id = v_shift.location_id
        ) balance on true
        left join lateral (
            select coalesce(sum(snap.quantity_total),0)::numeric(18,3)
                as theoretical_usage
            from public.sales sale
            join public.sale_item_component_snapshots snap
              on snap.sale_id = sale.id
            where sale.business_id = v_business
              and sale.shift_id = p_shift
              and snap.stock_item_id = si.id
              and snap.component_role = 'PACKAGING'
        ) usage on true
        where si.business_id = v_business
          and si.item_kind = 'PACKAGING'
          and (
              si.active
              or opening_line.stock_item_id is not null
              or closing_line.stock_item_id is not null
              or coalesce(usage.theoretical_usage,0) <> 0
          )
    ) item;

    return jsonb_build_object(
        'ready', true,
        'shift_id', v_shift.id,
        'shift_status', v_shift.status,
        'location_id', v_shift.location_id,
        'has_sales', v_has_sales,
        'opening_too_late', (
            v_has_sales
            and (
                v_opening.id is null
                or v_opening.status <> 'POSTED'
            )
        ),
        'opening_count', case
            when v_opening.id is null then null
            else jsonb_build_object(
                'id', v_opening.id,
                'status', v_opening.status,
                'snapshot_at', v_opening.snapshot_at,
                'counted_at', v_opening.counted_at,
                'posted_at', v_opening.posted_at
            )
        end,
        'closing_count', case
            when v_closing.id is null then null
            else jsonb_build_object(
                'id', v_closing.id,
                'status', v_closing.status,
                'snapshot_at', v_closing.snapshot_at,
                'counted_at', v_closing.counted_at,
                'posted_at', v_closing.posted_at
            )
        end,
        'items', v_items
    );
end;
$$;

revoke execute on function public.shift_packaging_reconciliation(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.shift_packaging_reconciliation(uuid)
to authenticated;

comment on function public.create_shift_packaging_count(uuid,text,text) is
'C11-F0C creates a canonical inventory count linked to one OPEN shift packaging checkpoint. OPENING must precede the first sale.';
comment on function public.shift_packaging_reconciliation(uuid) is
'C11-F0C shift-scoped packaging projection combining physical inventory counts, immutable theoretical sale usage, current ledger quantity, and closing variance.';
comment on column public.inventory_counts.shift_id is
'Optional C11-F0C shift link. Present only for shift packaging checkpoints.';
comment on column public.inventory_counts.shift_checkpoint is
'Optional C11-F0C packaging checkpoint: OPENING or CLOSING.';
