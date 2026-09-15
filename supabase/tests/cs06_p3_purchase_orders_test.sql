begin;

do $$
declare
    v_business uuid;
    v_supplier uuid;
    v_location uuid;
    v_unit uuid;
    v_stock_item uuid;
    v_profile uuid;
    v_po uuid;
    v_po_line uuid;
begin
    select id into v_business from public.businesses where code = 'SJ';
    if v_business is null then
        raise exception 'CS06_P3_NO_BUSINESS';
    end if;

    -- Verify tabel ada
    if to_regclass('public.purchase_orders') is null then
        raise exception 'CS06_P3_PURCHASE_ORDERS_MISSING';
    end if;
    if to_regclass('public.purchase_order_lines') is null then
        raise exception 'CS06_P3_PURCHASE_ORDER_LINES_MISSING';
    end if;

    -- Setup test data
    insert into public.units(business_id, code, display_name)
    values (v_business, 'P3UNIT', 'P3 Test Unit')
    returning id into v_unit;

    insert into public.stock_items(business_id, code, display_name, item_kind, base_unit, base_unit_id)
    values (v_business, 'P3ITEM', 'P3 Test Item', 'FINISHED_GOOD', 'P3UNIT', v_unit)
    returning id into v_stock_item;

    insert into public.suppliers(business_id, code, display_name)
    values (v_business, 'P3SUP', 'P3 Test Supplier')
    returning id into v_supplier;

    insert into public.locations(business_id, code, display_name, location_type)
    values (v_business, 'P3LOC', 'P3 Test Location', 'WAREHOUSE')
    returning id into v_location;

    -- Insert PO header
    insert into public.purchase_orders(business_id, order_number, supplier_id, location_id, status)
    values (v_business, 'PO-P3-001', v_supplier, v_location, 'DRAFT')
    returning id into v_po;

    if v_po is null then
        raise exception 'CS06_P3_PO_INSERT_FAILED';
    end if;

    -- Insert PO line: 5 BOX @ 12 PCS/BOX = 60 PCS base
    insert into public.purchase_order_lines(
        purchase_order_id, stock_item_id, unit_id,
        ordered_quantity, conversion_factor_snapshot, base_quantity,
        unit_price, line_total
    )
    values (v_po, v_stock_item, v_unit, 5, 12, 60, 10000, 50000)
    returning id into v_po_line;

    if v_po_line is null then
        raise exception 'CS06_P3_PO_LINE_INSERT_FAILED';
    end if;

    -- Test constraint: ordered_quantity harus > 0
    begin
        insert into public.purchase_order_lines(
            purchase_order_id, stock_item_id, unit_id,
            ordered_quantity, conversion_factor_snapshot, base_quantity,
            unit_price, line_total
        )
        values (v_po, v_stock_item, v_unit, -1, 12, -12, 10000, -120000);
        raise exception 'CS06_P3_QTY_CHECK_NOT_ENFORCED';
    exception
        when check_violation then
            null;
    end;
end $$;

rollback;
