-- CS-06-P8: Inventory Operational Controls
-- Stock Opname, explicit adjustment/write-off, and compensating reversal.
-- Canonical stock authority remains inventory_movements + inventory_movement_lines.

insert into public.permission_definitions (code, display_name, category, active)
values
    ('INVENTORY_COUNT', 'Stok Opname', 'PERSEDIAAN', true),
    ('INVENTORY_ADJUST', 'Koreksi Persediaan', 'PERSEDIAAN', true)
on conflict (code) do update
set display_name = excluded.display_name,
    category = excluded.category,
    active = true;

create table if not exists public.inventory_counts (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    location_id uuid not null references public.locations(id) on delete restrict,
    status text not null default 'DRAFT',
    notes text,
    snapshot_at timestamptz not null default now(),
    movement_id uuid unique references public.inventory_movements(id) on delete restrict,
    created_by uuid not null references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now(),
    counted_by uuid references public.profiles(id) on delete restrict,
    counted_at timestamptz,
    posted_by uuid references public.profiles(id) on delete restrict,
    posted_at timestamptz,
    updated_at timestamptz not null default now(),
    constraint inventory_counts_status_valid check (
        status in ('DRAFT', 'COUNTED', 'POSTED')
    ),
    constraint inventory_counts_notes_nonempty check (
        notes is null or length(btrim(notes)) > 0
    ),
    constraint inventory_counts_status_fields_valid check (
        (
            status = 'DRAFT'
            and movement_id is null
            and counted_by is null
            and counted_at is null
            and posted_by is null
            and posted_at is null
        )
        or (
            status = 'COUNTED'
            and movement_id is null
            and counted_by is not null
            and counted_at is not null
            and posted_by is null
            and posted_at is null
        )
        or (
            status = 'POSTED'
            and counted_by is not null
            and counted_at is not null
            and posted_by is not null
            and posted_at is not null
        )
    )
);

create table if not exists public.inventory_count_lines (
    count_id uuid not null references public.inventory_counts(id) on delete restrict,
    line_no integer not null,
    stock_item_id uuid not null references public.stock_items(id) on delete restrict,
    expected_quantity numeric(18,3) not null,
    physical_quantity numeric(18,3),
    created_at timestamptz not null default now(),
    primary key (count_id, line_no),
    unique (count_id, stock_item_id),
    constraint inventory_count_lines_line_positive check (line_no > 0),
    constraint inventory_count_lines_physical_nonnegative check (
        physical_quantity is null or physical_quantity >= 0
    )
);

create table if not exists public.inventory_adjustments (
    id uuid primary key,
    business_id uuid not null references public.businesses(id) on delete restrict,
    location_id uuid not null references public.locations(id) on delete restrict,
    stock_item_id uuid not null references public.stock_items(id) on delete restrict,
    adjustment_kind text not null,
    quantity_delta numeric(18,3) not null,
    reason_code text not null,
    note text,
    movement_id uuid not null unique references public.inventory_movements(id) on delete restrict,
    created_by uuid not null references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now(),
    constraint inventory_adjustments_kind_valid check (
        adjustment_kind in ('ADJUSTMENT', 'WRITE_OFF')
    ),
    constraint inventory_adjustments_delta_nonzero check (quantity_delta <> 0),
    constraint inventory_adjustments_writeoff_negative check (
        adjustment_kind <> 'WRITE_OFF' or quantity_delta < 0
    ),
    constraint inventory_adjustments_reason_nonempty check (
        length(btrim(reason_code)) > 0
    ),
    constraint inventory_adjustments_note_nonempty check (
        note is null or length(btrim(note)) > 0
    )
);

create index if not exists inventory_counts_business_location_status_idx
on public.inventory_counts(business_id, location_id, status);

create index if not exists inventory_count_lines_stock_item_idx
on public.inventory_count_lines(stock_item_id);

create index if not exists inventory_adjustments_business_location_created_idx
on public.inventory_adjustments(business_id, location_id, created_at desc);

create index if not exists inventory_adjustments_stock_item_idx
on public.inventory_adjustments(stock_item_id);

alter table public.inventory_counts enable row level security;
alter table public.inventory_count_lines enable row level security;
alter table public.inventory_adjustments enable row level security;

