begin;

-- CS-06-P8 integration regression: Stock Opname + adjustment/write-off + reversal.

insert into auth.users (id, email, is_sso_user, is_anonymous)
values
    ('00000000-0000-0000-0000-000000008101', 'p8-owner@auth.segeranjiwa.invalid', false, false),
    ('00000000-0000-0000-0000-000000008102', 'p8-stock@auth.segeranjiwa.invalid', false, false);

insert into auth.sessions (id, user_id)
values
    ('00000000-0000-0000-0000-000000008201', '00000000-0000-0000-0000-000000008101'),
    ('00000000-0000-0000-0000-000000008202', '00000000-0000-0000-0000-000000008102');

insert into public.profiles (id, auth_user_id, display_name, status)
values
    ('00000000-0000-0000-0000-000000008301', '00000000-0000-0000-0000-000000008101', 'P8 Owner', 'ACTIVE'),
    ('00000000-0000-0000-0000-000000008302', '00000000-0000-0000-0000-000000008102', 'P8 Stock Staff', 'ACTIVE');

insert into public.user_login_identities (profile_id, username)
values
    ('00000000-0000-0000-0000-000000008301', 'p8-owner'),
    ('00000000-0000-0000-0000-000000008302', 'p8-stock');

insert into public.business_memberships (business_id, profile_id, role_code)
select id, '00000000-0000-0000-0000-000000008301', 'OWNER'
from public.businesses where code = 'SJ';

insert into public.business_memberships (business_id, profile_id, role_code)
select id, '00000000-0000-0000-0000-000000008302', 'KASIR'
from public.businesses where code = 'SJ';

insert into public.trusted_devices (id, business_id, friendly_name, device_kind, platform_label)
select '00000000-0000-0000-0000-000000008401', id, 'P8 Owner Device', 'PERSONAL', 'TEST'
from public.businesses where code = 'SJ';

insert into public.trusted_devices (id, business_id, friendly_name, device_kind, platform_label)
select '00000000-0000-0000-0000-000000008402', id, 'P8 Stock Device', 'PERSONAL', 'TEST'
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

insert into public.user_permission_overrides (
    business_id, profile_id, permission_code, effect, set_by_profile_id
)
select id, '00000000-0000-0000-0000-000000008302', 'INVENTORY_COUNT', 'ALLOW', '00000000-0000-0000-0000-000000008301'
from public.businesses where code = 'SJ';

insert into public.user_permission_overrides (
    business_id, profile_id, permission_code, effect, set_by_profile_id
)
select id, '00000000-0000-0000-0000-000000008302', 'INVENTORY_ADJUST', 'ALLOW', '00000000-0000-0000-0000-000000008301'
from public.businesses where code = 'SJ';

do $$
declare
    v_business uuid;
    v_gerai uuid;
begin
    select id into v_business from public.businesses where code = 'SJ';
    select id into v_gerai from public.locations where business_id = v_business and code = 'GERAI';

    insert into public.stock_items(id, business_id, code, display_name, item_kind, base_unit, active)
    values ('00000000-0000-0000-0000-000000008501', v_business, 'P8ITEM1', 'P8 Item One', 'MATERIAL', 'PCS', true);

    perform private.record_inventory_movement(
        v_business,
        '00000000-0000-0000-0000-000000008301',
        'P8:SEED:STOCK',
        'P8_SEED',
        'P8_TEST',
        'SEED',
        'P8_INITIAL_STOCK',
        jsonb_build_array(
            jsonb_build_object(
                'line_no', 1,
                'stock_item_id', '00000000-0000-0000-0000-000000008501',
                'location_id', v_gerai,
                'quantity_delta', 10.000
            )
        ),
        null
    );
end $$;

-- Staff has permission but no P7 location scope yet.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000008102","role":"authenticated","session_id":"00000000-0000-0000-0000-000000008202"}',
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
        perform public.create_inventory_count(
            v_gerai,
            array['00000000-0000-0000-0000-000000008501'::uuid],
            'P8 scope denied',
            'P8:COUNT:SCOPE:DENY'
        );
        raise exception 'CS06_P8_EXPECTED_COUNT_SCOPE_DENIED';
    exception when others then
        if sqlerrm <> 'INVENTORY_COUNT_SCOPE_DENIED' then raise; end if;
    end;
end $$;

reset role;

-- Owner grants Gerai scope to stock staff.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000008101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000008201"}',
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

    perform public.set_inventory_location_scope(
        '00000000-0000-0000-0000-000000008302',
        v_gerai,
        true
    );
end $$;

reset role;

-- Staff counts 10 expected as 8 physical, then posts exactly one variance movement.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000008102","role":"authenticated","session_id":"00000000-0000-0000-0000-000000008202"}',
    true
);

do $$
declare
    v_gerai uuid;
    v_result jsonb;
    v_count uuid;
    v_movement uuid;
    v_replay jsonb;
    v_balance numeric;
