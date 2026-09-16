-- CS-06-P6: Production Execution
-- Single-location production batches bind an immutable BOM version and post
-- one canonical inventory movement for component consumption + finished output.

create table public.production_batches (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    location_id uuid not null references public.locations(id) on delete restrict,
    finished_good_id uuid not null references public.stock_items(id) on delete restrict,
    bom_id uuid not null references public.boms(id) on delete restrict,
    planned_output numeric(18,3) not null,
    actual_output numeric(18,3),
    status text not null default 'DRAFT',
    inventory_movement_id uuid unique references public.inventory_movements(id) on delete restrict,
    created_by uuid not null references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now(),
    posted_by uuid references public.profiles(id) on delete restrict,
    posted_at timestamptz,
    updated_at timestamptz not null default now(),
    constraint production_batches_planned_output_positive check (planned_output > 0),
    constraint production_batches_actual_output_positive check (actual_output is null or actual_output > 0),
    constraint production_batches_status_valid check (status in ('DRAFT', 'POSTED')),
    constraint production_batches_status_fields_valid check (
        (
            status = 'DRAFT'
            and actual_output is null
            and inventory_movement_id is null
            and posted_by is null
            and posted_at is null
        )
        or
        (
            status = 'POSTED'
            and actual_output is not null
            and inventory_movement_id is not null
            and posted_by is not null
            and posted_at is not null
        )
    )
);

create index production_batches_business_id_idx
    on public.production_batches(business_id);
create index production_batches_location_id_idx
    on public.production_batches(location_id);
create index production_batches_finished_good_id_idx
    on public.production_batches(finished_good_id);
create index production_batches_bom_id_idx
    on public.production_batches(bom_id);
create index production_batches_status_idx
    on public.production_batches(status);

alter table public.production_batches enable row level security;

create policy "Tenant read isolation for production_batches"
on public.production_batches
for select
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
);

revoke all on table public.production_batches
from public, anon, authenticated;

grant select on table public.production_batches to authenticated;

create or replace function private.guard_production_batch_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if tg_op = 'DELETE' then
        raise exception using errcode = '55000', message = 'PRODUCTION_IMMUTABLE';
    end if;

    if old.status <> 'DRAFT'
       or new.status <> 'POSTED'
       or new.business_id is distinct from old.business_id
       or new.location_id is distinct from old.location_id
       or new.finished_good_id is distinct from old.finished_good_id
       or new.bom_id is distinct from old.bom_id
       or new.planned_output is distinct from old.planned_output
       or new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at
       or new.actual_output is null
       or new.inventory_movement_id is null
       or new.posted_by is null
       or new.posted_at is null then
        raise exception using errcode = '55000', message = 'PRODUCTION_IMMUTABLE';
    end if;

    return new;
end;
$$;

create trigger production_batches_guard_mutation
before update or delete on public.production_batches
for each row execute function private.guard_production_batch_mutation();

create or replace function public.create_production_batch(
    p_location_id uuid,
    p_finished_good_id uuid,
    p_planned_output numeric,
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
    v_payload jsonb;
    v_payload_hash text;
    v_lock record;
    v_bom public.boms%rowtype;
    v_batch public.production_batches%rowtype;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'PRODUCTION_MANAGE') then
        raise exception using errcode = '42501', message = 'SJ_PRODUCTION_PERMISSION_DENIED';
    end if;

    v_payload := jsonb_build_object(
        'location_id', p_location_id,
        'finished_good_id', p_finished_good_id,
        'planned_output', p_planned_output
    );
    v_payload_hash := private.payload_sha256(v_payload);

    select *
    into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'PRODUCTION_BATCH_CREATE',
        v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'PRODUCTION_BATCH' then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_RESULT_TYPE_MISMATCH';
        end if;

        select *
        into v_batch
        from public.production_batches pb
        where pb.id = v_lock.result_id
          and pb.business_id = v_business;

        if not found then
            raise exception using errcode = 'P0002', message = 'PRODUCTION_IDEMPOTENCY_RESULT_MISSING';
        end if;

        select *
        into v_bom
        from public.boms b
        where b.id = v_batch.bom_id
          and b.business_id = v_business;

        return jsonb_build_object(
            'success', true,
            'replay', true,
            'batch_id', v_batch.id,
            'bom_id', v_batch.bom_id,
            'bom_version', v_bom.version,
            'location_id', v_batch.location_id,
            'finished_good_id', v_batch.finished_good_id,
            'status', v_batch.status
        );
    end if;

    if p_planned_output is null
       or lower(p_planned_output::text) in ('nan', 'infinity', '-infinity')
       or p_planned_output <= 0 then
        raise exception using errcode = '22023', message = 'PRODUCTION_OUTPUT_INVALID';
    end if;

    if p_planned_output <> round(p_planned_output, 3) then
        raise exception using errcode = '22023', message = 'PRODUCTION_LEDGER_PRECISION_UNSUPPORTED';
    end if;

    if not exists (
        select 1
        from public.locations l
        where l.id = p_location_id
          and l.business_id = v_business
          and l.active
          and l.location_type in ('WAREHOUSE', 'STORE')
    ) then
        raise exception using errcode = '23503', message = 'PRODUCTION_LOCATION_INVALID';
    end if;

    if not exists (
        select 1
        from public.stock_items si
        where si.id = p_finished_good_id
          and si.business_id = v_business
          and si.active
          and si.item_kind = 'FINISHED_GOOD'
    ) then
        raise exception using errcode = '23503', message = 'PRODUCTION_FINISHED_GOOD_INVALID';
    end if;

    select b.*
    into v_bom
    from public.boms b
    where b.business_id = v_business
      and b.finished_good_id = p_finished_good_id
      and b.status = 'ACTIVE'
    for share;

    if not found then
        raise exception using errcode = '23503', message = 'PRODUCTION_ACTIVE_BOM_REQUIRED';
    end if;

    insert into public.production_batches (
        business_id,
        location_id,
        finished_good_id,
        bom_id,
        planned_output,
        created_by
    ) values (
        v_business,
        p_location_id,
        p_finished_good_id,
        v_bom.id,
        p_planned_output::numeric(18,3),
        v_actor
    )
    returning * into v_batch;

    perform private.record_operation_success(
        v_business,
        p_idempotency_key,
        'PRODUCTION_BATCH_CREATE',
        v_payload_hash,
        'PRODUCTION_BATCH',
        v_batch.id,
        v_actor
    );

    return jsonb_build_object(
        'success', true,
        'replay', false,
        'batch_id', v_batch.id,
        'bom_id', v_bom.id,
        'bom_version', v_bom.version,
        'location_id', v_batch.location_id,
        'finished_good_id', v_batch.finished_good_id,
        'status', v_batch.status
    );
