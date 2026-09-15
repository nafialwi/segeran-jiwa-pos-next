begin;

do $$
declare
    v_business uuid;
    v_supplier uuid;
    v_location uuid;
    v_unit uuid;
    v_stock_item uuid;
    v_po uuid;
    v_po_line uuid;
    v_gr uuid;
begin
    select id into v_business from public.businesses where code = 'SJ';
    if v_business is null then
        raise exception 'CS06_P4_NO_BUSINESS';
    end if;

    -- Verify tabel ada
    if to_regclass('public.goods_receipts') is null then
        raise exception 'CS06_P4_GOODS_RECEIPTS_MISSING';
    end if;
    if to_regclass('public.goods_receipt_lines') is null then
        raise exception 'CS06_P4_GOODS_RECEIPT_LINES_MISSING';
    end if;

    -- Verify function ada
    if not exists (
        select 1 from pg_proc p
        join pg_namespace n on p.pronamespace = n.oid
        where n.nspname = 'public' and p.proname = 'post_goods_receipt'
    ) then
        raise exception 'CS06_P4_FUNCTION_MISSING';
    end if;

    -- Setup test data
    insert into public.units(business_id, code, display_name)
    values (v_business, 'P4UNIT', 'P4 Test Unit')
    returning id into v_unit;

    insert into public.stock_items(business_id, code, display_name, item_kind, base_unit, base_unit_id)
    values (v_business, 'P4ITEM', 'P4 Test Item', 'FINISHED_GOOD', 'P4UNIT', v_unit)
    returning id into v_stock_item;

    insert into public.suppliers(business_id, code, display_name)
    values (v_business, 'P4SUP', 'P4 Test Supplier')
    returning id into v_supplier;

    insert into public.locations(business_id, code, display_name, location_type)
    values (v_business, 'P4LOC', 'P4 Test Location', 'WAREHOUSE')
    returning id into v_location;

    -- Insert PO (status APPROVED)
    insert into public.purchase_orders(business_id, order_number, supplier_id, location_id, status)
    values (v_business, 'PO-P4-001', v_supplier, v_location, 'APPROVED')
    returning id into v_po;

    insert into public.purchase_order_lines(
        purchase_order_id, stock_item_id, unit_id,
        ordered_quantity, conversion_factor_snapshot, base_quantity,
        unit_price, line_total
    )
    values (v_po, v_stock_item, v_unit, 10, 1, 10, 5000, 50000)
    returning id into v_po_line;

    -- Insert GRN (status RECEIVED)
    insert into public.goods_receipts(business_id, receipt_number, purchase_order_id, location_id, status)
    values (v_business, 'GRN-P4-001', v_po, v_location, 'RECEIVED')
    returning id into v_gr;

    insert into public.goods_receipt_lines(
        goods_receipt_id, purchase_order_line_id, stock_item_id, unit_id,
        received_quantity, conversion_factor_snapshot, base_quantity
    )
    values (v_gr, v_po_line, v_stock_item, v_unit, 10, 1, 10);

    -- Test posting
    -- (function post_goods_receipt akan dipanggil manual di DB live)
    -- Di test ini hanya verify struktur + constraint
end $$;

rollback;
