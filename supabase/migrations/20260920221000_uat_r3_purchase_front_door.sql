-- UAT-R3: Purchase operational front door.
-- Blueprint authority: save purchase first; stock changes only when goods are received.
-- No multi-stage PO approval workflow is invented here. PURCHASE_MANAGE is the
-- server-side command gate; saved supplier orders are internally marked APPROVED
-- solely so the existing hardened GRN posting authority can receive them.

create sequence if not exists private.purchase_order_sequence;
create sequence if not exists private.goods_receipt_sequence;

insert into public.units (business_id, code, display_name, system, active)
select b.id, 'PCS', 'Pcs', true, true
from public.businesses b
on conflict (business_id, code) do update
set display_name = excluded.display_name,
    system = true,
    active = true;

create or replace function private.assign_stock_item_base_unit_id()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_unit uuid;
begin
    if new.base_unit_id is null then
        select u.id
        into v_unit
        from public.units u
        where u.business_id = new.business_id
          and u.code = upper(btrim(new.base_unit))
          and u.active
        limit 1;

        if v_unit is not null then
            new.base_unit_id := v_unit;
        end if;
    end if;

    return new;
end;
$$;

drop trigger if exists stock_items_assign_base_unit_id on public.stock_items;
create trigger stock_items_assign_base_unit_id
before insert or update of base_unit, base_unit_id
on public.stock_items
for each row
execute function private.assign_stock_item_base_unit_id();

update public.stock_items si
set base_unit_id = u.id
from public.units u
where si.base_unit_id is null
  and u.business_id = si.business_id
  and u.code = upper(btrim(si.base_unit))
  and u.active;

