begin;

do $$
declare
    v_business uuid;
    v_unit uuid;
    v_supplier uuid;
    v_product uuid;
begin
    select id into v_business from public.businesses where code = 'SJ';
    if v_business is null then
        raise exception 'CS06_P1_NO_BUSINESS';
    end if;

    if to_regclass('public.units') is null then
        raise exception 'CS06_P1_UNITS_MISSING';
    end if;
    if to_regclass('public.suppliers') is null then
        raise exception 'CS06_P1_SUPPLIERS_MISSING';
    end if;
    if to_regclass('public.products') is null then
        raise exception 'CS06_P1_PRODUCTS_MISSING';
    end if;
    if to_regclass('public.product_units') is null then
        raise exception 'CS06_P1_PRODUCT_UNITS_MISSING';
    end if;
    if to_regclass('public.product_suppliers') is null then
        raise exception 'CS06_P1_PRODUCT_SUPPLIERS_MISSING';
    end if;

    insert into public.units(business_id, code, display_name)
    values (v_business, 'PCS', 'Pieces')
    returning id into v_unit;

    insert into public.suppliers(business_id, code, display_name)
    values (v_business, 'SUP01', 'Test Supplier')
    returning id into v_supplier;

    insert into public.products(business_id, sku, display_name, base_unit_id)
    values (v_business, 'SKU01', 'Test Product', v_unit)
    returning id into v_product;

    insert into public.product_units(product_id, unit_id, conversion_factor)
    values (v_product, v_unit, 1.0);

    insert into public.product_suppliers(product_id, supplier_id, purchase_price)
    values (v_product, v_supplier, 1000);
end $$;

rollback;
