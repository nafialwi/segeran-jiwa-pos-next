begin;

do $$
begin
    if not exists (
        select 1
        from pg_policies
        where schemaname='public'
          and tablename='suppliers'
          and policyname='suppliers_purchase_read'
          and cmd='SELECT'
    ) then
        raise exception 'FIN_P5B_SUPPLIER_READ_POLICY_MISSING';
    end if;

    if not has_table_privilege('authenticated','public.suppliers','SELECT') then
        raise exception 'FIN_P5B_SUPPLIER_SELECT_GRANT_MISSING';
    end if;
end
$$;

rollback;
