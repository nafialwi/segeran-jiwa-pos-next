begin;

-- FIN-P1 hosted regression contract.
-- Full authenticated Owner/Kasir behavior is executed after migration apply.

do $$
begin
    if not exists (
        select 1
        from public.money_accounts ma
        join public.businesses b on b.id = ma.business_id
        where b.code = 'SJ'
          and ma.code = 'KAS_SHIFT'
          and ma.account_type = 'CASH'
          and ma.active
    ) then
        raise exception 'FIN_P1_KAS_SHIFT_MISSING';
    end if;

    if not exists (
        select 1 from pg_policies
        where schemaname = 'public'
          and tablename = 'money_accounts'
          and policyname = 'money_accounts_owner_read'
    ) then
        raise exception 'FIN_P1_ACCOUNT_OWNER_POLICY_MISSING';
    end if;

    if not exists (
        select 1 from pg_policies
        where schemaname = 'public'
          and tablename = 'money_movements'
          and policyname = 'money_movements_owner_read'
    ) then
        raise exception 'FIN_P1_MOVEMENT_OWNER_POLICY_MISSING';
    end if;

    if to_regprocedure('public.finance_post_transfer(uuid,uuid,numeric,text,text)') is null then
        raise exception 'FIN_P1_TRANSFER_RPC_MISSING';
    end if;

    if to_regprocedure('public.finance_post_owner_capital(uuid,numeric,text,text)') is null then
        raise exception 'FIN_P1_OWNER_CAPITAL_RPC_MISSING';
    end if;

    if to_regprocedure('public.finance_post_owner_personal_withdrawal(uuid,numeric,text,text)') is null then
        raise exception 'FIN_P1_OWNER_WITHDRAWAL_RPC_MISSING';
    end if;
end
$$;

rollback;
