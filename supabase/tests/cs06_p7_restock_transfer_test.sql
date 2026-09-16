begin;

-- CS-06-P7 integration regression: Restock Request + Stock Transfer.

insert into auth.users (id, email, is_sso_user, is_anonymous)
values
    ('00000000-0000-0000-0000-000000009101', 'p7-owner@auth.segeranjiwa.invalid', false, false),
    ('00000000-0000-0000-0000-000000009102', 'p7-requester@auth.segeranjiwa.invalid', false, false),
    ('00000000-0000-0000-0000-000000009103', 'p7-transfer@auth.segeranjiwa.invalid', false, false);

insert into auth.sessions (id, user_id)
values
    ('00000000-0000-0000-0000-000000009201', '00000000-0000-0000-0000-000000009101'),
    ('00000000-0000-0000-0000-000000009202', '00000000-0000-0000-0000-000000009102'),
    ('00000000-0000-0000-0000-000000009203', '00000000-0000-0000-0000-000000009103');

insert into public.profiles (id, auth_user_id, display_name, status)
values
    ('00000000-0000-0000-0000-000000009301', '00000000-0000-0000-0000-000000009101', 'P7 Owner', 'ACTIVE'),
    ('00000000-0000-0000-0000-000000009302', '00000000-0000-0000-0000-000000009102', 'P7 Requester', 'ACTIVE'),
    ('00000000-0000-0000-0000-000000009303', '00000000-0000-0000-0000-000000009103', 'P7 Transfer Staff', 'ACTIVE');

insert into public.user_login_identities (profile_id, username)
values
    ('00000000-0000-0000-0000-000000009301', 'p7-owner'),
    ('00000000-0000-0000-0000-000000009302', 'p7-requester'),
    ('00000000-0000-0000-0000-000000009303', 'p7-transfer');

insert into public.business_memberships (business_id, profile_id, role_code)
select id, '00000000-0000-0000-0000-000000009301', 'OWNER'
from public.businesses where code = 'SJ';

insert into public.business_memberships (business_id, profile_id, role_code)
select id, '00000000-0000-0000-0000-000000009302', 'KASIR'
from public.businesses where code = 'SJ';

insert into public.business_memberships (business_id, profile_id, role_code)
select id, '00000000-0000-0000-0000-000000009303', 'KASIR'
from public.businesses where code = 'SJ';

insert into public.trusted_devices (id, business_id, friendly_name, device_kind, platform_label)
select '00000000-0000-0000-0000-000000009401', id, 'P7 Owner Device', 'PERSONAL', 'TEST'
from public.businesses where code = 'SJ';

insert into public.trusted_devices (id, business_id, friendly_name, device_kind, platform_label)
select '00000000-0000-0000-0000-000000009402', id, 'P7 Requester Device', 'PERSONAL', 'TEST'
from public.businesses where code = 'SJ';

insert into public.trusted_devices (id, business_id, friendly_name, device_kind, platform_label)
select '00000000-0000-0000-0000-000000009403', id, 'P7 Transfer Device', 'PERSONAL', 'TEST'
from public.businesses where code = 'SJ';

insert into public.user_device_access (business_id, profile_id, device_id)
select id, '00000000-0000-0000-0000-000000009301', '00000000-0000-0000-0000-000000009401'
from public.businesses where code = 'SJ';

insert into public.user_device_access (business_id, profile_id, device_id)
select id, '00000000-0000-0000-0000-000000009302', '00000000-0000-0000-0000-000000009402'
from public.businesses where code = 'SJ';

insert into public.user_device_access (business_id, profile_id, device_id)
select id, '00000000-0000-0000-0000-000000009303', '00000000-0000-0000-0000-000000009403'
from public.businesses where code = 'SJ';

insert into public.session_registry (session_id, business_id, profile_id, device_id)
select '00000000-0000-0000-0000-000000009201', id, '00000000-0000-0000-0000-000000009301', '00000000-0000-0000-0000-000000009401'
from public.businesses where code = 'SJ';

insert into public.session_registry (session_id, business_id, profile_id, device_id)
select '00000000-0000-0000-0000-000000009202', id, '00000000-0000-0000-0000-000000009302', '00000000-0000-0000-0000-000000009402'
from public.businesses where code = 'SJ';

