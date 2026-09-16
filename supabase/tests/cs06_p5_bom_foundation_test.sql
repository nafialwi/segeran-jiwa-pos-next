begin;

-- CS-06-P5 integration regression: versioned BOM authority only.
-- PRODUCTION_MANAGE is enforced at both write RPC boundaries.
-- All fixtures and assertions are rolled back at the end.

insert into auth.users (id, email, is_sso_user, is_anonymous)
values
    ('00000000-0000-0000-0000-000000007101', 'p5-owner@auth.segeranjiwa.invalid', false, false),
    ('00000000-0000-0000-0000-000000007102', 'p5-cashier@auth.segeranjiwa.invalid', false, false);

insert into auth.sessions (id, user_id)
values
    ('00000000-0000-0000-0000-000000007201', '00000000-0000-0000-0000-000000007101'),
    ('00000000-0000-0000-0000-000000007202', '00000000-0000-0000-0000-000000007102');

insert into public.profiles (id, auth_user_id, display_name, status)
values
    ('00000000-0000-0000-0000-000000007301', '00000000-0000-0000-0000-000000007101', 'P5 Owner', 'ACTIVE'),
    ('00000000-0000-0000-0000-000000007302', '00000000-0000-0000-0000-000000007102', 'P5 Cashier', 'ACTIVE');

insert into public.user_login_identities (profile_id, username)
values
    ('00000000-0000-0000-0000-000000007301', 'p5-owner'),
    ('00000000-0000-0000-0000-000000007302', 'p5-cashier');

insert into public.business_memberships (business_id, profile_id, role_code)
select id, '00000000-0000-0000-0000-000000007301', 'OWNER'
from public.businesses where code = 'SJ';

insert into public.business_memberships (business_id, profile_id, role_code)
select id, '00000000-0000-0000-0000-000000007302', 'KASIR'
from public.businesses where code = 'SJ';

insert into public.trusted_devices (id, business_id, friendly_name, device_kind, platform_label)
select '00000000-0000-0000-0000-000000007401', id, 'P5 Owner Device', 'PERSONAL', 'TEST'
from public.businesses where code = 'SJ';

insert into public.trusted_devices (id, business_id, friendly_name, device_kind, platform_label)
select '00000000-0000-0000-0000-000000007402', id, 'P5 Cashier Device', 'PERSONAL', 'TEST'
from public.businesses where code = 'SJ';

insert into public.user_device_access (business_id, profile_id, device_id)
select id, '00000000-0000-0000-0000-000000007301', '00000000-0000-0000-0000-000000007401'
from public.businesses where code = 'SJ';

insert into public.user_device_access (business_id, profile_id, device_id)
select id, '00000000-0000-0000-0000-000000007302', '00000000-0000-0000-0000-000000007402'
from public.businesses where code = 'SJ';

insert into public.session_registry (session_id, business_id, profile_id, device_id)
select '00000000-0000-0000-0000-000000007201', id, '00000000-0000-0000-0000-000000007301', '00000000-0000-0000-0000-000000007401'
from public.businesses where code = 'SJ';

insert into public.session_registry (session_id, business_id, profile_id, device_id)
select '00000000-0000-0000-0000-000000007202', id, '00000000-0000-0000-0000-000000007302', '00000000-0000-0000-0000-000000007402'
from public.businesses where code = 'SJ';

-- A second business exists only to prove cross-tenant BOM references fail closed.
insert into public.businesses (id, code, display_name)
values ('00000000-0000-0000-0000-000000007900', 'P5X', 'P5 Foreign Business');

do $$
declare
    v_business uuid;
