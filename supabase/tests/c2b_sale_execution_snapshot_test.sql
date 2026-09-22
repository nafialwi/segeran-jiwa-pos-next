begin;

-- C2-B integration regression:
-- - real MAKE_TO_ORDER variant checkout;
-- - immutable component snapshot;
-- - aggregated inventory posting;
-- - replay safety;
-- - existing Refund and Correction reverse the original component movement;
-- - legacy checkout still uses the same post-sale writer fallback.

insert into auth.users (id, email, is_sso_user, is_anonymous)
values (
    '00000000-0000-0000-0000-000000009101',
    'c2b-owner@auth.segeranjiwa.invalid',
    false,
    false
);

insert into auth.sessions (id, user_id)
values (
    '00000000-0000-0000-0000-000000009201',
    '00000000-0000-0000-0000-000000009101'
);

insert into public.profiles (id, auth_user_id, display_name, status)
values (
    '00000000-0000-0000-0000-000000009301',
    '00000000-0000-0000-0000-000000009101',
    'C2B Owner',
    'ACTIVE'
);

insert into public.user_login_identities (profile_id, username)
values (
    '00000000-0000-0000-0000-000000009301',
    'c2b-owner'
);

insert into public.business_memberships (business_id, profile_id, role_code)
select
    id,
    '00000000-0000-0000-0000-000000009301',
    'OWNER'
from public.businesses
where code = 'SJ';

insert into public.trusted_devices (
    id,
    business_id,
    friendly_name,
    device_kind,
    platform_label
)
select
    '00000000-0000-0000-0000-000000009401',
    id,
    'C2B Device',
    'PERSONAL',
    'TEST'
from public.businesses
where code = 'SJ';

insert into public.user_device_access (
    business_id,
    profile_id,
    device_id
)
select
    id,
    '00000000-0000-0000-0000-000000009301',
    '00000000-0000-0000-0000-000000009401'
from public.businesses
where code = 'SJ';

insert into public.session_registry (
    session_id,
    business_id,
    profile_id,
    device_id
)
select
    '00000000-0000-0000-0000-000000009201',
    id,
    '00000000-0000-0000-0000-000000009301',
    '00000000-0000-0000-0000-000000009401'
from public.businesses
where code = 'SJ';

do $$
declare
    v_business uuid;
    v_location uuid;
begin
    select id into v_business
    from public.businesses
    where code = 'SJ';

    select id into v_location
    from public.locations
    where business_id = v_business
      and code = 'GERAI';

    insert into public.stock_items (
        id,
        business_id,
        code,
        display_name,
        item_kind,
        base_unit,
        active,
        sale_price,
        sale_category,
        sale_enabled,
        inventory_tracked
    ) values
        (
            '00000000-0000-0000-0000-000000009501',
            v_business,
            'C2B_ING',
            'C2B Ingredient',
            'MATERIAL',
            'KG',
            true,
            null,
            null,
            false,
            true
        ),
        (
            '00000000-0000-0000-0000-000000009502',
            v_business,
            'C2B_CUP',
            'C2B Cup',
            'PACKAGING',
            'PCS',
            true,
            null,
            null,
            false,
            true
        ),
        (
            '00000000-0000-0000-0000-000000009503',
            v_business,
            'C2B_DIRECT',
            'C2B Direct Stock',
            'FINISHED_GOOD',
            'PCS',
            true,
            5000,
            'TEST',
            true,
            true
        );

    insert into public.sale_products (
        id,
        business_id,
        code,
        display_name,
        category_code,
        active
    ) values (
        '00000000-0000-0000-0000-000000009601',
        v_business,
        'C2BMTO',
        'C2B Make To Order',
        'TEST',
        true
    );

    insert into public.product_variants (
        id,
        business_id,
        product_id,
        code,
        display_name,
        fulfillment_mode,
        sale_stock_item_id,
        sale_price,
        active,
        is_default
    ) values (
        '00000000-0000-0000-0000-000000009602',
        v_business,
        '00000000-0000-0000-0000-000000009601',
        'REGULAR',
        'Regular',
        'MAKE_TO_ORDER',
        null,
        10000,
        true,
        true
    );

    insert into public.variant_sale_components (
        variant_id,
        line_no,
        stock_item_id,
        component_role,
        quantity_per_unit
    ) values
        (
            '00000000-0000-0000-0000-000000009602',
            1,
            '00000000-0000-0000-0000-000000009501',
            'INGREDIENT',
            0.050
        ),
        (
            '00000000-0000-0000-0000-000000009602',
            2,
            '00000000-0000-0000-0000-000000009502',
            'PACKAGING',
            1.000
        );

    insert into public.shifts (
        id,
        business_id,
        location_id,
        cashier_profile_id,
        opening_balance,
        status
    ) values (
        '00000000-0000-0000-0000-000000009701',
        v_business,
        v_location,
        '00000000-0000-0000-0000-000000009301',
        0,
        'OPEN'
    );

    perform private.record_inventory_movement(
        v_business,
        '00000000-0000-0000-0000-000000009301',
        'C2B:OPENING',
        'OPENING',
        'C2B_TEST',
        'C2B_OPENING',
        'OPENING_BALANCE',
        jsonb_build_array(
            jsonb_build_object(
                'line_no', 1,
                'stock_item_id', '00000000-0000-0000-0000-000000009501',
                'location_id', v_location,
                'quantity_delta', 1.000
            ),
            jsonb_build_object(
                'line_no', 2,
                'stock_item_id', '00000000-0000-0000-0000-000000009502',
                'location_id', v_location,
                'quantity_delta', 10.000
            ),
            jsonb_build_object(
                'line_no', 3,
                'stock_item_id', '00000000-0000-0000-0000-000000009503',
                'location_id', v_location,
                'quantity_delta', 5.000
            )
        )
    );
