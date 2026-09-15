begin;

-- Deterministic identities used only inside this rolled-back integration test.
insert into auth.users (id, email, is_sso_user, is_anonymous)
values
    ('00000000-0000-0000-0000-000000006101', 'p4r1-owner@auth.segeranjiwa.invalid', false, false),
    ('00000000-0000-0000-0000-000000006102', 'p4r1-cashier@auth.segeranjiwa.invalid', false, false);

insert into auth.sessions (id, user_id)
values
    ('00000000-0000-0000-0000-000000006201', '00000000-0000-0000-0000-000000006101'),
    ('00000000-0000-0000-0000-000000006202', '00000000-0000-0000-0000-000000006102');

insert into public.profiles (id, auth_user_id, display_name, status)
values
    ('00000000-0000-0000-0000-000000006301', '00000000-0000-0000-0000-000000006101', 'P4R1 Owner', 'ACTIVE'),
    ('00000000-0000-0000-0000-000000006302', '00000000-0000-0000-0000-000000006102', 'P4R1 Cashier', 'ACTIVE');

insert into public.user_login_identities (profile_id, username)
values
    ('00000000-0000-0000-0000-000000006301', 'p4r1-owner'),
    ('00000000-0000-0000-0000-000000006302', 'p4r1-cashier');

insert into public.business_memberships (business_id, profile_id, role_code)
select id, '00000000-0000-0000-0000-000000006301', 'OWNER'
from public.businesses where code = 'SJ';

insert into public.business_memberships (business_id, profile_id, role_code)
select id, '00000000-0000-0000-0000-000000006302', 'KASIR'
from public.businesses where code = 'SJ';

insert into public.trusted_devices (id, business_id, friendly_name, device_kind, platform_label)
select '00000000-0000-0000-0000-000000006401', id, 'P4R1 Owner Device', 'PERSONAL', 'TEST'
from public.businesses where code = 'SJ';

insert into public.trusted_devices (id, business_id, friendly_name, device_kind, platform_label)
select '00000000-0000-0000-0000-000000006402', id, 'P4R1 Cashier Device', 'PERSONAL', 'TEST'
from public.businesses where code = 'SJ';

insert into public.user_device_access (business_id, profile_id, device_id)
select id, '00000000-0000-0000-0000-000000006301', '00000000-0000-0000-0000-000000006401'
from public.businesses where code = 'SJ';

insert into public.user_device_access (business_id, profile_id, device_id)
select id, '00000000-0000-0000-0000-000000006302', '00000000-0000-0000-0000-000000006402'
from public.businesses where code = 'SJ';

insert into public.session_registry (session_id, business_id, profile_id, device_id)
select '00000000-0000-0000-0000-000000006201', id, '00000000-0000-0000-0000-000000006301', '00000000-0000-0000-0000-000000006401'
from public.businesses where code = 'SJ';

insert into public.session_registry (session_id, business_id, profile_id, device_id)
select '00000000-0000-0000-0000-000000006202', id, '00000000-0000-0000-0000-000000006302', '00000000-0000-0000-0000-000000006402'
from public.businesses where code = 'SJ';

do $$
declare
    v_business uuid;
    v_supplier uuid := '00000000-0000-0000-0000-000000006501';
    v_location uuid := '00000000-0000-0000-0000-000000006502';
    v_unit uuid := '00000000-0000-0000-0000-000000006503';
    v_item_a uuid := '00000000-0000-0000-0000-000000006511';
    v_item_b uuid := '00000000-0000-0000-0000-000000006512';