insert into public.session_registry (session_id, business_id, profile_id, device_id)
select '00000000-0000-0000-0000-000000009203', id, '00000000-0000-0000-0000-000000009303', '00000000-0000-0000-0000-000000009403'
from public.businesses where code = 'SJ';

insert into public.user_permission_overrides (
    business_id, profile_id, permission_code, effect, set_by_profile_id
)
select id, '00000000-0000-0000-0000-000000009302', 'INVENTORY_REQUEST', 'ALLOW', '00000000-0000-0000-0000-000000009301'
from public.businesses where code = 'SJ';

insert into public.user_permission_overrides (
    business_id, profile_id, permission_code, effect, set_by_profile_id
)
select id, '00000000-0000-0000-0000-000000009303', 'INVENTORY_TRANSFER', 'ALLOW', '00000000-0000-0000-0000-000000009301'
from public.businesses where code = 'SJ';

insert into public.businesses (id, code, display_name)
values ('00000000-0000-0000-0000-000000009900', 'P7X', 'P7 Foreign Business');

insert into public.locations (id, business_id, code, display_name, location_type, active)
values ('00000000-0000-0000-0000-000000009901', '00000000-0000-0000-0000-000000009900', 'P7XSTORE', 'P7 Foreign Store', 'STORE', true);

insert into public.stock_items (id, business_id, code, display_name, item_kind, base_unit, active)
values ('00000000-0000-0000-0000-000000009902', '00000000-0000-0000-0000-000000009900', 'P7XITEM', 'P7 Foreign Item', 'MATERIAL', 'PCS', true);

do $$
declare
    v_business uuid;
begin
    select id into v_business from public.businesses where code = 'SJ';

    insert into public.stock_items(id, business_id, code, display_name, item_kind, base_unit, active)
    values
        ('00000000-0000-0000-0000-000000009501', v_business, 'P7ITEM1', 'P7 Item One', 'MATERIAL', 'PCS', true),
        ('00000000-0000-0000-0000-000000009502', v_business, 'P7ITEM2', 'P7 Item Two', 'PACKAGING', 'PCS', true);
end $$;

-- Requester has INVENTORY_REQUEST but initially no destination scope.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000009102","role":"authenticated","session_id":"00000000-0000-0000-0000-000000009202"}',
    true
);

do $$
declare
    v_gerai uuid;
begin
    select id into v_gerai
    from public.locations
    where business_id = (select id from public.businesses where code = 'SJ')
      and code = 'GERAI';

    begin
        perform public.save_restock_request(
            null,
            v_gerai,
            jsonb_build_array(
                jsonb_build_object('stock_item_id', '00000000-0000-0000-0000-000000009501', 'quantity', 3.000)
            ),
            'P7 scope test',
            'P7:REQUEST:SCOPE:DENY'
        );
        raise exception 'CS06_P7_EXPECTED_RESTOCK_SCOPE_DENIED';
    exception when others then
        if sqlerrm <> 'RESTOCK_SCOPE_DENIED' then raise; end if;
    end;
end $$;

reset role;

-- Owner grants requester Gerai scope and transfer staff Gudang scope.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000009101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000009201"}',
    true
);

do $$
declare
    v_gudang uuid;
    v_gerai uuid;
begin
    select id into v_gudang from public.locations
    where business_id = (select id from public.businesses where code = 'SJ') and code = 'GUDANG';
    select id into v_gerai from public.locations
    where business_id = (select id from public.businesses where code = 'SJ') and code = 'GERAI';

    perform public.set_inventory_location_scope('00000000-0000-0000-0000-000000009302', v_gerai, true);
    perform public.set_inventory_location_scope('00000000-0000-0000-0000-000000009303', v_gudang, true);
end $$;

reset role;

-- Transfer staff lacks INVENTORY_REQUEST.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000009103","role":"authenticated","session_id":"00000000-0000-0000-0000-000000009203"}',
    true
);

do $$
declare
    v_gerai uuid;