create or replace function public.purchase_create_supplier(
    p_code text,
    p_display_name text,
    p_phone text,
    p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
    v_code text;
    v_name text;
    v_hash text;
    v_lock record;
    v_supplier uuid;
    v_receipt uuid;
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'PURCHASE_MANAGE') then
        raise exception using errcode = '42501', message = 'SJ_PURCHASE_PERMISSION_DENIED';
    end if;

    v_code := upper(btrim(coalesce(p_code, '')));
    v_name := btrim(coalesce(p_display_name, ''));

    if v_code !~ '^[A-Z0-9][A-Z0-9_-]{1,31}$' then
        raise exception using errcode = '22023', message = 'PURCHASE_SUPPLIER_CODE_INVALID';
    end if;
    if v_name = '' then
        raise exception using errcode = '22023', message = 'PURCHASE_SUPPLIER_NAME_REQUIRED';
    end if;

    v_hash := private.payload_sha256(jsonb_build_object(
        'code', v_code,
        'display_name', v_name,
        'phone', nullif(btrim(coalesce(p_phone,'')), '')
    ));

    select * into v_lock
    from private.lock_operation(
        v_business, p_idempotency_key, 'PURCHASE_SUPPLIER_CREATE', v_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'SUPPLIER' or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;
        return v_lock.result_id;
    end if;

    insert into public.suppliers (
        business_id, code, display_name, phone, active
    ) values (
        v_business, v_code, v_name,
        nullif(btrim(coalesce(p_phone,'')), ''), true
    )
    returning id into v_supplier;

    v_receipt := private.record_operation_success(
        v_business, p_idempotency_key, 'PURCHASE_SUPPLIER_CREATE', v_hash,
        'SUPPLIER', v_supplier, v_actor
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor, v_receipt,
        'PURCHASE_SUPPLIER_CREATED', 'SUPPLIER', v_supplier,
        jsonb_build_object('code', v_code, 'display_name', v_name)
    );

    return v_supplier;
end;
$$;

revoke execute on function public.purchase_create_supplier(text,text,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.purchase_create_supplier(text,text,text,text)
to authenticated;

create or replace function public.purchase_create_item(
    p_code text,
    p_display_name text,
    p_item_kind text,
    p_unit_id uuid,
    p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
    v_code text;
    v_name text;
    v_kind text;
    v_unit public.units%rowtype;
    v_hash text;
    v_lock record;
    v_item uuid;
    v_receipt uuid;
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'PURCHASE_MANAGE') then
        raise exception using errcode = '42501', message = 'SJ_PURCHASE_PERMISSION_DENIED';
    end if;

    v_code := upper(btrim(coalesce(p_code, '')));
    v_name := btrim(coalesce(p_display_name, ''));
    v_kind := upper(btrim(coalesce(p_item_kind, '')));

    if v_code !~ '^[A-Z0-9][A-Z0-9_-]{1,63}$' then
        raise exception using errcode = '22023', message = 'PURCHASE_ITEM_CODE_INVALID';
    end if;
    if v_name = '' then
        raise exception using errcode = '22023', message = 'PURCHASE_ITEM_NAME_REQUIRED';
    end if;
    if v_kind not in ('MATERIAL','FINISHED_GOOD','PACKAGING','OTHER') then
        raise exception using errcode = '22023', message = 'PURCHASE_ITEM_KIND_INVALID';
    end if;

    v_hash := private.payload_sha256(jsonb_build_object(
        'code', v_code,
        'display_name', v_name,
        'item_kind', v_kind,
        'unit_id', p_unit_id
    ));

    select * into v_lock
    from private.lock_operation(
        v_business, p_idempotency_key, 'PURCHASE_ITEM_CREATE', v_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'STOCK_ITEM' or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;
        return v_lock.result_id;
    end if;

    select * into v_unit
    from public.units
    where id = p_unit_id
      and business_id = v_business
      and active;

    if not found then
        raise exception using errcode = '23503', message = 'PURCHASE_UNIT_INVALID';
    end if;

    insert into public.stock_items (
        business_id, code, display_name, item_kind, base_unit, base_unit_id,
        active, sale_enabled, inventory_tracked
    ) values (
        v_business, v_code, v_name, v_kind, v_unit.code, v_unit.id,
        true, false, true
    )
    returning id into v_item;

    insert into public.stock_item_units (
        stock_item_id, unit_id, conversion_factor, is_base_unit
    ) values (
        v_item, v_unit.id, 1, true
    )
    on conflict (stock_item_id, unit_id) do update
    set conversion_factor = 1,
        is_base_unit = true;

    v_receipt := private.record_operation_success(
        v_business, p_idempotency_key, 'PURCHASE_ITEM_CREATE', v_hash,
        'STOCK_ITEM', v_item, v_actor
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor, v_receipt,
        'PURCHASE_ITEM_CREATED', 'STOCK_ITEM', v_item,
        jsonb_build_object(
            'code', v_code,
            'display_name', v_name,
            'item_kind', v_kind,
            'unit_code', v_unit.code
        )
    );

    return v_item;
end;
$$;

revoke execute on function public.purchase_create_item(text,text,text,uuid,text)
from public, anon, authenticated, service_role;
grant execute on function public.purchase_create_item(text,text,text,uuid,text)
to authenticated;

create or replace function public.purchase_create_order(
    p_supplier_id uuid,
    p_location_id uuid,
    p_lines jsonb,
    p_notes text,
    p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
    v_hash text;
    v_lock record;
    v_po uuid;
    v_order_number text;
    v_receipt uuid;
    v_line jsonb;
    v_item public.stock_items%rowtype;
    v_unit public.units%rowtype;
    v_qty numeric;
    v_price numeric;
    v_factor numeric;
    v_base numeric;
    v_line_total numeric;
    v_seen uuid[] := '{}'::uuid[];
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'PURCHASE_MANAGE') then
        raise exception using errcode = '42501', message = 'SJ_PURCHASE_PERMISSION_DENIED';
    end if;

    if p_lines is null or jsonb_typeof(p_lines) <> 'array'
       or jsonb_array_length(p_lines) = 0 then
        raise exception using errcode = '22023', message = 'PURCHASE_LINES_REQUIRED';
    end if;

    v_hash := private.payload_sha256(jsonb_build_object(
        'supplier_id', p_supplier_id,
        'location_id', p_location_id,
        'lines', p_lines,
        'notes', nullif(btrim(coalesce(p_notes,'')), '')
    ));

    select * into v_lock
    from private.lock_operation(
        v_business, p_idempotency_key, 'PURCHASE_ORDER_CREATE', v_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'PURCHASE_ORDER' or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;

        select order_number into v_order_number
        from public.purchase_orders
        where id = v_lock.result_id;

        return jsonb_build_object(
            'purchase_order_id', v_lock.result_id,
            'order_number', v_order_number,
            'status', 'APPROVED',
            'replay', true
        );
    end if;

    if not exists (
        select 1 from public.suppliers s
        where s.id = p_supplier_id
          and s.business_id = v_business
          and s.active
    ) then
        raise exception using errcode = '23503', message = 'PURCHASE_SUPPLIER_INVALID';
    end if;

    if not exists (
        select 1 from public.locations l
        where l.id = p_location_id
          and l.business_id = v_business
          and l.active
    ) then
        raise exception using errcode = '23503', message = 'PURCHASE_LOCATION_INVALID';
    end if;

    v_order_number :=
        'PO-' || to_char(clock_timestamp(), 'YYYYMMDD') || '-'
        || lpad(nextval('private.purchase_order_sequence')::text, 6, '0');

    insert into public.purchase_orders (
        business_id, order_number, supplier_id, location_id, status,
        notes, created_by, approved_by, approved_at
    ) values (
        v_business, v_order_number, p_supplier_id, p_location_id, 'APPROVED',
        nullif(btrim(coalesce(p_notes,'')), ''),
        v_actor, v_actor, now()
    )
    returning id into v_po;

    for v_line in select value from jsonb_array_elements(p_lines)
    loop
        begin
            v_qty := (v_line ->> 'quantity')::numeric;
            v_price := (v_line ->> 'unit_price')::numeric;
        exception when invalid_text_representation then
            raise exception using errcode = '22023', message = 'PURCHASE_LINE_INVALID';
        end;

        if (v_line ->> 'stock_item_id') is null
           or (v_line ->> 'unit_id') is null
           or v_qty is null or v_qty <= 0
           or v_price is null or v_price < 0 then
            raise exception using errcode = '22023', message = 'PURCHASE_LINE_INVALID';
        end if;

        select * into v_item
        from public.stock_items
        where id = (v_line ->> 'stock_item_id')::uuid
          and business_id = v_business
          and active;

        if not found then
            raise exception using errcode = '23503', message = 'PURCHASE_ITEM_INVALID';
        end if;

        if v_item.id = any(v_seen) then
            raise exception using errcode = '22023', message = 'PURCHASE_DUPLICATE_ITEM';
        end if;
        v_seen := array_append(v_seen, v_item.id);

        select * into v_unit
        from public.units
        where id = (v_line ->> 'unit_id')::uuid
          and business_id = v_business
          and active;

        if not found then
            raise exception using errcode = '23503', message = 'PURCHASE_UNIT_INVALID';
        end if;

        if v_item.base_unit_id = v_unit.id then
            v_factor := 1;
        else
            select siu.conversion_factor
            into v_factor
            from public.stock_item_units siu
            where siu.stock_item_id = v_item.id
              and siu.unit_id = v_unit.id;
        end if;

        if v_factor is null or v_factor <= 0 then
            raise exception using errcode = '22023', message = 'PURCHASE_UNIT_CONVERSION_MISSING';
        end if;

        v_base := round(v_qty * v_factor, 4);
        if v_base <= 0 or v_base <> round(v_base, 3) then
            raise exception using errcode = '22023', message = 'PURCHASE_LEDGER_PRECISION_UNSUPPORTED';
        end if;

        v_line_total := round(v_qty * v_price, 4);

        insert into public.purchase_order_lines (
            purchase_order_id, stock_item_id, unit_id,
            ordered_quantity, conversion_factor_snapshot, base_quantity,
            unit_price, discount_amount, tax_amount, line_total
        ) values (
            v_po, v_item.id, v_unit.id,
            v_qty, v_factor, v_base,
            v_price, 0, 0, v_line_total
        );
    end loop;

    v_receipt := private.record_operation_success(
        v_business, p_idempotency_key, 'PURCHASE_ORDER_CREATE', v_hash,
        'PURCHASE_ORDER', v_po, v_actor
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor, v_receipt,
        'PURCHASE_ORDER_CREATED', 'PURCHASE_ORDER', v_po,
        jsonb_build_object(
            'order_number', v_order_number,
            'supplier_id', p_supplier_id,
            'location_id', p_location_id,
            'line_count', jsonb_array_length(p_lines),
            'status', 'APPROVED'
        )
    );

    return jsonb_build_object(
        'purchase_order_id', v_po,
        'order_number', v_order_number,
        'status', 'APPROVED',
        'replay', false
    );
end;
$$;

revoke execute on function public.purchase_create_order(uuid,uuid,jsonb,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.purchase_create_order(uuid,uuid,jsonb,text,text)
to authenticated;

create or replace function public.purchase_create_goods_receipt(
    p_purchase_order_id uuid,
    p_lines jsonb,
    p_notes text,
    p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
    v_hash text;
    v_lock record;
    v_po public.purchase_orders%rowtype;
    v_gr uuid;
    v_receipt_number text;
    v_receipt uuid;
    v_line jsonb;
    v_pol public.purchase_order_lines%rowtype;
    v_qty numeric;
    v_base numeric;
    v_already numeric;
    v_seen uuid[] := '{}'::uuid[];
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'PURCHASE_MANAGE') then
        raise exception using errcode = '42501', message = 'SJ_PURCHASE_PERMISSION_DENIED';
    end if;

    if p_lines is null or jsonb_typeof(p_lines) <> 'array'
       or jsonb_array_length(p_lines) = 0 then
        raise exception using errcode = '22023', message = 'GRN_LINES_REQUIRED';
    end if;

    v_hash := private.payload_sha256(jsonb_build_object(
        'purchase_order_id', p_purchase_order_id,
        'lines', p_lines,
        'notes', nullif(btrim(coalesce(p_notes,'')), '')
    ));

    select * into v_lock
    from private.lock_operation(
        v_business, p_idempotency_key, 'GOODS_RECEIPT_CREATE', v_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'GOODS_RECEIPT' or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;

        select receipt_number into v_receipt_number
        from public.goods_receipts
        where id = v_lock.result_id;

        return jsonb_build_object(
            'goods_receipt_id', v_lock.result_id,
            'receipt_number', v_receipt_number,
            'status', 'RECEIVED',
            'replay', true
        );
    end if;

    select * into v_po
    from public.purchase_orders
    where id = p_purchase_order_id
      and business_id = v_business
    for update;

    if not found then
        raise exception using errcode = 'P0002', message = 'PO_NOT_FOUND';
    end if;

    if v_po.status not in ('APPROVED','PARTIALLY_RECEIVED') then
        raise exception using errcode = '22023', message = 'PO_INVALID_STATUS';
    end if;

    v_receipt_number :=
        'GRN-' || to_char(clock_timestamp(), 'YYYYMMDD') || '-'
        || lpad(nextval('private.goods_receipt_sequence')::text, 6, '0');

    insert into public.goods_receipts (
        business_id, receipt_number, purchase_order_id, location_id,
        status, received_by, notes
    ) values (
        v_business, v_receipt_number, v_po.id, v_po.location_id,
        'RECEIVED', v_actor, nullif(btrim(coalesce(p_notes,'')), '')
    )
    returning id into v_gr;

    for v_line in select value from jsonb_array_elements(p_lines)
    loop
        if (v_line ->> 'purchase_order_line_id') is null then
            raise exception using errcode = '22023', message = 'GRN_LINE_PO_REQUIRED';
        end if;

        if (v_line ->> 'purchase_order_line_id')::uuid = any(v_seen) then
            raise exception using errcode = '22023', message = 'GRN_DUPLICATE_PO_LINE';
        end if;

        v_seen := array_append(
            v_seen, (v_line ->> 'purchase_order_line_id')::uuid
        );

        begin
            v_qty := (v_line ->> 'received_quantity')::numeric;
        exception when invalid_text_representation then
            raise exception using errcode = '22023', message = 'GRN_RECEIVED_QUANTITY_INVALID';
        end;

        if v_qty is null or v_qty <= 0 then
            raise exception using errcode = '22023', message = 'GRN_RECEIVED_QUANTITY_INVALID';
        end if;

        select * into v_pol
        from public.purchase_order_lines
        where id = (v_line ->> 'purchase_order_line_id')::uuid
          and purchase_order_id = v_po.id;

        if not found then
            raise exception using errcode = '22023', message = 'GRN_LINE_PO_MISMATCH';
        end if;

        v_base := round(v_qty * v_pol.conversion_factor_snapshot, 4);

        if v_base <= 0
           or v_base <> round(v_base, 3) then
            raise exception using errcode = '22023', message = 'GRN_LEDGER_PRECISION_UNSUPPORTED';
        end if;

        select coalesce(sum(grl.base_quantity),0)::numeric
        into v_already
        from public.goods_receipt_lines grl
        join public.goods_receipts gr on gr.id = grl.goods_receipt_id
        where gr.purchase_order_id = v_po.id
          and gr.status in ('RECEIVED','POSTED')
          and gr.id <> v_gr
          and grl.purchase_order_line_id = v_pol.id;

        if v_already + v_base > v_pol.base_quantity then
            raise exception using errcode = '22023', message = 'GRN_OVER_RECEIPT';
        end if;

        insert into public.goods_receipt_lines (
            goods_receipt_id, purchase_order_line_id, stock_item_id, unit_id,
            received_quantity, conversion_factor_snapshot, base_quantity
        ) values (
            v_gr, v_pol.id, v_pol.stock_item_id, v_pol.unit_id,
            v_qty, v_pol.conversion_factor_snapshot, v_base
        );
    end loop;

    v_receipt := private.record_operation_success(
        v_business, p_idempotency_key, 'GOODS_RECEIPT_CREATE', v_hash,
        'GOODS_RECEIPT', v_gr, v_actor
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor, v_receipt,
        'GOODS_RECEIPT_CREATED', 'GOODS_RECEIPT', v_gr,
        jsonb_build_object(
            'receipt_number', v_receipt_number,
            'purchase_order_id', v_po.id,
            'line_count', jsonb_array_length(p_lines),
            'status', 'RECEIVED'
        )
    );

    return jsonb_build_object(
        'goods_receipt_id', v_gr,
        'receipt_number', v_receipt_number,
        'status', 'RECEIVED',
        'replay', false
    );
end;
$$;

revoke execute on function public.purchase_create_goods_receipt(uuid,jsonb,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.purchase_create_goods_receipt(uuid,jsonb,text,text)
to authenticated;

create or replace function public.purchase_direct_buy(
    p_supplier_id uuid,
    p_location_id uuid,
    p_lines jsonb,
    p_notes text,
    p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_order jsonb;
    v_po uuid;
    v_receipt_lines jsonb;
    v_gr jsonb;
    v_post jsonb;
begin
    v_order := public.purchase_create_order(
        p_supplier_id,
        p_location_id,
        p_lines,
        p_notes,
        p_idempotency_key || ':PO'
    );

    v_po := (v_order ->> 'purchase_order_id')::uuid;

    select jsonb_agg(
        jsonb_build_object(
            'purchase_order_line_id', pol.id,
            'received_quantity', pol.ordered_quantity
        )
        order by pol.created_at, pol.id
    )
    into v_receipt_lines
    from public.purchase_order_lines pol
    where pol.purchase_order_id = v_po;

    if v_receipt_lines is null then
        raise exception using errcode = '22023', message = 'PURCHASE_LINES_REQUIRED';
    end if;

    v_gr := public.purchase_create_goods_receipt(
        v_po,
        v_receipt_lines,
        p_notes,
        p_idempotency_key || ':GRN'
    );

    v_post := public.post_goods_receipt(
        (v_gr ->> 'goods_receipt_id')::uuid
    );

    return jsonb_build_object(
        'purchase_order_id', v_po,
        'order_number', v_order ->> 'order_number',
        'goods_receipt_id', v_gr ->> 'goods_receipt_id',
        'receipt_number', v_gr ->> 'receipt_number',
        'po_status', v_post ->> 'po_status',
        'movement_id', v_post ->> 'movement_id',
        'already_posted', coalesce((v_post ->> 'already_posted')::boolean,false)
    );
end;
$$;

revoke execute on function public.purchase_direct_buy(uuid,uuid,jsonb,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.purchase_direct_buy(uuid,uuid,jsonb,text,text)
to authenticated;

create or replace function public.purchase_front_door_options()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
    v_suppliers jsonb;
    v_locations jsonb;
    v_units jsonb;
    v_items jsonb;
    v_orders jsonb;
    v_receipts jsonb;
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'PURCHASE_MANAGE') then
        raise exception using errcode = '42501', message = 'SJ_PURCHASE_PERMISSION_DENIED';
    end if;

    select coalesce(jsonb_agg(to_jsonb(x) order by x.display_name), '[]'::jsonb)
    into v_suppliers
    from (
        select id, code, display_name, phone
        from public.suppliers
        where business_id = v_business and active
    ) x;

    select coalesce(jsonb_agg(to_jsonb(x) order by x.display_name), '[]'::jsonb)
    into v_locations
    from (
        select id, code, display_name, location_type
        from public.locations
        where business_id = v_business and active
    ) x;

    select coalesce(jsonb_agg(to_jsonb(x) order by x.display_name), '[]'::jsonb)
    into v_units
    from (
        select id, code, display_name
        from public.units
        where business_id = v_business and active
    ) x;

    select coalesce(jsonb_agg(to_jsonb(x) order by x.display_name), '[]'::jsonb)
    into v_items
    from (
        select
            si.id,
            si.code,
            si.display_name,
            si.item_kind,
            si.base_unit,
            si.base_unit_id
        from public.stock_items si
        where si.business_id = v_business
          and si.active
          and si.inventory_tracked
    ) x;

    select coalesce(jsonb_agg(to_jsonb(o) order by o.ordered_at desc), '[]'::jsonb)
    into v_orders
    from (
        select
            po.id,
            po.order_number,
            po.status,
            po.ordered_at,
            po.supplier_id,
            s.display_name as supplier_name,
            po.location_id,
            l.display_name as location_name,
            (
                select coalesce(jsonb_agg(to_jsonb(line) order by line.created_at, line.id), '[]'::jsonb)
                from (
                    select
                        pol.id,
                        pol.stock_item_id,
                        si.display_name as item_name,
                        pol.unit_id,
                        u.display_name as unit_name,
                        pol.ordered_quantity,
                        pol.conversion_factor_snapshot,
                        pol.base_quantity,
                        pol.unit_price,
                        coalesce(received.received_base_quantity,0)::numeric as received_base_quantity,
                        greatest(
                            pol.base_quantity - coalesce(received.received_base_quantity,0),
                            0
                        )::numeric as remaining_base_quantity,
                        greatest(
                            (pol.base_quantity - coalesce(received.received_base_quantity,0))
                            / pol.conversion_factor_snapshot,
                            0
                        )::numeric as remaining_quantity,
                        pol.created_at
                    from public.purchase_order_lines pol
                    join public.stock_items si on si.id = pol.stock_item_id
                    join public.units u on u.id = pol.unit_id
                    left join lateral (
                        select coalesce(sum(grl.base_quantity),0)::numeric as received_base_quantity
                        from public.goods_receipt_lines grl
                        join public.goods_receipts gr on gr.id = grl.goods_receipt_id
                        where gr.purchase_order_id = po.id
                          and gr.status in ('RECEIVED','POSTED')
                          and grl.purchase_order_line_id = pol.id
                    ) received on true
                    where pol.purchase_order_id = po.id
                ) line
            ) as lines
        from public.purchase_orders po
        join public.suppliers s on s.id = po.supplier_id
        join public.locations l on l.id = po.location_id
        where po.business_id = v_business
          and po.status in ('APPROVED','PARTIALLY_RECEIVED')
    ) o;

    select coalesce(jsonb_agg(to_jsonb(x) order by x.received_at desc), '[]'::jsonb)
    into v_receipts
    from (
        select
            gr.id,
            gr.receipt_number,
            gr.status,
            gr.received_at,
            gr.posted_at,
            po.order_number,
            s.display_name as supplier_name,
            l.display_name as location_name
        from public.goods_receipts gr
        join public.purchase_orders po on po.id = gr.purchase_order_id
        join public.suppliers s on s.id = po.supplier_id
        join public.locations l on l.id = gr.location_id
        where gr.business_id = v_business
          and gr.status in ('DRAFT','RECEIVED','POSTED')
        order by gr.received_at desc
        limit 50
    ) x;

    return jsonb_build_object(
        'suppliers', v_suppliers,
        'locations', v_locations,
        'units', v_units,
        'items', v_items,
        'receivable_orders', v_orders,
        'receipts', v_receipts
    );
end;
$$;

revoke execute on function public.purchase_front_door_options()
from public, anon, authenticated, service_role;
grant execute on function public.purchase_front_door_options()
to authenticated;
