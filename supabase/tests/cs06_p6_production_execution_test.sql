begin;

-- CS-06-P6 integration regression: single-location production execution.

insert into auth.users (id, email, is_sso_user, is_anonymous)
values
    ('00000000-0000-0000-0000-000000008101', 'p6-owner@auth.segeranjiwa.invalid', false, false),
    ('00000000-0000-0000-0000-000000008102', 'p6-cashier@auth.segeranjiwa.invalid', false, false);

insert into auth.sessions (id, user_id)
values
    ('00000000-0000-0000-0000-000000008201', '00000000-0000-0000-0000-000000008101'),
    ('00000000-0000-0000-0000-000000008202', '00000000-0000-0000-0000-000000008102');

insert into public.profiles (id, auth_user_id, display_name, status)
values
    ('00000000-0000-0000-0000-000000008301', '00000000-0000-0000-0000-000000008101', 'P6 Owner', 'ACTIVE'),
    ('00000000-0000-0000-0000-000000008302', '00000000-0000-0000-0000-000000008102', 'P6 Cashier', 'ACTIVE');

insert into public.user_login_identities (profile_id, username)
values
    ('00000000-0000-0000-0000-000000008301', 'p6-owner'),
    ('00000000-0000-0000-0000-000000008302', 'p6-cashier');

insert into public.business_memberships (business_id, profile_id, role_code)
select id, '00000000-0000-0000-0000-000000008301', 'OWNER'
from public.businesses where code = 'SJ';

insert into public.business_memberships (business_id, profile_id, role_code)
select id, '00000000-0000-0000-0000-000000008302', 'KASIR'
from public.businesses where code = 'SJ';

insert into public.trusted_devices (id, business_id, friendly_name, device_kind, platform_label)
select '00000000-0000-0000-0000-000000008401', id, 'P6 Owner Device', 'PERSONAL', 'TEST'
from public.businesses where code = 'SJ';

insert into public.trusted_devices (id, business_id, friendly_name, device_kind, platform_label)
select '00000000-0000-0000-0000-000000008402', id, 'P6 Cashier Device', 'PERSONAL', 'TEST'
from public.businesses where code = 'SJ';

insert into public.user_device_access (business_id, profile_id, device_id)
select id, '00000000-0000-0000-0000-000000008301', '00000000-0000-0000-0000-000000008401'
from public.businesses where code = 'SJ';

insert into public.user_device_access (business_id, profile_id, device_id)
select id, '00000000-0000-0000-0000-000000008302', '00000000-0000-0000-0000-000000008402'
from public.businesses where code = 'SJ';

insert into public.session_registry (session_id, business_id, profile_id, device_id)
select '00000000-0000-0000-0000-000000008201', id, '00000000-0000-0000-0000-000000008301', '00000000-0000-0000-0000-000000008401'
from public.businesses where code = 'SJ';

insert into public.session_registry (session_id, business_id, profile_id, device_id)
select '00000000-0000-0000-0000-000000008202', id, '00000000-0000-0000-0000-000000008302', '00000000-0000-0000-0000-000000008402'
from public.businesses where code = 'SJ';

insert into public.businesses (id, code, display_name)
values ('00000000-0000-0000-0000-000000008900', 'P6X', 'P6 Foreign Business');

insert into public.locations (id, business_id, code, display_name, location_type, active)
select '00000000-0000-0000-0000-000000008601', id, 'P6OFF', 'P6 Inactive Store', 'STORE', false
from public.businesses where code = 'SJ';

insert into public.locations (id, business_id, code, display_name, location_type, active)
values ('00000000-0000-0000-0000-000000008901', '00000000-0000-0000-0000-000000008900', 'P6XSTORE', 'P6 Foreign Store', 'STORE', true);

do $$
declare
    v_business uuid;
begin
    select id into v_business from public.businesses where code = 'SJ';

    insert into public.stock_items(id, business_id, code, display_name, item_kind, base_unit, active)
    values
        ('00000000-0000-0000-0000-000000008501', v_business, 'P6FG', 'P6 Finished Good', 'FINISHED_GOOD', 'PCS', true),
        ('00000000-0000-0000-0000-000000008502', v_business, 'P6MAT', 'P6 Material', 'MATERIAL', 'GRAM', true),
        ('00000000-0000-0000-0000-000000008503', v_business, 'P6PACK', 'P6 Packaging', 'PACKAGING', 'PCS', true);
