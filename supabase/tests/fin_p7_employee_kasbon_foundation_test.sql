begin;

do $$
declare
    v_def text;
begin
    if to_regclass('public.employee_kasbons') is null then
        raise exception 'FIN_P7_EMPLOYEE_KASBONS_MISSING';
    end if;

    if to_regclass('public.employee_kasbon_balances') is null then
        raise exception 'FIN_P7_EMPLOYEE_KASBON_BALANCES_MISSING';
    end if;

    if not exists (
        select 1
        from public.money_accounts ma
        join public.businesses b on b.id = ma.business_id
        where b.code = 'SJ'
          and ma.code = 'KASBON_KARYAWAN'
          and ma.active
    ) then
        raise exception 'FIN_P7_KASBON_ACCOUNT_MISSING';
    end if;

    v_def := pg_get_functiondef(
        'public.finance_create_employee_kasbon(uuid,text,numeric,text,text)'::regprocedure
    );

    if position('EMPLOYEE_KASBON_CREATE' in v_def) = 0
       or position('EMPLOYEE_KASBON_EMPLOYEE_INVALID' in v_def) = 0
       or position('FINANCE_INSUFFICIENT_BALANCE' in v_def) = 0 then
        raise exception 'FIN_P7_COMMAND_CONTRACT_INVALID';
    end if;
end $$;

rollback;