begin
    select id into v_gerai from public.locations
    where business_id = (select id from public.businesses where code = 'SJ') and code = 'GERAI';

    begin
        perform public.save_restock_request(
            null,
            v_gerai,
            jsonb_build_array(
                jsonb_build_object('stock_item_id', '00000000-0000-0000-0000-000000009501', 'quantity', 1.000)
            ),
            null,
            'P7:NO:REQUEST:PERMISSION'
        );
        raise exception 'CS06_P7_EXPECTED_RESTOCK_PERMISSION_DENIED';
    exception when others then
        if sqlerrm <> 'RESTOCK_PERMISSION_DENIED' then raise; end if;
    end;
end $$;

reset role;

-- Requester creates and submits a request for Gerai.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000009102","role":"authenticated","session_id":"00000000-0000-0000-0000-000000009202"}',
    true
);

do $$
declare
    v_gerai uuid;
    v_result jsonb;
    v_request uuid;
begin
    select id into v_gerai from public.locations
    where business_id = (select id from public.businesses where code = 'SJ') and code = 'GERAI';

    v_result := public.save_restock_request(
        null,
        v_gerai,
        jsonb_build_array(
            jsonb_build_object('stock_item_id', '00000000-0000-0000-0000-000000009501', 'quantity', 3.000),
            jsonb_build_object('stock_item_id', '00000000-0000-0000-0000-000000009502', 'quantity', 2.000)
        ),
        'P7 Restock Request',
        'P7:REQUEST:CREATE:A'
    );
    v_request := (v_result ->> 'request_id')::uuid;

    perform public.submit_restock_request(v_request);

    if not exists (
        select 1 from public.restock_requests rr
        where rr.id = v_request and rr.status = 'SUBMITTED'
    ) then
        raise exception 'CS06_P7_REQUEST_SUBMIT_FAILED';
    end if;

    v_result := public.save_restock_request(
        null,
        v_gerai,
        jsonb_build_array(
            jsonb_build_object('stock_item_id', '00000000-0000-0000-0000-000000009501', 'quantity', 1.000)
        ),
        'P7 Reject Request',
        'P7:REQUEST:CREATE:REJECT'
    );
    perform public.submit_restock_request((v_result ->> 'request_id')::uuid);

    begin
        perform public.approve_restock_request(v_request, v_gerai, 'P7:REQUESTER:APPROVE');
        raise exception 'CS06_P7_EXPECTED_TRANSFER_PERMISSION_DENIED';
    exception when others then
        if sqlerrm <> 'TRANSFER_PERMISSION_DENIED' then raise; end if;
    end;
end $$;

reset role;

-- Owner approves from Gudang; repeated approval must not create another transfer.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000009101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000009201"}',
    true
);

do $$
declare
    v_request uuid;
    v_gudang uuid;
    v_result jsonb;
    v_replay jsonb;
    v_second_key jsonb;
    v_transfer uuid;
    v_count integer;
begin
    select result_id into v_request
    from public.operation_receipts
    where idempotency_key = 'P7:REQUEST:CREATE:A';

    select id into v_gudang from public.locations
    where business_id = (select id from public.businesses where code = 'SJ') and code = 'GUDANG';

    perform public.reject_restock_request(
        (select result_id from public.operation_receipts where idempotency_key = 'P7:REQUEST:CREATE:REJECT'),
        'Tidak dibutuhkan'
    );

    if not exists (
        select 1
        from public.restock_requests rr
        where rr.id = (select result_id from public.operation_receipts where idempotency_key = 'P7:REQUEST:CREATE:REJECT')
          and rr.status = 'REJECTED'
          and rr.transfer_id is null
    ) then
        raise exception 'CS06_P7_REJECT_FLOW_FAILED';
    end if;

    v_result := public.approve_restock_request(v_request, v_gudang, 'P7:REQUEST:APPROVE:A');
    v_transfer := (v_result ->> 'transfer_id')::uuid;
    v_replay := public.approve_restock_request(v_request, v_gudang, 'P7:REQUEST:APPROVE:A');
    v_second_key := public.approve_restock_request(v_request, v_gudang, 'P7:REQUEST:APPROVE:A:SECONDKEY');

    if (v_replay ->> 'transfer_id')::uuid <> v_transfer
       or (v_second_key ->> 'transfer_id')::uuid <> v_transfer then
        raise exception 'CS06_P7_APPROVAL_REPLAY_CHANGED_TRANSFER';
    end if;

    select count(*) into v_count
    from public.stock_transfers st
    where st.restock_request_id = v_request;

    if v_count <> 1 then
        raise exception 'CS06_P7_DUPLICATE_TRANSFER';
    end if;

    if exists (
        select 1 from public.inventory_movements m
        where m.source_type = 'STOCK_TRANSFER'
          and m.source_ref = v_transfer::text
    ) then
        raise exception 'CS06_P7_DRAFT_CHANGED_STOCK';
    end if;
