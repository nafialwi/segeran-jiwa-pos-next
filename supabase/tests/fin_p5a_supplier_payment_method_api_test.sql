begin;

do $$
begin
    if to_regprocedure('public.finance_pay_supplier_payable(uuid,text,numeric,text)') is null then
        raise exception 'FIN_P5A_METHOD_RPC_MISSING';
    end if;

    if to_regprocedure('public.finance_pay_supplier_payable(uuid,uuid,numeric,text)') is not null then
        raise exception 'FIN_P5A_LEGACY_UUID_RPC_STILL_PRESENT';
    end if;
end
$$;

rollback;