drop policy if exists "Tenant read isolation for inventory_counts" on public.inventory_counts;

create policy "Tenant read isolation for inventory_counts"
on public.inventory_counts
for select
using (business_id = (public.get_my_authority() ->> 'business_id')::uuid);

drop policy if exists "Tenant read isolation for inventory_count_lines" on public.inventory_count_lines;

create policy "Tenant read isolation for inventory_count_lines"
on public.inventory_count_lines
for select
using (
    exists (
        select 1
        from public.inventory_counts c
        where c.id = public.inventory_count_lines.count_id
          and c.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    )
);

drop policy if exists "Tenant read isolation for inventory_adjustments" on public.inventory_adjustments;

create policy "Tenant read isolation for inventory_adjustments"
on public.inventory_adjustments
for select
using (business_id = (public.get_my_authority() ->> 'business_id')::uuid);

revoke all on table public.inventory_counts from public, anon, authenticated;
revoke all on table public.inventory_count_lines from public, anon, authenticated;
revoke all on table public.inventory_adjustments from public, anon, authenticated;

grant select on table public.inventory_counts to authenticated;
grant select on table public.inventory_count_lines to authenticated;
grant select on table public.inventory_adjustments to authenticated;

create or replace function private.guard_inventory_count_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if tg_op = 'DELETE' then
        raise exception using errcode = '55000', message = 'INVENTORY_COUNT_IMMUTABLE';
    end if;

    if new.business_id is distinct from old.business_id
       or new.location_id is distinct from old.location_id
       or new.snapshot_at is distinct from old.snapshot_at
       or new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at then
        raise exception using errcode = '55000', message = 'INVENTORY_COUNT_IMMUTABLE';
    end if;

    if old.status = 'POSTED' then
        raise exception using errcode = '55000', message = 'INVENTORY_COUNT_IMMUTABLE';
    end if;

    if old.status = 'DRAFT' and new.status = 'DRAFT' then
        if new.movement_id is not null
           or new.counted_by is not null
           or new.counted_at is not null
           or new.posted_by is not null
           or new.posted_at is not null then
            raise exception using errcode = '55000', message = 'INVENTORY_COUNT_IMMUTABLE';
        end if;
        return new;
    end if;

    if old.status = 'DRAFT' and new.status = 'COUNTED' then
        if new.movement_id is not null
           or new.counted_by is null
           or new.counted_at is null
           or new.posted_by is not null
           or new.posted_at is not null then
            raise exception using errcode = '55000', message = 'INVENTORY_COUNT_IMMUTABLE';
        end if;
        return new;
    end if;

    if old.status = 'COUNTED' and new.status = 'COUNTED' then
        if new.movement_id is not null
           or new.counted_by is null
           or new.counted_at is null
           or new.posted_by is not null
           or new.posted_at is not null then
            raise exception using errcode = '55000', message = 'INVENTORY_COUNT_IMMUTABLE';
        end if;
        return new;
    end if;

    if old.status = 'COUNTED' and new.status = 'POSTED' then
        if new.counted_by is distinct from old.counted_by
           or new.counted_at is distinct from old.counted_at
           or new.posted_by is null
           or new.posted_at is null then
            raise exception using errcode = '55000', message = 'INVENTORY_COUNT_IMMUTABLE';
        end if;
        return new;
    end if;

    raise exception using errcode = '55000', message = 'INVENTORY_COUNT_IMMUTABLE';
end;
$$;

create or replace function private.guard_inventory_count_line_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_status text;
begin
    if tg_op = 'DELETE' then
        raise exception using errcode = '55000', message = 'INVENTORY_COUNT_IMMUTABLE';
    end if;

    if new.count_id is distinct from old.count_id
       or new.line_no is distinct from old.line_no
       or new.stock_item_id is distinct from old.stock_item_id
       or new.expected_quantity is distinct from old.expected_quantity
       or new.created_at is distinct from old.created_at then
        raise exception using errcode = '55000', message = 'INVENTORY_COUNT_IMMUTABLE';
    end if;

    select c.status
    into v_status
    from public.inventory_counts c
    where c.id = old.count_id;

    if v_status = 'POSTED' then
        raise exception using errcode = '55000', message = 'INVENTORY_COUNT_IMMUTABLE';
    end if;

    return new;