end $$;

reset role;

-- Seed Gudang inventory only through canonical inventory authority.
do $$
declare
    v_business uuid;
    v_gudang uuid;
    v_movement uuid;
begin
    select id into v_business from public.businesses where code = 'SJ';
    select id into v_gudang from public.locations where business_id = v_business and code = 'GUDANG';

    v_movement := private.record_inventory_movement(
        v_business,
        '00000000-0000-0000-0000-000000009301',
        'P7:SEED:GUDANG',
        'OPENING_STOCK',
        'P7_TEST',
        'SEED',
        'P7_TEST_SEED',
        jsonb_build_array(
            jsonb_build_object('line_no', 1, 'stock_item_id', '00000000-0000-0000-0000-000000009501', 'location_id', v_gudang, 'quantity_delta', 10.000),
            jsonb_build_object('line_no', 2, 'stock_item_id', '00000000-0000-0000-0000-000000009502', 'location_id', v_gudang, 'quantity_delta', 5.000)
        ),
        null
    );

    if v_movement is null then
        raise exception 'CS06_P7_SEED_FAILED';
    end if;
end $$;

-- Request-only user cannot ship or receive the approved transfer.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000009102","role":"authenticated","session_id":"00000000-0000-0000-0000-000000009202"}',
    true
);

do $$
declare
    v_request uuid;
    v_transfer uuid;
begin
    select result_id into v_request from public.operation_receipts where idempotency_key = 'P7:REQUEST:CREATE:A';
    select transfer_id into v_transfer from public.restock_requests where id = v_request;

    begin
        perform public.ship_stock_transfer(v_transfer);
        raise exception 'CS06_P7_EXPECTED_SHIP_PERMISSION_DENIED';
    exception when others then
        if sqlerrm <> 'TRANSFER_PERMISSION_DENIED' then raise; end if;
    end;

    begin
        perform public.receive_stock_transfer(v_transfer);
        raise exception 'CS06_P7_EXPECTED_RECEIVE_PERMISSION_DENIED';
    exception when others then
        if sqlerrm <> 'TRANSFER_PERMISSION_DENIED' then raise; end if;
    end;
end $$;

reset role;

-- Transfer staff has source scope, so shipment succeeds. Destination must remain unchanged.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000009103","role":"authenticated","session_id":"00000000-0000-0000-0000-000000009203"}',
    true
);

do $$
declare
    v_request uuid;
    v_transfer uuid;
    v_result jsonb;
    v_replay jsonb;
    v_outbound uuid;
    v_business uuid;
    v_gudang uuid;
    v_gerai uuid;
    v_gudang_1 numeric;
    v_gudang_2 numeric;
    v_gerai_1 numeric;
    v_gerai_2 numeric;
    v_count integer;