end $$;

-- Owner creates and activates BOM V1.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000008101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000008201"}',
    true
);

do $$
declare
    v_result jsonb;
    v_bom uuid;
begin
    v_result := public.save_bom_draft(
        '00000000-0000-0000-0000-000000008501',
        1,
        1.000,
        jsonb_build_array(
            jsonb_build_object('component_stock_item_id', '00000000-0000-0000-0000-000000008502', 'base_quantity', 0.200),
            jsonb_build_object('component_stock_item_id', '00000000-0000-0000-0000-000000008503', 'base_quantity', 1.000)
        ),
        'P6:BOM:SAVE:V1'
    );
    v_bom := (v_result ->> 'bom_id')::uuid;
    perform public.activate_bom(v_bom, 'P6:BOM:ACTIVATE:V1');
end $$;

-- Batch A binds BOM V1.
do $$
declare
    v_location uuid;
    v_result jsonb;
    v_bom_version integer;
begin
    select id into v_location
    from public.locations
    where business_id = (select id from public.businesses where code = 'SJ')
      and code = 'GERAI';

    v_result := public.create_production_batch(
        v_location,
        '00000000-0000-0000-0000-000000008501',
        5.000,
        'P6:BATCH:CREATE:A'
    );

    select b.version into v_bom_version
    from public.production_batches pb
    join public.boms b on b.id = pb.bom_id
    where pb.id = (v_result ->> 'batch_id')::uuid;

    if v_bom_version <> 1 or v_result ->> 'status' <> 'DRAFT' then
        raise exception 'CS06_P6_CREATE_BIND_V1_FAILED';
    end if;
end $$;

-- Activate V2 after Batch A exists; Batch A must remain bound to V1.
do $$
declare
    v_result jsonb;
    v_bom uuid;
    v_batch uuid;
    v_bound_version integer;
begin
    v_result := public.save_bom_draft(
        '00000000-0000-0000-0000-000000008501',
        2,
        1.000,
        jsonb_build_array(
            jsonb_build_object('component_stock_item_id', '00000000-0000-0000-0000-000000008502', 'base_quantity', 0.500),
            jsonb_build_object('component_stock_item_id', '00000000-0000-0000-0000-000000008503', 'base_quantity', 2.000)
        ),
        'P6:BOM:SAVE:V2'
    );
    v_bom := (v_result ->> 'bom_id')::uuid;
    perform public.activate_bom(v_bom, 'P6:BOM:ACTIVATE:V2');

    select result_id into v_batch
    from public.operation_receipts
    where idempotency_key = 'P6:BATCH:CREATE:A';

    select b.version into v_bound_version
    from public.production_batches pb
    join public.boms b on b.id = pb.bom_id
    where pb.id = v_batch;

    if v_bound_version <> 1 then
        raise exception 'CS06_P6_BOUND_BOM_CHANGED';
    end if;
end $$;

reset role;

-- Seed component stock at Gerai only through canonical inventory authority.
do $$
declare
    v_business uuid;
    v_location uuid;
    v_movement uuid;
begin
    select id into v_business from public.businesses where code = 'SJ';
    select id into v_location from public.locations where business_id = v_business and code = 'GERAI';

    v_movement := private.record_inventory_movement(
        v_business,
        '00000000-0000-0000-0000-000000008301',
        'P6:SEED:COMPONENTS',
        'OPENING_STOCK',
        'P6_TEST',
        'SEED',
        'P6_TEST_SEED',
        jsonb_build_array(
            jsonb_build_object('line_no', 1, 'stock_item_id', '00000000-0000-0000-0000-000000008502', 'location_id', v_location, 'quantity_delta', 10.000),
            jsonb_build_object('line_no', 2, 'stock_item_id', '00000000-0000-0000-0000-000000008503', 'location_id', v_location, 'quantity_delta', 20.000)
        ),
        null
    );

    if v_movement is null then
        raise exception 'CS06_P6_SEED_FAILED';
    end if;
