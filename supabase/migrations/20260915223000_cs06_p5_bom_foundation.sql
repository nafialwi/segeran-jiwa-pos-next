-- CS-06-P5: BOM Foundation
--
-- Versioned recipe authority for finished goods.
-- P5 defines recipe metadata only and MUST NOT change inventory stock.
-- Production execution and inventory posting belong to a later milestone.

create table public.boms (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    finished_good_id uuid not null references public.stock_items(id) on delete restrict,
    version integer not null,
    status text not null default 'DRAFT',
    yield_quantity numeric(18,3) not null,
    created_by uuid not null references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now(),
    activated_by uuid references public.profiles(id) on delete restrict,
    activated_at timestamptz,
    retired_by uuid references public.profiles(id) on delete restrict,
    retired_at timestamptz,
    updated_at timestamptz not null default now(),
    unique (business_id, finished_good_id, version),
    constraint boms_version_positive check (version > 0),
    constraint boms_yield_positive check (yield_quantity > 0),
    constraint boms_status_valid check (status in ('DRAFT', 'ACTIVE', 'RETIRED'))
);

create index boms_business_id_idx on public.boms(business_id);
create index boms_finished_good_id_idx on public.boms(finished_good_id);
create index boms_status_idx on public.boms(status);
create unique index boms_one_active_per_finished_good_idx
    on public.boms(business_id, finished_good_id)
    where status = 'ACTIVE';

create table public.bom_lines (
    bom_id uuid not null references public.boms(id) on delete cascade,
    line_no integer not null,
    component_stock_item_id uuid not null references public.stock_items(id) on delete restrict,
    base_quantity numeric(18,3) not null,
    created_at timestamptz not null default now(),
    primary key (bom_id, line_no),
    constraint bom_lines_component_unique
        unique (bom_id, component_stock_item_id)
        deferrable initially deferred,
    constraint bom_lines_line_no_positive check (line_no > 0),
    constraint bom_lines_base_quantity_positive check (base_quantity > 0)
);

create index bom_lines_component_stock_item_id_idx
    on public.bom_lines(component_stock_item_id);

alter table public.boms enable row level security;
alter table public.bom_lines enable row level security;

create policy "Tenant read isolation for boms"
on public.boms
for select
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
);

create policy "Tenant read isolation for bom_lines"
on public.bom_lines
for select
using (
    exists (
        select 1
        from public.boms b
        where b.id = bom_id
          and b.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    )
);

revoke all on table public.boms
from public, anon, authenticated;

revoke all on table public.bom_lines
from public, anon, authenticated;

grant select on table public.boms to authenticated;
grant select on table public.bom_lines to authenticated;

create or replace function private.guard_bom_header_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if tg_op = 'DELETE' then
        if old.status <> 'DRAFT' then
            raise exception using errcode = '55000', message = 'BOM_IMMUTABLE';
        end if;
        return old;
    end if;

    if old.status = 'RETIRED' then
        raise exception using errcode = '55000', message = 'BOM_IMMUTABLE';
    end if;

    if old.status = 'ACTIVE' then
        if new.status <> 'RETIRED'
           or new.business_id is distinct from old.business_id
           or new.finished_good_id is distinct from old.finished_good_id
           or new.version is distinct from old.version
           or new.yield_quantity is distinct from old.yield_quantity
           or new.created_by is distinct from old.created_by
           or new.created_at is distinct from old.created_at
           or new.activated_by is distinct from old.activated_by
           or new.activated_at is distinct from old.activated_at
           or new.retired_by is null
           or new.retired_at is null then
            raise exception using errcode = '55000', message = 'BOM_IMMUTABLE';
        end if;
        return new;
    end if;

    if old.status = 'DRAFT' and new.status not in ('DRAFT', 'ACTIVE') then
        raise exception using errcode = '55000', message = 'BOM_IMMUTABLE';
    end if;

    return new;
end;
$$;

create trigger boms_guard_mutation
before update or delete on public.boms
for each row execute function private.guard_bom_header_mutation();

create or replace function private.guard_bom_line_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_bom_id uuid;
    v_status text;
