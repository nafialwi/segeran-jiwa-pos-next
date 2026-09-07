create table public.money_movements (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    movement_type text not null,
    from_account_id uuid references public.money_accounts(id) on delete restrict,
    to_account_id uuid references public.money_accounts(id) on delete restrict,
    amount numeric(18, 2) not null,
    source_type text not null,
    source_ref text not null,
    reason_code text not null,
    actor_profile_id uuid references public.profiles(id) on delete restrict,
    reverses_movement_id uuid unique references public.money_movements(id) on delete restrict,
    created_at timestamptz not null default now(),
    constraint money_movements_amount_positive check (amount > 0),
    constraint money_movements_has_direction check (from_account_id is not null or to_account_id is not null),
    constraint money_movements_distinct_accounts check (from_account_id is null or to_account_id is null or from_account_id <> to_account_id),
    constraint money_movements_type_valid check (movement_type in ('INCOME', 'EXPENSE', 'TRANSFER', 'SETTLEMENT', 'OPENING_BALANCE', 'ADJUSTMENT', 'REVERSAL')),
    constraint money_movements_source_type_nonempty check (length(btrim(source_type)) > 0),
    constraint money_movements_source_ref_nonempty check (length(btrim(source_ref)) > 0),
    constraint money_movements_reason_nonempty check (length(btrim(reason_code)) > 0)
);

create trigger money_movements_immutable
before update or delete on public.money_movements
for each row execute function private.prevent_fact_mutation();

create view public.money_balances
with (security_invoker = true)
as
select
    business_id,
    account_id,
    sum(delta)::numeric(18, 2) as balance
from (
    select business_id, to_account_id as account_id, amount as delta
    from public.money_movements
    where to_account_id is not null

    union all

    select business_id, from_account_id as account_id, -amount as delta
    from public.money_movements
    where from_account_id is not null
) x
group by business_id, account_id;

create or replace function private.record_money_movement(
    p_business_id uuid,
    p_actor_profile_id uuid,
    p_idempotency_key text,
    p_movement_type text,
    p_from_account_id uuid,
    p_to_account_id uuid,
    p_amount numeric,
    p_source_type text,
    p_source_ref text,
    p_reason_code text,
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
begin
    if p_business_id is null then
        raise exception using errcode = '22023', message = 'SJ_BUSINESS_REQUIRED';
    end if;
    if p_amount is null or p_amount <= 0 then
        raise exception using errcode = '22023', message = 'SJ_MONEY_AMOUNT_INVALID';
    end if;
    if p_from_account_id is null and p_to_account_id is null then
        raise exception using errcode = '22023', message = 'SJ_MONEY_DIRECTION_REQUIRED';
    end if;
    if p_from_account_id is not null and p_to_account_id is not null and p_from_account_id = p_to_account_id then
        raise exception using errcode = '22023', message = 'SJ_MONEY_ACCOUNTS_MUST_DIFFER';
    end if;
    if p_movement_type not in ('INCOME', 'EXPENSE', 'TRANSFER', 'SETTLEMENT', 'OPENING_BALANCE', 'ADJUSTMENT', 'REVERSAL') then
        raise exception using errcode = '22023', message = 'SJ_MONEY_MOVEMENT_TYPE_INVALID';
    end if;
    if p_movement_type in ('TRANSFER', 'SETTLEMENT') and (p_from_account_id is null or p_to_account_id is null) then
        raise exception using errcode = '22023', message = 'SJ_MONEY_TWO_SIDED_REQUIRED';
    end if;
    if p_movement_type in ('INCOME', 'OPENING_BALANCE') and p_to_account_id is null then
        raise exception using errcode = '22023', message = 'SJ_MONEY_DESTINATION_REQUIRED';
    end if;
    if p_movement_type = 'EXPENSE' and p_from_account_id is null then
        raise exception using errcode = '22023', message = 'SJ_MONEY_SOURCE_REQUIRED';
    end if;

    if p_from_account_id is not null and not exists (
        select 1 from public.money_accounts where id = p_from_account_id and business_id = p_business_id
    ) then
        raise exception using errcode = '23503', message = 'SJ_MONEY_SOURCE_ACCOUNT_INVALID';
    end if;
    if p_to_account_id is not null and not exists (
        select 1 from public.money_accounts where id = p_to_account_id and business_id = p_business_id
    ) then
        raise exception using errcode = '23503', message = 'SJ_MONEY_DESTINATION_ACCOUNT_INVALID';
    end if;

    if p_reverses_movement_id is not null and not exists (
        select 1 from public.money_movements where id = p_reverses_movement_id and business_id = p_business_id
    ) then
        raise exception using errcode = '23503', message = 'SJ_REVERSAL_TARGET_INVALID';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'business_id', p_business_id,
            'actor_profile_id', p_actor_profile_id,
            'movement_type', p_movement_type,
            'from_account_id', p_from_account_id,
            'to_account_id', p_to_account_id,
            'amount', p_amount,
            'source_type', p_source_type,
            'source_ref', p_source_ref,
            'reason_code', p_reason_code,
            'reverses_movement_id', p_reverses_movement_id
        )
    );

    select * into v_replay
    from private.lock_operation(
        p_business_id,
        p_idempotency_key,
        'MONEY_MOVEMENT',
        v_payload_hash
    );

    if v_replay.replay then
        if v_replay.result_type <> 'MONEY_MOVEMENT' then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_RESULT_TYPE_MISMATCH';
        end if;
        return v_replay.result_id;
    end if;

    insert into public.money_movements (
        business_id,
        movement_type,
        from_account_id,
        to_account_id,
        amount,
        source_type,
        source_ref,
        reason_code,
        actor_profile_id,
        reverses_movement_id
    ) values (
        p_business_id,
        p_movement_type,
        p_from_account_id,
        p_to_account_id,
        p_amount::numeric(18, 2),
        p_source_type,
        p_source_ref,
        p_reason_code,
        p_actor_profile_id,
        p_reverses_movement_id
    ) returning id into v_movement_id;

    v_receipt_id := private.record_operation_success(
        p_business_id,
        p_idempotency_key,
        'MONEY_MOVEMENT',
        v_payload_hash,
        'MONEY_MOVEMENT',
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
        case when p_reverses_movement_id is null then 'MONEY_MOVEMENT_RECORDED' else 'MONEY_MOVEMENT_REVERSED' end,
        'MONEY_MOVEMENT',
        v_movement_id,
        jsonb_build_object('source_type', p_source_type, 'source_ref', p_source_ref, 'reason_code', p_reason_code)
    );

    return v_movement_id;
end;
$$;