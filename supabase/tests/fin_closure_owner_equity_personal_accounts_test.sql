begin;

do $$
declare
    v_capital text;
    v_personal text;
begin
    if not exists (
        select 1
        from public.money_accounts ma
        join public.businesses b on b.id = ma.business_id
        where b.code = 'SJ'
          and ma.code = 'MODAL'
          and ma.active
    ) then
        raise exception 'FIN_CLOSURE_MODAL_ACCOUNT_MISSING';
    end if;

    if not exists (
        select 1
        from public.money_accounts ma
        join public.businesses b on b.id = ma.business_id
        where b.code = 'SJ'
          and ma.code = 'PENGELUARAN_PRIBADI'
          and ma.active
    ) then
        raise exception 'FIN_CLOSURE_PERSONAL_ACCOUNT_MISSING';
    end if;

    v_capital := pg_get_functiondef(
        'public.finance_post_owner_capital(uuid,numeric,text,text)'::regprocedure
    );
    v_personal := pg_get_functiondef(
        'public.finance_post_owner_personal_withdrawal(uuid,numeric,text,text)'::regprocedure
    );

    if position('MODAL' in v_capital) = 0
       or position('ADJUSTMENT' in v_capital) = 0
       or position('OWNER_CAPITAL' in v_capital) = 0 then
        raise exception 'FIN_CLOSURE_CAPITAL_CONTRACT_INVALID';
    end if;

    if position('PENGELUARAN_PRIBADI' in v_personal) = 0
       or position('ADJUSTMENT' in v_personal) = 0
       or position('OWNER_PERSONAL_EXPENSE' in v_personal) = 0 then
        raise exception 'FIN_CLOSURE_PERSONAL_CONTRACT_INVALID';
    end if;
end $$;

rollback;
