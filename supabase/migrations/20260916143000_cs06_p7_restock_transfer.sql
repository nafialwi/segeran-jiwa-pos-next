-- CS-06-P7: Restock Request & Stock Transfer
-- Request approval stays separate from physical stock transfer. Inventory changes
-- occur only at SHIPPED and RECEIVED through the canonical inventory writer.

insert into public.permission_definitions (code, display_name, category, active)
values ('INVENTORY_REQUEST', 'Minta Restock', 'PERSEDIAAN', true)
on conflict (code) do update
set display_name = excluded.display_name,
    category = excluded.category,
    active = true;

create table public.inventory_location_scopes (
    business_id uuid not null references public.businesses(id) on delete restrict,
    profile_id uuid not null references public.profiles(id) on delete restrict,
    location_id uuid not null references public.locations(id) on delete restrict,
    active boolean not null default true,
    created_by uuid not null references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now(),
    updated_by uuid not null references public.profiles(id) on delete restrict,
    updated_at timestamptz not null default now(),
    primary key (business_id, profile_id, location_id),
    foreign key (business_id, profile_id)
        references public.business_memberships(business_id, profile_id)
        on delete restrict
);

create table public.restock_requests (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    destination_location_id uuid not null references public.locations(id) on delete restrict,
    requester_profile_id uuid not null references public.profiles(id) on delete restrict,
    status text not null default 'DRAFT',
    notes text,
    transfer_id uuid unique,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    submitted_at timestamptz,
    approved_at timestamptz,
    approved_by uuid references public.profiles(id) on delete restrict,
    rejected_at timestamptz,
    rejected_by uuid references public.profiles(id) on delete restrict,
    rejection_reason text,
    constraint restock_requests_status_valid check (
        status in ('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED')
    ),
    constraint restock_requests_rejection_reason_nonempty check (
        rejection_reason is null or length(btrim(rejection_reason)) > 0
    ),
    constraint restock_requests_status_fields_valid check (
        (
            status = 'DRAFT'
            and submitted_at is null
            and approved_at is null
            and approved_by is null
            and rejected_at is null
            and rejected_by is null
            and rejection_reason is null
            and transfer_id is null
        )
        or
        (
            status = 'SUBMITTED'
            and submitted_at is not null
            and approved_at is null
            and approved_by is null
            and rejected_at is null
            and rejected_by is null
            and rejection_reason is null
            and transfer_id is null
        )
        or
        (
            status = 'APPROVED'
            and submitted_at is not null
            and approved_at is not null
            and approved_by is not null
            and rejected_at is null
            and rejected_by is null
            and rejection_reason is null
            and transfer_id is not null
        )
        or
        (
            status = 'REJECTED'
            and submitted_at is not null
            and approved_at is null
            and approved_by is null
            and rejected_at is not null
            and rejected_by is not null
            and rejection_reason is not null
            and transfer_id is null
        )
    )
);

create table public.restock_request_lines (
    id uuid primary key default gen_random_uuid(),
    request_id uuid not null references public.restock_requests(id) on delete restrict,
    line_no integer not null,
    stock_item_id uuid not null references public.stock_items(id) on delete restrict,
    requested_quantity numeric(18,3) not null,
    created_at timestamptz not null default now(),
    constraint restock_request_lines_line_positive check (line_no > 0),
    constraint restock_request_lines_quantity_positive check (requested_quantity > 0),
    constraint restock_request_lines_line_unique unique (request_id, line_no),
    constraint restock_request_lines_item_unique unique (request_id, stock_item_id)
        deferrable initially deferred
);

create table public.stock_transfers (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    source_location_id uuid not null references public.locations(id) on delete restrict,
    destination_location_id uuid not null references public.locations(id) on delete restrict,
    status text not null default 'DRAFT',
    restock_request_id uuid unique references public.restock_requests(id) on delete restrict,
    outbound_movement_id uuid unique references public.inventory_movements(id) on delete restrict,
    inbound_movement_id uuid unique references public.inventory_movements(id) on delete restrict,
    created_by uuid not null references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    shipped_by uuid references public.profiles(id) on delete restrict,
    shipped_at timestamptz,
    received_by uuid references public.profiles(id) on delete restrict,
    received_at timestamptz,
    constraint stock_transfers_locations_different check (source_location_id <> destination_location_id),
    constraint stock_transfers_status_valid check (status in ('DRAFT', 'SHIPPED', 'RECEIVED')),
    constraint stock_transfers_status_fields_valid check (
        (
            status = 'DRAFT'
            and outbound_movement_id is null
            and inbound_movement_id is null
            and shipped_by is null
            and shipped_at is null
            and received_by is null
            and received_at is null
        )
        or
        (
            status = 'SHIPPED'
            and outbound_movement_id is not null
            and inbound_movement_id is null
            and shipped_by is not null
            and shipped_at is not null
            and received_by is null
            and received_at is null
        )
        or
        (
            status = 'RECEIVED'
            and outbound_movement_id is not null
            and inbound_movement_id is not null
            and shipped_by is not null
            and shipped_at is not null
            and received_by is not null
            and received_at is not null
        )
    )
);

create table public.stock_transfer_lines (
    id uuid primary key default gen_random_uuid(),
    transfer_id uuid not null references public.stock_transfers(id) on delete restrict,
    line_no integer not null,
    stock_item_id uuid not null references public.stock_items(id) on delete restrict,
    quantity numeric(18,3) not null,
    created_at timestamptz not null default now(),
    constraint stock_transfer_lines_line_positive check (line_no > 0),
    constraint stock_transfer_lines_quantity_positive check (quantity > 0),
    constraint stock_transfer_lines_line_unique unique (transfer_id, line_no),
    constraint stock_transfer_lines_item_unique unique (transfer_id, stock_item_id)
);