end;
$$;

create or replace function public.post_production_batch(
    p_batch_id uuid,
    p_actual_output numeric
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
    v_batch public.production_batches%rowtype;
    v_bom public.boms%rowtype;
    v_bad_count integer;
    v_shortage_count integer;
    v_component_count integer;
    v_lines jsonb;
    v_movement_id uuid;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'PRODUCTION_MANAGE') then
        raise exception using errcode = '42501', message = 'SJ_PRODUCTION_PERMISSION_DENIED';
    end if;

    if p_actual_output is null
       or lower(p_actual_output::text) in ('nan', 'infinity', '-infinity')
       or p_actual_output <= 0 then
        raise exception using errcode = '22023', message = 'PRODUCTION_OUTPUT_INVALID';
    end if;

    if p_actual_output <> round(p_actual_output, 3) then
        raise exception using errcode = '22023', message = 'PRODUCTION_LEDGER_PRECISION_UNSUPPORTED';
    end if;

    select pb.*
    into v_batch
    from public.production_batches pb
    where pb.id = p_batch_id
      and pb.business_id = v_business
    for update;

    if not found then
        raise exception using errcode = 'P0002', message = 'PRODUCTION_BATCH_NOT_FOUND';
    end if;

    if v_batch.status = 'POSTED' then
        if v_batch.actual_output is distinct from p_actual_output::numeric(18,3) then
            raise exception using errcode = '55000', message = 'PRODUCTION_ALREADY_POSTED_MISMATCH';
        end if;

        return jsonb_build_object(
            'success', true,
            'already_posted', true,
            'batch_id', v_batch.id,
            'movement_id', v_batch.inventory_movement_id,
            'actual_output', v_batch.actual_output,
            'status', v_batch.status
        );
    end if;

    if v_batch.status <> 'DRAFT' then
        raise exception using errcode = '55000', message = 'PRODUCTION_BATCH_NOT_DRAFT';
    end if;

    select b.*
    into v_bom
    from public.boms b
    where b.id = v_batch.bom_id
      and b.business_id = v_business
      and b.finished_good_id = v_batch.finished_good_id
      and b.status in ('ACTIVE', 'RETIRED');

    if not found or v_bom.yield_quantity <= 0 then
        raise exception using errcode = '23503', message = 'PRODUCTION_BOM_INVALID';
    end if;

    select count(*)
    into v_component_count
    from public.bom_lines bl
    where bl.bom_id = v_batch.bom_id;

    if v_component_count <= 0 then
        raise exception using errcode = '23503', message = 'PRODUCTION_BOM_INVALID';
    end if;

    select count(*)
    into v_bad_count
    from public.bom_lines bl
    left join public.stock_items si
      on si.id = bl.component_stock_item_id
     and si.business_id = v_business
    where bl.bom_id = v_batch.bom_id
      and (
          si.id is null
          or si.item_kind not in ('MATERIAL', 'PACKAGING', 'OTHER')
          or bl.base_quantity <= 0
      );

    if v_bad_count > 0 then
        raise exception using errcode = '23503', message = 'PRODUCTION_BOM_INVALID';
    end if;

    perform si.id
    from public.bom_lines bl
    join public.stock_items si
      on si.id = bl.component_stock_item_id
     and si.business_id = v_business
    where bl.bom_id = v_batch.bom_id
    order by bl.component_stock_item_id
    for update of si;

    with requirements as (
        select
            bl.line_no,
            bl.component_stock_item_id,
            round((bl.base_quantity * p_actual_output / v_bom.yield_quantity)::numeric, 3)::numeric(18,3) as required_quantity
        from public.bom_lines bl
        where bl.bom_id = v_batch.bom_id
    )
    select count(*)
    into v_bad_count
    from requirements r
    where r.required_quantity <= 0;

    if v_bad_count > 0 then
        raise exception using errcode = '22023', message = 'PRODUCTION_LEDGER_PRECISION_UNSUPPORTED';
    end if;

    with requirements as (
        select
            bl.component_stock_item_id,
            round((bl.base_quantity * p_actual_output / v_bom.yield_quantity)::numeric, 3)::numeric(18,3) as required_quantity
        from public.bom_lines bl
        where bl.bom_id = v_batch.bom_id
    ), balances as (
        select
            r.component_stock_item_id,
            r.required_quantity,
            coalesce(balance.available_quantity, 0)::numeric(18,3) as available_quantity
        from requirements r
        left join lateral (
            select coalesce(sum(iml.quantity_delta), 0)::numeric(18,3) as available_quantity
            from public.inventory_movements m
            join public.inventory_movement_lines iml
              on iml.movement_id = m.id
            where m.business_id = v_business
              and iml.stock_item_id = r.component_stock_item_id
              and iml.location_id = v_batch.location_id
        ) balance on true
    )
    select count(*)
    into v_shortage_count
    from balances b
    where b.available_quantity < b.required_quantity;

    if v_shortage_count > 0 then
        raise exception using errcode = '23514', message = 'PRODUCTION_STOCK_INSUFFICIENT';
    end if;

    with component_lines as (
        select
            row_number() over (order by bl.line_no, bl.component_stock_item_id)::integer as movement_line_no,
            bl.component_stock_item_id,
            round((bl.base_quantity * p_actual_output / v_bom.yield_quantity)::numeric, 3)::numeric(18,3) as required_quantity
        from public.bom_lines bl
        where bl.bom_id = v_batch.bom_id
    ), all_lines as (
        select
            cl.movement_line_no as line_no,
            cl.component_stock_item_id as stock_item_id,
            v_batch.location_id as location_id,
            (cl.required_quantity * -1)::numeric(18,3) as quantity_delta
        from component_lines cl
        union all
        select
            v_component_count + 1,
            v_batch.finished_good_id,
            v_batch.location_id,
            p_actual_output::numeric(18,3)
    )
    select jsonb_agg(
        jsonb_build_object(
            'line_no', al.line_no,
            'stock_item_id', al.stock_item_id,
            'location_id', al.location_id,
            'quantity_delta', al.quantity_delta
        )
        order by al.line_no
    )
    into v_lines
    from all_lines al;

    v_movement_id := private.record_inventory_movement(
        v_business,
        v_actor,
        'PRODUCTION_POST:' || p_batch_id::text,
        'PRODUCTION',
        'PRODUCTION_BATCH',
        p_batch_id::text,
        'PRODUCTION_POSTED',
        v_lines,
        null
    );

    update public.production_batches
    set status = 'POSTED',
        actual_output = p_actual_output::numeric(18,3),
        inventory_movement_id = v_movement_id,
        posted_by = v_actor,
        posted_at = now(),
        updated_at = now()
    where id = v_batch.id
    returning * into v_batch;

    return jsonb_build_object(
        'success', true,
        'already_posted', false,
        'batch_id', v_batch.id,
        'movement_id', v_batch.inventory_movement_id,
        'actual_output', v_batch.actual_output,
        'status', v_batch.status,
        'bom_id', v_batch.bom_id,
        'location_id', v_batch.location_id
    );
end;
$$;

revoke execute on function public.create_production_batch(uuid, uuid, numeric, text)
from public, anon, authenticated, service_role;

grant execute on function public.create_production_batch(uuid, uuid, numeric, text)
to authenticated;

revoke execute on function public.post_production_batch(uuid, numeric)
from public, anon, authenticated, service_role;

grant execute on function public.post_production_batch(uuid, numeric)
to authenticated;

comment on table public.production_batches is
'CS-06-P6 production batch authority. One bound BOM, one location, one canonical inventory movement after posting.';

comment on function public.create_production_batch(uuid, uuid, numeric, text) is
'CS-06-P6 create DRAFT production batch and bind the currently ACTIVE BOM. Requires PRODUCTION_MANAGE.';

comment on function public.post_production_batch(uuid, numeric) is
'CS-06-P6 atomically consume bound-BOM components and add finished output at one location. Requires PRODUCTION_MANAGE.';