end $$;

set local role authenticated;

select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000009101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000009201"}',
    true
);

do $$
declare
    v_location uuid;
    v_result jsonb;
    v_replay jsonb;
    v_sale1 uuid;
    v_sale2 uuid;
    v_legacy_sale uuid;
begin
    select id into v_location
    from public.locations
    where code = 'GERAI'
      and business_id = (
          select id from public.businesses where code = 'SJ'
      );

    v_result := public.checkout_sale_v2(
        '00000000-0000-0000-0000-000000009801',
        v_location,
        jsonb_build_array(
            jsonb_build_object(
                'variant_id', '00000000-0000-0000-0000-000000009602',
                'quantity', 2
            )
        ),
        jsonb_build_object('method','CASH','amount',20000),
        'C2B sale one'
    );

    v_sale1 := (v_result ->> 'sale_id')::uuid;

    if v_result ->> 'inventory_basis' <> 'SNAPSHOT_V2'
       or coalesce((v_result ->> 'already_posted')::boolean, true) then
        raise exception 'C2B_FIRST_CHECKOUT_FAILED';
    end if;

    v_replay := public.checkout_sale_v2(
        '00000000-0000-0000-0000-000000009801',
        v_location,
        jsonb_build_array(
            jsonb_build_object(
                'variant_id', '00000000-0000-0000-0000-000000009602',
                'quantity', 2
            )
        ),
        jsonb_build_object('method','CASH','amount',20000),
        'C2B sale one'
    );

    if (v_replay ->> 'sale_id')::uuid <> v_sale1
       or coalesce((v_replay ->> 'already_posted')::boolean, false) is not true then
        raise exception 'C2B_REPLAY_FAILED';
    end if;

    v_result := public.checkout_sale_v2(
        '00000000-0000-0000-0000-000000009802',
        v_location,
        jsonb_build_array(
            jsonb_build_object(
                'variant_id', '00000000-0000-0000-0000-000000009602',
                'quantity', 1
            )
        ),
        jsonb_build_object('method','CASH','amount',10000),
        'C2B sale two'
    );

    v_sale2 := (v_result ->> 'sale_id')::uuid;

    v_result := public.checkout_sale(
        '00000000-0000-0000-0000-000000009803',
        v_location,
        jsonb_build_array(
            jsonb_build_object(
                'stock_item_id', '00000000-0000-0000-0000-000000009503',
                'quantity', 1
            )
        ),
        jsonb_build_object('method','CASH','amount',5000),
        'C2B legacy compatibility'
    );

    v_legacy_sale := (v_result ->> 'sale_id')::uuid;

    perform set_config('c2b.sale1', v_sale1::text, true);
    perform set_config('c2b.sale2', v_sale2::text, true);
    perform set_config('c2b.legacy_sale', v_legacy_sale::text, true);

    perform public.refund_sale(
        v_sale1,
        'RETURN_TO_STOCK',
        'CASH',
        'C2B refund snapshot reversal',
        'C2B:REFUND:SALE1'
    );

    perform public.correct_sale(
        v_sale2,
        'C2B correction snapshot reversal',
        'C2B:CORRECT:SALE2'
    );
end $$;

reset role;

do $$
declare
    v_sale1 uuid := current_setting('c2b.sale1')::uuid;
    v_sale2 uuid := current_setting('c2b.sale2')::uuid;
    v_legacy_sale uuid := current_setting('c2b.legacy_sale')::uuid;
    v_count integer;
    v_qty numeric;
    v_invoice text;
    v_original_movement uuid;
    v_reversal_movement uuid;
    v_business uuid;
    v_location uuid;