alter table public.restock_requests
    add constraint restock_requests_transfer_fk
    foreign key (transfer_id)
    references public.stock_transfers(id)
    on delete restrict;

create index inventory_location_scopes_profile_idx
    on public.inventory_location_scopes(business_id, profile_id, active);
create index inventory_location_scopes_location_idx
    on public.inventory_location_scopes(business_id, location_id, active);
create index restock_requests_business_status_idx
    on public.restock_requests(business_id, status);
create index restock_requests_destination_idx
    on public.restock_requests(destination_location_id, status);
create index restock_request_lines_request_idx
    on public.restock_request_lines(request_id);
create index stock_transfers_business_status_idx
    on public.stock_transfers(business_id, status);
create index stock_transfers_source_idx
    on public.stock_transfers(source_location_id, status);
create index stock_transfers_destination_idx
    on public.stock_transfers(destination_location_id, status);
create index stock_transfer_lines_transfer_idx
    on public.stock_transfer_lines(transfer_id);

alter table public.inventory_location_scopes enable row level security;
alter table public.restock_requests enable row level security;
alter table public.restock_request_lines enable row level security;
alter table public.stock_transfers enable row level security;
alter table public.stock_transfer_lines enable row level security;

create policy "Tenant read isolation for inventory_location_scopes"
on public.inventory_location_scopes
for select
using (business_id = (public.get_my_authority() ->> 'business_id')::uuid);

create policy "Tenant read isolation for restock_requests"
on public.restock_requests
for select
using (business_id = (public.get_my_authority() ->> 'business_id')::uuid);

create policy "Tenant read isolation for restock_request_lines"
on public.restock_request_lines
for select
using (
    exists (
        select 1
        from public.restock_requests rr
        where rr.id = public.restock_request_lines.request_id
          and rr.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    )
);

create policy "Tenant read isolation for stock_transfers"
on public.stock_transfers
for select
using (business_id = (public.get_my_authority() ->> 'business_id')::uuid);

create policy "Tenant read isolation for stock_transfer_lines"
on public.stock_transfer_lines
for select
using (
    exists (
        select 1
        from public.stock_transfers st
        where st.id = public.stock_transfer_lines.transfer_id
          and st.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    )
);

revoke all on table public.inventory_location_scopes from public, anon, authenticated;
revoke all on table public.restock_requests from public, anon, authenticated;
revoke all on table public.restock_request_lines from public, anon, authenticated;
revoke all on table public.stock_transfers from public, anon, authenticated;
revoke all on table public.stock_transfer_lines from public, anon, authenticated;

grant select on table public.inventory_location_scopes to authenticated;
grant select on table public.restock_requests to authenticated;
grant select on table public.restock_request_lines to authenticated;
grant select on table public.stock_transfers to authenticated;
grant select on table public.stock_transfer_lines to authenticated;

create or replace function private.has_inventory_location_scope(
    p_business_id uuid,
    p_profile_id uuid,
    p_location_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.inventory_location_scopes s
        join public.business_memberships m
          on m.business_id = s.business_id
         and m.profile_id = s.profile_id
         and m.active
        join public.locations l
          on l.id = s.location_id
         and l.business_id = s.business_id
         and l.active
        where s.business_id = p_business_id
          and s.profile_id = p_profile_id
          and s.location_id = p_location_id
          and s.active
    );
$$;

create or replace function private.guard_inventory_location_scope_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if tg_op = 'DELETE' then
        raise exception using errcode = '55000', message = 'TRANSFER_IMMUTABLE';
    end if;

    if new.business_id is distinct from old.business_id
       or new.profile_id is distinct from old.profile_id
       or new.location_id is distinct from old.location_id
       or new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at then
        raise exception using errcode = '55000', message = 'TRANSFER_IMMUTABLE';
    end if;

    return new;
end;
$$;

create trigger inventory_location_scopes_guard_mutation
before update or delete on public.inventory_location_scopes
for each row execute function private.guard_inventory_location_scope_mutation();