end;
$$;

drop trigger if exists inventory_counts_guard_mutation on public.inventory_counts;

create trigger inventory_counts_guard_mutation
before update or delete on public.inventory_counts
for each row execute function private.guard_inventory_count_mutation();

drop trigger if exists inventory_count_lines_guard_mutation on public.inventory_count_lines;

create trigger inventory_count_lines_guard_mutation
before update or delete on public.inventory_count_lines
for each row execute function private.guard_inventory_count_line_mutation();

drop trigger if exists inventory_adjustments_immutable on public.inventory_adjustments;

create trigger inventory_adjustments_immutable
before update or delete on public.inventory_adjustments
for each row execute function private.prevent_fact_mutation();

create or replace function public.create_inventory_count(
    p_location_id uuid,
    p_stock_item_ids uuid[],
    p_notes text,
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
    v_items uuid[];
    v_item_count integer;
    v_payload jsonb;
    v_payload_hash text;
    v_lock record;
    v_count public.inventory_counts%rowtype;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'INVENTORY_COUNT') then
        raise exception using errcode = '42501', message = 'INVENTORY_COUNT_PERMISSION_DENIED';
    end if;

    v_owner := private.is_owner(v_business);

    if not exists (
        select 1
        from public.locations l
        where l.id = p_location_id
          and l.business_id = v_business
          and l.active
          and l.location_type in ('WAREHOUSE', 'STORE')
    ) then
        raise exception using errcode = '23503', message = 'INVENTORY_COUNT_LOCATION_INVALID';
    end if;

    if not v_owner
       and not private.has_inventory_location_scope(v_business, v_actor, p_location_id) then
        raise exception using errcode = '42501', message = 'INVENTORY_COUNT_SCOPE_DENIED';
    end if;

    if p_stock_item_ids is null or cardinality(p_stock_item_ids) = 0 then
        raise exception using errcode = '22023', message = 'INVENTORY_COUNT_ITEMS_INVALID';
    end if;

    if exists (select 1 from unnest(p_stock_item_ids) item_id where item_id is null) then
        raise exception using errcode = '22023', message = 'INVENTORY_COUNT_ITEMS_INVALID';
    end if;

    select array_agg(item_id order by item_id)
    into v_items
    from (
        select distinct item_id
        from unnest(p_stock_item_ids) item_id
    ) normalized;

    if cardinality(v_items) <> cardinality(p_stock_item_ids) then
        raise exception using errcode = '22023', message = 'INVENTORY_COUNT_ITEMS_INVALID';
    end if;

    select count(*)
    into v_item_count
    from public.stock_items si
    where si.business_id = v_business
      and si.active
      and si.id = any(v_items);

    if v_item_count <> cardinality(v_items) then
        raise exception using errcode = '23503', message = 'INVENTORY_COUNT_ITEM_INVALID';
    end if;

    if p_notes is not null and length(btrim(p_notes)) = 0 then
        raise exception using errcode = '22023', message = 'INVENTORY_COUNT_NOTE_INVALID';
    end if;

    v_payload := jsonb_build_object(
        'location_id', p_location_id,
        'stock_item_ids', to_jsonb(v_items),
        'notes', p_notes
    );
    v_payload_hash := private.payload_sha256(v_payload);

    select *
    into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'INVENTORY_COUNT_CREATE',
        v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'INVENTORY_COUNT' then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_RESULT_TYPE_MISMATCH';
        end if;

        select *
        into v_count
        from public.inventory_counts c
        where c.id = v_lock.result_id
          and c.business_id = v_business;

        if not found then
            raise exception using errcode = 'P0002', message = 'INVENTORY_COUNT_NOT_FOUND';
        end if;

        return jsonb_build_object(
            'success', true,
            'replay', true,
            'count_id', v_count.id,
            'status', v_count.status,
            'location_id', v_count.location_id
        );
    end if;

    perform si.id
    from public.stock_items si
    where si.business_id = v_business
      and si.id = any(v_items)
    order by si.id
    for update of si;

    insert into public.inventory_counts (
        business_id,
        location_id,
        notes,
        created_by
    ) values (
        v_business,
        p_location_id,
        p_notes,
        v_actor
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
          and iml.location_id = p_location_id
    ) current_balance on true
    where si.business_id = v_business
      and si.id = any(v_items)
    order by si.id;

    perform private.record_operation_success(
        v_business,
        p_idempotency_key,
        'INVENTORY_COUNT_CREATE',
        v_payload_hash,
        'INVENTORY_COUNT',
        v_count.id,
        v_actor
    );

    return jsonb_build_object(
        'success', true,
        'replay', false,
        'count_id', v_count.id,
        'status', v_count.status,
        'location_id', v_count.location_id
    );