begin
    select id into v_business from public.businesses where code = 'SJ';
    if v_business is null then
        raise exception 'CS06_P4R1_NO_BUSINESS';
    end if;

    insert into public.units(id, business_id, code, display_name)
    values (v_unit, v_business, 'P4R1U', 'P4R1 Unit');

    insert into public.stock_items(id, business_id, code, display_name, item_kind, base_unit, base_unit_id)
    values
        (v_item_a, v_business, 'P4R1A', 'P4R1 Item A', 'FINISHED_GOOD', 'P4R1U', v_unit),
        (v_item_b, v_business, 'P4R1B', 'P4R1 Item B', 'FINISHED_GOOD', 'P4R1U', v_unit);

    insert into public.suppliers(id, business_id, code, display_name)
    values (v_supplier, v_business, 'P4R1SUP', 'P4R1 Supplier');

    insert into public.locations(id, business_id, code, display_name, location_type)
    values (v_location, v_business, 'P4R1LOC', 'P4R1 Warehouse', 'WAREHOUSE');

    -- PO-1: two lines. First receipt must remain partial, second completes it.
    insert into public.purchase_orders(id, business_id, order_number, supplier_id, location_id, status)
    values ('00000000-0000-0000-0000-000000006601', v_business, 'PO-P4R1-001', v_supplier, v_location, 'APPROVED');

    insert into public.purchase_order_lines(
        id, purchase_order_id, stock_item_id, unit_id,
        ordered_quantity, conversion_factor_snapshot, base_quantity, unit_price, line_total
    ) values
        ('00000000-0000-0000-0000-000000006611', '00000000-0000-0000-0000-000000006601', v_item_a, v_unit, 5, 1, 5, 1000, 5000),
        ('00000000-0000-0000-0000-000000006612', '00000000-0000-0000-0000-000000006601', v_item_b, v_unit, 5, 1, 5, 1000, 5000);

    insert into public.goods_receipts(id, business_id, receipt_number, purchase_order_id, location_id, status)
    values
        ('00000000-0000-0000-0000-000000006701', v_business, 'GRN-P4R1-001A', '00000000-0000-0000-0000-000000006601', v_location, 'RECEIVED'),
        ('00000000-0000-0000-0000-000000006702', v_business, 'GRN-P4R1-001B', '00000000-0000-0000-0000-000000006601', v_location, 'RECEIVED');

    insert into public.goods_receipt_lines(
        id, goods_receipt_id, purchase_order_line_id, stock_item_id, unit_id,
        received_quantity, conversion_factor_snapshot, base_quantity
    ) values
        ('00000000-0000-0000-0000-000000006711', '00000000-0000-0000-0000-000000006701', '00000000-0000-0000-0000-000000006611', v_item_a, v_unit, 5, 1, 5),
        ('00000000-0000-0000-0000-000000006712', '00000000-0000-0000-0000-000000006702', '00000000-0000-0000-0000-000000006612', v_item_b, v_unit, 5, 1, 5);

    -- PO-2: 5 ordered; 4 posted then 2 must be rejected as over-receipt.
    insert into public.purchase_orders(id, business_id, order_number, supplier_id, location_id, status)
    values ('00000000-0000-0000-0000-000000006602', v_business, 'PO-P4R1-002', v_supplier, v_location, 'APPROVED');

    insert into public.purchase_order_lines(
        id, purchase_order_id, stock_item_id, unit_id,
        ordered_quantity, conversion_factor_snapshot, base_quantity, unit_price, line_total
    ) values
        ('00000000-0000-0000-0000-000000006621', '00000000-0000-0000-0000-000000006602', v_item_a, v_unit, 5, 1, 5, 1000, 5000);

    insert into public.goods_receipts(id, business_id, receipt_number, purchase_order_id, location_id, status)
    values
        ('00000000-0000-0000-0000-000000006703', v_business, 'GRN-P4R1-002A', '00000000-0000-0000-0000-000000006602', v_location, 'RECEIVED'),
        ('00000000-0000-0000-0000-000000006704', v_business, 'GRN-P4R1-002B', '00000000-0000-0000-0000-000000006602', v_location, 'RECEIVED');

    insert into public.goods_receipt_lines(
        id, goods_receipt_id, purchase_order_line_id, stock_item_id, unit_id,
        received_quantity, conversion_factor_snapshot, base_quantity
    ) values
        ('00000000-0000-0000-0000-000000006713', '00000000-0000-0000-0000-000000006703', '00000000-0000-0000-0000-000000006621', v_item_a, v_unit, 4, 1, 4),
        ('00000000-0000-0000-0000-000000006714', '00000000-0000-0000-0000-000000006704', '00000000-0000-0000-0000-000000006621', v_item_a, v_unit, 2, 1, 2);

    -- PO-3: line deliberately references a line from PO-2 and must be rejected.
    insert into public.purchase_orders(id, business_id, order_number, supplier_id, location_id, status)
    values ('00000000-0000-0000-0000-000000006603', v_business, 'PO-P4R1-003', v_supplier, v_location, 'APPROVED');

    insert into public.purchase_order_lines(
        id, purchase_order_id, stock_item_id, unit_id,
        ordered_quantity, conversion_factor_snapshot, base_quantity, unit_price, line_total
    ) values
        ('00000000-0000-0000-0000-000000006631', '00000000-0000-0000-0000-000000006603', v_item_b, v_unit, 1, 1, 1, 1000, 1000);

    insert into public.goods_receipts(id, business_id, receipt_number, purchase_order_id, location_id, status)
    values ('00000000-0000-0000-0000-000000006705', v_business, 'GRN-P4R1-003', '00000000-0000-0000-0000-000000006603', v_location, 'RECEIVED');

    insert into public.goods_receipt_lines(
        id, goods_receipt_id, purchase_order_line_id, stock_item_id, unit_id,
        received_quantity, conversion_factor_snapshot, base_quantity
    ) values
        ('00000000-0000-0000-0000-000000006715', '00000000-0000-0000-0000-000000006705', '00000000-0000-0000-0000-000000006621', v_item_a, v_unit, 1, 1, 1);

    -- PO-4: valid GRN used to prove cashier permission denial.
    insert into public.purchase_orders(id, business_id, order_number, supplier_id, location_id, status)
    values ('00000000-0000-0000-0000-000000006604', v_business, 'PO-P4R1-004', v_supplier, v_location, 'APPROVED');

    insert into public.purchase_order_lines(
        id, purchase_order_id, stock_item_id, unit_id,
        ordered_quantity, conversion_factor_snapshot, base_quantity, unit_price, line_total
    ) values
        ('00000000-0000-0000-0000-000000006641', '00000000-0000-0000-0000-000000006604', v_item_b, v_unit, 1, 1, 1, 1000, 1000);

    insert into public.goods_receipts(id, business_id, receipt_number, purchase_order_id, location_id, status)
    values ('00000000-0000-0000-0000-000000006706', v_business, 'GRN-P4R1-004', '00000000-0000-0000-0000-000000006604', v_location, 'RECEIVED');

    insert into public.goods_receipt_lines(
        id, goods_receipt_id, purchase_order_line_id, stock_item_id, unit_id,
        received_quantity, conversion_factor_snapshot, base_quantity
    ) values
        ('00000000-0000-0000-0000-000000006716', '00000000-0000-0000-0000-000000006706', '00000000-0000-0000-0000-000000006641', v_item_b, v_unit, 1, 1, 1);