begin
    select id into v_business from public.businesses where code = 'SJ';
    select id into v_gudang from public.locations where business_id = v_business and code = 'GUDANG';
    select id into v_gerai from public.locations where business_id = v_business and code = 'GERAI';
    select result_id into v_request from public.operation_receipts where idempotency_key = 'P7:REQUEST:CREATE:A';
    select transfer_id into v_transfer from public.restock_requests where id = v_request;

    v_result := public.ship_stock_transfer(v_transfer);
    v_outbound := (v_result ->> 'movement_id')::uuid;
    v_replay := public.ship_stock_transfer(v_transfer);

    if (v_replay ->> 'movement_id')::uuid <> v_outbound then
        raise exception 'CS06_P7_SHIP_REPLAY_CHANGED_MOVEMENT';
    end if;

    select count(*) into v_count
    from public.inventory_movements m
    where m.source_type = 'STOCK_TRANSFER'
      and m.source_ref = v_transfer::text
      and m.movement_type = 'TRANSFER_OUT';

    if v_count <> 1 then
        raise exception 'CS06_P7_DUPLICATE_OUTBOUND';
    end if;

    select coalesce(sum(quantity), 0) into v_gudang_1
    from public.inventory_balances where business_id = v_business and location_id = v_gudang and stock_item_id = '00000000-0000-0000-0000-000000009501';
    select coalesce(sum(quantity), 0) into v_gudang_2
    from public.inventory_balances where business_id = v_business and location_id = v_gudang and stock_item_id = '00000000-0000-0000-0000-000000009502';
    select coalesce(sum(quantity), 0) into v_gerai_1
    from public.inventory_balances where business_id = v_business and location_id = v_gerai and stock_item_id = '00000000-0000-0000-0000-000000009501';
    select coalesce(sum(quantity), 0) into v_gerai_2
    from public.inventory_balances where business_id = v_business and location_id = v_gerai and stock_item_id = '00000000-0000-0000-0000-000000009502';

    if v_gudang_1 <> 7.000 or v_gudang_2 <> 3.000 then
        raise exception 'CS06_P7_SHIP_SOURCE_BALANCE_FAILED';
    end if;

    if v_gerai_1 <> 0 or v_gerai_2 <> 0 then
        raise exception 'CS06_P7_SHIP_CHANGED_DESTINATION';
    end if;

    begin
        perform public.receive_stock_transfer(v_transfer);
        raise exception 'CS06_P7_EXPECTED_DESTINATION_SCOPE_DENIED';
    exception when others then
        if sqlerrm <> 'TRANSFER_SCOPE_DENIED' then raise; end if;
    end;
end $$;

reset role;

-- Owner grants destination scope to transfer staff.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000009101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000009201"}',
    true
);

do $$
declare
    v_gerai uuid;
begin
    select id into v_gerai from public.locations
    where business_id = (select id from public.businesses where code = 'SJ') and code = 'GERAI';
    perform public.set_inventory_location_scope('00000000-0000-0000-0000-000000009303', v_gerai, true);
end $$;

reset role;

-- Destination-scoped transfer staff receives; replay cannot duplicate inbound movement.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000009103","role":"authenticated","session_id":"00000000-0000-0000-0000-000000009203"}',
    true
);

do $$
declare
    v_request uuid;
    v_transfer uuid;
    v_result jsonb;
    v_replay jsonb;
    v_inbound uuid;
    v_business uuid;
    v_gerai uuid;
    v_gerai_1 numeric;
    v_gerai_2 numeric;
    v_count integer;
begin
    select id into v_business from public.businesses where code = 'SJ';
    select id into v_gerai from public.locations where business_id = v_business and code = 'GERAI';
    select result_id into v_request from public.operation_receipts where idempotency_key = 'P7:REQUEST:CREATE:A';
    select transfer_id into v_transfer from public.restock_requests where id = v_request;

    v_result := public.receive_stock_transfer(v_transfer);
    v_inbound := (v_result ->> 'movement_id')::uuid;
    v_replay := public.receive_stock_transfer(v_transfer);

    if (v_replay ->> 'movement_id')::uuid <> v_inbound then
        raise exception 'CS06_P7_RECEIVE_REPLAY_CHANGED_MOVEMENT';
    end if;

    select count(*) into v_count
    from public.inventory_movements m
    where m.source_type = 'STOCK_TRANSFER'
      and m.source_ref = v_transfer::text
      and m.movement_type = 'TRANSFER_IN';

    if v_count <> 1 then
        raise exception 'CS06_P7_DUPLICATE_INBOUND';
    end if;

    select coalesce(sum(quantity), 0) into v_gerai_1
    from public.inventory_balances where business_id = v_business and location_id = v_gerai and stock_item_id = '00000000-0000-0000-0000-000000009501';
    select coalesce(sum(quantity), 0) into v_gerai_2
    from public.inventory_balances where business_id = v_business and location_id = v_gerai and stock_item_id = '00000000-0000-0000-0000-000000009502';

    if v_gerai_1 <> 3.000 or v_gerai_2 <> 2.000 then
        raise exception 'CS06_P7_RECEIVE_DESTINATION_BALANCE_FAILED';
    end if;