begin
    select id into v_business from public.businesses where code = 'SJ';
    if v_business is null then
        raise exception 'CS06_P5_NO_BUSINESS';
    end if;

    insert into public.stock_items(id, business_id, code, display_name, item_kind, base_unit, active)
    values
        ('00000000-0000-0000-0000-000000007501', v_business, 'P5FG', 'P5 Finished Good', 'FINISHED_GOOD', 'UNIT', true),
        ('00000000-0000-0000-0000-000000007502', v_business, 'P5MAT', 'P5 Material', 'MATERIAL', 'GRAM', true),
        ('00000000-0000-0000-0000-000000007503', v_business, 'P5PACK', 'P5 Packaging', 'PACKAGING', 'PCS', true),
        ('00000000-0000-0000-0000-000000007504', v_business, 'P5OTHER', 'P5 Other', 'OTHER', 'UNIT', true),
        ('00000000-0000-0000-0000-000000007505', v_business, 'P5FG2', 'P5 Other Finished Good', 'FINISHED_GOOD', 'UNIT', true),
        ('00000000-0000-0000-0000-000000007506', v_business, 'P5OFF', 'P5 Inactive Material', 'MATERIAL', 'GRAM', false);

    insert into public.stock_items(id, business_id, code, display_name, item_kind, base_unit, active)
    values
        ('00000000-0000-0000-0000-000000007901', '00000000-0000-0000-0000-000000007900', 'P5XMAT', 'P5 Foreign Material', 'MATERIAL', 'GRAM', true),
        ('00000000-0000-0000-0000-000000007902', '00000000-0000-0000-0000-000000007900', 'P5XFG', 'P5 Foreign Finished Good', 'FINISHED_GOOD', 'UNIT', true);
end $$;

-- Authorized owner saves V1 DRAFT.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000007101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000007201"}',
    true
);

do $$
declare
    v_result jsonb;
    v_replay jsonb;
begin
    v_result := public.save_bom_draft(
        '00000000-0000-0000-0000-000000007501',
        1,
        1.000,
        jsonb_build_array(
            jsonb_build_object('component_stock_item_id', '00000000-0000-0000-0000-000000007502', 'base_quantity', 0.250),
            jsonb_build_object('component_stock_item_id', '00000000-0000-0000-0000-000000007503', 'base_quantity', 1.000)
        ),
        'P5:BOM:SAVE:V1'
    );

    if v_result ->> 'status' <> 'DRAFT'
       or (v_result ->> 'version')::integer <> 1
       or coalesce((v_result ->> 'replay')::boolean, true) then
        raise exception 'CS06_P5_SAVE_V1_FAILED';
    end if;

    v_replay := public.save_bom_draft(
        '00000000-0000-0000-0000-000000007501',
        1,
        1.000,
        jsonb_build_array(
            jsonb_build_object('component_stock_item_id', '00000000-0000-0000-0000-000000007502', 'base_quantity', 0.250),
            jsonb_build_object('component_stock_item_id', '00000000-0000-0000-0000-000000007503', 'base_quantity', 1.000)
        ),
        'P5:BOM:SAVE:V1'
    );

    if coalesce((v_replay ->> 'replay')::boolean, false) is not true
       or v_replay ->> 'bom_id' <> v_result ->> 'bom_id' then
        raise exception 'CS06_P5_SAVE_REPLAY_FAILED';
    end if;
end $$;

reset role;

do $$
declare
    v_business uuid;
    v_count integer;
begin
    select id into v_business from public.businesses where code = 'SJ';

    select count(*) into v_count
    from public.boms
    where business_id = v_business
      and finished_good_id = '00000000-0000-0000-0000-000000007501'
      and version = 1
      and status = 'DRAFT';
    if v_count <> 1 then
        raise exception 'CS06_P5_DRAFT_COUNT_FAILED';
    end if;

    select count(*) into v_count
    from public.bom_lines bl
    join public.boms b on b.id = bl.bom_id
    where b.business_id = v_business
      and b.finished_good_id = '00000000-0000-0000-0000-000000007501'
      and b.version = 1;
    if v_count <> 2 then
        raise exception 'CS06_P5_LINE_COUNT_FAILED';
    end if;
end $$;