end;
$$;

create or replace function public.record_inventory_count(
    p_count_id uuid,
    p_lines jsonb
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
    v_count public.inventory_counts%rowtype;
    v_line jsonb;
    v_item uuid;
    v_physical numeric;
    v_seen uuid[] := array[]::uuid[];
    v_expected_lines integer;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'INVENTORY_COUNT') then
        raise exception using errcode = '42501', message = 'INVENTORY_COUNT_PERMISSION_DENIED';
    end if;

    v_owner := private.is_owner(v_business);

    select *
    into v_count
    from public.inventory_counts c
    where c.id = p_count_id
      and c.business_id = v_business
    for update;

    if not found then
        raise exception using errcode = 'P0002', message = 'INVENTORY_COUNT_NOT_FOUND';
    end if;

    if not v_owner
       and not private.has_inventory_location_scope(v_business, v_actor, v_count.location_id) then
        raise exception using errcode = '42501', message = 'INVENTORY_COUNT_SCOPE_DENIED';
    end if;

    if v_count.status = 'POSTED' then
        raise exception using errcode = '55000', message = 'INVENTORY_COUNT_IMMUTABLE';
    end if;

    if p_lines is null
       or jsonb_typeof(p_lines) <> 'array'
       or jsonb_array_length(p_lines) = 0 then
        raise exception using errcode = '22023', message = 'INVENTORY_COUNT_LINES_INVALID';
    end if;

    select count(*)
    into v_expected_lines
    from public.inventory_count_lines l
    where l.count_id = v_count.id;

    if jsonb_array_length(p_lines) <> v_expected_lines then
        raise exception using errcode = '22023', message = 'INVENTORY_COUNT_LINES_INVALID';
    end if;

    for v_line in
        select value
        from jsonb_array_elements(p_lines)
    loop
        if jsonb_typeof(v_line) <> 'object'
           or not (v_line ? 'stock_item_id')
           or not (v_line ? 'physical_quantity') then
            raise exception using errcode = '22023', message = 'INVENTORY_COUNT_LINES_INVALID';
        end if;

        begin
            v_item := nullif(v_line ->> 'stock_item_id', '')::uuid;
            v_physical := nullif(v_line ->> 'physical_quantity', '')::numeric;
        exception when others then
            raise exception using errcode = '22023', message = 'INVENTORY_COUNT_LINES_INVALID';
        end;

        if v_item is null
           or v_physical is null
           or lower(v_physical::text) in ('nan', 'infinity', '-infinity')
           or v_physical < 0
           or v_physical <> round(v_physical, 3)
           or v_item = any(v_seen) then
            raise exception using errcode = '22023', message = 'INVENTORY_COUNT_LINES_INVALID';
        end if;

        if not exists (
            select 1
            from public.inventory_count_lines l
            where l.count_id = v_count.id
              and l.stock_item_id = v_item
        ) then
            raise exception using errcode = '23503', message = 'INVENTORY_COUNT_ITEM_INVALID';
        end if;

        update public.inventory_count_lines
        set physical_quantity = v_physical
        where count_id = v_count.id
          and stock_item_id = v_item;

        v_seen := array_append(v_seen, v_item);
    end loop;

    if cardinality(v_seen) <> v_expected_lines then
        raise exception using errcode = '22023', message = 'INVENTORY_COUNT_LINES_INVALID';
    end if;

    update public.inventory_counts
    set status = 'COUNTED',
        counted_by = v_actor,
        counted_at = now(),
        updated_at = now()
    where id = v_count.id
    returning * into v_count;

    return jsonb_build_object(
        'success', true,
        'count_id', v_count.id,
        'status', v_count.status,
        'counted_at', v_count.counted_at
    );