begin
    select id into v_gerai
    from public.locations
    where business_id = (select id from public.businesses where code = 'SJ')
      and code = 'GERAI';

    v_result := public.create_inventory_count(
        v_gerai,
        array['00000000-0000-0000-0000-000000008501'::uuid],
        'P8 Stock Opname',
        'P8:COUNT:CREATE:A'
    );
    v_count := (v_result ->> 'count_id')::uuid;

    perform public.record_inventory_count(
        v_count,
        jsonb_build_array(
            jsonb_build_object(
                'stock_item_id', '00000000-0000-0000-0000-000000008501',
                'physical_quantity', 8.000
            )
        )
    );

    v_result := public.post_inventory_count(v_count);
    v_movement := nullif(v_result ->> 'movement_id', '')::uuid;

    if v_movement is null then
        raise exception 'CS06_P8_COUNT_MOVEMENT_MISSING';
    end if;

    if not exists (
        select 1
        from public.inventory_movements im
        where im.id = v_movement
          and im.movement_type = 'STOCK_OPNAME'
          and im.source_type = 'INVENTORY_COUNT'
          and im.reverses_movement_id is null
    ) then
        raise exception 'CS06_P8_COUNT_MOVEMENT_INVALID';
    end if;

    select quantity into v_balance
    from public.inventory_balances
    where business_id = (select id from public.businesses where code = 'SJ')
      and stock_item_id = '00000000-0000-0000-0000-000000008501'
      and location_id = v_gerai;

    if v_balance <> 8.000 then
        raise exception 'CS06_P8_COUNT_BALANCE_FAILED';
    end if;

    v_replay := public.post_inventory_count(v_count);
    if (v_replay ->> 'movement_id')::uuid <> v_movement then
        raise exception 'CS06_P8_COUNT_REPLAY_CHANGED_MOVEMENT';
    end if;

    if (
        select count(*)
        from public.inventory_movements im
        where im.source_type = 'INVENTORY_COUNT'
          and im.source_ref = v_count::text
    ) <> 1 then
        raise exception 'CS06_P8_DUPLICATE_COUNT_MOVEMENT';
    end if;

    begin
        update public.inventory_count_lines
        set physical_quantity = 9.000
        where count_id = v_count;
        raise exception 'CS06_P8_EXPECTED_COUNT_IMMUTABLE';
    exception when others then
        if sqlerrm <> 'INVENTORY_COUNT_IMMUTABLE' then raise; end if;
    end;
end $$;

-- Adjustment is idempotent; write-off and negative-stock guard are enforced.
do $$
declare
    v_gerai uuid;
    v_adjust jsonb;
    v_replay jsonb;
    v_writeoff jsonb;
    v_adjustment uuid;
    v_adjustment_movement uuid;
    v_balance numeric;
begin
    select id into v_gerai
    from public.locations
    where business_id = (select id from public.businesses where code = 'SJ')
      and code = 'GERAI';

    v_adjust := public.post_inventory_adjustment(
        v_gerai,
        '00000000-0000-0000-0000-000000008501',
        'ADJUSTMENT',
        2.000,
        'MANUAL_CORRECTION',
        'P8 add two',
        'P8:ADJUST:A'
    );
    v_adjustment := (v_adjust ->> 'adjustment_id')::uuid;
    v_adjustment_movement := (v_adjust ->> 'movement_id')::uuid;

    v_replay := public.post_inventory_adjustment(
        v_gerai,
        '00000000-0000-0000-0000-000000008501',
        'ADJUSTMENT',
        2.000,
        'MANUAL_CORRECTION',
        'P8 add two',
        'P8:ADJUST:A'
    );

    if (v_replay ->> 'adjustment_id')::uuid <> v_adjustment then
        raise exception 'CS06_P8_ADJUST_REPLAY_CHANGED_FACT';
    end if;

    if (
        select count(*)
        from public.inventory_adjustments a
        where a.id = v_adjustment
    ) <> 1 then
        raise exception 'CS06_P8_DUPLICATE_ADJUSTMENT';
    end if;

    v_writeoff := public.post_inventory_adjustment(
        v_gerai,
        '00000000-0000-0000-0000-000000008501',
        'WRITE_OFF',
        -3.000,
        'DAMAGED',
        'P8 damaged stock',
        'P8:WRITEOFF:A'
    );

    begin
        perform public.post_inventory_adjustment(
            v_gerai,
            '00000000-0000-0000-0000-000000008501',
            'WRITE_OFF',
            -100.000,
            'DAMAGED',
            'P8 impossible writeoff',
            'P8:WRITEOFF:NEGATIVE'
        );
        raise exception 'CS06_P8_EXPECTED_NEGATIVE_STOCK_DENIED';
    exception when others then
        if sqlerrm <> 'INVENTORY_ADJUSTMENT_NEGATIVE_STOCK' then raise; end if;
    end;

    select quantity into v_balance
    from public.inventory_balances
    where business_id = (select id from public.businesses where code = 'SJ')
      and stock_item_id = '00000000-0000-0000-0000-000000008501'
      and location_id = v_gerai;

    if v_balance <> 7.000 then
        raise exception 'CS06_P8_ADJUST_BALANCE_FAILED';
    end if;

    perform set_config('p8.adjustment_movement', v_adjustment_movement::text, true);