end $$;

-- Post Batch A. It must use bound V1 quantities: material -1, packaging -5, finished +5.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000008101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000008201"}',
    true
);

do $$
declare
    v_batch uuid;
    v_result jsonb;
    v_replay jsonb;
    v_movement uuid;
    v_count integer;
begin
    select result_id into v_batch
    from public.operation_receipts
    where idempotency_key = 'P6:BATCH:CREATE:A';

    v_result := public.post_production_batch(v_batch, 5.000);
    v_movement := (v_result ->> 'movement_id')::uuid;

    if v_result ->> 'status' <> 'POSTED'
       or coalesce((v_result ->> 'already_posted')::boolean, true) then
        raise exception 'CS06_P6_POST_FAILED';
    end if;

    v_replay := public.post_production_batch(v_batch, 5.000);
    if coalesce((v_replay ->> 'already_posted')::boolean, false) is not true
       or (v_replay ->> 'movement_id')::uuid <> v_movement then
        raise exception 'CS06_P6_POST_REPLAY_FAILED';
    end if;

    select count(*) into v_count
    from public.inventory_movements
    where movement_type = 'PRODUCTION'
      and source_type = 'PRODUCTION_BATCH'
      and source_ref = v_batch::text;

    if v_count <> 1 then
        raise exception 'CS06_P6_DUPLICATE_MOVEMENT';
    end if;

    begin
        perform public.post_production_batch(v_batch, 4.000);
        raise exception 'CS06_P6_EXPECTED_POST_MISMATCH';
    exception when others then
        if sqlerrm <> 'PRODUCTION_ALREADY_POSTED_MISMATCH' then raise; end if;
    end;
end $$;

reset role;

-- Exact inventory balances prove bound V1, not newly-active V2, was consumed.
do $$
declare
    v_business uuid;
    v_location uuid;
    v_material numeric;
    v_packaging numeric;
    v_finished numeric;
begin
    select id into v_business from public.businesses where code = 'SJ';
    select id into v_location from public.locations where business_id = v_business and code = 'GERAI';

    select coalesce(sum(quantity), 0) into v_material
    from public.inventory_balances
    where business_id = v_business and location_id = v_location
      and stock_item_id = '00000000-0000-0000-0000-000000008502';

    select coalesce(sum(quantity), 0) into v_packaging
    from public.inventory_balances
    where business_id = v_business and location_id = v_location
      and stock_item_id = '00000000-0000-0000-0000-000000008503';

    select coalesce(sum(quantity), 0) into v_finished
    from public.inventory_balances
    where business_id = v_business and location_id = v_location
      and stock_item_id = '00000000-0000-0000-0000-000000008501';

    if v_material <> 9.000 or v_packaging <> 15.000 or v_finished <> 5.000 then
        raise exception 'CS06_P6_BOUND_BOM_CONSUMPTION_FAILED';
    end if;
end $$;

-- Owner creates a second batch under active V2; shortage must roll back all stock effects.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000008101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000008201"}',
    true
);

do $$
declare
    v_location uuid;
    v_result jsonb;
    v_batch uuid;
begin
    select id into v_location
    from public.locations
    where business_id = (select id from public.businesses where code = 'SJ')
      and code = 'GERAI';

    v_result := public.create_production_batch(
        v_location,
        '00000000-0000-0000-0000-000000008501',
        100.000,
        'P6:BATCH:CREATE:B'
    );
    v_batch := (v_result ->> 'batch_id')::uuid;

    begin
        perform public.post_production_batch(v_batch, 100.000);
        raise exception 'CS06_P6_EXPECTED_SHORTAGE';
    exception when others then
        if sqlerrm <> 'PRODUCTION_STOCK_INSUFFICIENT' then raise; end if;
    end;
end $$;

reset role;

do $$
declare
    v_business uuid;
    v_location uuid;
    v_batch uuid;
    v_material numeric;
    v_packaging numeric;
    v_finished numeric;
    v_movement_count integer;
