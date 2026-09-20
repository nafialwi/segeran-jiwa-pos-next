begin;

do $$
begin
    if to_regclass('public.expense_approval_rules') is null then
        raise exception 'FIN_P6_RULES_MISSING';
    end if;
    if to_regclass('public.expense_approval_requests') is null then
        raise exception 'FIN_P6_REQUESTS_MISSING';
    end if;
    if to_regclass('public.expense_approval_decisions') is null then
        raise exception 'FIN_P6_DECISIONS_MISSING';
    end if;
    if to_regclass('public.expense_approval_queue') is null then
        raise exception 'FIN_P6_QUEUE_MISSING';
    end if;
    if to_regprocedure('public.finance_submit_shift_expense(text,text,numeric,text)') is null then
        raise exception 'FIN_P6_SUBMIT_RPC_MISSING';
    end if;
    if to_regprocedure('public.finance_decide_expense_request(uuid,boolean,text,text)') is null then
        raise exception 'FIN_P6_DECIDE_RPC_MISSING';
    end if;
end
$$;

rollback;