begin
    v_bom_id := case when tg_op = 'DELETE' then old.bom_id else new.bom_id end;

    select b.status
    into v_status
    from public.boms b
    where b.id = v_bom_id;

    if v_status is distinct from 'DRAFT' then
        raise exception using errcode = '55000', message = 'BOM_IMMUTABLE';
    end if;

    if tg_op = 'DELETE' then
        return old;
    end if;
    return new;
end;
$$;

create trigger bom_lines_guard_mutation
before insert or update or delete on public.bom_lines
for each row execute function private.guard_bom_line_mutation();

create or replace function public.save_bom_draft(
    p_finished_good_id uuid,
    p_version integer,
    p_yield_quantity numeric,
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
    v_payload jsonb;
    v_payload_hash text;
    v_lock record;
    v_bom public.boms%rowtype;
    v_line jsonb;
    v_component uuid;
    v_quantity numeric;
    v_seen_components uuid[] := array[]::uuid[];
    v_ordinality bigint;
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
        'finished_good_id', p_finished_good_id,
        'version', p_version,
        'yield_quantity', p_yield_quantity,
        'lines', p_lines
    );
    v_payload_hash := private.payload_sha256(v_payload);

    select *
    into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'BOM_SAVE_DRAFT',
        v_payload_hash
    );

    if v_lock.replay then
        select *
        into v_bom
        from public.boms b
        where b.id = v_lock.result_id
          and b.business_id = v_business;

        if not found then
            raise exception using errcode = 'P0002', message = 'BOM_IDEMPOTENCY_RESULT_MISSING';
        end if;

        return jsonb_build_object(
            'success', true,
            'replay', true,
            'bom_id', v_bom.id,
            'status', v_bom.status,
            'version', v_bom.version
        );
    end if;

    if p_version is null or p_version <= 0 then
        raise exception using errcode = '22023', message = 'BOM_VERSION_INVALID';
    end if;

    if p_yield_quantity is null
       or lower(p_yield_quantity::text) in ('nan', 'infinity', '-infinity')
       or p_yield_quantity <= 0 then
        raise exception using errcode = '22023', message = 'BOM_YIELD_INVALID';
    end if;

    if p_yield_quantity <> round(p_yield_quantity, 3) then
        raise exception using errcode = '22023', message = 'BOM_LEDGER_PRECISION_UNSUPPORTED';
    end if;

    if p_lines is null
       or jsonb_typeof(p_lines) <> 'array'
       or jsonb_array_length(p_lines) = 0 then
        raise exception using errcode = '22023', message = 'BOM_LINES_REQUIRED';
    end if;

    if not exists (
        select 1
        from public.stock_items si
        where si.id = p_finished_good_id
          and si.business_id = v_business
          and si.active
          and si.item_kind = 'FINISHED_GOOD'
    ) then
        if exists (
            select 1
            from public.stock_items si
            where si.id = p_finished_good_id
              and si.business_id <> v_business
        ) then
            raise exception using errcode = '42501', message = 'BOM_CROSS_TENANT';
        end if;

        raise exception using errcode = '22023', message = 'BOM_FINISHED_GOOD_INVALID';
    end if;

    for v_line, v_ordinality in
        select value, ordinality
        from jsonb_array_elements(p_lines) with ordinality
    loop
        if jsonb_typeof(v_line) <> 'object'
           or not (v_line ? 'component_stock_item_id')
           or not (v_line ? 'base_quantity') then
            raise exception using errcode = '22023', message = 'BOM_LINE_INVALID';
        end if;

        begin
            v_component := nullif(v_line ->> 'component_stock_item_id', '')::uuid;
            v_quantity := nullif(v_line ->> 'base_quantity', '')::numeric;
        exception when others then
            raise exception using errcode = '22023', message = 'BOM_LINE_INVALID';
        end;

        if v_component is null or v_quantity is null
           or lower(v_quantity::text) in ('nan', 'infinity', '-infinity')
           or v_quantity <= 0 then
            raise exception using errcode = '22023', message = 'BOM_LINE_INVALID';
        end if;

        if v_quantity <> round(v_quantity, 3) then
            raise exception using errcode = '22023', message = 'BOM_LEDGER_PRECISION_UNSUPPORTED';
        end if;

        if v_component = p_finished_good_id then
            raise exception using errcode = '22023', message = 'BOM_SELF_REFERENCE';
        end if;

        if v_component = any(v_seen_components) then
            raise exception using errcode = '22023', message = 'BOM_DUPLICATE_COMPONENT';
        end if;
        v_seen_components := array_append(v_seen_components, v_component);

        if not exists (
            select 1
            from public.stock_items si
            where si.id = v_component
              and si.business_id = v_business
              and si.active
              and si.item_kind in ('MATERIAL', 'PACKAGING', 'OTHER')
        ) then
            if exists (
                select 1
                from public.stock_items si
                where si.id = v_component
                  and si.business_id <> v_business
            ) then
                raise exception using errcode = '42501', message = 'BOM_CROSS_TENANT';
            end if;

            raise exception using errcode = '22023', message = 'BOM_LINE_INVALID';
        end if;
    end loop;

    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(
            v_business::text || ':BOM:' || p_finished_good_id::text || ':' || p_version::text,
            0
        )
    );

    select *
    into v_bom
    from public.boms b
    where b.business_id = v_business
      and b.finished_good_id = p_finished_good_id
      and b.version = p_version
    for update;

    if found then
        if v_bom.status <> 'DRAFT' then
            raise exception using errcode = '55000', message = 'BOM_NOT_DRAFT';
        end if;

        update public.boms
        set yield_quantity = round(p_yield_quantity, 3),
            updated_at = now()
        where id = v_bom.id
        returning * into v_bom;

    else
        insert into public.boms (
            business_id,
            finished_good_id,
            version,
            status,
            yield_quantity,
            created_by
        ) values (
            v_business,
            p_finished_good_id,
            p_version,
            'DRAFT',
            round(p_yield_quantity, 3),
            v_actor
        )
        returning * into v_bom;
    end if;

    merge into public.bom_lines as target
    using (
        select
            v_bom.id as bom_id,
            incoming.ordinality::integer as line_no,
            (incoming.value ->> 'component_stock_item_id')::uuid as component_stock_item_id,
            round((incoming.value ->> 'base_quantity')::numeric, 3) as base_quantity,
            true as keep_line
        from jsonb_array_elements(p_lines) with ordinality as incoming(value, ordinality)

        union all

        select
            existing.bom_id,
            existing.line_no,
            existing.component_stock_item_id,
            existing.base_quantity,
            false as keep_line
        from public.bom_lines existing
        where existing.bom_id = v_bom.id
          and existing.line_no > jsonb_array_length(p_lines)
    ) as source
    on target.bom_id = source.bom_id
       and target.line_no = source.line_no
    when matched and source.keep_line then
        update set
            component_stock_item_id = source.component_stock_item_id,
            base_quantity = source.base_quantity
    when matched and not source.keep_line then
        delete
    when not matched and source.keep_line then
        insert (bom_id, line_no, component_stock_item_id, base_quantity)
        values (
            source.bom_id,
            source.line_no,
            source.component_stock_item_id,
            source.base_quantity
        );

    perform private.record_operation_success(
        v_business,
        p_idempotency_key,
        'BOM_SAVE_DRAFT',
        v_payload_hash,
        'BOM',
        v_bom.id,
        v_actor
    );

    return jsonb_build_object(
        'success', true,
        'replay', false,
        'bom_id', v_bom.id,
        'status', 'DRAFT',
        'version', v_bom.version
    );