end;
$$;

create or replace function public.post_inventory_count(
    p_count_id uuid
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
    v_count public.inventory_counts%rowtype;
    v_changed integer;
    v_lines jsonb;
    v_movement_id uuid;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'INVENTORY_COUNT') then
        raise exception using errcode = '42501', message = 'INVENTORY_COUNT_PERMISSION_DENIED';
    end if;

    v_owner := private.is_owner(v_business);

    select *
    into v_count
    from public.inventory_counts c
    where c.id = p_count_id
      and c.business_id = v_business
    for update;

    if not found then
        raise exception using errcode = 'P0002', message = 'INVENTORY_COUNT_NOT_FOUND';
    end if;

    if not v_owner
       and not private.has_inventory_location_scope(v_business, v_actor, v_count.location_id) then
        raise exception using errcode = '42501', message = 'INVENTORY_COUNT_SCOPE_DENIED';
    end if;

    if v_count.status = 'POSTED' then
        return jsonb_build_object(
            'success', true,
            'already_posted', true,
            'count_id', v_count.id,
            'movement_id', v_count.movement_id,
            'status', v_count.status
        );
    end if;

    if v_count.status <> 'COUNTED' then
        raise exception using errcode = '55000', message = 'INVENTORY_COUNT_NOT_COUNTED';
    end if;

    if exists (
        select 1
        from public.inventory_count_lines l
        where l.count_id = v_count.id
          and l.physical_quantity is null
    ) then
        raise exception using errcode = '22023', message = 'INVENTORY_COUNT_LINES_INVALID';
    end if;

    perform si.id
    from public.inventory_count_lines l
    join public.stock_items si
      on si.id = l.stock_item_id
     and si.business_id = v_business
    where l.count_id = v_count.id
    order by si.id
    for update of si;

    select count(*)
    into v_changed
    from public.inventory_count_lines l
    left join lateral (
        select coalesce(sum(iml.quantity_delta), 0)::numeric(18,3) as quantity
        from public.inventory_movements im
        join public.inventory_movement_lines iml
          on iml.movement_id = im.id
        where im.business_id = v_business
          and iml.stock_item_id = l.stock_item_id
          and iml.location_id = v_count.location_id
    ) current_balance on true
    where l.count_id = v_count.id
      and current_balance.quantity is distinct from l.expected_quantity;

    if v_changed > 0 then
        raise exception using errcode = '40001', message = 'INVENTORY_COUNT_BALANCE_CHANGED';
    end if;

    select jsonb_agg(
        jsonb_build_object(
            'line_no', l.line_no,
            'stock_item_id', l.stock_item_id,
            'location_id', v_count.location_id,
            'quantity_delta', (l.physical_quantity - l.expected_quantity)
        )
        order by l.line_no
    )
    into v_lines
    from public.inventory_count_lines l
    where l.count_id = v_count.id
      and l.physical_quantity <> l.expected_quantity;

    if v_lines is not null and jsonb_array_length(v_lines) > 0 then
        v_movement_id := private.record_inventory_movement(
            v_business,
            v_actor,
            'INVENTORY_COUNT_POST:' || p_count_id::text,
            'STOCK_OPNAME',
            'INVENTORY_COUNT',
            p_count_id::text,
            'INVENTORY_COUNT_VARIANCE',
            v_lines,
            null
        );
    else
        v_movement_id := null;
    end if;

    update public.inventory_counts
    set status = 'POSTED',
        movement_id = v_movement_id,
        posted_by = v_actor,
        posted_at = now(),
        updated_at = now()
    where id = v_count.id
    returning * into v_count;

    return jsonb_build_object(
        'success', true,
        'already_posted', false,
        'zero_variance', v_movement_id is null,
        'count_id', v_count.id,
        'movement_id', v_count.movement_id,
        'status', v_count.status
    );
end;
$$;

