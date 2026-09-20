begin;

do $$
declare
    v_qual text;
begin
    select qual into v_qual
    from pg_policies
    where schemaname='public'
      and tablename='customer_debts'
      and policyname='customer_debts_authorized_read';

    if v_qual is null or position('get_my_authority' in v_qual)=0 then
        raise exception 'FIN_P3A_PUBLIC_AUTHORITY_POLICY_MISSING';
    end if;

    if position('has_permission' in v_qual)>0 then
        raise exception 'FIN_P3A_PRIVATE_HELPER_LEAK';
    end if;
end
$$;

rollback;
