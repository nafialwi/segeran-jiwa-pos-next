-- FIN-P1: Finance Foundation
-- Canonical money authority remains public.money_movements.
-- This migration adds the missing Kas Shift account, tightens finance reads
-- to Owner-only, and exposes bounded Owner finance commands.

insert into public.money_accounts (
    business_id,
    code,
    display_name,
    account_type,
    active
)
select
    b.id,
    'KAS_SHIFT',
    'Kas Shift',
    'CASH',
    true
from public.businesses b
where b.code = 'SJ'
on conflict (business_id, code) do update
set display_name = excluded.display_name,
    account_type = excluded.account_type,
    active = true;

drop policy if exists money_accounts_member_read on public.money_accounts;
drop policy if exists money_accounts_owner_read on public.money_accounts;

create policy money_accounts_owner_read
on public.money_accounts
for select
to authenticated
using (private.is_owner(business_id));

drop policy if exists money_movements_member_read on public.money_movements;
drop policy if exists money_movements_owner_read on public.money_movements;

create policy money_movements_owner_read
on public.money_movements
for select
to authenticated
using (private.is_owner(business_id));

create or replace function private.finance_require_owner()
returns table (
    business_id uuid,
    actor_profile_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    return query
    select m.business_id, m.profile_id
    from public.business_memberships m
    where m.profile_id = private.current_profile_id()
      and m.active
      and private.is_owner(m.business_id)
    order by m.created_at
    limit 1;

    if not found then
        raise exception using errcode = '42501', message = 'FINANCE_OWNER_REQUIRED';
    end if;
end;
$$;

create or replace function private.finance_account_balance(
    p_business_id uuid,
    p_account_id uuid
)
returns numeric(18, 2)
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(sum(
        case
            when mm.to_account_id = p_account_id then mm.amount
            when mm.from_account_id = p_account_id then -mm.amount
            else 0
        end
    ), 0)::numeric(18, 2)
    from public.money_movements mm
    where mm.business_id = p_business_id
      and (mm.to_account_id = p_account_id or mm.from_account_id = p_account_id);
$$;

create or replace function public.finance_post_transfer(
    p_from_account_id uuid,
    p_to_account_id uuid,
    p_amount numeric,
    p_reason_code text,
    p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
    v_from_code text;
    v_to_code text;
begin
    select x.business_id, x.actor_profile_id
    into v_business, v_actor
    from private.finance_require_owner() x;

    if p_amount is null or p_amount <= 0 then
        raise exception using errcode = '22023', message = 'FINANCE_AMOUNT_INVALID';
    end if;
    if p_from_account_id is null or p_to_account_id is null or p_from_account_id = p_to_account_id then
        raise exception using errcode = '22023', message = 'FINANCE_TRANSFER_ACCOUNTS_INVALID';
    end if;
    if p_reason_code is null or length(btrim(p_reason_code)) = 0 then
        raise exception using errcode = '22023', message = 'FINANCE_REASON_REQUIRED';
    end if;

    select code into v_from_code
    from public.money_accounts
    where id = p_from_account_id
      and business_id = v_business
      and active;

    select code into v_to_code
    from public.money_accounts
    where id = p_to_account_id
      and business_id = v_business
      and active;

    if v_from_code is null or v_to_code is null then
        raise exception using errcode = '23503', message = 'FINANCE_ACCOUNT_INVALID';
    end if;

    if v_from_code not in ('KAS_UTAMA', 'KAS_SHIFT', 'BANK')
       or v_to_code not in ('KAS_UTAMA', 'KAS_SHIFT', 'BANK') then
        raise exception using errcode = '22023', message = 'FINANCE_TRANSFER_ACCOUNT_SCOPE_INVALID';
    end if;

    if private.finance_account_balance(v_business, p_from_account_id) < p_amount then
        raise exception using errcode = '23514', message = 'FINANCE_INSUFFICIENT_BALANCE';
    end if;

    return private.record_money_movement(
        v_business,
        v_actor,
        p_idempotency_key,
        'TRANSFER',
        p_from_account_id,
        p_to_account_id,
        p_amount,
        'INTERNAL_TRANSFER',
        p_idempotency_key,
        upper(btrim(p_reason_code)),
        null
    );
end;
$$;

create or replace function public.finance_post_owner_capital(
    p_to_account_id uuid,
    p_amount numeric,
    p_reason_code text,
    p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
    v_to_code text;
begin
    select x.business_id, x.actor_profile_id
    into v_business, v_actor
    from private.finance_require_owner() x;

    if p_amount is null or p_amount <= 0 then
        raise exception using errcode = '22023', message = 'FINANCE_AMOUNT_INVALID';
    end if;
    if p_reason_code is null or length(btrim(p_reason_code)) = 0 then
        raise exception using errcode = '22023', message = 'FINANCE_REASON_REQUIRED';
    end if;

    select code into v_to_code
    from public.money_accounts
    where id = p_to_account_id
      and business_id = v_business
      and active;

    if v_to_code not in ('KAS_UTAMA', 'BANK') then
        raise exception using errcode = '22023', message = 'FINANCE_OWNER_CAPITAL_ACCOUNT_INVALID';
    end if;

    return private.record_money_movement(
        v_business,
        v_actor,
        p_idempotency_key,
        'ADJUSTMENT',
        null,
        p_to_account_id,
        p_amount,
        'OWNER_CAPITAL',
        p_idempotency_key,
        upper(btrim(p_reason_code)),
        null
    );
end;
$$;

create or replace function public.finance_post_owner_personal_withdrawal(
    p_from_account_id uuid,
    p_amount numeric,
    p_reason_code text,
    p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
    v_from_code text;
begin
    select x.business_id, x.actor_profile_id
    into v_business, v_actor
    from private.finance_require_owner() x;

    if p_amount is null or p_amount <= 0 then
        raise exception using errcode = '22023', message = 'FINANCE_AMOUNT_INVALID';
    end if;
    if p_reason_code is null or length(btrim(p_reason_code)) = 0 then
        raise exception using errcode = '22023', message = 'FINANCE_REASON_REQUIRED';
    end if;

    select code into v_from_code
    from public.money_accounts
    where id = p_from_account_id
      and business_id = v_business
      and active;

    if v_from_code not in ('KAS_UTAMA', 'BANK') then
        raise exception using errcode = '22023', message = 'FINANCE_OWNER_PERSONAL_ACCOUNT_INVALID';
    end if;

    if private.finance_account_balance(v_business, p_from_account_id) < p_amount then
        raise exception using errcode = '23514', message = 'FINANCE_INSUFFICIENT_BALANCE';
    end if;

    return private.record_money_movement(
        v_business,
        v_actor,
        p_idempotency_key,
        'ADJUSTMENT',
        p_from_account_id,
        null,
        p_amount,
        'OWNER_PERSONAL_EXPENSE',
        p_idempotency_key,
        upper(btrim(p_reason_code)),
        null
    );
end;
$$;

revoke all on function private.finance_require_owner() from public, anon, authenticated, service_role;
revoke all on function private.finance_account_balance(uuid, uuid) from public, anon, authenticated, service_role;

revoke execute on function public.finance_post_transfer(uuid, uuid, numeric, text, text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_post_transfer(uuid, uuid, numeric, text, text)
to authenticated;

revoke execute on function public.finance_post_owner_capital(uuid, numeric, text, text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_post_owner_capital(uuid, numeric, text, text)
to authenticated;

revoke execute on function public.finance_post_owner_personal_withdrawal(uuid, numeric, text, text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_post_owner_personal_withdrawal(uuid, numeric, text, text)
to authenticated;