end $$;

-- Reversal creates a compensating movement, replay is stable, second reversal is denied.
do $$
declare
    v_original uuid;
    v_result jsonb;
    v_replay jsonb;
    v_reversal uuid;
    v_balance numeric;
    v_gerai uuid;
begin
    v_original := current_setting('p8.adjustment_movement')::uuid;

    v_result := public.reverse_inventory_control(
        v_original,
        'REVERSE_TEST_ADJUSTMENT',
        'P8:REVERSE:A'
    );
    v_reversal := (v_result ->> 'reversal_movement_id')::uuid;

    if not exists (
        select 1
        from public.inventory_movements im
        where im.id = v_reversal
          and im.movement_type = 'INVENTORY_REVERSAL'
          and im.reverses_movement_id = v_original
    ) then
        raise exception 'CS06_P8_REVERSAL_LINK_MISSING';
    end if;

    v_replay := public.reverse_inventory_control(
        v_original,
        'REVERSE_TEST_ADJUSTMENT',
        'P8:REVERSE:A'
    );

    if (v_replay ->> 'reversal_movement_id')::uuid <> v_reversal then
        raise exception 'CS06_P8_REVERSAL_REPLAY_CHANGED_MOVEMENT';
    end if;

    begin
        perform public.reverse_inventory_control(
            v_original,
            'SECOND_REVERSAL',
            'P8:REVERSE:B'
        );
        raise exception 'CS06_P8_EXPECTED_SECOND_REVERSAL_DENIED';
    exception when others then
        if sqlerrm <> 'INVENTORY_CONTROL_ALREADY_REVERSED' then raise; end if;
    end;

    select id into v_gerai
    from public.locations
    where business_id = (select id from public.businesses where code = 'SJ')
      and code = 'GERAI';

    select quantity into v_balance
    from public.inventory_balances
    where business_id = (select id from public.businesses where code = 'SJ')
      and stock_item_id = '00000000-0000-0000-0000-000000008501'
      and location_id = v_gerai;

    if v_balance <> 5.000 then
        raise exception 'CS06_P8_REVERSAL_BALANCE_FAILED';
    end if;
end $$;

-- A count snapshot becomes invalid if canonical stock changes before posting.
do $$
declare
    v_gerai uuid;
    v_result jsonb;
    v_count uuid;
begin
    select id into v_gerai
    from public.locations
    where business_id = (select id from public.businesses where code = 'SJ')
      and code = 'GERAI';

    v_result := public.create_inventory_count(
        v_gerai,
        array['00000000-0000-0000-0000-000000008501'::uuid],
        'P8 stale snapshot',
        'P8:COUNT:STALE'
    );
    v_count := (v_result ->> 'count_id')::uuid;

    perform public.post_inventory_adjustment(
        v_gerai,
        '00000000-0000-0000-0000-000000008501',
        'ADJUSTMENT',
        1.000,
        'AFTER_COUNT_SNAPSHOT',
        null,
        'P8:ADJUST:AFTER:COUNT'
    );

    perform public.record_inventory_count(
        v_count,
        jsonb_build_array(
            jsonb_build_object(
                'stock_item_id', '00000000-0000-0000-0000-000000008501',
                'physical_quantity', 5.000
            )
        )
    );

    begin
        perform public.post_inventory_count(v_count);
        raise exception 'CS06_P8_EXPECTED_STALE_COUNT_DENIED';
    exception when others then
        if sqlerrm <> 'INVENTORY_COUNT_BALANCE_CHANGED' then raise; end if;
    end;
end $$;

-- Scope revocation is enforced for later writes.
reset role;
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000008101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000008201"}',
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

    perform public.set_inventory_location_scope(
        '00000000-0000-0000-0000-000000008302',
        v_gerai,
        false
    );
end $$;

reset role;
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000008102","role":"authenticated","session_id":"00000000-0000-0000-0000-000000008202"}',
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
        perform public.post_inventory_adjustment(
            v_gerai,
            '00000000-0000-0000-0000-000000008501',
            'ADJUSTMENT',
            1.000,
            'SCOPE_REVOKED',
            null,
            'P8:ADJUST:SCOPE:REVOKED'
        );
        raise exception 'CS06_P8_EXPECTED_SCOPE_REVOKE_ENFORCED';
    exception when others then
        if sqlerrm <> 'INVENTORY_ADJUST_SCOPE_DENIED' then raise; end if;
    end;
end $$;

reset role;

rollback;
