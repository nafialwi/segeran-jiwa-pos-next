-- Finance closure hardening: canonical Modal and Pengeluaran Pribadi accounts.
-- Blueprint requires both as minimum Finance accounts. Owner capital and Owner
-- personal withdrawal remain ADJUSTMENT facts (not operating income/expense)
-- but are now explicitly two-sided in the single money ledger.

insert into public.money_accounts (
    business_id,
    code,
    display_name,
    account_type,
    active
)
select b.id, x.code, x.display_name, 'OTHER', true
from public.businesses b
cross join (
    values
        ('MODAL'::text, 'Modal Owner'::text),
        ('PENGELUARAN_PRIBADI'::text, 'Pengeluaran Pribadi Owner'::text)
) as x(code, display_name)
where b.code = 'SJ'
on conflict (business_id, code) do update
set display_name = excluded.display_name,
    account_type = excluded.account_type,
    active = true;

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
    v_modal_account uuid;
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

    select id into v_modal_account
    from public.money_accounts
    where business_id = v_business
      and code = 'MODAL'
      and active;

    if v_modal_account is null then
        raise exception using errcode = '55000', message = 'FINANCE_MODAL_ACCOUNT_MISSING';
    end if;

    return private.record_money_movement(
        v_business,
        v_actor,
        p_idempotency_key,
        'ADJUSTMENT',
        v_modal_account,
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
    v_personal_account uuid;
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

    select id into v_personal_account
    from public.money_accounts
    where business_id = v_business
      and code = 'PENGELUARAN_PRIBADI'
      and active;

    if v_personal_account is null then
        raise exception using errcode = '55000', message = 'FINANCE_PERSONAL_ACCOUNT_MISSING';
    end if;

    return private.record_money_movement(
        v_business,
        v_actor,
        p_idempotency_key,
        'ADJUSTMENT',
        p_from_account_id,
        v_personal_account,
        p_amount,
        'OWNER_PERSONAL_EXPENSE',
        p_idempotency_key,
        upper(btrim(p_reason_code)),
        null
    );
end;
$$;

revoke execute on function public.finance_post_owner_capital(uuid, numeric, text, text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_post_owner_capital(uuid, numeric, text, text)
to authenticated;

revoke execute on function public.finance_post_owner_personal_withdrawal(uuid, numeric, text, text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_post_owner_personal_withdrawal(uuid, numeric, text, text)
to authenticated;
