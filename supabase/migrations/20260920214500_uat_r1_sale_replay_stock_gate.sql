-- UAT-R1: sale replay must bypass post-sale stock availability checks.

create or replace function private.record_sale(
    p_operation_id uuid,
    p_business_id uuid,
    p_location_id uuid,
    p_items jsonb,
    p_payment jsonb,
    p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_invoice text;
    v_sale_id uuid;
    v_lock record;
    v_payload_hash text;
    v_subtotal numeric(18,2) := 0;
    v_line integer := 0;
    v_item jsonb;
    v_normalized_items jsonb := '[]'::jsonb;
    v_item_id uuid;
    v_qty numeric;
    v_price numeric;
    v_inventory_tracked boolean;
    v_available numeric;
    v_payment_method text;
    v_payment_amount numeric(18,2);
    v_actor uuid;
    v_shift uuid;
    v_customer uuid;
begin
    v_actor := private.current_profile_id();

    if v_actor is null
       or not private.has_permission(p_business_id, 'SALE_EXECUTE') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if not exists (
        select 1 from public.locations l
        where l.id = p_location_id
          and l.business_id = p_business_id
          and l.active
    ) then
        raise exception using errcode = '23503', message = 'SJ_LOCATION_NOT_FOUND';
    end if;

    select s.id into v_shift
    from public.shifts s
    where s.business_id = p_business_id
      and s.location_id = p_location_id
      and s.cashier_profile_id = v_actor
      and s.status = 'OPEN'
    limit 1;

    if v_shift is null then
        raise exception using errcode = '42501', message = 'SJ_SHIFT_NOT_OPEN';
    end if;

    if p_items is null
       or jsonb_typeof(p_items) <> 'array'
       or jsonb_array_length(p_items) = 0 then
        raise exception using errcode = '22023', message = 'SJ_INVALID_ITEM';
    end if;

    if (
        select count(*) <> count(distinct value ->> 'stock_item_id')
        from jsonb_array_elements(p_items)
    ) then
        raise exception using errcode = '22023', message = 'SJ_INVALID_ITEM';
    end if;

    for v_item in
        select value from jsonb_array_elements(p_items)
    loop
        begin
            v_item_id := nullif(v_item ->> 'stock_item_id', '')::uuid;
            v_qty := (v_item ->> 'quantity')::numeric;
        exception when invalid_text_representation then
            raise exception using errcode = '22023', message = 'SJ_INVALID_ITEM';
        end;

        if v_item_id is null or v_qty is null or v_qty <= 0 then
            raise exception using errcode = '22023', message = 'SJ_INVALID_ITEM';
        end if;

        select si.sale_price, si.inventory_tracked
        into v_price, v_inventory_tracked
        from public.stock_items si
        where si.id = v_item_id
          and si.business_id = p_business_id
          and si.active
          and si.sale_enabled
        for update;

        if not found or v_price is null or v_price <= 0 then
            raise exception using errcode = '22023', message = 'SJ_SALE_PRICE_INVALID';
        end if;

        v_subtotal := v_subtotal + (v_qty * v_price);
        v_normalized_items := v_normalized_items || jsonb_build_array(
            jsonb_build_object(
                'stock_item_id', v_item_id,
                'quantity', v_qty,
                'unit_price', v_price,
                'inventory_tracked', v_inventory_tracked
            )
        );
    end loop;

    if v_subtotal <= 0 then
        raise exception using errcode = '22023', message = 'SJ_INVALID_ITEM';
    end if;

    v_payment_method := upper(btrim(coalesce(p_payment ->> 'method','')));

    if v_payment_method not in ('CASH','QRIS','TRANSFER','CREDIT') then
        raise exception using errcode = '22023', message = 'SJ_PAYMENT_METHOD_UNSUPPORTED';
    end if;

    if v_payment_method = 'QRIS'
       and not private.has_permission(p_business_id, 'PAYMENT_QRIS') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if v_payment_method = 'TRANSFER'
       and not private.has_permission(p_business_id, 'PAYMENT_TRANSFER') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if v_payment_method = 'CREDIT' then
        if not private.has_permission(p_business_id, 'CUSTOMER_DEBT_MANAGE') then
            raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
        end if;

        begin
            v_customer := nullif(p_payment ->> 'customer_id','')::uuid;
        exception when invalid_text_representation then
            raise exception using errcode = '22023', message = 'CUSTOMER_REQUIRED_FOR_DEBT';
        end;

        if v_customer is null or not exists (
            select 1 from public.customers c
            where c.id = v_customer
              and c.business_id = p_business_id
              and c.active
        ) then
            raise exception using errcode = '23503', message = 'CUSTOMER_REQUIRED_FOR_DEBT';
        end if;

        v_payment_amount := v_subtotal;
    else
        begin
            v_payment_amount := nullif(p_payment ->> 'amount','')::numeric;
        exception when invalid_text_representation then
            raise exception using errcode = '22023', message = 'SJ_PAYMENT_INVALID';
        end;

        if v_payment_amount is null
           or v_payment_amount <= 0
           or v_payment_amount <> v_subtotal then
            raise exception using errcode = '22023', message = 'SJ_PAYMENT_ALLOCATION_MISMATCH';
        end if;
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'actor', v_actor,
            'location_id', p_location_id,
            'items', v_normalized_items,
            'payment', jsonb_build_object(
                'method', v_payment_method,
                'amount', v_payment_amount,
                'customer_id', v_customer
            ),
            'note', p_note
        )
    );

    select * into v_lock
    from private.lock_operation(
        p_business_id, p_operation_id::text, 'SALE_CREATE', v_payload_hash
    );

    if v_lock.replay then
        return jsonb_build_object(
            'success', true,
            'replay', true,
            'receipt_id', v_lock.receipt_id,
            'result_id', v_lock.result_id
        );
    end if;

    -- Stock availability is checked only for a new operation. A replay must
    -- return the original sale even though that sale has already consumed stock.
    for v_item in
        select value from jsonb_array_elements(v_normalized_items)
    loop
        if coalesce((v_item ->> 'inventory_tracked')::boolean, false) then
            v_item_id := (v_item ->> 'stock_item_id')::uuid;
            v_qty := (v_item ->> 'quantity')::numeric;

            select coalesce(ib.quantity, 0)
            into v_available
            from public.inventory_balances ib
            where ib.business_id = p_business_id
              and ib.location_id = p_location_id
              and ib.stock_item_id = v_item_id;

            v_available := coalesce(v_available, 0);

            if v_available < v_qty then
                raise exception using errcode = '23514', message = 'SJ_STOCK_LOW';
            end if;
        end if;
    end loop;

    v_invoice := private.generate_sale_invoice();

    insert into public.sales (
        business_id, location_id, shift_id, customer_id,
        invoice_number, cashier_profile_id, status,
        subtotal, discount_amount, total_amount, note
    ) values (
        p_business_id, p_location_id, v_shift, v_customer,
        v_invoice, v_actor, 'COMPLETED',
        v_subtotal, 0, v_subtotal, p_note
    ) returning id into v_sale_id;

    for v_item in
        select value from jsonb_array_elements(v_normalized_items)
    loop
        v_line := v_line + 1;

        insert into public.sale_items (
            sale_id, line_no, stock_item_id, quantity, unit_price, subtotal
        ) values (
            v_sale_id,
            v_line,
            (v_item ->> 'stock_item_id')::uuid,
            (v_item ->> 'quantity')::numeric,
            (v_item ->> 'unit_price')::numeric,
            (v_item ->> 'quantity')::numeric * (v_item ->> 'unit_price')::numeric
        );
    end loop;

    insert into public.payments (
        sale_id, method, amount, status, verified_by
    ) values (
        v_sale_id, v_payment_method, v_payment_amount, 'PAID', v_actor
    );

    perform private.record_operation_success(
        p_business_id,
        p_operation_id::text,
        'SALE_CREATE',
        v_payload_hash,
        'SALE',
        v_sale_id,
        v_actor
    );

    return jsonb_build_object(
        'success', true,
        'sale_id', v_sale_id,
        'invoice_number', v_invoice,
        'status', 'COMPLETED'
    );
end;
$$;

revoke all on function private.record_sale(uuid,uuid,uuid,jsonb,jsonb,text)
from public, anon, authenticated, service_role;