-- Validation failures must use stable domain errors.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000007101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000007201"}',
    true
);

do $$
begin
    begin
        perform public.save_bom_draft(
            '00000000-0000-0000-0000-000000007501', 2, 1,
            jsonb_build_array(jsonb_build_object(
                'component_stock_item_id', '00000000-0000-0000-0000-000000007501',
                'base_quantity', 1
            )),
            'P5:ERR:SELF'
        );
        raise exception 'CS06_P5_EXPECTED_BOM_SELF_REFERENCE';
    exception when others then
        if sqlerrm <> 'BOM_SELF_REFERENCE' then raise; end if;
    end;

    begin
        perform public.save_bom_draft(
            '00000000-0000-0000-0000-000000007501', 2, 1,
            jsonb_build_array(
                jsonb_build_object('component_stock_item_id', '00000000-0000-0000-0000-000000007502', 'base_quantity', 0.2),
                jsonb_build_object('component_stock_item_id', '00000000-0000-0000-0000-000000007502', 'base_quantity', 0.3)
            ),
            'P5:ERR:DUP'
        );
        raise exception 'CS06_P5_EXPECTED_BOM_DUPLICATE_COMPONENT';
    exception when others then
        if sqlerrm <> 'BOM_DUPLICATE_COMPONENT' then raise; end if;
    end;

    begin
        perform public.save_bom_draft(
            '00000000-0000-0000-0000-000000007501', 2, 1,
            jsonb_build_array(jsonb_build_object(
                'component_stock_item_id', '00000000-0000-0000-0000-000000007502',
                'base_quantity', 0.1234
            )),
            'P5:ERR:PRECISION'
        );
        raise exception 'CS06_P5_EXPECTED_BOM_LEDGER_PRECISION_UNSUPPORTED';
    exception when others then
        if sqlerrm <> 'BOM_LEDGER_PRECISION_UNSUPPORTED' then raise; end if;
    end;

    begin
        perform public.save_bom_draft(
            '00000000-0000-0000-0000-000000007502', 1, 1,
            jsonb_build_array(jsonb_build_object(
                'component_stock_item_id', '00000000-0000-0000-0000-000000007503',
                'base_quantity', 1
            )),
            'P5:ERR:FGKIND'
        );
        raise exception 'CS06_P5_EXPECTED_BOM_FINISHED_GOOD_INVALID';
    exception when others then
        if sqlerrm <> 'BOM_FINISHED_GOOD_INVALID' then raise; end if;
    end;

    begin
        perform public.save_bom_draft(
            '00000000-0000-0000-0000-000000007501', 2, 1,
            jsonb_build_array(jsonb_build_object(
                'component_stock_item_id', '00000000-0000-0000-0000-000000007901',
                'base_quantity', 1
            )),
            'P5:ERR:CROSSCOMP'
        );
        raise exception 'CS06_P5_EXPECTED_BOM_CROSS_TENANT';
    exception when others then
        if sqlerrm <> 'BOM_CROSS_TENANT' then raise; end if;
    end;

    begin
        perform public.save_bom_draft(
            '00000000-0000-0000-0000-000000007902', 1, 1,
            jsonb_build_array(jsonb_build_object(
                'component_stock_item_id', '00000000-0000-0000-0000-000000007502',
                'base_quantity', 1
            )),
            'P5:ERR:CROSSFG'
        );
        raise exception 'CS06_P5_EXPECTED_BOM_CROSS_TENANT';
    exception when others then
        if sqlerrm <> 'BOM_CROSS_TENANT' then raise; end if;
    end;

    begin
        perform public.save_bom_draft(
            '00000000-0000-0000-0000-000000007501', 2, 1,
            jsonb_build_array(jsonb_build_object(
                'component_stock_item_id', '00000000-0000-0000-0000-000000007505',
                'base_quantity', 1
            )),
            'P5:ERR:COMP_KIND'
        );
        raise exception 'CS06_P5_EXPECTED_BOM_LINE_INVALID';
    exception when others then
        if sqlerrm <> 'BOM_LINE_INVALID' then raise; end if;
    end;

    begin
        perform public.save_bom_draft(
            '00000000-0000-0000-0000-000000007501', 2, 1,
            jsonb_build_array(jsonb_build_object(
                'component_stock_item_id', '00000000-0000-0000-0000-000000007506',
                'base_quantity', 1
            )),
            'P5:ERR:INACTIVE'
        );
        raise exception 'CS06_P5_EXPECTED_BOM_LINE_INVALID';
    exception when others then
        if sqlerrm <> 'BOM_LINE_INVALID' then raise; end if;
    end;