begin
    select id into v_business from public.businesses where code = 'SJ';
    select id into v_location from public.locations where business_id = v_business and code = 'GERAI';
    select result_id into v_batch from public.operation_receipts where idempotency_key = 'P6:BATCH:CREATE:B';

    select coalesce(sum(quantity), 0) into v_material
    from public.inventory_balances
    where business_id = v_business and location_id = v_location
      and stock_item_id = '00000000-0000-0000-0000-000000008502';
    select coalesce(sum(quantity), 0) into v_packaging
    from public.inventory_balances
    where business_id = v_business and location_id = v_location
      and stock_item_id = '00000000-0000-0000-0000-000000008503';
    select coalesce(sum(quantity), 0) into v_finished
    from public.inventory_balances
    where business_id = v_business and location_id = v_location
      and stock_item_id = '00000000-0000-0000-0000-000000008501';

    select count(*) into v_movement_count
    from public.inventory_movements
    where source_type = 'PRODUCTION_BATCH'
      and source_ref = v_batch::text;

    if v_material <> 9.000
       or v_packaging <> 15.000
       or v_finished <> 5.000
       or v_movement_count <> 0
       or not exists (
            select 1 from public.production_batches
            where id = v_batch and status = 'DRAFT' and inventory_movement_id is null
       ) then
        raise exception 'CS06_P6_SHORTAGE_CHANGED_STOCK';
    end if;
end $$;

-- Cashier has no PRODUCTION_MANAGE permission.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000008102","role":"authenticated","session_id":"00000000-0000-0000-0000-000000008202"}',
    true
);

do $$
declare
    v_location uuid;
    v_batch uuid;
begin
    select id into v_location
    from public.locations
    where business_id = (select id from public.businesses where code = 'SJ')
      and code = 'GERAI';
    select result_id into v_batch from public.operation_receipts where idempotency_key = 'P6:BATCH:CREATE:B';

    begin
        perform public.create_production_batch(
            v_location,
            '00000000-0000-0000-0000-000000008501',
            1.000,
            'P6:CASHIER:CREATE'
        );
        raise exception 'CS06_P6_EXPECTED_CREATE_PERMISSION_DENIED';
    exception when others then
        if sqlerrm <> 'SJ_PRODUCTION_PERMISSION_DENIED' then raise; end if;
    end;

    begin
        perform public.post_production_batch(v_batch, 1.000);
        raise exception 'CS06_P6_EXPECTED_POST_PERMISSION_DENIED';
    exception when others then
        if sqlerrm <> 'SJ_PRODUCTION_PERMISSION_DENIED' then raise; end if;
    end;
end $$;

reset role;

-- Invalid, inactive, and cross-tenant locations fail closed for owner.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000008101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000008201"}',
    true
);

do $$
begin
    begin
        perform public.create_production_batch(
            '00000000-0000-0000-0000-000000008601',
            '00000000-0000-0000-0000-000000008501',
            1.000,
            'P6:ERR:INACTIVE_LOCATION'
        );
        raise exception 'CS06_P6_EXPECTED_INACTIVE_LOCATION';
    exception when others then
        if sqlerrm <> 'PRODUCTION_LOCATION_INVALID' then raise; end if;
    end;

    begin
        perform public.create_production_batch(
            '00000000-0000-0000-0000-000000008901',
            '00000000-0000-0000-0000-000000008501',
            1.000,
            'P6:ERR:CROSS_LOCATION'
        );
        raise exception 'CS06_P6_EXPECTED_CROSS_LOCATION';
    exception when others then
        if sqlerrm <> 'PRODUCTION_LOCATION_INVALID' then raise; end if;
    end;
end $$;

reset role;

-- POSTED facts are immutable even to a privileged SQL caller.
do $$
declare
    v_batch uuid;
begin
    select result_id into v_batch from public.operation_receipts where idempotency_key = 'P6:BATCH:CREATE:A';

    begin
        update public.production_batches
        set planned_output = 6.000
        where id = v_batch;
        raise exception 'CS06_P6_EXPECTED_IMMUTABLE';
    exception when others then
        if sqlerrm <> 'PRODUCTION_IMMUTABLE' then raise; end if;
    end;
end $$;

rollback;
