begin;

do $$
begin
    if to_regclass('public.customers') is null then
        raise exception 'FIN_P3_CUSTOMERS_MISSING';
    end if;
    if to_regclass('public.customer_debts') is null then
        raise exception 'FIN_P3_DEBTS_MISSING';
    end if;
    if to_regclass('public.customer_debt_payments') is null then
        raise exception 'FIN_P3_DEBT_PAYMENTS_MISSING';
    end if;
    if to_regclass('public.customer_debt_balances') is null then
        raise exception 'FIN_P3_DEBT_BALANCE_VIEW_MISSING';
    end if;
    if to_regprocedure('public.checkout_sale(uuid,uuid,jsonb,jsonb,text)') is null then
        raise exception 'FIN_P3_CHECKOUT_RPC_MISSING';
    end if;
    if to_regprocedure('public.finance_pay_customer_debt(uuid,text,numeric,text)') is null then
        raise exception 'FIN_P3_PAYMENT_RPC_MISSING';
    end if;
    if not exists (
        select 1 from public.money_accounts where code='HUTANG_PELANGGAN'
    ) then
        raise exception 'FIN_P3_RECEIVABLE_ACCOUNT_MISSING';
    end if;
end
$$;

rollback;