end $$;

reset role;

-- Cashier has no PRODUCTION_MANAGE permission and must fail both write RPCs.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000007102","role":"authenticated","session_id":"00000000-0000-0000-0000-000000007202"}',
    true
);

do $$
declare
    v_bom_id uuid;
begin
    select id into v_bom_id
    from public.boms
    where finished_good_id = '00000000-0000-0000-0000-000000007501'
      and version = 1;

    begin
        perform public.save_bom_draft(
            '00000000-0000-0000-0000-000000007501', 3, 1,
            jsonb_build_array(jsonb_build_object(
                'component_stock_item_id', '00000000-0000-0000-0000-000000007502',
                'base_quantity', 1
            )),
            'P5:CASHIER:SAVE'
        );
        raise exception 'CS06_P5_EXPECTED_SJ_PRODUCTION_PERMISSION_DENIED';
    exception when others then
        if sqlerrm <> 'SJ_PRODUCTION_PERMISSION_DENIED' then raise; end if;
    end;

    begin
        perform public.activate_bom(v_bom_id, 'P5:CASHIER:ACTIVATE');
        raise exception 'CS06_P5_EXPECTED_SJ_PRODUCTION_PERMISSION_DENIED';
    exception when others then
        if sqlerrm <> 'SJ_PRODUCTION_PERMISSION_DENIED' then raise; end if;
    end;
end $$;

reset role;

-- Owner activates V1, then creates and activates V2. V1 must retire atomically.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000007101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000007201"}',
    true
);

do $$
declare
    v_v1 uuid;
    v_v2 uuid;
    v_result jsonb;
    v_replay jsonb;
begin
    select id into v_v1
    from public.boms
    where finished_good_id = '00000000-0000-0000-0000-000000007501'
      and version = 1;

    v_result := public.activate_bom(v_v1, 'P5:BOM:ACTIVATE:V1');
    if v_result ->> 'status' <> 'ACTIVE'
       or coalesce((v_result ->> 'replay')::boolean, true) then
        raise exception 'CS06_P5_ACTIVATE_V1_FAILED';
    end if;

    v_result := public.save_bom_draft(
        '00000000-0000-0000-0000-000000007501',
        2,
        1.000,
        jsonb_build_array(
            jsonb_build_object('component_stock_item_id', '00000000-0000-0000-0000-000000007502', 'base_quantity', 0.300),
            jsonb_build_object('component_stock_item_id', '00000000-0000-0000-0000-000000007503', 'base_quantity', 1.000),
            jsonb_build_object('component_stock_item_id', '00000000-0000-0000-0000-000000007504', 'base_quantity', 0.050)
        ),
        'P5:BOM:SAVE:V2'
    );
    v_v2 := (v_result ->> 'bom_id')::uuid;

    v_result := public.activate_bom(v_v2, 'P5:BOM:ACTIVATE:V2');
    if v_result ->> 'status' <> 'ACTIVE'
       or (v_result ->> 'retired_bom_id')::uuid <> v_v1 then
        raise exception 'CS06_P5_ACTIVATE_V2_FAILED';
    end if;

    v_replay := public.activate_bom(v_v2, 'P5:BOM:ACTIVATE:V2');
    if coalesce((v_replay ->> 'replay')::boolean, false) is not true
       or (v_replay ->> 'bom_id')::uuid <> v_v2 then
        raise exception 'CS06_P5_ACTIVATE_REPLAY_FAILED';
    end if;