begin
    select count(*)
    into v_count
    from public.sale_item_component_snapshots s
    where s.sale_id = v_sale1;

    if v_count <> 2 then
        raise exception 'C2B_SNAPSHOT_COUNT_FAILED';
    end if;

    select quantity_total
    into v_qty
    from public.sale_item_component_snapshots
    where sale_id = v_sale1
      and stock_item_id = '00000000-0000-0000-0000-000000009501';

    if v_qty <> 0.100 then
        raise exception 'C2B_SNAPSHOT_QUANTITY_FAILED';
    end if;

    select quantity_total
    into v_qty
    from public.sale_item_component_snapshots
    where sale_id = v_sale1
      and stock_item_id = '00000000-0000-0000-0000-000000009502';

    if v_qty <> 2.000 then
        raise exception 'C2B_SNAPSHOT_QUANTITY_FAILED';
    end if;

    if exists (
        select 1
        from public.sale_items
        where sale_id = v_sale1
          and stock_item_id is not null
    ) then
        raise exception 'C2B_MAKE_TO_ORDER_FAKE_STOCK_ITEM';
    end if;

    select s.invoice_number
    into v_invoice
    from public.sales s
    where s.id = v_sale1;

    select im.id
    into v_original_movement
    from public.inventory_movements im
    where im.source_type = 'SALE'
      and im.source_ref = v_invoice
      and im.reason_code = 'SALE_CONSUMPTION';

    select count(*)
    into v_count
    from public.inventory_movements im
    where im.source_type = 'SALE'
      and im.source_ref = v_invoice
      and im.reason_code = 'SALE_CONSUMPTION';

    if v_count <> 1 or v_original_movement is null then
        raise exception 'C2B_REPLAY_FAILED';
    end if;

    select quantity_delta
    into v_qty
    from public.inventory_movement_lines
    where movement_id = v_original_movement
      and stock_item_id = '00000000-0000-0000-0000-000000009501';

    if v_qty <> -0.100 then
        raise exception 'C2B_INVENTORY_AGGREGATION_FAILED';
    end if;

    select quantity_delta
    into v_qty
    from public.inventory_movement_lines
    where movement_id = v_original_movement
      and stock_item_id = '00000000-0000-0000-0000-000000009502';

    if v_qty <> -2.000 then
        raise exception 'C2B_INVENTORY_AGGREGATION_FAILED';
    end if;

    select r.inventory_movement_id
    into v_reversal_movement
    from public.sale_refunds r
    where r.sale_id = v_sale1;

    select quantity_delta
    into v_qty
    from public.inventory_movement_lines
    where movement_id = v_reversal_movement
      and stock_item_id = '00000000-0000-0000-0000-000000009501';

    if v_qty <> 0.100 then
        raise exception 'C2B_REFUND_REVERSAL_FAILED';
    end if;

    select c.inventory_reversal_movement_id
    into v_reversal_movement
    from public.sale_corrections c
    where c.sale_id = v_sale2;

    select quantity_delta
    into v_qty
    from public.inventory_movement_lines
    where movement_id = v_reversal_movement
      and stock_item_id = '00000000-0000-0000-0000-000000009502';

    if v_qty <> 1.000 then
        raise exception 'C2B_CORRECTION_REVERSAL_FAILED';
    end if;

    if exists (
        select 1
        from public.sale_item_component_snapshots
        where sale_id = v_legacy_sale
    ) then
        raise exception 'C2B_LEGACY_SNAPSHOT_UNEXPECTED';
    end if;

    select s.invoice_number
    into v_invoice
    from public.sales s
    where s.id = v_legacy_sale;

    select im.id
    into v_original_movement
    from public.inventory_movements im
    where im.source_type = 'SALE'
      and im.source_ref = v_invoice
      and im.reason_code = 'SALE_CONSUMPTION';

    select quantity_delta
    into v_qty
    from public.inventory_movement_lines
    where movement_id = v_original_movement
      and stock_item_id = '00000000-0000-0000-0000-000000009503';

    if v_qty <> -1.000 then
        raise exception 'C2B_LEGACY_FALLBACK_FAILED';
    end if;

    select id into v_business
    from public.businesses
    where code = 'SJ';

    select id into v_location
    from public.locations
    where business_id = v_business
      and code = 'GERAI';

    select quantity
    into v_qty
    from public.inventory_balances
    where business_id = v_business
      and location_id = v_location
      and stock_item_id = '00000000-0000-0000-0000-000000009501';

    if v_qty <> 1.000 then
        raise exception 'C2B_FINAL_BALANCE_FAILED';
    end if;

    select quantity
    into v_qty
    from public.inventory_balances
    where business_id = v_business
      and location_id = v_location
      and stock_item_id = '00000000-0000-0000-0000-000000009502';

    if v_qty <> 10.000 then
        raise exception 'C2B_FINAL_BALANCE_FAILED';
    end if;

    select quantity
    into v_qty
    from public.inventory_balances
    where business_id = v_business
      and location_id = v_location
      and stock_item_id = '00000000-0000-0000-0000-000000009503';

    if v_qty <> 4.000 then
        raise exception 'C2B_FINAL_BALANCE_FAILED';
    end if;
end $$;

rollback;