end $$;

reset role;

-- Terminal request/transfer facts and lines remain immutable.
do $$
declare
    v_request uuid;
    v_transfer uuid;
begin
    select result_id into v_request from public.operation_receipts where idempotency_key = 'P7:REQUEST:CREATE:A';
    select transfer_id into v_transfer from public.restock_requests where id = v_request;

    begin
        update public.restock_request_lines
        set requested_quantity = requested_quantity + 1
        where request_id = v_request and line_no = 1;
        raise exception 'CS06_P7_EXPECTED_RESTOCK_IMMUTABLE';
    exception when others then
        if sqlerrm <> 'RESTOCK_IMMUTABLE' then raise; end if;
    end;

    begin
        update public.restock_requests
        set notes = 'changed after approval'
        where id = v_request;
        raise exception 'CS06_P7_EXPECTED_RESTOCK_HEADER_IMMUTABLE';
    exception when others then
        if sqlerrm <> 'RESTOCK_IMMUTABLE' then raise; end if;
    end;

    begin
        update public.stock_transfer_lines
        set quantity = quantity + 1
        where transfer_id = v_transfer and line_no = 1;
        raise exception 'CS06_P7_EXPECTED_TRANSFER_IMMUTABLE';
    exception when others then
        if sqlerrm <> 'TRANSFER_IMMUTABLE' then raise; end if;
    end;

    begin
        update public.stock_transfers
        set updated_at = now()
        where id = v_transfer;
        raise exception 'CS06_P7_EXPECTED_TRANSFER_HEADER_IMMUTABLE';
    exception when others then
        if sqlerrm <> 'TRANSFER_IMMUTABLE' then raise; end if;
    end;
end $$;

-- Owner direct transfer, same-location rejection, cross-tenant guards, and shortage rollback.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000009101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000009201"}',
    true
);

do $$
declare
    v_business uuid;
    v_gudang uuid;
    v_gerai uuid;
    v_direct jsonb;
    v_short jsonb;
    v_direct_id uuid;
    v_short_id uuid;
    v_before_1 numeric;
    v_before_2 numeric;
    v_after_1 numeric;
    v_after_2 numeric;
    v_count integer;