end $$;

reset role;

do $$
declare
    v_business uuid;
    v_active_count integer;
    v_active_version integer;
    v_v1 uuid;
    v_v2 uuid;
begin
    select id into v_business from public.businesses where code = 'SJ';

    select id into v_v1
    from public.boms
    where business_id = v_business
      and finished_good_id = '00000000-0000-0000-0000-000000007501'
      and version = 1
      and status = 'RETIRED';
    if v_v1 is null then
        raise exception 'CS06_P5_V1_NOT_RETIRED';
    end if;

    select id into v_v2
    from public.boms
    where business_id = v_business
      and finished_good_id = '00000000-0000-0000-0000-000000007501'
      and version = 2
      and status = 'ACTIVE';
    if v_v2 is null then
        raise exception 'CS06_P5_V2_NOT_ACTIVE';
    end if;

    select count(*), max(version)
    into v_active_count, v_active_version
    from public.boms
    where business_id = v_business
      and finished_good_id = '00000000-0000-0000-0000-000000007501'
      and status = 'ACTIVE';

    if v_active_count <> 1 or v_active_version <> 2 then
        raise exception 'CS06_P5_SINGLE_ACTIVE_FAILED';
    end if;

    begin
        update public.boms
        set yield_quantity = 2
        where id = v_v2;
        raise exception 'CS06_P5_EXPECTED_BOM_IMMUTABLE';
    exception when others then
        if sqlerrm <> 'BOM_IMMUTABLE' then raise; end if;
    end;

    begin
        update public.bom_lines
        set base_quantity = base_quantity + 1
        where bom_id = v_v1
          and line_no = 1;
        raise exception 'CS06_P5_EXPECTED_BOM_IMMUTABLE';
    exception when others then
        if sqlerrm <> 'BOM_IMMUTABLE' then raise; end if;
    end;
end $$;

-- P5 must never touch inventory. Newly-created fixture items have no stock rows.
do $$
declare
    v_business uuid;
    v_count integer;
begin
    select id into v_business from public.businesses where code = 'SJ';

    select count(*) into v_count
    from public.inventory_movement_lines iml
    join public.inventory_movements im on im.id = iml.movement_id
    where im.business_id = v_business
      and iml.stock_item_id in (
          '00000000-0000-0000-0000-000000007501',
          '00000000-0000-0000-0000-000000007502',
          '00000000-0000-0000-0000-000000007503',
          '00000000-0000-0000-0000-000000007504'
      );
    if v_count <> 0 then
        raise exception 'CS06_P5_INVENTORY_MOVEMENTS_CHANGED';
    end if;

    select count(*) into v_count
    from public.inventory_balances ib
    where ib.business_id = v_business
      and ib.stock_item_id in (
          '00000000-0000-0000-0000-000000007501',
          '00000000-0000-0000-0000-000000007502',
          '00000000-0000-0000-0000-000000007503',
          '00000000-0000-0000-0000-000000007504'
      );
    if v_count <> 0 then
        raise exception 'CS06_P5_INVENTORY_BALANCES_CHANGED';
    end if;
end $$;

-- Re-query through the authenticated read boundary and confirm V2 remains canonical.
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000007101","role":"authenticated","session_id":"00000000-0000-0000-0000-000000007201"}',
    true
);

do $$
declare
    v_count integer;
    v_version integer;
begin
    select count(*), max(version)
    into v_count, v_version
    from public.boms
    where finished_good_id = '00000000-0000-0000-0000-000000007501'
      and status = 'ACTIVE';

    if v_count <> 1 or v_version <> 2 then
        raise exception 'CS06_P5_RLS_REQUERY_FAILED';
    end if;
end $$;

reset role;

rollback;