create or replace function public.set_inventory_location_scope(
    p_profile_id uuid,
    p_location_id uuid,
    p_allowed boolean
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
    v_scope public.inventory_location_scopes%rowtype;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.is_owner(v_business) then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if p_allowed is null then
        raise exception using errcode = '22023', message = 'TRANSFER_SCOPE_DENIED';
    end if;

    if not exists (
        select 1
        from public.business_memberships m
        join public.profiles p on p.id = m.profile_id
        where m.business_id = v_business
          and m.profile_id = p_profile_id
          and m.active
          and p.status = 'ACTIVE'
    ) then
        raise exception using errcode = '23503', message = 'TRANSFER_SCOPE_DENIED';
    end if;

    if not exists (
        select 1
        from public.locations l
        where l.id = p_location_id
          and l.business_id = v_business
          and l.active
          and l.location_type in ('WAREHOUSE', 'STORE')
    ) then
        raise exception using errcode = '23503', message = 'TRANSFER_LOCATION_INVALID';
    end if;

    insert into public.inventory_location_scopes (
        business_id,
        profile_id,
        location_id,
        active,
        created_by,
        updated_by
    ) values (
        v_business,
        p_profile_id,
        p_location_id,
        p_allowed,
        v_actor,
        v_actor
    )
    on conflict (business_id, profile_id, location_id) do update
    set active = excluded.active,
        updated_by = excluded.updated_by,
        updated_at = now()
    returning * into v_scope;

    return jsonb_build_object(
        'success', true,
        'business_id', v_scope.business_id,
        'profile_id', v_scope.profile_id,
        'location_id', v_scope.location_id,
        'active', v_scope.active,
        'updated_by', v_scope.updated_by,
        'updated_at', v_scope.updated_at
    );
end;
$$;

create or replace function private.guard_restock_request_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if tg_op = 'DELETE' then
        raise exception using errcode = '55000', message = 'RESTOCK_IMMUTABLE';
    end if;

    if new.business_id is distinct from old.business_id
       or new.requester_profile_id is distinct from old.requester_profile_id
       or new.created_at is distinct from old.created_at
       or new.submitted_at is distinct from old.submitted_at and not (old.status = 'DRAFT' and new.status = 'SUBMITTED') then
        raise exception using errcode = '55000', message = 'RESTOCK_IMMUTABLE';
    end if;

    if old.status = 'DRAFT' and new.status = 'DRAFT' then
        if new.transfer_id is not null
           or new.approved_at is not null
           or new.approved_by is not null
           or new.rejected_at is not null
           or new.rejected_by is not null
           or new.rejection_reason is not null then
            raise exception using errcode = '55000', message = 'RESTOCK_IMMUTABLE';
        end if;
        return new;
    end if;

    if old.status = 'DRAFT' and new.status = 'SUBMITTED' then
        if new.destination_location_id is distinct from old.destination_location_id
           or new.notes is distinct from old.notes
           or new.submitted_at is null
           or new.transfer_id is not null
           or new.approved_at is not null
           or new.approved_by is not null
           or new.rejected_at is not null
           or new.rejected_by is not null
           or new.rejection_reason is not null then
            raise exception using errcode = '55000', message = 'RESTOCK_IMMUTABLE';
        end if;
        return new;
    end if;

    if old.status = 'SUBMITTED' and new.status = 'APPROVED' then
        if new.destination_location_id is distinct from old.destination_location_id
           or new.notes is distinct from old.notes
           or new.submitted_at is distinct from old.submitted_at
           or new.transfer_id is null
           or new.approved_at is null
           or new.approved_by is null
           or new.rejected_at is not null
           or new.rejected_by is not null
           or new.rejection_reason is not null then
            raise exception using errcode = '55000', message = 'RESTOCK_IMMUTABLE';
        end if;
        return new;
    end if;

    if old.status = 'SUBMITTED' and new.status = 'REJECTED' then
        if new.destination_location_id is distinct from old.destination_location_id
           or new.notes is distinct from old.notes
           or new.submitted_at is distinct from old.submitted_at
           or new.transfer_id is not null
           or new.approved_at is not null
           or new.approved_by is not null
           or new.rejected_at is null
           or new.rejected_by is null
           or new.rejection_reason is null
           or length(btrim(new.rejection_reason)) = 0 then
            raise exception using errcode = '55000', message = 'RESTOCK_IMMUTABLE';
        end if;
        return new;
    end if;

    raise exception using errcode = '55000', message = 'RESTOCK_IMMUTABLE';
end;
$$;

create or replace function private.guard_restock_request_line_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_request_id uuid;
    v_status text;
begin
    v_request_id := case when tg_op = 'DELETE' then old.request_id else new.request_id end;

    select rr.status
    into v_status
    from public.restock_requests rr
    where rr.id = v_request_id;

    if v_status is distinct from 'DRAFT' then
        raise exception using errcode = '55000', message = 'RESTOCK_IMMUTABLE';
    end if;

    if tg_op = 'UPDATE' and new.request_id is distinct from old.request_id then
        raise exception using errcode = '55000', message = 'RESTOCK_IMMUTABLE';
    end if;

    if tg_op = 'DELETE' then
        return old;
    end if;

    return new;
end;
$$;

create or replace function private.guard_stock_transfer_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if tg_op = 'DELETE' then
        raise exception using errcode = '55000', message = 'TRANSFER_IMMUTABLE';
    end if;

    if new.business_id is distinct from old.business_id
       or new.source_location_id is distinct from old.source_location_id
       or new.destination_location_id is distinct from old.destination_location_id
       or new.restock_request_id is distinct from old.restock_request_id
       or new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at then
        raise exception using errcode = '55000', message = 'TRANSFER_IMMUTABLE';
    end if;

    if old.status = 'DRAFT' and new.status = 'SHIPPED' then
        if new.outbound_movement_id is null
           or new.inbound_movement_id is not null
           or new.shipped_by is null
           or new.shipped_at is null
           or new.received_by is not null
           or new.received_at is not null then
            raise exception using errcode = '55000', message = 'TRANSFER_IMMUTABLE';
        end if;
        return new;
    end if;

    if old.status = 'SHIPPED' and new.status = 'RECEIVED' then
        if new.outbound_movement_id is distinct from old.outbound_movement_id
           or new.shipped_by is distinct from old.shipped_by
           or new.shipped_at is distinct from old.shipped_at
           or new.inbound_movement_id is null
           or new.received_by is null
           or new.received_at is null then
            raise exception using errcode = '55000', message = 'TRANSFER_IMMUTABLE';
        end if;
        return new;
    end if;

    raise exception using errcode = '55000', message = 'TRANSFER_IMMUTABLE';
end;
$$;

create or replace function private.guard_stock_transfer_line_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_transfer_id uuid;
    v_status text;
begin
    v_transfer_id := case when tg_op = 'DELETE' then old.transfer_id else new.transfer_id end;

    select st.status
    into v_status
    from public.stock_transfers st
    where st.id = v_transfer_id;

    if v_status is distinct from 'DRAFT' then
        raise exception using errcode = '55000', message = 'TRANSFER_IMMUTABLE';
    end if;

    if tg_op = 'UPDATE' and new.transfer_id is distinct from old.transfer_id then
        raise exception using errcode = '55000', message = 'TRANSFER_IMMUTABLE';
    end if;

    if tg_op = 'DELETE' then
        return old;
    end if;

    return new;
end;
$$;

create trigger restock_requests_guard_mutation
before update or delete on public.restock_requests
for each row execute function private.guard_restock_request_mutation();

create trigger restock_request_lines_guard_mutation
before update or delete on public.restock_request_lines
for each row execute function private.guard_restock_request_line_mutation();

create trigger stock_transfers_guard_mutation
before update or delete on public.stock_transfers
for each row execute function private.guard_stock_transfer_mutation();

create trigger stock_transfer_lines_guard_mutation
before update or delete on public.stock_transfer_lines
for each row execute function private.guard_stock_transfer_line_mutation();

create or replace function public.save_restock_request(
    p_request_id uuid,
    p_destination_location_id uuid,
    p_lines jsonb,
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
    v_payload jsonb;
    v_payload_hash text;
    v_lock record;
    v_request public.restock_requests%rowtype;
    v_line jsonb;
    v_ordinality bigint;
    v_item uuid;
    v_quantity numeric;
    v_seen_items uuid[] := array[]::uuid[];
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'INVENTORY_REQUEST') then
        raise exception using errcode = '42501', message = 'RESTOCK_PERMISSION_DENIED';
    end if;

    v_owner := private.is_owner(v_business);

    if not exists (
        select 1
        from public.locations l
        where l.id = p_destination_location_id
          and l.business_id = v_business
          and l.active
          and l.location_type in ('WAREHOUSE', 'STORE')
    ) then
        raise exception using errcode = '23503', message = 'RESTOCK_REQUEST_INVALID';
    end if;

    if not v_owner and not private.has_inventory_location_scope(v_business, v_actor, p_destination_location_id) then
        raise exception using errcode = '42501', message = 'RESTOCK_SCOPE_DENIED';
    end if;

    if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
        raise exception using errcode = '22023', message = 'RESTOCK_REQUEST_INVALID';
    end if;

    for v_line, v_ordinality in
        select value, ordinality
        from jsonb_array_elements(p_lines) with ordinality
    loop
        if jsonb_typeof(v_line) <> 'object'
           or not (v_line ? 'stock_item_id')
           or not (v_line ? 'quantity') then
            raise exception using errcode = '22023', message = 'RESTOCK_REQUEST_INVALID';
        end if;

        begin
            v_item := nullif(v_line ->> 'stock_item_id', '')::uuid;
            v_quantity := nullif(v_line ->> 'quantity', '')::numeric;
        exception when others then
            raise exception using errcode = '22023', message = 'RESTOCK_REQUEST_INVALID';
        end;

        if v_item is null
           or v_quantity is null
           or lower(v_quantity::text) in ('nan', 'infinity', '-infinity')
           or v_quantity <= 0
           or v_quantity <> round(v_quantity, 3) then
            raise exception using errcode = '22023', message = 'RESTOCK_REQUEST_INVALID';
        end if;

        if v_item = any(v_seen_items) then
            raise exception using errcode = '22023', message = 'RESTOCK_REQUEST_INVALID';
        end if;
        v_seen_items := array_append(v_seen_items, v_item);

        if not exists (
            select 1
            from public.stock_items si
            where si.id = v_item
              and si.business_id = v_business
              and si.active
        ) then
            raise exception using errcode = '23503', message = 'RESTOCK_REQUEST_INVALID';
        end if;
    end loop;

    v_payload := jsonb_build_object(
        'request_id', p_request_id,
        'destination_location_id', p_destination_location_id,
        'lines', p_lines,
        'notes', p_notes
    );
    v_payload_hash := private.payload_sha256(v_payload);

    select *
    into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'RESTOCK_REQUEST_SAVE',
        v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'RESTOCK_REQUEST' then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_RESULT_TYPE_MISMATCH';
        end if;

        select *
        into v_request
        from public.restock_requests rr
        where rr.id = v_lock.result_id
          and rr.business_id = v_business;

        if not found then
            raise exception using errcode = 'P0002', message = 'RESTOCK_REQUEST_NOT_FOUND';
        end if;

        return jsonb_build_object(
            'success', true,
            'replay', true,
            'request_id', v_request.id,
            'status', v_request.status,
            'destination_location_id', v_request.destination_location_id
        );
    end if;

    if p_request_id is null then
        insert into public.restock_requests (
            business_id,
            destination_location_id,
            requester_profile_id,
            notes
        ) values (
            v_business,
            p_destination_location_id,
            v_actor,
            nullif(btrim(p_notes), '')
        )
        returning * into v_request;
    else
        select *
        into v_request
        from public.restock_requests rr
        where rr.id = p_request_id
          and rr.business_id = v_business
        for update;

        if not found then
            raise exception using errcode = 'P0002', message = 'RESTOCK_REQUEST_NOT_FOUND';
        end if;

        if v_request.requester_profile_id <> v_actor then
            raise exception using errcode = '42501', message = 'RESTOCK_PERMISSION_DENIED';
        end if;

        if v_request.status <> 'DRAFT' then
            raise exception using errcode = '55000', message = 'RESTOCK_REQUEST_NOT_DRAFT';
        end if;

        update public.restock_requests
        set destination_location_id = p_destination_location_id,
            notes = nullif(btrim(p_notes), ''),
            updated_at = now()
        where id = v_request.id
        returning * into v_request;
    end if;

    merge into public.restock_request_lines as target
    using (
        select
            v_request.id as request_id,
            incoming.ordinality::integer as line_no,
            (incoming.value ->> 'stock_item_id')::uuid as stock_item_id,
            round((incoming.value ->> 'quantity')::numeric, 3)::numeric(18,3) as requested_quantity,
            true as keep_line
        from jsonb_array_elements(p_lines) with ordinality as incoming(value, ordinality)

        union all

        select
            existing.request_id,
            existing.line_no,
            existing.stock_item_id,
            existing.requested_quantity,
            false as keep_line
        from public.restock_request_lines existing
        where existing.request_id = v_request.id
          and existing.line_no > jsonb_array_length(p_lines)
    ) as source
    on target.request_id = source.request_id
       and target.line_no = source.line_no
    when matched and source.keep_line then
        update set
            stock_item_id = source.stock_item_id,
            requested_quantity = source.requested_quantity
    when matched and not source.keep_line then
        delete
    when not matched and source.keep_line then
        insert (request_id, line_no, stock_item_id, requested_quantity)
        values (source.request_id, source.line_no, source.stock_item_id, source.requested_quantity);

    perform private.record_operation_success(
        v_business,
        p_idempotency_key,
        'RESTOCK_REQUEST_SAVE',
        v_payload_hash,
        'RESTOCK_REQUEST',
        v_request.id,
        v_actor
    );

    return jsonb_build_object(
        'success', true,
        'replay', false,
        'request_id', v_request.id,
        'status', v_request.status,
        'destination_location_id', v_request.destination_location_id
    );
end;
$$;

create or replace function public.submit_restock_request(
    p_request_id uuid
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
    v_request public.restock_requests%rowtype;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'INVENTORY_REQUEST') then
        raise exception using errcode = '42501', message = 'RESTOCK_PERMISSION_DENIED';
    end if;

    v_owner := private.is_owner(v_business);

    select *
    into v_request
    from public.restock_requests rr
    where rr.id = p_request_id
      and rr.business_id = v_business
    for update;

    if not found then
        raise exception using errcode = 'P0002', message = 'RESTOCK_REQUEST_NOT_FOUND';
    end if;

    if not v_owner and v_request.requester_profile_id <> v_actor then
        raise exception using errcode = '42501', message = 'RESTOCK_PERMISSION_DENIED';
    end if;

    if not v_owner and not private.has_inventory_location_scope(v_business, v_actor, v_request.destination_location_id) then
        raise exception using errcode = '42501', message = 'RESTOCK_SCOPE_DENIED';
    end if;

    if v_request.status = 'SUBMITTED' then
        return jsonb_build_object(
            'success', true,
            'already_submitted', true,
            'request_id', v_request.id,
            'status', v_request.status
        );
    end if;

    if v_request.status in ('APPROVED', 'REJECTED') then
        raise exception using errcode = '55000', message = 'RESTOCK_REQUEST_ALREADY_RESOLVED';
    end if;

    if v_request.status <> 'DRAFT' then
        raise exception using errcode = '55000', message = 'RESTOCK_REQUEST_NOT_DRAFT';
    end if;

    if not exists (
        select 1
        from public.restock_request_lines rrl
        where rrl.request_id = v_request.id
    ) then
        raise exception using errcode = '22023', message = 'RESTOCK_REQUEST_EMPTY';
    end if;

    update public.restock_requests
    set status = 'SUBMITTED',
        submitted_at = now(),
        updated_at = now()
    where id = v_request.id
    returning * into v_request;

    return jsonb_build_object(
        'success', true,
        'already_submitted', false,
        'request_id', v_request.id,
        'status', v_request.status
    );
end;
$$;

create or replace function public.approve_restock_request(
    p_request_id uuid,
    p_source_location_id uuid,
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
    v_payload jsonb;
    v_payload_hash text;
    v_lock record;
    v_request public.restock_requests%rowtype;
    v_transfer public.stock_transfers%rowtype;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'INVENTORY_TRANSFER') then
        raise exception using errcode = '42501', message = 'TRANSFER_PERMISSION_DENIED';
    end if;

    v_owner := private.is_owner(v_business);
    v_payload := jsonb_build_object(
        'request_id', p_request_id,
        'source_location_id', p_source_location_id
    );
    v_payload_hash := private.payload_sha256(v_payload);

    select *
    into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'RESTOCK_REQUEST_APPROVE',
        v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'STOCK_TRANSFER' then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_RESULT_TYPE_MISMATCH';
        end if;

        select *
        into v_transfer
        from public.stock_transfers st
        where st.id = v_lock.result_id
          and st.business_id = v_business;

        if not found then
            raise exception using errcode = 'P0002', message = 'TRANSFER_NOT_FOUND';
        end if;

        if not v_owner and not private.has_inventory_location_scope(v_business, v_actor, v_transfer.source_location_id) then
            raise exception using errcode = '42501', message = 'TRANSFER_SCOPE_DENIED';
        end if;

        return jsonb_build_object(
            'success', true,
            'replay', true,
            'request_id', v_transfer.restock_request_id,
            'transfer_id', v_transfer.id,
            'status', v_transfer.status
        );
    end if;

    select *
    into v_request
    from public.restock_requests rr
    where rr.id = p_request_id
      and rr.business_id = v_business
    for update;

    if not found then
        raise exception using errcode = 'P0002', message = 'RESTOCK_REQUEST_NOT_FOUND';
    end if;

    if v_request.status = 'APPROVED' then
        select *
        into v_transfer
        from public.stock_transfers st
        where st.id = v_request.transfer_id
          and st.business_id = v_business;

        if not found or v_transfer.source_location_id is distinct from p_source_location_id then
            raise exception using errcode = '55000', message = 'RESTOCK_REQUEST_ALREADY_RESOLVED';
        end if;

        if not v_owner and not private.has_inventory_location_scope(v_business, v_actor, v_transfer.source_location_id) then
            raise exception using errcode = '42501', message = 'TRANSFER_SCOPE_DENIED';
        end if;

        perform private.record_operation_success(
            v_business,
            p_idempotency_key,
            'RESTOCK_REQUEST_APPROVE',
            v_payload_hash,
            'STOCK_TRANSFER',
            v_transfer.id,
            v_actor
        );

        return jsonb_build_object(
            'success', true,
            'replay', true,
            'request_id', v_request.id,
            'transfer_id', v_transfer.id,
            'status', v_transfer.status
        );
    end if;

    if v_request.status = 'REJECTED' then
        raise exception using errcode = '55000', message = 'RESTOCK_REQUEST_ALREADY_RESOLVED';
    end if;

    if v_request.status <> 'SUBMITTED' then
        raise exception using errcode = '55000', message = 'RESTOCK_REQUEST_NOT_SUBMITTED';
    end if;

    if not exists (
        select 1
        from public.locations l
        where l.id = p_source_location_id
          and l.business_id = v_business
          and l.active
          and l.location_type in ('WAREHOUSE', 'STORE')
    ) then
        raise exception using errcode = '23503', message = 'TRANSFER_LOCATION_INVALID';
    end if;

    if p_source_location_id = v_request.destination_location_id then
        raise exception using errcode = '23514', message = 'TRANSFER_SAME_LOCATION';
    end if;

    if not v_owner and not private.has_inventory_location_scope(v_business, v_actor, p_source_location_id) then
        raise exception using errcode = '42501', message = 'TRANSFER_SCOPE_DENIED';
    end if;

    insert into public.stock_transfers (
        business_id,
        source_location_id,
        destination_location_id,
        restock_request_id,
        created_by
    ) values (
        v_business,
        p_source_location_id,
        v_request.destination_location_id,
        v_request.id,
        v_actor
    )
    returning * into v_transfer;

    insert into public.stock_transfer_lines (
        transfer_id,
        line_no,
        stock_item_id,
        quantity
    )
    select
        v_transfer.id,
        rrl.line_no,
        rrl.stock_item_id,
        rrl.requested_quantity
    from public.restock_request_lines rrl
    where rrl.request_id = v_request.id
    order by rrl.line_no;

    update public.restock_requests
    set status = 'APPROVED',
        transfer_id = v_transfer.id,
        approved_at = now(),
        approved_by = v_actor,
        updated_at = now()
    where id = v_request.id;

    perform private.record_operation_success(
        v_business,
        p_idempotency_key,
        'RESTOCK_REQUEST_APPROVE',
        v_payload_hash,
        'STOCK_TRANSFER',
        v_transfer.id,
        v_actor
    );

    return jsonb_build_object(
        'success', true,
        'replay', false,
        'request_id', v_request.id,
        'transfer_id', v_transfer.id,
        'status', v_transfer.status
    );
end;
$$;

create or replace function public.reject_restock_request(
    p_request_id uuid,
    p_reason text
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
    v_request public.restock_requests%rowtype;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'INVENTORY_TRANSFER') then
        raise exception using errcode = '42501', message = 'TRANSFER_PERMISSION_DENIED';
    end if;

    if p_reason is null or length(btrim(p_reason)) = 0 then
        raise exception using errcode = '22023', message = 'RESTOCK_REJECTION_REASON_REQUIRED';
    end if;

    select *
    into v_request
    from public.restock_requests rr
    where rr.id = p_request_id
      and rr.business_id = v_business
    for update;

    if not found then
        raise exception using errcode = 'P0002', message = 'RESTOCK_REQUEST_NOT_FOUND';
    end if;

    if v_request.status = 'REJECTED' then
        return jsonb_build_object(
            'success', true,
            'already_rejected', true,
            'request_id', v_request.id,
            'status', v_request.status
        );
    end if;

    if v_request.status = 'APPROVED' then
        raise exception using errcode = '55000', message = 'RESTOCK_REQUEST_ALREADY_RESOLVED';
    end if;

    if v_request.status <> 'SUBMITTED' then
        raise exception using errcode = '55000', message = 'RESTOCK_REQUEST_NOT_SUBMITTED';
    end if;

    update public.restock_requests
    set status = 'REJECTED',
        rejected_at = now(),
        rejected_by = v_actor,
        rejection_reason = btrim(p_reason),
        updated_at = now()
    where id = v_request.id
    returning * into v_request;

    return jsonb_build_object(
        'success', true,
        'already_rejected', false,
        'request_id', v_request.id,
        'status', v_request.status
    );
end;
$$;

create or replace function public.create_stock_transfer(
    p_source_location_id uuid,
    p_destination_location_id uuid,
    p_lines jsonb,
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
    v_payload jsonb;
    v_payload_hash text;
    v_lock record;
    v_transfer public.stock_transfers%rowtype;
    v_line jsonb;
    v_ordinality bigint;
    v_item uuid;
    v_quantity numeric;
    v_seen_items uuid[] := array[]::uuid[];
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'INVENTORY_TRANSFER') then
        raise exception using errcode = '42501', message = 'TRANSFER_PERMISSION_DENIED';
    end if;

    v_owner := private.is_owner(v_business);

    if p_source_location_id = p_destination_location_id then
        raise exception using errcode = '23514', message = 'TRANSFER_SAME_LOCATION';
    end if;

    if (
        select count(*)
        from public.locations l
        where l.id in (p_source_location_id, p_destination_location_id)
          and l.business_id = v_business
          and l.active
          and l.location_type in ('WAREHOUSE', 'STORE')
    ) <> 2 then
        raise exception using errcode = '23503', message = 'TRANSFER_LOCATION_INVALID';
    end if;

    if not v_owner and not private.has_inventory_location_scope(v_business, v_actor, p_source_location_id) then
        raise exception using errcode = '42501', message = 'TRANSFER_SCOPE_DENIED';
    end if;

    if p_lines is null
       or jsonb_typeof(p_lines) <> 'array'
       or jsonb_array_length(p_lines) = 0 then
        raise exception using errcode = '22023', message = 'TRANSFER_QUANTITY_INVALID';
    end if;

    for v_line, v_ordinality in
        select value, ordinality
        from jsonb_array_elements(p_lines) with ordinality
    loop
        if jsonb_typeof(v_line) <> 'object'
           or not (v_line ? 'stock_item_id')
           or not (v_line ? 'quantity') then
            raise exception using errcode = '22023', message = 'TRANSFER_ITEM_INVALID';
        end if;

        begin
            v_item := nullif(v_line ->> 'stock_item_id', '')::uuid;
            v_quantity := nullif(v_line ->> 'quantity', '')::numeric;
        exception when others then
            raise exception using errcode = '22023', message = 'TRANSFER_ITEM_INVALID';
        end;

        if v_item is null then
            raise exception using errcode = '22023', message = 'TRANSFER_ITEM_INVALID';
        end if;

        if v_quantity is null
           or lower(v_quantity::text) in ('nan', 'infinity', '-infinity')
           or v_quantity <= 0
           or v_quantity <> round(v_quantity, 3) then
            raise exception using errcode = '22023', message = 'TRANSFER_QUANTITY_INVALID';
        end if;

        if v_item = any(v_seen_items) then
            raise exception using errcode = '22023', message = 'TRANSFER_ITEM_INVALID';
        end if;
        v_seen_items := array_append(v_seen_items, v_item);

        if not exists (
            select 1
            from public.stock_items si
            where si.id = v_item
              and si.business_id = v_business
              and si.active
        ) then
            raise exception using errcode = '23503', message = 'TRANSFER_ITEM_INVALID';
        end if;
    end loop;

    v_payload := jsonb_build_object(
        'source_location_id', p_source_location_id,
        'destination_location_id', p_destination_location_id,
        'lines', p_lines
    );
    v_payload_hash := private.payload_sha256(v_payload);

    select *
    into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'STOCK_TRANSFER_CREATE',
        v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'STOCK_TRANSFER' then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_RESULT_TYPE_MISMATCH';
        end if;

        select *
        into v_transfer
        from public.stock_transfers st
        where st.id = v_lock.result_id
          and st.business_id = v_business;

        if not found then
            raise exception using errcode = 'P0002', message = 'TRANSFER_NOT_FOUND';
        end if;

        return jsonb_build_object(
            'success', true,
            'replay', true,
            'transfer_id', v_transfer.id,
            'status', v_transfer.status
        );
    end if;

    insert into public.stock_transfers (
        business_id,
        source_location_id,
        destination_location_id,
        created_by
    ) values (
        v_business,
        p_source_location_id,
        p_destination_location_id,
        v_actor
    )
    returning * into v_transfer;

    insert into public.stock_transfer_lines (
        transfer_id,
        line_no,
        stock_item_id,
        quantity
    )
    select
        v_transfer.id,
        incoming.ordinality::integer,
        (incoming.value ->> 'stock_item_id')::uuid,
        round((incoming.value ->> 'quantity')::numeric, 3)::numeric(18,3)
    from jsonb_array_elements(p_lines) with ordinality as incoming(value, ordinality);

    perform private.record_operation_success(
        v_business,
        p_idempotency_key,
        'STOCK_TRANSFER_CREATE',
        v_payload_hash,
        'STOCK_TRANSFER',
        v_transfer.id,
        v_actor
    );

    return jsonb_build_object(
        'success', true,
        'replay', false,
        'transfer_id', v_transfer.id,
        'status', v_transfer.status
    );
end;
$$;

create or replace function public.ship_stock_transfer(
    p_transfer_id uuid
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
    v_transfer public.stock_transfers%rowtype;
    v_shortage_count integer;
    v_lines jsonb;
    v_movement_id uuid;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'INVENTORY_TRANSFER') then
        raise exception using errcode = '42501', message = 'TRANSFER_PERMISSION_DENIED';
    end if;

    v_owner := private.is_owner(v_business);

    select *
    into v_transfer
    from public.stock_transfers st
    where st.id = p_transfer_id
      and st.business_id = v_business
    for update;

    if not found then
        raise exception using errcode = 'P0002', message = 'TRANSFER_NOT_FOUND';
    end if;

    if not v_owner and not private.has_inventory_location_scope(v_business, v_actor, v_transfer.source_location_id) then
        raise exception using errcode = '42501', message = 'TRANSFER_SCOPE_DENIED';
    end if;

    if v_transfer.status in ('SHIPPED', 'RECEIVED') and v_transfer.outbound_movement_id is not null then
        return jsonb_build_object(
            'success', true,
            'already_shipped', true,
            'transfer_id', v_transfer.id,
            'movement_id', v_transfer.outbound_movement_id,
            'status', v_transfer.status
        );
    end if;

    if v_transfer.status <> 'DRAFT' then
        raise exception using errcode = '55000', message = 'TRANSFER_NOT_DRAFT';
    end if;

    if (
        select count(*)
        from public.locations l
        where l.id in (v_transfer.source_location_id, v_transfer.destination_location_id)
          and l.business_id = v_business
          and l.active
          and l.location_type in ('WAREHOUSE', 'STORE')
    ) <> 2 then
        raise exception using errcode = '23503', message = 'TRANSFER_LOCATION_INVALID';
    end if;

    if not exists (
        select 1
        from public.stock_transfer_lines stl
        where stl.transfer_id = v_transfer.id
    ) then
        raise exception using errcode = '22023', message = 'TRANSFER_QUANTITY_INVALID';
    end if;

    perform si.id
    from public.stock_transfer_lines stl
    join public.stock_items si
      on si.id = stl.stock_item_id
     and si.business_id = v_business
    where stl.transfer_id = v_transfer.id
    order by stl.stock_item_id
    for update of si;

    with balances as (
        select
            stl.stock_item_id,
            stl.quantity as required_quantity,
            coalesce(current_balance.available_quantity, 0)::numeric(18,3) as available_quantity
        from public.stock_transfer_lines stl
        left join lateral (
            select coalesce(sum(iml.quantity_delta), 0)::numeric(18,3) as available_quantity
            from public.inventory_movements m
            join public.inventory_movement_lines iml
              on iml.movement_id = m.id
            where m.business_id = v_business
              and iml.stock_item_id = stl.stock_item_id
              and iml.location_id = v_transfer.source_location_id
        ) current_balance on true
        where stl.transfer_id = v_transfer.id
    )
    select count(*)
    into v_shortage_count
    from balances b
    where b.available_quantity < b.required_quantity;

    if v_shortage_count > 0 then
        raise exception using errcode = '23514', message = 'TRANSFER_STOCK_INSUFFICIENT';
    end if;

    select jsonb_agg(
        jsonb_build_object(
            'line_no', stl.line_no,
            'stock_item_id', stl.stock_item_id,
            'location_id', v_transfer.source_location_id,
            'quantity_delta', -stl.quantity
        )
        order by stl.line_no
    )
    into v_lines
    from public.stock_transfer_lines stl
    where stl.transfer_id = v_transfer.id;

    v_movement_id := private.record_inventory_movement(
        v_business,
        v_actor,
        'TRANSFER_SHIP:' || p_transfer_id::text,
        'TRANSFER_OUT',
        'STOCK_TRANSFER',
        p_transfer_id::text,
        'TRANSFER_SHIPPED',
        v_lines,
        null
    );

    update public.stock_transfers
    set status = 'SHIPPED',
        outbound_movement_id = v_movement_id,
        shipped_by = v_actor,
        shipped_at = now(),
        updated_at = now()
    where id = v_transfer.id
    returning * into v_transfer;

    return jsonb_build_object(
        'success', true,
        'already_shipped', false,
        'transfer_id', v_transfer.id,
        'movement_id', v_transfer.outbound_movement_id,
        'status', v_transfer.status
    );
end;
$$;

create or replace function public.receive_stock_transfer(
    p_transfer_id uuid
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
    v_transfer public.stock_transfers%rowtype;
    v_lines jsonb;
    v_movement_id uuid;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'INVENTORY_TRANSFER') then
        raise exception using errcode = '42501', message = 'TRANSFER_PERMISSION_DENIED';
    end if;

    v_owner := private.is_owner(v_business);

    select *
    into v_transfer
    from public.stock_transfers st
    where st.id = p_transfer_id
      and st.business_id = v_business
    for update;

    if not found then
        raise exception using errcode = 'P0002', message = 'TRANSFER_NOT_FOUND';
    end if;

    if not v_owner and not private.has_inventory_location_scope(v_business, v_actor, v_transfer.destination_location_id) then
        raise exception using errcode = '42501', message = 'TRANSFER_SCOPE_DENIED';
    end if;

    if v_transfer.status = 'RECEIVED' and v_transfer.inbound_movement_id is not null then
        return jsonb_build_object(
            'success', true,
            'already_received', true,
            'transfer_id', v_transfer.id,
            'movement_id', v_transfer.inbound_movement_id,
            'status', v_transfer.status
        );
    end if;

    if v_transfer.status <> 'SHIPPED' then
        raise exception using errcode = '55000', message = 'TRANSFER_NOT_SHIPPED';
    end if;

    select jsonb_agg(
        jsonb_build_object(
            'line_no', stl.line_no,
            'stock_item_id', stl.stock_item_id,
            'location_id', v_transfer.destination_location_id,
            'quantity_delta', stl.quantity
        )
        order by stl.line_no
    )
    into v_lines
    from public.stock_transfer_lines stl
    where stl.transfer_id = v_transfer.id;

    if v_lines is null or jsonb_array_length(v_lines) = 0 then
        raise exception using errcode = '22023', message = 'TRANSFER_QUANTITY_INVALID';
    end if;

    v_movement_id := private.record_inventory_movement(
        v_business,
        v_actor,
        'TRANSFER_RECEIVE:' || p_transfer_id::text,
        'TRANSFER_IN',
        'STOCK_TRANSFER',
        p_transfer_id::text,
        'TRANSFER_RECEIVED',
        v_lines,
        null
    );

    update public.stock_transfers
    set status = 'RECEIVED',
        inbound_movement_id = v_movement_id,
        received_by = v_actor,
        received_at = now(),
        updated_at = now()
    where id = v_transfer.id
    returning * into v_transfer;

    return jsonb_build_object(
        'success', true,
        'already_received', false,
        'transfer_id', v_transfer.id,
        'movement_id', v_transfer.inbound_movement_id,
        'status', v_transfer.status
    );
end;
$$;

revoke all on function private.has_inventory_location_scope(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function private.guard_inventory_location_scope_mutation() from public, anon, authenticated;
revoke all on function private.guard_restock_request_mutation() from public, anon, authenticated;
revoke all on function private.guard_restock_request_line_mutation() from public, anon, authenticated;
revoke all on function private.guard_stock_transfer_mutation() from public, anon, authenticated;
revoke all on function private.guard_stock_transfer_line_mutation() from public, anon, authenticated;

revoke all on function public.set_inventory_location_scope(uuid, uuid, boolean) from public, anon;
revoke all on function public.save_restock_request(uuid, uuid, jsonb, text, text) from public, anon;
revoke all on function public.submit_restock_request(uuid) from public, anon;
revoke all on function public.approve_restock_request(uuid, uuid, text) from public, anon;
revoke all on function public.reject_restock_request(uuid, text) from public, anon;
revoke all on function public.create_stock_transfer(uuid, uuid, jsonb, text) from public, anon;
revoke all on function public.ship_stock_transfer(uuid) from public, anon;
revoke all on function public.receive_stock_transfer(uuid) from public, anon;

grant execute on function public.set_inventory_location_scope(uuid, uuid, boolean) to authenticated;
grant execute on function public.save_restock_request(uuid, uuid, jsonb, text, text) to authenticated;
grant execute on function public.submit_restock_request(uuid) to authenticated;
grant execute on function public.approve_restock_request(uuid, uuid, text) to authenticated;
grant execute on function public.reject_restock_request(uuid, text) to authenticated;
grant execute on function public.create_stock_transfer(uuid, uuid, jsonb, text) to authenticated;
grant execute on function public.ship_stock_transfer(uuid) to authenticated;
grant execute on function public.receive_stock_transfer(uuid) to authenticated;
