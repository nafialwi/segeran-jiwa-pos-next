-- FIN-P2A: Shift Funding Bridge
-- Positive opening cash must have an explicit source and canonical money movement.

alter table public.shifts
    add column if not exists opening_source_type text,
    add column if not exists opening_source_ref text,
    add column if not exists opening_money_movement_id uuid unique
        references public.money_movements(id) on delete restrict;

alter table public.shifts
    drop constraint if exists shifts_opening_source_type_valid;

alter table public.shifts
    add constraint shifts_opening_source_type_valid check (
        opening_source_type is null
        or opening_source_type in ('ZERO', 'KAS_UTAMA', 'HANDOVER', 'OWNER_CAPITAL', 'OTHER')
    );

create or replace function public.cs05_open_my_shift(
    p_location uuid,
    p_opening numeric,
    p_config jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor uuid;
    v_business uuid;
    v_shift uuid;
begin
    perform private.cs05_require_shift_permission();
    v_actor := private.cs05_my_profile_id();

    select business_id into v_business
    from public.locations
    where id = p_location;

    if v_business is null
        or v_business <> (public.get_my_authority() ->> 'business_id')::uuid then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if coalesce(p_opening, 0) <> 0 then
        raise exception using errcode = '22023', message = 'FINANCE_OPENING_SOURCE_REQUIRED';
    end if;

    v_shift := private.cs05_open_shift(v_business, p_location, v_actor, 0, p_config);

    update public.shifts
    set opening_source_type = 'ZERO',
        opening_source_ref = 'ZERO'
    where id = v_shift;

    return v_shift;
end;
$$;

create or replace function public.finance_open_shift_from_main_cash(
    p_location uuid,
    p_opening numeric,
    p_config jsonb,
    p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor uuid;
    v_business uuid;
    v_main_cash uuid;
    v_shift_cash uuid;
    v_shift uuid;
    v_movement uuid;
    v_payload_hash text;
    v_lock record;
begin
    perform private.cs05_require_shift_permission();
    v_actor := private.cs05_my_profile_id();

    select business_id into v_business
    from public.locations
    where id = p_location;

    if v_business is null
        or v_business <> (public.get_my_authority() ->> 'business_id')::uuid then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if p_opening is null or p_opening <= 0 then
        raise exception using errcode = '22023', message = 'FINANCE_OPENING_AMOUNT_INVALID';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'location_id', p_location,
            'opening', p_opening,
            'config', coalesce(p_config, '{}'::jsonb),
            'source', 'KAS_UTAMA',
            'actor', v_actor
        )
    );

    select *
    into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'SHIFT_OPEN_MAIN_CASH',
        v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'SHIFT' or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;
        return v_lock.result_id;
    end if;

    select id into v_main_cash
    from public.money_accounts
    where business_id = v_business
      and code = 'KAS_UTAMA'
      and active;

    select id into v_shift_cash
    from public.money_accounts
    where business_id = v_business
      and code = 'KAS_SHIFT'
      and active;

    if v_main_cash is null or v_shift_cash is null then
        raise exception using errcode = '23503', message = 'FINANCE_SHIFT_ACCOUNT_MISSING';
    end if;

    if private.finance_account_balance(v_business, v_main_cash) < p_opening then
        raise exception using errcode = '23514', message = 'FINANCE_INSUFFICIENT_BALANCE';
    end if;

    v_shift := private.cs05_open_shift(
        v_business,
        p_location,
        v_actor,
        p_opening,
        coalesce(p_config, '{}'::jsonb)
    );

    v_movement := private.record_money_movement(
        v_business,
        v_actor,
        p_idempotency_key || ':OPENING_TRANSFER',
        'TRANSFER',
        v_main_cash,
        v_shift_cash,
        p_opening,
        'SHIFT_OPENING',
        v_shift::text,
        'KAS_UTAMA_TO_KAS_SHIFT',
        null
    );

    update public.shifts
    set opening_source_type = 'KAS_UTAMA',
        opening_source_ref = v_main_cash::text,
        opening_money_movement_id = v_movement
    where id = v_shift;

    perform private.record_operation_success(
        v_business,
        p_idempotency_key,
        'SHIFT_OPEN_MAIN_CASH',
        v_payload_hash,
        'SHIFT',
        v_shift,
        v_actor
    );

    return v_shift;
end;
$$;

create or replace function private.cs05_shift_immutable()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
    if old.status = 'CLOSED' then
        raise exception 'CS05: closed shifts are immutable (AC-05)';
    end if;
    if new.cashier_profile_id is distinct from old.cashier_profile_id then
        raise exception 'CS05: shift actor is immutable (R-02)';
    end if;
    if new.config_snapshot is distinct from old.config_snapshot then
        raise exception 'CS05: config snapshot is immutable (R-02)';
    end if;
    if new.opening_balance is distinct from old.opening_balance then
        raise exception 'CS05: opening balance is immutable';
    end if;
    if old.opening_source_type is not null and (
        new.opening_source_type is distinct from old.opening_source_type
        or new.opening_source_ref is distinct from old.opening_source_ref
        or new.opening_money_movement_id is distinct from old.opening_money_movement_id
    ) then
        raise exception 'CS05: opening funding provenance is immutable';
    end if;
    return new;
end;
$$;

revoke execute on function public.finance_open_shift_from_main_cash(uuid, numeric, jsonb, text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_open_shift_from_main_cash(uuid, numeric, jsonb, text)
to authenticated;
