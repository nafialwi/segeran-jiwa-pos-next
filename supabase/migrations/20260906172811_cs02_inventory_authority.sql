create table public.inventory_movements (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    movement_type text not null,
    source_type text not null,
    source_ref text not null,
    reason_code text not null,
    actor_profile_id uuid references public.profiles(id) on delete restrict,
    reverses_movement_id uuid unique references public.inventory_movements(id) on delete restrict,
    created_at timestamptz not null default now(),
    constraint inventory_movements_type_nonempty check (length(btrim(movement_type)) > 0),
    constraint inventory_movements_source_type_nonempty check (length(btrim(source_type)) > 0),
    constraint inventory_movements_source_ref_nonempty check (length(btrim(source_ref)) > 0),
    constraint inventory_movements_reason_nonempty check (length(btrim(reason_code)) > 0)
);

create trigger inventory_movements_immutable
before update or delete on public.inventory_movements
for each row execute function private.prevent_fact_mutation();

create table public.inventory_movement_lines (
    movement_id uuid not null references public.inventory_movements(id) on delete restrict,
    line_no integer not null,
    stock_item_id uuid not null references public.stock_items(id) on delete restrict,
    location_id uuid not null references public.locations(id) on delete restrict,
    quantity_delta numeric(18, 3) not null,
    primary key (movement_id, line_no),
    constraint inventory_lines_line_positive check (line_no > 0),
    constraint inventory_lines_nonzero check (quantity_delta <> 0)
);

create trigger inventory_movement_lines_immutable
before update or delete on public.inventory_movement_lines
for each row execute function private.prevent_fact_mutation();

create view public.inventory_balances
with (security_invoker = true)
as
select
    m.business_id,
    l.stock_item_id,
    l.location_id,
    sum(l.quantity_delta)::numeric(18, 3) as quantity
from public.inventory_movements m
join public.inventory_movement_lines l
  on l.movement_id = m.id
group by m.business_id, l.stock_item_id, l.location_id;

create or replace function private.record_inventory_movement(
    p_business_id uuid,
    p_actor_profile_id uuid,
    p_idempotency_key text,
    p_movement_type text,
    p_source_type text,
    p_source_ref text,
    p_reason_code text,
    p_lines jsonb,
    p_reverses_movement_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_payload_hash text;
    v_replay record;
    v_movement_id uuid;
    v_receipt_id uuid;
    v_bad_count integer;
begin
    if p_business_id is null then
        raise exception using errcode = '22023', message = 'SJ_BUSINESS_REQUIRED';
    end if;
    if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
        raise exception using errcode = '22023', message = 'SJ_INVENTORY_LINES_REQUIRED';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'business_id', p_business_id,
            'actor_profile_id', p_actor_profile_id,
            'movement_type', p_movement_type,
            'source_type', p_source_type,
            'source_ref', p_source_ref,
            'reason_code', p_reason_code,
            'lines', p_lines,
            'reverses_movement_id', p_reverses_movement_id
        )
    );

    select * into v_replay
    from private.lock_operation(
        p_business_id,
        p_idempotency_key,
        'INVENTORY_MOVEMENT',
        v_payload_hash
    );

    if v_replay.replay then
        if v_replay.result_type <> 'INVENTORY_MOVEMENT' then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_RESULT_TYPE_MISMATCH';
        end if;
        return v_replay.result_id;
    end if;

    if p_reverses_movement_id is not null then
        if not exists (
            select 1
            from public.inventory_movements
            where id = p_reverses_movement_id
              and business_id = p_business_id
        ) then
            raise exception using errcode = '23503', message = 'SJ_REVERSAL_TARGET_INVALID';
        end if;
    end if;

    select count(*) into v_bad_count
    from jsonb_to_recordset(p_lines) as x(
        line_no integer,
        stock_item_id uuid,
        location_id uuid,
        quantity_delta numeric
    )
    left join public.stock_items i
      on i.id = x.stock_item_id and i.business_id = p_business_id
    left join public.locations l
      on l.id = x.location_id and l.business_id = p_business_id
    where x.line_no is null
       or x.line_no <= 0
       or x.stock_item_id is null
       or x.location_id is null
       or x.quantity_delta is null
       or x.quantity_delta = 0
       or i.id is null
       or l.id is null;

    if v_bad_count > 0 then
        raise exception using errcode = '22023', message = 'SJ_INVENTORY_LINE_INVALID';
    end if;

    if (
        select count(*) <> count(distinct x.line_no)
        from jsonb_to_recordset(p_lines) as x(line_no integer)
    ) then
        raise exception using errcode = '22023', message = 'SJ_INVENTORY_LINE_DUPLICATE';
    end if;

    insert into public.inventory_movements (
        business_id,
        movement_type,
        source_type,
        source_ref,
        reason_code,
        actor_profile_id,
        reverses_movement_id
    ) values (
        p_business_id,
        p_movement_type,
        p_source_type,
        p_source_ref,
        p_reason_code,
        p_actor_profile_id,
        p_reverses_movement_id
    ) returning id into v_movement_id;

    insert into public.inventory_movement_lines (
        movement_id,
        line_no,
        stock_item_id,
        location_id,
        quantity_delta
    )
    select
        v_movement_id,
        x.line_no,
        x.stock_item_id,
        x.location_id,
        x.quantity_delta::numeric(18, 3)
    from jsonb_to_recordset(p_lines) as x(
        line_no integer,
        stock_item_id uuid,
        location_id uuid,
        quantity_delta numeric
    );

    v_receipt_id := private.record_operation_success(
        p_business_id,
        p_idempotency_key,
        'INVENTORY_MOVEMENT',
        v_payload_hash,
        'INVENTORY_MOVEMENT',
        v_movement_id,
        p_actor_profile_id
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
        p_business_id,
        p_actor_profile_id,
        v_receipt_id,
        case when p_reverses_movement_id is null then 'INVENTORY_MOVEMENT_RECORDED' else 'INVENTORY_MOVEMENT_REVERSED' end,
        'INVENTORY_MOVEMENT',
        v_movement_id,
        jsonb_build_object('source_type', p_source_type, 'source_ref', p_source_ref, 'reason_code', p_reason_code)
    );

    return v_movement_id;
end;
$$;