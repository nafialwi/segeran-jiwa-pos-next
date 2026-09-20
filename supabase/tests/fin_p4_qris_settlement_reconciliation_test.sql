begin;

do $$
begin
    if to_regclass('public.qris_settlements') is null then
        raise exception 'FIN_P4_QRIS_SETTLEMENTS_MISSING';
    end if;
    if to_regclass('public.finance_daily_reconciliations') is null then
        raise exception 'FIN_P4_RECONCILIATIONS_MISSING';
    end if;
    if to_regprocedure('public.finance_settle_qris(date,text,numeric,numeric,text)') is null then
        raise exception 'FIN_P4_SETTLEMENT_RPC_MISSING';
    end if;
    if to_regprocedure('public.finance_reconcile_day(date,numeric,numeric,text,text)') is null then
        raise exception 'FIN_P4_RECONCILIATION_RPC_MISSING';
    end if;
end
$$;

rollback;