end;
$$;

create or replace function public.activate_bom(
    p_bom_id uuid,
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
    v_retired_bom_id uuid;
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

    v_payload := jsonb_build_object('bom_id', p_bom_id);
    v_payload_hash := private.payload_sha256(v_payload);

    select *
    into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'BOM_ACTIVATE',
        v_payload_hash
    );

    if v_lock.replay then
        select *
        into v_bom
        from public.boms b
        where b.id = v_lock.result_id
          and b.business_id = v_business;

        if not found then
            raise exception using errcode = 'P0002', message = 'BOM_IDEMPOTENCY_RESULT_MISSING';
        end if;

        return jsonb_build_object(
            'success', true,
            'replay', true,
            'bom_id', v_bom.id,
            'status', v_bom.status,
            'version', v_bom.version
        );
    end if;

    select *
    into v_bom
    from public.boms b
    where b.id = p_bom_id
      and b.business_id = v_business;

    if not found then
        if exists (
            select 1
            from public.boms b
            where b.id = p_bom_id
              and b.business_id <> v_business
        ) then
            raise exception using errcode = '42501', message = 'BOM_CROSS_TENANT';
        end if;

        raise exception using errcode = 'P0002', message = 'BOM_NOT_FOUND';
    end if;

    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(
            v_business::text || ':BOM_ACTIVE:' || v_bom.finished_good_id::text,
            0
        )
    );

    select *
    into v_bom
    from public.boms b
    where b.id = p_bom_id
      and b.business_id = v_business
    for update;

    if not found then
        raise exception using errcode = 'P0002', message = 'BOM_NOT_FOUND';
    end if;

    if v_bom.status <> 'DRAFT' then
        raise exception using errcode = '55000', message = 'BOM_NOT_DRAFT';
    end if;

    if not exists (
        select 1
        from public.bom_lines bl
        where bl.bom_id = v_bom.id
    ) then
        raise exception using errcode = '22023', message = 'BOM_LINES_REQUIRED';
    end if;

    if not exists (
        select 1
        from public.stock_items si
        where si.id = v_bom.finished_good_id
          and si.business_id = v_business
          and si.active
          and si.item_kind = 'FINISHED_GOOD'
    ) then
        raise exception using errcode = '22023', message = 'BOM_FINISHED_GOOD_INVALID';
    end if;

    if exists (
        select 1
        from public.bom_lines bl
        left join public.stock_items si
          on si.id = bl.component_stock_item_id
         and si.business_id = v_business
         and si.active
         and si.item_kind in ('MATERIAL', 'PACKAGING', 'OTHER')
        where bl.bom_id = v_bom.id
          and (
              si.id is null
              or bl.component_stock_item_id = v_bom.finished_good_id
              or bl.base_quantity <= 0
              or bl.base_quantity <> round(bl.base_quantity, 3)
          )
    ) then
        raise exception using errcode = '22023', message = 'BOM_LINE_INVALID';
    end if;

    select b.id
    into v_retired_bom_id
    from public.boms b
    where b.business_id = v_business
      and b.finished_good_id = v_bom.finished_good_id
      and b.status = 'ACTIVE'
      and b.id <> v_bom.id
    for update;

    if v_retired_bom_id is not null then
        update public.boms
        set status = 'RETIRED',
            retired_by = v_actor,
            retired_at = now(),
            updated_at = now()
        where id = v_retired_bom_id;
    end if;

    update public.boms
    set status = 'ACTIVE',
        activated_by = v_actor,
        activated_at = now(),
        updated_at = now()
    where id = v_bom.id
    returning * into v_bom;

    perform private.record_operation_success(
        v_business,
        p_idempotency_key,
        'BOM_ACTIVATE',
        v_payload_hash,
        'BOM',
        v_bom.id,
        v_actor
    );

    return jsonb_build_object(
        'success', true,
        'replay', false,
        'bom_id', v_bom.id,
        'status', v_bom.status,
        'version', v_bom.version,
        'retired_bom_id', v_retired_bom_id
    );
end;
$$;

revoke execute on function public.save_bom_draft(uuid, integer, numeric, jsonb, text)
from public, anon, authenticated, service_role;

grant execute on function public.save_bom_draft(uuid, integer, numeric, jsonb, text)
to authenticated;

revoke execute on function public.activate_bom(uuid, text)
from public, anon, authenticated, service_role;

grant execute on function public.activate_bom(uuid, text)
to authenticated;

comment on table public.boms is
'CS-06-P5 versioned BOM recipe authority. Recipe metadata only; no inventory side effects.';

comment on table public.bom_lines is
'CS-06-P5 BOM components expressed in canonical stock-item base quantity.';

comment on function public.save_bom_draft(uuid, integer, numeric, jsonb, text) is
'CS-06-P5 save/replace DRAFT BOM. Requires PRODUCTION_MANAGE. No inventory posting.';

comment on function public.activate_bom(uuid, text) is
'CS-06-P5 activate immutable BOM version and retire previous ACTIVE version. Requires PRODUCTION_MANAGE. No inventory posting.';