create or replace function public.post_inventory_adjustment(
    p_location_id uuid,
    p_stock_item_id uuid,
    p_adjustment_kind text,
    p_quantity_delta numeric,
    p_reason_code text,
    p_note text,
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
    v_kind text;
    v_current numeric(18,3);
    v_payload jsonb;
    v_payload_hash text;
    v_lock record;
    v_adjustment_id uuid;
    v_adjustment public.inventory_adjustments%rowtype;
    v_movement_id uuid;
    v_movement_type text;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'INVENTORY_ADJUST') then
        raise exception using errcode = '42501', message = 'INVENTORY_ADJUST_PERMISSION_DENIED';
    end if;

    v_owner := private.is_owner(v_business);
    v_kind := upper(btrim(coalesce(p_adjustment_kind, '')));

    if v_kind not in ('ADJUSTMENT', 'WRITE_OFF') then
        raise exception using errcode = '22023', message = 'INVENTORY_ADJUSTMENT_KIND_INVALID';
    end if;

    if p_quantity_delta is null
       or lower(p_quantity_delta::text) in ('nan', 'infinity', '-infinity')
       or p_quantity_delta = 0
       or p_quantity_delta <> round(p_quantity_delta, 3) then
        raise exception using errcode = '22023', message = 'INVENTORY_ADJUSTMENT_QUANTITY_INVALID';
    end if;

    if v_kind = 'WRITE_OFF' and p_quantity_delta >= 0 then
        raise exception using errcode = '22023', message = 'INVENTORY_WRITEOFF_MUST_BE_NEGATIVE';
    end if;

    if p_reason_code is null or length(btrim(p_reason_code)) = 0 then
        raise exception using errcode = '22023', message = 'INVENTORY_ADJUSTMENT_REASON_REQUIRED';
    end if;

    if p_note is not null and length(btrim(p_note)) = 0 then
        raise exception using errcode = '22023', message = 'INVENTORY_ADJUSTMENT_NOTE_INVALID';
    end if;

    if not exists (
        select 1
        from public.locations l
        where l.id = p_location_id
          and l.business_id = v_business
          and l.active
          and l.location_type in ('WAREHOUSE', 'STORE')
    ) then
        raise exception using errcode = '23503', message = 'INVENTORY_ADJUSTMENT_LOCATION_INVALID';
    end if;

    if not v_owner
       and not private.has_inventory_location_scope(v_business, v_actor, p_location_id) then
        raise exception using errcode = '42501', message = 'INVENTORY_ADJUST_SCOPE_DENIED';
    end if;

    if not exists (
        select 1
        from public.stock_items si
        where si.id = p_stock_item_id
          and si.business_id = v_business
          and si.active
    ) then
        raise exception using errcode = '23503', message = 'INVENTORY_ADJUSTMENT_ITEM_INVALID';
    end if;

    v_payload := jsonb_build_object(
        'location_id', p_location_id,
        'stock_item_id', p_stock_item_id,
        'adjustment_kind', v_kind,
        'quantity_delta', p_quantity_delta,
        'reason_code', btrim(p_reason_code),
        'note', p_note
    );
    v_payload_hash := private.payload_sha256(v_payload);

    select *
    into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'INVENTORY_ADJUSTMENT_CREATE',
        v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'INVENTORY_ADJUSTMENT' then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_RESULT_TYPE_MISMATCH';
        end if;

        select *
        into v_adjustment
        from public.inventory_adjustments a
        where a.id = v_lock.result_id
          and a.business_id = v_business;

        if not found then
            raise exception using errcode = 'P0002', message = 'INVENTORY_ADJUSTMENT_NOT_FOUND';
        end if;

        return jsonb_build_object(
            'success', true,
            'replay', true,
            'adjustment_id', v_adjustment.id,
            'movement_id', v_adjustment.movement_id,
            'quantity_delta', v_adjustment.quantity_delta
        );
    end if;

    perform si.id
    from public.stock_items si
    where si.id = p_stock_item_id
      and si.business_id = v_business
    for update;

    select coalesce(sum(iml.quantity_delta), 0)::numeric(18,3)
    into v_current
    from public.inventory_movements im
    join public.inventory_movement_lines iml
      on iml.movement_id = im.id
    where im.business_id = v_business
      and iml.stock_item_id = p_stock_item_id
      and iml.location_id = p_location_id;

    if v_current + p_quantity_delta < 0 then
        raise exception using errcode = '23514', message = 'INVENTORY_ADJUSTMENT_NEGATIVE_STOCK';
    end if;

    v_adjustment_id := gen_random_uuid();
    v_movement_type := case
        when v_kind = 'WRITE_OFF' then 'INVENTORY_WRITE_OFF'
        else 'INVENTORY_ADJUSTMENT'
    end;

    v_movement_id := private.record_inventory_movement(
        v_business,
        v_actor,
        'INVENTORY_ADJUSTMENT_POST:' || v_adjustment_id::text,
        v_movement_type,
        'INVENTORY_ADJUSTMENT',
        v_adjustment_id::text,
        upper(btrim(p_reason_code)),
        jsonb_build_array(
            jsonb_build_object(
                'line_no', 1,
                'stock_item_id', p_stock_item_id,
                'location_id', p_location_id,
                'quantity_delta', p_quantity_delta
            )
        ),
        null
    );

    insert into public.inventory_adjustments (
        id,
        business_id,
        location_id,
        stock_item_id,
        adjustment_kind,
        quantity_delta,
        reason_code,
        note,
        movement_id,
        created_by
    ) values (
        v_adjustment_id,
        v_business,
        p_location_id,
        p_stock_item_id,
        v_kind,
        p_quantity_delta,
        upper(btrim(p_reason_code)),
        p_note,
        v_movement_id,
        v_actor
    )
    returning * into v_adjustment;

    perform private.record_operation_success(
        v_business,
        p_idempotency_key,
        'INVENTORY_ADJUSTMENT_CREATE',
        v_payload_hash,
        'INVENTORY_ADJUSTMENT',
        v_adjustment.id,
        v_actor
    );

    return jsonb_build_object(
        'success', true,
        'replay', false,
        'adjustment_id', v_adjustment.id,
        'movement_id', v_adjustment.movement_id,
        'quantity_delta', v_adjustment.quantity_delta
    );
