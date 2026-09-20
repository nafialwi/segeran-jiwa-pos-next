begin;

do $$
begin
    if to_regclass('public.business_expenses') is null then
        raise exception 'FIN_P2B_EXPENSE_TABLE_MISSING';
    end if;

    if to_regprocedure('public.finance_post_shift_expense(text,text,numeric,text)') is null then
        raise exception 'FIN_P2B_EXPENSE_RPC_MISSING';
    end if;

    if not exists (
        select 1 from pg_policies
        where schemaname='public' and tablename='business_expenses'
          and policyname='business_expenses_scope_read'
    ) then
        raise exception 'FIN_P2B_EXPENSE_RLS_MISSING';
    end if;
end
$$;

rollback;
