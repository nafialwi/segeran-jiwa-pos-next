create table public.operation_receipts (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    idempotency_key text not null,
    command_type text not null,
    payload_hash text not null,
    result_type text not null,
    result_id uuid not null,
    actor_profile_id uuid references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now(),
    unique (business_id, idempotency_key),
    constraint operation_receipts_key_nonempty check (length(btrim(idempotency_key)) > 0),
    constraint operation_receipts_command_nonempty check (length(btrim(command_type)) > 0),
    constraint operation_receipts_result_type_nonempty check (length(btrim(result_type)) > 0),
    constraint operation_receipts_hash_format check (payload_hash ~ '^[0-9a-f]{64}$')
);

create trigger operation_receipts_immutable
before update or delete on public.operation_receipts
for each row execute function private.prevent_fact_mutation();

create table public.audit_events (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    actor_profile_id uuid references public.profiles(id) on delete restrict,
    operation_receipt_id uuid references public.operation_receipts(id) on delete restrict,
    event_type text not null,
    entity_type text not null,
    entity_id uuid not null,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    constraint audit_events_event_type_nonempty check (length(btrim(event_type)) > 0),
    constraint audit_events_entity_type_nonempty check (length(btrim(entity_type)) > 0)
);

create trigger audit_events_immutable
before update or delete on public.audit_events
for each row execute function private.prevent_fact_mutation();

create or replace function private.payload_sha256(p_payload jsonb)
returns text
language sql
immutable
strict
set search_path = ''
as $$
    select pg_catalog.encode(
        extensions.digest(pg_catalog.convert_to(p_payload::text, 'UTF8'), 'sha256'),
        'hex'
    );
$$;

create or replace function private.lock_operation(
    p_business_id uuid,
    p_idempotency_key text,
    p_command_type text,
    p_payload_hash text
)
returns table (
    replay boolean,
    receipt_id uuid,
    result_type text,
    result_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_existing public.operation_receipts%rowtype;
begin
    if p_business_id is null then
        raise exception using errcode = '22023', message = 'SJ_BUSINESS_REQUIRED';
    end if;

    if p_idempotency_key is null or length(btrim(p_idempotency_key)) = 0 then
        raise exception using errcode = '22023', message = 'SJ_IDEMPOTENCY_KEY_REQUIRED';
    end if;

    if p_command_type is null or length(btrim(p_command_type)) = 0 then
        raise exception using errcode = '22023', message = 'SJ_COMMAND_TYPE_REQUIRED';
    end if;

    if p_payload_hash is null or p_payload_hash !~ '^[0-9a-f]{64}$' then
        raise exception using errcode = '22023', message = 'SJ_PAYLOAD_HASH_INVALID';
    end if;

    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(p_business_id::text || ':' || p_idempotency_key, 0)
    );

    select *
    into v_existing
    from public.operation_receipts
    where business_id = p_business_id
      and idempotency_key = p_idempotency_key;

    if not found then
        return query select false, null::uuid, null::text, null::uuid;
        return;
    end if;

    if v_existing.command_type <> p_command_type
       or v_existing.payload_hash <> p_payload_hash then
        raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
    end if;

    return query
    select true, v_existing.id, v_existing.result_type, v_existing.result_id;
end;
$$;

create or replace function private.record_operation_success(
    p_business_id uuid,
    p_idempotency_key text,
    p_command_type text,
    p_payload_hash text,
    p_result_type text,
    p_result_id uuid,
    p_actor_profile_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_receipt_id uuid;
begin
    insert into public.operation_receipts (
        business_id,
        idempotency_key,
        command_type,
        payload_hash,
        result_type,
        result_id,
        actor_profile_id
    )
    values (
        p_business_id,
        p_idempotency_key,
        p_command_type,
        p_payload_hash,
        p_result_type,
        p_result_id,
        p_actor_profile_id
    )
    returning id into v_receipt_id;

    return v_receipt_id;
end;
$$;