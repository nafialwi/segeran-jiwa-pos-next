begin;

do $$
begin
    if to_regclass('public.supplier_payables') is null then
        raise exception 'FIN_P5_SUPPLIER_PAYABLE_TABLE_MISSING';
    end if;
    if to_regclass('public.supplier_payable_payments') is null then
        raise exception 'FIN_P5_SUPPLIER_PAYMENT_TABLE_MISSING';
    end if;
    if to_regclass('public.supplier_payable_balances') is null then
        raise exception 'FIN_P5_SUPPLIER_BALANCE_VIEW_MISSING';
    end if;
    if to_regprocedure('public.finance_create_supplier_payable(uuid,numeric,text,text)') is null then
        raise exception 'FIN_P5_CREATE_RPC_MISSING';
    end if;
    if to_regprocedure('public.finance_pay_supplier_payable(uuid,uuid,numeric,text)') is null then
        raise exception 'FIN_P5_PAY_RPC_MISSING';
    end if;
end
$$;

rollback;