end;
$$;

create or replace function public.reverse_inventory_control(
    p_movement_id uuid,
    p_reason_code text,
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
    v_original public.inventory_movements%rowtype;
    v_location uuid;
    v_location_count integer;
    v_bad_count integer;
    v_payload jsonb;
    v_payload_hash text;
    v_lock record;
    v_lines jsonb;
    v_reversal_id uuid;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'INVENTORY_ADJUST') then
        raise exception using errcode = '42501', message = 'INVENTORY_ADJUST_PERMISSION_DENIED';
    end if;

    if p_reason_code is null or length(btrim(p_reason_code)) = 0 then
        raise exception using errcode = '22023', message = 'INVENTORY_REVERSAL_REASON_REQUIRED';
    end if;

    v_payload := jsonb_build_object(
        'movement_id', p_movement_id,
        'reason_code', upper(btrim(p_reason_code))
    );
    v_payload_hash := private.payload_sha256(v_payload);

    select *
    into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'INVENTORY_CONTROL_REVERSE',
        v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'INVENTORY_MOVEMENT' then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_RESULT_TYPE_MISMATCH';
        end if;

        return jsonb_build_object(
            'success', true,
            'replay', true,
            'original_movement_id', p_movement_id,
            'reversal_movement_id', v_lock.result_id
        );
    end if;

    select *
    into v_original
    from public.inventory_movements im
    where im.id = p_movement_id
      and im.business_id = v_business
      and im.movement_type in (
          'STOCK_OPNAME',
          'INVENTORY_ADJUSTMENT',
          'INVENTORY_WRITE_OFF'
      )
    for update;

    if not found then
        raise exception using errcode = 'P0002', message = 'INVENTORY_CONTROL_MOVEMENT_NOT_FOUND';
    end if;

    if exists (
        select 1
        from public.inventory_movements reversal
        where reversal.business_id = v_business
          and reversal.reverses_movement_id = v_original.id
    ) then
        raise exception using errcode = '55000', message = 'INVENTORY_CONTROL_ALREADY_REVERSED';
    end if;

    select min(iml.location_id::text)::uuid, count(distinct iml.location_id)
    into v_location, v_location_count
    from public.inventory_movement_lines iml
    where iml.movement_id = v_original.id;

    if v_location is null or v_location_count <> 1 then
        raise exception using errcode = '55000', message = 'INVENTORY_CONTROL_LOCATION_INVALID';
    end if;

    v_owner := private.is_owner(v_business);

    if not v_owner
       and not private.has_inventory_location_scope(v_business, v_actor, v_location) then
        raise exception using errcode = '42501', message = 'INVENTORY_ADJUST_SCOPE_DENIED';
    end if;

    perform si.id
    from public.inventory_movement_lines iml
    join public.stock_items si
      on si.id = iml.stock_item_id
     and si.business_id = v_business
    where iml.movement_id = v_original.id
    order by si.id
    for update of si;

    with original_lines as (
        select iml.stock_item_id, iml.location_id, iml.quantity_delta
        from public.inventory_movement_lines iml
        where iml.movement_id = v_original.id
    ),
    current_balances as (
        select
            ol.stock_item_id,
            ol.location_id,
            ol.quantity_delta,
            current_balance.current_quantity
        from original_lines ol
        left join lateral (
            select coalesce(sum(iml.quantity_delta), 0)::numeric(18,3) as current_quantity
            from public.inventory_movements im
            join public.inventory_movement_lines iml
              on iml.movement_id = im.id
            where im.business_id = v_business
              and iml.stock_item_id = ol.stock_item_id
              and iml.location_id = ol.location_id
        ) current_balance on true
    )
    select count(*)
    into v_bad_count
    from current_balances b
    where b.current_quantity - b.quantity_delta < 0;

    if v_bad_count > 0 then
        raise exception using errcode = '23514', message = 'INVENTORY_REVERSAL_NEGATIVE_STOCK';
    end if;

    select jsonb_agg(
        jsonb_build_object(
            'line_no', iml.line_no,
            'stock_item_id', iml.stock_item_id,
            'location_id', iml.location_id,
            'quantity_delta', -iml.quantity_delta
        )
        order by iml.line_no
    )
    into v_lines
    from public.inventory_movement_lines iml
    where iml.movement_id = v_original.id;

    v_reversal_id := private.record_inventory_movement(
        v_business,
        v_actor,
        'INVENTORY_CONTROL_REVERSE_WRITE:' || p_idempotency_key,
        'INVENTORY_REVERSAL',
        'INVENTORY_CONTROL_REVERSAL',
        v_original.id::text,
        upper(btrim(p_reason_code)),
        v_lines,
        v_original.id
    );

    perform private.record_operation_success(
        v_business,
        p_idempotency_key,
        'INVENTORY_CONTROL_REVERSE',
        v_payload_hash,
        'INVENTORY_MOVEMENT',
        v_reversal_id,
        v_actor
    );

    return jsonb_build_object(
        'success', true,
        'replay', false,
        'original_movement_id', v_original.id,
        'reversal_movement_id', v_reversal_id
    );