end $$;

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000006101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000006201"}',
    true
);

do $$
declare
    v_result jsonb;
begin
    v_result := public.post_goods_receipt('00000000-0000-0000-0000-000000006701');
    if v_result ->> 'po_status' <> 'PARTIALLY_RECEIVED' then
        raise exception 'CS06_P4R1_PARTIAL_STATUS_FAILED';
    end if;
end $$;

reset role;

do $$
declare
    v_business uuid;
    v_balance numeric;
begin
    select id into v_business from public.businesses where code = 'SJ';

    if not exists (
        select 1 from public.goods_receipts
        where id = '00000000-0000-0000-0000-000000006701'
          and status = 'POSTED'
          and posted_by = '00000000-0000-0000-0000-000000006301'
    ) then
        raise exception 'CS06_P4R1_POSTED_ACTOR_FAILED';
    end if;

    select quantity into v_balance
    from public.inventory_balances
    where business_id = v_business
      and stock_item_id = '00000000-0000-0000-0000-000000006511'
      and location_id = '00000000-0000-0000-0000-000000006502';

    if v_balance <> 5 then
        raise exception 'CS06_P4R1_FIRST_LEDGER_BALANCE_FAILED';
    end if;

    if not exists (
        select 1 from public.purchase_orders
        where id = '00000000-0000-0000-0000-000000006601'
          and status = 'PARTIALLY_RECEIVED'
    ) then
        raise exception 'CS06_P4R1_PO_SHOULD_BE_PARTIAL';
    end if;
