begin;

-- Test: verify policies use get_my_authority() helper (not auth.jwt() directly)
do $$
declare
    v_policy_def text;
begin
    -- Check units policy
    select pg_get_expr(polqual, polrelid) into v_policy_def
    from pg_policy
    where polrelid = 'public.units'::regclass
      and polname = 'Tenant isolation for units';
    
    if v_policy_def is null or v_policy_def not like '%get_my_authority%' then
        raise exception 'CS06_P2A_UNITS_POLICY_WRONG';
    end if;

    -- Check suppliers policy
    select pg_get_expr(polqual, polrelid) into v_policy_def
    from pg_policy
    where polrelid = 'public.suppliers'::regclass
      and polname = 'Tenant isolation for suppliers';
    
    if v_policy_def is null or v_policy_def not like '%get_my_authority%' then
        raise exception 'CS06_P2A_SUPPLIERS_POLICY_WRONG';
    end if;

    -- Check products policy
    select pg_get_expr(polqual, polrelid) into v_policy_def
    from pg_policy
    where polrelid = 'public.products'::regclass
      and polname = 'Tenant isolation for products';
    
    if v_policy_def is null or v_policy_def not like '%get_my_authority%' then
        raise exception 'CS06_P2A_PRODUCTS_POLICY_WRONG';
    end if;
end $$;

rollback;