end;
$$;

revoke all on function private.guard_inventory_count_mutation() from public, anon, authenticated;
revoke all on function private.guard_inventory_count_line_mutation() from public, anon, authenticated;

revoke all on function public.create_inventory_count(uuid, uuid[], text, text) from public, anon;
revoke all on function public.record_inventory_count(uuid, jsonb) from public, anon;
revoke all on function public.post_inventory_count(uuid) from public, anon;
revoke all on function public.post_inventory_adjustment(uuid, uuid, text, numeric, text, text, text) from public, anon;
revoke all on function public.reverse_inventory_control(uuid, text, text) from public, anon;

grant execute on function public.create_inventory_count(uuid, uuid[], text, text) to authenticated;
grant execute on function public.record_inventory_count(uuid, jsonb) to authenticated;
grant execute on function public.post_inventory_count(uuid) to authenticated;
grant execute on function public.post_inventory_adjustment(uuid, uuid, text, numeric, text, text, text) to authenticated;
grant execute on function public.reverse_inventory_control(uuid, text, text) to authenticated;

comment on table public.inventory_counts is
'CS-06-P8 Stock Opname sessions. Expected quantities are immutable server snapshots; stock changes only through canonical inventory movements.';

comment on table public.inventory_adjustments is
'CS-06-P8 immutable inventory adjustment/write-off facts linked to canonical inventory movements.';
