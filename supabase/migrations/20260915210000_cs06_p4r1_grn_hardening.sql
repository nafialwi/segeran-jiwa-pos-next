-- CS-06-P4R1: Goods Receipt posting hardening
-- Forward-only repair for CS-06-P4.
--
-- Goals:
-- - remove the invalid receipt-line location reference from P4;
-- - require PURCHASE_MANAGE at the SECURITY DEFINER boundary;
-- - bind every GRN line to the exact PO line/item/unit being received;
-- - reject malformed quantity snapshots and cumulative over-receipt;
-- - write stock only through private.record_inventory_movement();
-- - make PO PARTIALLY_RECEIVED/RECEIVED status line-aware;
-- - record the posting actor and make retries idempotent.

create or replace function public.post_goods_receipt(p_goods_receipt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_gr public.goods_receipts%rowtype;
    v_po public.purchase_orders%rowtype;
    v_movement_id uuid;
    v_lines jsonb;
    v_line_count integer;
    v_bad_count integer;
    v_duplicate_count integer;
    v_over_count integer;
    v_all_received boolean;
    v_po_status text;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if not private.has_permission(v_business, 'PURCHASE_MANAGE') then
        raise exception using errcode = '42501', message = 'SJ_PURCHASE_PERMISSION_DENIED';
    end if;

    select *
    into v_gr
    from public.goods_receipts
    where id = p_goods_receipt_id
      and business_id = v_business
    for update;

    if not found then
        raise exception using errcode = 'P0002', message = 'GRN_NOT_FOUND';
    end if;

    select *
    into v_po
    from public.purchase_orders
    where id = v_gr.purchase_order_id
      and business_id = v_business
    for update;

    if not found then
        raise exception using errcode = 'P0002', message = 'PO_NOT_FOUND';
    end if;

    if v_gr.status = 'POSTED' then
        select r.result_id
        into v_movement_id
        from public.operation_receipts r
        where r.business_id = v_business
          and r.idempotency_key = 'GRN_POST:' || p_goods_receipt_id::text
          and r.command_type = 'INVENTORY_MOVEMENT'
          and r.result_type = 'INVENTORY_MOVEMENT';

        if v_movement_id is null then
            select m.id
            into v_movement_id
            from public.inventory_movements m
            where m.business_id = v_business
              and m.source_type = 'GOODS_RECEIPT'
              and m.source_ref = v_gr.receipt_number
            order by m.created_at, m.id
            limit 1;
        end if;

        return jsonb_build_object(
            'success', true,
            'already_posted', true,
            'movement_id', v_movement_id,
            'po_status', v_po.status
        );
    end if;

    if v_gr.status not in ('DRAFT', 'RECEIVED') then
        raise exception using errcode = '22023', message = 'GRN_INVALID_STATUS';
    end if;

    if v_po.status not in ('APPROVED', 'PARTIALLY_RECEIVED') then
        raise exception using errcode = '22023', message = 'PO_INVALID_STATUS';
    end if;

    if v_gr.location_id <> v_po.location_id then
        raise exception using errcode = '22023', message = 'GRN_LOCATION_MISMATCH';
    end if;

    if not exists (
        select 1
        from public.locations l
        where l.id = v_gr.location_id
          and l.business_id = v_business
    ) then
        raise exception using errcode = '22023', message = 'GRN_LOCATION_INVALID';
    end if;

    if not exists (
        select 1
        from public.suppliers s
        where s.id = v_po.supplier_id
          and s.business_id = v_business
    ) then
        raise exception using errcode = '22023', message = 'PO_SUPPLIER_INVALID';
    end if;

    select count(*)
    into v_line_count
    from public.goods_receipt_lines grl
    where grl.goods_receipt_id = p_goods_receipt_id;

    if v_line_count = 0 then
        raise exception using errcode = '22023', message = 'GRN_LINES_REQUIRED';
    end if;

    select count(*) - count(distinct grl.purchase_order_line_id)
    into v_duplicate_count
    from public.goods_receipt_lines grl
    where grl.goods_receipt_id = p_goods_receipt_id;

    if v_duplicate_count > 0 then
        raise exception using errcode = '22023', message = 'GRN_DUPLICATE_PO_LINE';
    end if;

    select count(*)
    into v_bad_count
    from public.goods_receipt_lines grl
    left join public.purchase_order_lines pol
      on pol.id = grl.purchase_order_line_id
    left join public.stock_items si
      on si.id = grl.stock_item_id
     and si.business_id = v_business
    left join public.units u
      on u.id = grl.unit_id
     and u.business_id = v_business
    where grl.goods_receipt_id = p_goods_receipt_id
      and (
          pol.id is null
          or pol.purchase_order_id <> v_po.id
          or pol.stock_item_id <> grl.stock_item_id
          or pol.unit_id <> grl.unit_id
          or si.id is null
          or u.id is null
      );

    if v_bad_count > 0 then
        if exists (
            select 1
            from public.goods_receipt_lines grl
            left join public.purchase_order_lines pol
              on pol.id = grl.purchase_order_line_id
            where grl.goods_receipt_id = p_goods_receipt_id
              and (pol.id is null or pol.purchase_order_id <> v_po.id)
        ) then
            raise exception using errcode = '22023', message = 'GRN_LINE_PO_MISMATCH';
        end if;

        if exists (
            select 1
            from public.goods_receipt_lines grl
            join public.purchase_order_lines pol
              on pol.id = grl.purchase_order_line_id
            where grl.goods_receipt_id = p_goods_receipt_id
              and pol.stock_item_id <> grl.stock_item_id
        ) then
            raise exception using errcode = '22023', message = 'GRN_LINE_ITEM_MISMATCH';
        end if;

        raise exception using errcode = '22023', message = 'GRN_LINE_UNIT_OR_TENANT_MISMATCH';
    end if;

    select count(*)
    into v_bad_count
    from public.goods_receipt_lines grl
    join public.purchase_order_lines pol
      on pol.id = grl.purchase_order_line_id
    where grl.goods_receipt_id = p_goods_receipt_id
      and (
          pol.base_quantity <> round(pol.ordered_quantity * pol.conversion_factor_snapshot, 4)
          or grl.conversion_factor_snapshot <> pol.conversion_factor_snapshot
          or grl.base_quantity <> round(grl.received_quantity * grl.conversion_factor_snapshot, 4)
      );

    if v_bad_count > 0 then
        raise exception using errcode = '22023', message = 'GRN_LINE_ARITHMETIC_INVALID';
    end if;

    -- The canonical CS-02 ledger stores numeric(18,3). Reject values that
    -- would otherwise be silently rounded by the inventory writer.
    if exists (
        select 1
        from public.goods_receipt_lines grl
        where grl.goods_receipt_id = p_goods_receipt_id
          and grl.base_quantity <> round(grl.base_quantity, 3)
    ) then
        raise exception using errcode = '22023', message = 'GRN_LEDGER_PRECISION_UNSUPPORTED';
    end if;

    select count(*)
    into v_over_count
    from public.goods_receipt_lines current_line
    join public.purchase_order_lines pol
      on pol.id = current_line.purchase_order_line_id
    left join lateral (
        select coalesce(sum(previous_line.base_quantity), 0)::numeric as posted_quantity
        from public.goods_receipt_lines previous_line
        join public.goods_receipts previous_gr
          on previous_gr.id = previous_line.goods_receipt_id
        where previous_gr.purchase_order_id = v_po.id
          and previous_gr.status = 'POSTED'
          and previous_gr.id <> p_goods_receipt_id
          and previous_line.purchase_order_line_id = pol.id
    ) received on true
    where current_line.goods_receipt_id = p_goods_receipt_id
      and received.posted_quantity + current_line.base_quantity > pol.base_quantity;

    if v_over_count > 0 then
        raise exception using errcode = '22023', message = 'GRN_OVER_RECEIPT';
    end if;

    select jsonb_agg(
        jsonb_build_object(
            'line_no', numbered.line_no,
            'stock_item_id', numbered.stock_item_id,
            'location_id', v_gr.location_id,
            'quantity_delta', numbered.base_quantity
        )
        order by numbered.line_no
    )
    into v_lines
    from (
        select
            row_number() over (order by grl.id)::integer as line_no,
            grl.stock_item_id,
            grl.base_quantity
        from public.goods_receipt_lines grl
        where grl.goods_receipt_id = p_goods_receipt_id
    ) numbered;

    v_movement_id := private.record_inventory_movement(
        v_business,
        v_actor,
        'GRN_POST:' || p_goods_receipt_id::text,
        'PURCHASE_RECEIPT',
        'GOODS_RECEIPT',
        v_gr.receipt_number,
        'GRN_POSTED',
        v_lines,
        null
    );

    update public.goods_receipts
    set status = 'POSTED',
        posted_at = now(),
        posted_by = v_actor,
        updated_at = now()
    where id = p_goods_receipt_id;

    select not exists (
        select 1
        from public.purchase_order_lines pol
        left join lateral (
            select coalesce(sum(grl.base_quantity), 0)::numeric as posted_quantity
            from public.goods_receipt_lines grl
            join public.goods_receipts gr
              on gr.id = grl.goods_receipt_id
            where gr.purchase_order_id = v_po.id
              and gr.status = 'POSTED'
              and grl.purchase_order_line_id = pol.id
        ) received on true
        where pol.purchase_order_id = v_po.id
          and received.posted_quantity < pol.base_quantity
    )
    into v_all_received;

    v_po_status := case when v_all_received then 'RECEIVED' else 'PARTIALLY_RECEIVED' end;

    update public.purchase_orders
    set status = v_po_status,
        updated_at = now()
    where id = v_po.id;

    return jsonb_build_object(
        'success', true,
        'already_posted', false,
        'movement_id', v_movement_id,
        'po_status', v_po_status
    );
end;
$$;

revoke execute on function public.post_goods_receipt(uuid)
from public, anon, authenticated, service_role;

grant execute on function public.post_goods_receipt(uuid)
to authenticated;

comment on function public.post_goods_receipt(uuid) is
'CS-06-P4R1 hardened GRN posting: PURCHASE_MANAGE boundary, canonical inventory writer, line-aware receipt validation, idempotent retry.';
