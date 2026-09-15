begin;

do $$
declare
    v_business uuid;
    v_unit uuid;
    v_stock_item uuid;
    v_supplier uuid;
begin
    select id into v_business from public.businesses where code = 'SJ';
    if v_business is null then
        raise exception 'CS06_P2C_NO_BUSINESS';
    end if;

    -- Verify tabel baru ada
    if to_regclass('public.stock_item_units') is null then
        raise exception 'CS06_P2C_STOCK_ITEM_UNITS_MISSING';
    end if;
    if to_regclass('public.stock_item_suppliers') is null then
        raise exception 'CS06_P2C_STOCK_ITEM_SUPPLIERS_MISSING';
    end if;

    -- Verify stock_items punya kolom base_unit_id
    if not exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'stock_items'
          and column_name = 'base_unit_id'
    ) then
        raise exception 'CS06_P2C_BASE_UNIT_ID_MISSING';
    end if;

    -- Insert test data
    insert into public.units(business_id, code, display_name)
    values (v_business, 'P2CUNIT', 'P2C Test Unit')
    returning id into v_unit;

    insert into public.stock_items(business_id, code, display_name, item_kind, base_unit, base_unit_id)
    values (v_business, 'P2CITEM', 'P2C Test Item', 'FINISHED_GOOD', 'P2CUNIT', v_unit)
    returning id into v_stock_item;

    insert into public.suppliers(business_id, code, display_name)
    values (v_business, 'P2CSUP', 'P2C Test Supplier')
    returning id into v_supplier;

    -- Test stock_item_units
    insert into public.stock_item_units(stock_item_id, unit_id, conversion_factor, is_base_unit)
    values (v_stock_item, v_unit, 1.0, true);

    -- Test stock_item_suppliers
    insert into public.stock_item_suppliers(stock_item_id, supplier_id, purchase_price)
    values (v_stock_item, v_supplier, 5000);

end $$;

rollback;
