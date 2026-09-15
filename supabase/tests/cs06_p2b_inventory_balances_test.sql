begin;

do $$
declare
    v_business uuid;
    v_unit uuid;
    v_product uuid;
    v_location uuid;
    v_balance uuid;
begin
    select id into v_business from public.businesses where code = 'SJ';
    if v_business is null then
        raise exception 'CS06_P2B_NO_BUSINESS';
    end if;

    if to_regclass('public.inventory_balances') is null then
        raise exception 'CS06_P2B_TABLE_MISSING';
    end if;

    insert into public.units(business_id, code, display_name)
    values (v_business, 'P2BUNIT', 'P2B Test Unit')
    returning id into v_unit;

    insert into public.products(business_id, sku, display_name, base_unit_id)
    values (v_business, 'P2BSKU', 'P2B Test Product', v_unit)
    returning id into v_product;

    insert into public.locations(business_id, code, display_name, location_type)
    values (v_business, 'P2BLOC', 'P2B Test Location', 'WAREHOUSE')
    returning id into v_location;

    insert into public.inventory_balances(product_id, location_id, quantity)
    values (v_product, v_location, 100)
    returning id into v_balance;

    if v_balance is null then
        raise exception 'CS06_P2B_INSERT_FAILED';
    end if;

    begin
        insert into public.inventory_balances(product_id, location_id, quantity)
        values (v_product, v_location, 50);
        raise exception 'CS06_P2B_UNIQUE_NOT_ENFORCED';
    exception
        when unique_violation then
            null;
    end;
end $$;

rollback;