end $$;

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000006101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000006201"}',
    true
);

do $$
declare
    v_result jsonb;
begin
    v_result := public.post_goods_receipt('00000000-0000-0000-0000-000000006702');
    if v_result ->> 'po_status' <> 'RECEIVED' then
        raise exception 'CS06_P4R1_FULL_STATUS_FAILED';
    end if;

    v_result := public.post_goods_receipt('00000000-0000-0000-0000-000000006702');
    if coalesce((v_result ->> 'already_posted')::boolean, false) is not true then
        raise exception 'CS06_P4R1_IDEMPOTENT_REPLAY_FAILED';
    end if;
end $$;

reset role;

do $$
declare
    v_business uuid;
    v_balance numeric;
    v_count integer;
begin
    select id into v_business from public.businesses where code = 'SJ';

    select quantity into v_balance
    from public.inventory_balances
    where business_id = v_business
      and stock_item_id = '00000000-0000-0000-0000-000000006512'
      and location_id = '00000000-0000-0000-0000-000000006502';

    if v_balance <> 5 then
        raise exception 'CS06_P4R1_SECOND_LEDGER_BALANCE_FAILED';
    end if;

    select count(*) into v_count
    from public.inventory_movements
    where business_id = v_business
      and source_type = 'GOODS_RECEIPT'
      and source_ref = 'GRN-P4R1-001B';

    if v_count <> 1 then
        raise exception 'CS06_P4R1_REPLAY_DUPLICATED_MOVEMENT';
    end if;
end $$;

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000006101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000006201"}',
    true
);

do $$
declare
    v_result jsonb;
    v_caught boolean := false;
begin
    v_result := public.post_goods_receipt('00000000-0000-0000-0000-000000006703');
    if v_result ->> 'po_status' <> 'PARTIALLY_RECEIVED' then
        raise exception 'CS06_P4R1_OVER_SETUP_PARTIAL_FAILED';
    end if;

    begin
        perform public.post_goods_receipt('00000000-0000-0000-0000-000000006704');
    exception when others then
        if sqlerrm = 'GRN_OVER_RECEIPT' then
            v_caught := true;
        else
            raise;
        end if;
    end;

    if not v_caught then
        raise exception 'CS06_P4R1_OVER_RECEIPT_NOT_BLOCKED';
    end if;

    v_caught := false;
    begin
        perform public.post_goods_receipt('00000000-0000-0000-0000-000000006705');
    exception when others then
        if sqlerrm = 'GRN_LINE_PO_MISMATCH' then
            v_caught := true;
        else
            raise;
        end if;
    end;

    if not v_caught then
        raise exception 'CS06_P4R1_PO_LINE_MISMATCH_NOT_BLOCKED';
    end if;
end $$;

reset role;

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000006102","role":"authenticated","session_id":"00000000-0000-0000-0000-000000006202"}',
    true
);

do $$
declare
    v_caught boolean := false;
begin
    begin
        perform public.post_goods_receipt('00000000-0000-0000-0000-000000006706');
    exception when insufficient_privilege then
        if sqlerrm = 'SJ_PURCHASE_PERMISSION_DENIED' then
            v_caught := true;
        else
            raise;
        end if;
    end;

    if not v_caught then
        raise exception 'CS06_P4R1_PURCHASE_PERMISSION_NOT_ENFORCED';
    end if;
end $$;

reset role;

rollback;