begin
    select id into v_business from public.businesses where code = 'SJ';
    select id into v_gudang from public.locations where business_id = v_business and code = 'GUDANG';
    select id into v_gerai from public.locations where business_id = v_business and code = 'GERAI';

    v_direct := public.create_stock_transfer(
        v_gudang,
        v_gerai,
        jsonb_build_array(
            jsonb_build_object('stock_item_id', '00000000-0000-0000-0000-000000009501', 'quantity', 1.000)
        ),
        'P7:DIRECT:CREATE:A'
    );
    v_direct_id := (v_direct ->> 'transfer_id')::uuid;

    if exists (
        select 1 from public.stock_transfers st
        where st.id = v_direct_id and st.restock_request_id is not null
    ) then
        raise exception 'CS06_P7_DIRECT_TRANSFER_LINKED_REQUEST';
    end if;

    begin
        perform public.create_stock_transfer(
            v_gudang,
            v_gudang,
            jsonb_build_array(
                jsonb_build_object('stock_item_id', '00000000-0000-0000-0000-000000009501', 'quantity', 1.000)
            ),
            'P7:SAME:LOCATION'
        );
        raise exception 'CS06_P7_EXPECTED_SAME_LOCATION';
    exception when others then
        if sqlerrm <> 'TRANSFER_SAME_LOCATION' then raise; end if;
    end;

    begin
        perform public.create_stock_transfer(
            v_gudang,
            '00000000-0000-0000-0000-000000009901',
            jsonb_build_array(
                jsonb_build_object('stock_item_id', '00000000-0000-0000-0000-000000009501', 'quantity', 1.000)
            ),
            'P7:CROSS:TENANT:LOCATION'
        );
        raise exception 'CS06_P7_EXPECTED_CROSS_TENANT_LOCATION';
    exception when others then
        if sqlerrm <> 'TRANSFER_LOCATION_INVALID' then raise; end if;
    end;

    begin
        perform public.create_stock_transfer(
            v_gudang,
            v_gerai,
            jsonb_build_array(
                jsonb_build_object('stock_item_id', '00000000-0000-0000-0000-000000009902', 'quantity', 1.000)
            ),
            'P7:CROSS:TENANT:ITEM'
        );
        raise exception 'CS06_P7_EXPECTED_CROSS_TENANT_ITEM';
    exception when others then
        if sqlerrm <> 'TRANSFER_ITEM_INVALID' then raise; end if;
    end;

    v_short := public.create_stock_transfer(
        v_gudang,
        v_gerai,
        jsonb_build_array(
            jsonb_build_object('stock_item_id', '00000000-0000-0000-0000-000000009501', 'quantity', 100.000),
            jsonb_build_object('stock_item_id', '00000000-0000-0000-0000-000000009502', 'quantity', 1.000)
        ),
        'P7:SHORTAGE:CREATE'
    );
    v_short_id := (v_short ->> 'transfer_id')::uuid;

    select coalesce(sum(quantity), 0) into v_before_1
    from public.inventory_balances where business_id = v_business and location_id = v_gudang and stock_item_id = '00000000-0000-0000-0000-000000009501';
    select coalesce(sum(quantity), 0) into v_before_2
    from public.inventory_balances where business_id = v_business and location_id = v_gudang and stock_item_id = '00000000-0000-0000-0000-000000009502';

    begin
        perform public.ship_stock_transfer(v_short_id);
        raise exception 'CS06_P7_EXPECTED_SHORTAGE';
    exception when others then
        if sqlerrm <> 'TRANSFER_STOCK_INSUFFICIENT' then raise; end if;
    end;

    select coalesce(sum(quantity), 0) into v_after_1
    from public.inventory_balances where business_id = v_business and location_id = v_gudang and stock_item_id = '00000000-0000-0000-0000-000000009501';
    select coalesce(sum(quantity), 0) into v_after_2
    from public.inventory_balances where business_id = v_business and location_id = v_gudang and stock_item_id = '00000000-0000-0000-0000-000000009502';
    select count(*) into v_count
    from public.inventory_movements m
    where m.source_type = 'STOCK_TRANSFER' and m.source_ref = v_short_id::text;

    if v_before_1 <> v_after_1
       or v_before_2 <> v_after_2
       or v_count <> 0
       or not exists (select 1 from public.stock_transfers where id = v_short_id and status = 'DRAFT') then
        raise exception 'CS06_P7_SHORTAGE_CHANGED_STOCK';
    end if;
end $$;

-- Owner revokes transfer staff source scope; next ship must be denied.
do $$
declare
    v_gudang uuid;
begin
    select id into v_gudang from public.locations
    where business_id = (select id from public.businesses where code = 'SJ') and code = 'GUDANG';
    perform public.set_inventory_location_scope('00000000-0000-0000-0000-000000009303', v_gudang, false);

    if not exists (
        select 1
        from public.inventory_location_scopes s
        where s.profile_id = '00000000-0000-0000-0000-000000009303'
          and s.location_id = v_gudang
          and s.active = false
          and s.updated_by = '00000000-0000-0000-0000-000000009301'
    ) then
        raise exception 'CS06_P7_SCOPE_SOFT_DISABLE_FAILED';
    end if;
end $$;

reset role;

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000009103","role":"authenticated","session_id":"00000000-0000-0000-0000-000000009203"}',
    true
);

do $$
declare
    v_direct uuid;
begin
    select result_id into v_direct
    from public.operation_receipts
    where idempotency_key = 'P7:DIRECT:CREATE:A';

    begin
        perform public.ship_stock_transfer(v_direct);
        raise exception 'CS06_P7_SCOPE_REVOKE_NOT_ENFORCED';
    exception when others then
        if sqlerrm <> 'TRANSFER_SCOPE_DENIED' then raise; end if;
    end;
end $$;

rollback;
