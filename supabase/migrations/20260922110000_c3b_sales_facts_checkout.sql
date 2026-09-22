-- C3-B: Sales facts + Board 02 checkout convergence.

insert into public.permission_definitions (code, display_name, category, active)
values ('SALE_DISCOUNT','Beri Diskon Penjualan','PENJUALAN',true)
on conflict (code) do update
set display_name=excluded.display_name,
    category=excluded.category,
    active=excluded.active;

alter table public.sales
    add column discount_type text not null default 'NONE',
    add column discount_value numeric(18,2) not null default 0,
    add column discount_reason text,
    add column discount_approved_by uuid references public.profiles(id) on delete restrict;

alter table public.sales
    add constraint sales_discount_fact_valid
    check (
        (discount_type='NONE' and discount_amount=0 and discount_value=0 and discount_reason is null and discount_approved_by is null)
        or
        (discount_type='AMOUNT' and discount_value > 0 and discount_value <= subtotal and discount_amount = discount_value and discount_reason is not null and length(btrim(discount_reason)) > 0 and discount_approved_by is not null)
        or
        (discount_type='PERCENT' and discount_value > 0 and discount_value <= 100 and discount_amount = round(subtotal * discount_value / 100, 2) and discount_reason is not null and length(btrim(discount_reason)) > 0 and discount_approved_by is not null)
    ),
    add constraint sales_total_matches_discount
    check (total_amount = subtotal - discount_amount);

alter table public.sale_items
    add column line_note text;

alter table public.sale_items
    add constraint sale_items_line_note_nonempty
    check (line_note is null or length(btrim(line_note)) > 0);

alter table public.payments
    add column tendered_amount numeric(18,2),
    add column change_amount numeric(18,2);

alter table public.payments
    drop constraint payments_amount_positive;

alter table public.payments
    add constraint payments_amount_nonnegative check (amount >= 0),
    add constraint payments_tender_change_valid
    check (
        (method='CASH' and (
            (tendered_amount is null and change_amount is null)
            or
            (tendered_amount is not null and change_amount is not null and tendered_amount >= amount and change_amount = tendered_amount - amount)
        ))
        or
        (method <> 'CASH' and tendered_amount is null and change_amount is null)
    );

alter table public.sale_corrections
    alter column money_reversal_movement_id drop not null;

create or replace function private.cs05_capture_cash_sale()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    r record;
    v_shift uuid;
begin
    if new.method <> 'CASH' or new.status <> 'PAID' then
        return new;
    end if;

    -- A 100% discount is a real sale/inventory event but moves no cash.
    -- Preserve the zero-valued payment fact without inventing a zero cash transaction.
    if new.amount = 0 then
        return new;
    end if;

    select business_id, location_id, cashier_profile_id into r
    from public.sales
    where id = new.sale_id;

    select id into v_shift
    from public.shifts
    where cashier_profile_id = r.cashier_profile_id
      and location_id = r.location_id
      and status = 'OPEN';

    if v_shift is null then
        raise exception using errcode = '42501', message = 'SJ_SHIFT_NOT_OPEN';
    end if;

    insert into public.cash_transactions (
        business_id,
        location_id,
        shift_id,
        cashier_profile_id,
        transaction_type,
        amount,
        reference_type,
        reference_id
    ) values (
        r.business_id,
        r.location_id,
        v_shift,
        r.cashier_profile_id,
        'SALE',
        new.amount,
        'SALE',
        new.sale_id
    );

    return new;
end;
$$;

create or replace function private.record_sale_v2(
    p_operation_id uuid,
    p_business_id uuid,
    p_location_id uuid,
    p_items jsonb,
    p_payment jsonb,
    p_discount jsonb,
    p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor uuid;
    v_shift uuid;
    v_invoice text;
    v_sale_id uuid;
    v_request_items jsonb := '[]'::jsonb;
    v_resolved_items jsonb := '[]'::jsonb;
    v_item jsonb;
    v_variant_id uuid;
    v_qty numeric;
    v_subtotal numeric(18,2) := 0;
    v_line integer := 0;
    v_payment_method text;
    v_requested_amount numeric(18,2);
    v_payment_amount numeric(18,2);
    v_customer uuid;
    v_payload_hash text;
    v_lock record;
    v_product_id uuid;
    v_product_code text;
    v_product_name text;
    v_variant_code text;
    v_variant_name text;
    v_fulfillment_mode text;
    v_sale_stock_item_id uuid;
    v_price numeric(18,2);
    v_component_count integer;
    v_finished_good_match_count integer;
    v_invalid_component_count integer;
    v_precision_bad_count integer;
    v_tendered_amount numeric(18,2);
    v_change_amount numeric(18,2);
    v_discount_type text := 'NONE';
    v_discount_value numeric(18,2) := 0;
    v_discount_amount numeric(18,2) := 0;
    v_discount_reason text;
    v_discount_approved_by uuid;
    v_total_amount numeric(18,2);
begin
    v_actor := private.current_profile_id();

    if p_operation_id is null then
        raise exception using errcode='22023', message='SJ_OPERATION_REQUIRED';
    end if;

    if v_actor is null
       or not private.has_permission(p_business_id, 'SALE_EXECUTE') then
        raise exception using errcode='42501', message='SJ_PERMISSION_DENIED';
    end if;

    if not exists (
        select 1
        from public.locations l
        where l.id = p_location_id
          and l.business_id = p_business_id
          and l.active
    ) then
        raise exception using errcode='23503', message='SJ_LOCATION_NOT_FOUND';
    end if;

    select s.id
    into v_shift
    from public.shifts s
    where s.business_id = p_business_id
      and s.location_id = p_location_id
      and s.cashier_profile_id = v_actor
      and s.status = 'OPEN'
    limit 1;

    if v_shift is null then
        raise exception using errcode='42501', message='SJ_SHIFT_NOT_OPEN';
    end if;

    if p_items is null
       or jsonb_typeof(p_items) <> 'array'
       or jsonb_array_length(p_items) = 0 then
        raise exception using errcode='22023', message='SJ_INVALID_ITEM';
    end if;

    if (
        select count(*) <> count(distinct value ->> 'variant_id')
        from jsonb_array_elements(p_items)
    ) then
        raise exception using errcode='22023', message='SJ_INVALID_ITEM';
    end if;

    for v_item in
        select value
        from jsonb_array_elements(p_items)
    loop
        begin
            v_variant_id := nullif(v_item ->> 'variant_id','')::uuid;
            v_qty := (v_item ->> 'quantity')::numeric;
        exception when invalid_text_representation then
            raise exception using errcode='22023', message='SJ_INVALID_ITEM';
        end;

        if v_variant_id is null or v_qty is null or v_qty <= 0 then
            raise exception using errcode='22023', message='SJ_INVALID_ITEM';
        end if;

        v_request_items := v_request_items || jsonb_build_array(
            jsonb_build_object(
                'variant_id', v_variant_id,
                'quantity', v_qty,
                'line_note', nullif(btrim(coalesce(v_item ->> 'line_note','')), '')
            )
        );
    end loop;

    v_discount_type := upper(btrim(coalesce(p_discount ->> 'type','NONE')));

    if v_discount_type not in ('NONE','AMOUNT','PERCENT') then
        raise exception using errcode='22023', message='SJ_DISCOUNT_TYPE_INVALID';
    end if;

    begin
        v_discount_value := coalesce(nullif(p_discount ->> 'value','')::numeric,0);
    exception when invalid_text_representation then
        raise exception using errcode='22023', message='SJ_DISCOUNT_VALUE_INVALID';
    end;

    v_discount_reason := nullif(btrim(coalesce(p_discount ->> 'reason','')), '');

    if v_discount_type = 'NONE' then
        v_discount_value := 0;
        v_discount_reason := null;
    else
        if not private.has_permission(p_business_id, 'SALE_DISCOUNT') then
            raise exception using errcode='42501', message='SJ_DISCOUNT_PERMISSION_REQUIRED';
        end if;
        if v_discount_reason is null then
            raise exception using errcode='22023', message='SJ_DISCOUNT_REASON_REQUIRED';
        end if;
    end if;

    v_payment_method := upper(btrim(coalesce(p_payment ->> 'method','')));

    if v_payment_method not in ('CASH','QRIS','TRANSFER','CREDIT') then
        raise exception using errcode='22023', message='SJ_PAYMENT_METHOD_UNSUPPORTED';
    end if;

    if v_payment_method = 'QRIS'
       and not private.has_permission(p_business_id, 'PAYMENT_QRIS') then
        raise exception using errcode='42501', message='SJ_PERMISSION_DENIED';
    end if;

    if v_payment_method = 'TRANSFER'
       and not private.has_permission(p_business_id, 'PAYMENT_TRANSFER') then
        raise exception using errcode='42501', message='SJ_PERMISSION_DENIED';
    end if;

    if v_payment_method = 'CREDIT' then
        if not private.has_permission(p_business_id, 'CUSTOMER_DEBT_MANAGE') then
            raise exception using errcode='42501', message='SJ_PERMISSION_DENIED';
        end if;

        begin
            v_customer := nullif(p_payment ->> 'customer_id','')::uuid;
        exception when invalid_text_representation then
            raise exception using errcode='22023', message='CUSTOMER_REQUIRED_FOR_DEBT';
        end;
    else
        begin
            v_requested_amount := nullif(p_payment ->> 'amount','')::numeric;
        exception when invalid_text_representation then
            raise exception using errcode='22023', message='SJ_PAYMENT_INVALID';
        end;

        if v_requested_amount is null or v_requested_amount < 0 then
            raise exception using errcode='22023', message='SJ_PAYMENT_INVALID';
        end if;
    end if;

    if v_payment_method = 'CASH' then
        begin
            v_tendered_amount := nullif(p_payment ->> 'tendered_amount','')::numeric;
        exception when invalid_text_representation then
            raise exception using errcode='22023', message='SJ_CASH_TENDER_INVALID';
        end;
    else
        v_tendered_amount := null;
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'actor', v_actor,
            'location_id', p_location_id,
            'items', v_request_items,
            'payment', jsonb_build_object(
                'method', v_payment_method,
                'amount', v_requested_amount,
                'tendered_amount', v_tendered_amount,
                'customer_id', v_customer
            ),
            'discount', jsonb_build_object(
                'type', v_discount_type,
                'value', v_discount_value,
                'reason', v_discount_reason
            ),
            'note', p_note
        )
    );

    select *
    into v_lock
    from private.lock_operation(
        p_business_id,
        p_operation_id::text,
        'SALE_CREATE_V2',
        v_payload_hash
    );

    if v_lock.replay then
        return jsonb_build_object(
            'success', true,
            'replay', true,
            'receipt_id', v_lock.receipt_id,
            'result_id', v_lock.result_id
        );
    end if;

    if v_payment_method = 'CREDIT' then
        if v_customer is null or not exists (
            select 1
            from public.customers c
            where c.id = v_customer
              and c.business_id = p_business_id
              and c.active
        ) then
            raise exception using errcode='23503', message='CUSTOMER_REQUIRED_FOR_DEBT';
        end if;
    end if;

    for v_item in
        select value
        from jsonb_array_elements(v_request_items)
    loop
        v_variant_id := (v_item ->> 'variant_id')::uuid;
        v_qty := (v_item ->> 'quantity')::numeric;

        select
            p.id,
            p.code,
            p.display_name,
            v.code,
            v.display_name,
            v.fulfillment_mode,
            v.sale_stock_item_id,
            v.sale_price
        into
            v_product_id,
            v_product_code,
            v_product_name,
            v_variant_code,
            v_variant_name,
            v_fulfillment_mode,
            v_sale_stock_item_id,
            v_price
        from public.product_variants v
        join public.sale_products p
          on p.id = v.product_id
         and p.business_id = v.business_id
        where v.id = v_variant_id
          and v.business_id = p_business_id
          and v.active
          and p.active;

        if not found or v_price is null or v_price <= 0 then
            raise exception using errcode='22023', message='SJ_VARIANT_INVALID';
        end if;

        select count(*)
        into v_component_count
        from public.variant_sale_components c
        where c.variant_id = v_variant_id;

        if v_component_count = 0 then
            raise exception using errcode='23514', message='SJ_VARIANT_COMPONENTS_MISSING';
        end if;

        select count(*)
        into v_invalid_component_count
        from public.variant_sale_components c
        left join public.stock_items si
          on si.id = c.stock_item_id
         and si.business_id = p_business_id
        where c.variant_id = v_variant_id
          and (
              si.id is null
              or not si.active
              or (
                  v_fulfillment_mode = 'MAKE_TO_ORDER'
                  and c.component_role = 'FINISHED_GOOD'
              )
          );

        if v_invalid_component_count > 0 then
            raise exception using errcode='23514', message='SJ_VARIANT_COMPONENT_SHAPE_INVALID';
        end if;

        if v_fulfillment_mode in ('DIRECT_STOCK','PREPRODUCED') then
            select count(*)
            into v_finished_good_match_count
            from public.variant_sale_components c
            where c.variant_id = v_variant_id
              and c.component_role = 'FINISHED_GOOD'
              and c.stock_item_id = v_sale_stock_item_id;

            if v_sale_stock_item_id is null or v_finished_good_match_count <> 1 then
                raise exception using errcode='23514', message='SJ_VARIANT_COMPONENT_SHAPE_INVALID';
            end if;
        end if;

        select count(*)
        into v_precision_bad_count
        from public.variant_sale_components c
        where c.variant_id = v_variant_id
          and (c.quantity_per_unit * v_qty) <> round(c.quantity_per_unit * v_qty, 3);

        if v_precision_bad_count > 0 then
            raise exception using errcode='22023', message='SJ_VARIANT_COMPONENT_PRECISION_UNSUPPORTED';
        end if;

        v_subtotal := v_subtotal + (v_qty * v_price);

        v_resolved_items := v_resolved_items || jsonb_build_array(
            jsonb_build_object(
                'sale_product_id', v_product_id,
                'variant_id', v_variant_id,
                'product_code_snapshot', v_product_code,
                'product_name_snapshot', v_product_name,
                'variant_code_snapshot', v_variant_code,
                'variant_name_snapshot', v_variant_name,
                'fulfillment_mode_snapshot', v_fulfillment_mode,
                'sale_stock_item_id', v_sale_stock_item_id,
                'quantity', v_qty,
                'unit_price', v_price,
                'line_note', nullif(btrim(coalesce(v_item ->> 'line_note','')), '')
            )
        );
    end loop;

    if v_subtotal <= 0 then
        raise exception using errcode='22023', message='SJ_INVALID_ITEM';
    end if;

    if v_discount_type = 'NONE' then
        v_discount_amount := 0;
    elsif v_discount_type = 'AMOUNT' then
        if v_discount_value <= 0 or v_discount_value > v_subtotal then
            raise exception using errcode='22023', message='SJ_DISCOUNT_VALUE_INVALID';
        end if;
        v_discount_amount := v_discount_value;
    else
        if v_discount_value <= 0 or v_discount_value > 100 then
            raise exception using errcode='22023', message='SJ_DISCOUNT_VALUE_INVALID';
        end if;
        v_discount_amount := round(v_subtotal * v_discount_value / 100, 2);
    end if;

    v_total_amount := (v_subtotal - v_discount_amount)::numeric(18,2);
    v_discount_approved_by := case when v_discount_amount > 0 then v_actor else null end;

    if v_total_amount < 0 then
        raise exception using errcode='22023', message='SJ_DISCOUNT_VALUE_INVALID';
    end if;

    if v_total_amount = 0 and v_payment_method <> 'CASH' then
        raise exception using errcode='22023', message='SJ_ZERO_TOTAL_PAYMENT_METHOD_INVALID';
    end if;

    if v_payment_method = 'CREDIT' then
        v_payment_amount := v_total_amount;
    else
        if v_requested_amount is null or v_requested_amount <> v_total_amount then
            raise exception using errcode='22023', message='SJ_PAYMENT_ALLOCATION_MISMATCH';
        end if;
        v_payment_amount := v_total_amount;
    end if;

    if v_payment_method = 'CASH' then
        if v_total_amount = 0 then
            if coalesce(v_tendered_amount,0) <> 0 then
                raise exception using errcode='22023', message='SJ_ZERO_TOTAL_TENDER_INVALID';
            end if;
            v_tendered_amount := 0;
            v_change_amount := 0;
        else
            if v_tendered_amount is null or v_tendered_amount < v_total_amount then
                raise exception using errcode='22023', message='SJ_CASH_TENDER_INSUFFICIENT';
            end if;
            v_change_amount := (v_tendered_amount - v_total_amount)::numeric(18,2);
        end if;
    else
        v_tendered_amount := null;
        v_change_amount := null;
    end if;

    v_invoice := private.generate_sale_invoice();

    insert into public.sales (
        business_id,
        location_id,
        shift_id,
        customer_id,
        invoice_number,
        cashier_profile_id,
        status,
        subtotal,
        discount_amount,
        total_amount,
        note,
        discount_type,
        discount_value,
        discount_reason,
        discount_approved_by
    ) values (
        p_business_id,
        p_location_id,
        v_shift,
        v_customer,
        v_invoice,
        v_actor,
        'COMPLETED',
        v_subtotal,
        v_discount_amount,
        v_total_amount,
        p_note,
        v_discount_type,
        v_discount_value,
        v_discount_reason,
        v_discount_approved_by
    )
    returning id into v_sale_id;

    for v_item in
        select value
        from jsonb_array_elements(v_resolved_items)
    loop
        v_line := v_line + 1;

        insert into public.sale_items (
            sale_id,
            line_no,
            stock_item_id,
            quantity,
            unit_price,
            subtotal,
            sale_product_id,
            variant_id,
            product_code_snapshot,
            product_name_snapshot,
            variant_code_snapshot,
            variant_name_snapshot,
            fulfillment_mode_snapshot,
            line_note
        ) values (
            v_sale_id,
            v_line,
            nullif(v_item ->> 'sale_stock_item_id','')::uuid,
            (v_item ->> 'quantity')::numeric,
            (v_item ->> 'unit_price')::numeric,
            (v_item ->> 'quantity')::numeric * (v_item ->> 'unit_price')::numeric,
            (v_item ->> 'sale_product_id')::uuid,
            (v_item ->> 'variant_id')::uuid,
            v_item ->> 'product_code_snapshot',
            v_item ->> 'product_name_snapshot',
            v_item ->> 'variant_code_snapshot',
            v_item ->> 'variant_name_snapshot',
            v_item ->> 'fulfillment_mode_snapshot',
            nullif(btrim(coalesce(v_item ->> 'line_note','')), '')
        );

        insert into public.sale_item_component_snapshots (
            sale_id,
            sale_line_no,
            component_line_no,
            stock_item_id,
            component_role,
            quantity_per_unit,
            quantity_total,
            inventory_tracked_snapshot,
            stock_item_code_snapshot,
            stock_item_name_snapshot
        )
        select
            v_sale_id,
            v_line,
            c.line_no,
            c.stock_item_id,
            c.component_role,
            c.quantity_per_unit,
            (c.quantity_per_unit * (v_item ->> 'quantity')::numeric)::numeric(18,3),
            si.inventory_tracked,
            si.code,
            si.display_name
        from public.variant_sale_components c
        join public.stock_items si
          on si.id = c.stock_item_id
         and si.business_id = p_business_id
        where c.variant_id = (v_item ->> 'variant_id')::uuid
        order by c.line_no;
    end loop;

    insert into public.payments (
        sale_id,
        method,
        amount,
        status,
        verified_by,
        tendered_amount,
        change_amount
    ) values (
        v_sale_id,
        v_payment_method,
        v_payment_amount,
        'PAID',
        v_actor,
        v_tendered_amount,
        v_change_amount
    );

    perform private.record_operation_success(
        p_business_id,
        p_operation_id::text,
        'SALE_CREATE_V2',
        v_payload_hash,
        'SALE',
        v_sale_id,
        v_actor
    );

    return jsonb_build_object(
        'success', true,
        'sale_id', v_sale_id,
        'invoice_number', v_invoice,
        'subtotal', v_subtotal,
        'discount_amount', v_discount_amount,
        'total_amount', v_total_amount,
        'payment_method', v_payment_method,
        'tendered_amount', v_tendered_amount,
        'change_amount', v_change_amount,
        'status', 'COMPLETED'
    );
end;
$$;

revoke all on function private.record_sale_v2(uuid,uuid,uuid,jsonb,jsonb,jsonb,text)
from public, anon, authenticated, service_role;

create or replace function private.record_sale_v2(
    p_operation_id uuid,
    p_business_id uuid,
    p_location_id uuid,
    p_items jsonb,
    p_payment jsonb,
    p_note text default null
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
    select private.record_sale_v2(
        p_operation_id,
        p_business_id,
        p_location_id,
        p_items,
        case
            when upper(btrim(coalesce(p_payment ->> 'method','')))='CASH'
                 and not (p_payment ? 'tendered_amount')
                then p_payment || jsonb_build_object(
                    'tendered_amount',
                    coalesce((p_payment ->> 'amount')::numeric,0)
                )
            else p_payment
        end,
        null::jsonb,
        p_note
    );
$$;

revoke all on function private.record_sale_v2(uuid,uuid,uuid,jsonb,jsonb,text)
from public, anon, authenticated, service_role;
create or replace function private.post_sale_transaction(
    p_business_id uuid,
    p_actor_profile_id uuid,
    p_sale_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_sale public.sales%rowtype;
    v_inventory_id uuid;
    v_money_id uuid;
    v_receipt_id uuid;
    v_debt_id uuid;
    v_inventory_lines jsonb;
    v_inventory_basis text;
    v_payment jsonb;
    v_payload_hash text;
    v_replay record;
    v_account_id uuid;
    v_method text;
    v_amount numeric;
    v_stock record;
    v_available numeric;
begin
    if p_business_id is null or p_sale_id is null or p_actor_profile_id is null then
        raise exception using errcode='22023', message='SJ_SALE_REQUIRED';
    end if;

    select *
    into v_sale
    from public.sales
    where id = p_sale_id
      and business_id = p_business_id;

    if not found then
        raise exception using errcode='23503', message='SJ_SALE_NOT_FOUND';
    end if;

    if v_sale.cashier_profile_id <> p_actor_profile_id
       or v_sale.shift_id is null
       or not exists (
            select 1
            from public.shifts s
            where s.id = v_sale.shift_id
              and s.business_id = p_business_id
              and s.location_id = v_sale.location_id
              and s.cashier_profile_id = p_actor_profile_id
       ) then
        raise exception using errcode='42501', message='SJ_SALE_ACTOR_SHIFT_MISMATCH';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object('sale_id', p_sale_id)
    );

    select *
    into v_replay
    from private.lock_operation(
        p_business_id,
        'SALE-POSTING-' || p_sale_id::text,
        'SALE_POSTING',
        v_payload_hash
    );

    if v_replay.replay then
        return jsonb_build_object(
            'success', true,
            'already_posted', true,
            'sale_id', p_sale_id,
            'result_id', v_replay.result_id
        );
    end if;

    if exists (
        select 1
        from public.sale_item_component_snapshots sics
        where sics.sale_id = p_sale_id
    ) then
        v_inventory_basis := 'SNAPSHOT_V2';

        select jsonb_agg(
            jsonb_build_object(
                'line_no', x.line_no,
                'stock_item_id', x.stock_item_id,
                'location_id', v_sale.location_id,
                'quantity_delta', x.quantity_total * -1
            )
            order by x.line_no
        )
        into v_inventory_lines
        from (
            select
                row_number() over(order by sics.stock_item_id)::integer as line_no,
                sics.stock_item_id,
                sum(sics.quantity_total)::numeric(18,3) as quantity_total
            from public.sale_item_component_snapshots sics
            where sics.sale_id = p_sale_id
              and sics.inventory_tracked_snapshot
            group by sics.stock_item_id
        ) x;
    else
        v_inventory_basis := 'LEGACY_SALE_ITEM';

        select jsonb_agg(
            jsonb_build_object(
                'line_no', x.line_no,
                'stock_item_id', x.stock_item_id,
                'location_id', v_sale.location_id,
                'quantity_delta', x.quantity_total * -1
            )
            order by x.line_no
        )
        into v_inventory_lines
        from (
            select
                row_number() over(order by sai.stock_item_id)::integer as line_no,
                sai.stock_item_id,
                sum(sai.quantity)::numeric(18,3) as quantity_total
            from public.sale_items sai
            join public.stock_items si
              on si.id = sai.stock_item_id
             and si.business_id = p_business_id
            where sai.sale_id = p_sale_id
              and si.inventory_tracked
            group by sai.stock_item_id
        ) x;
    end if;

    if v_inventory_lines is not null then
        for v_stock in
            select *
            from jsonb_to_recordset(v_inventory_lines) as x(
                line_no integer,
                stock_item_id uuid,
                location_id uuid,
                quantity_delta numeric
            )
            order by stock_item_id
        loop
            perform pg_catalog.pg_advisory_xact_lock(
                pg_catalog.hashtextextended(
                    'C2B:SALE-STOCK:'
                    || p_business_id::text || ':'
                    || v_sale.location_id::text || ':'
                    || v_stock.stock_item_id::text,
                    0
                )
            );

            select coalesce(ib.quantity, 0::numeric)
            into v_available
            from public.inventory_balances ib
            where ib.business_id = p_business_id
              and ib.location_id = v_sale.location_id
              and ib.stock_item_id = v_stock.stock_item_id;

            v_available := coalesce(v_available, 0::numeric);

            if v_stock.quantity_delta >= 0
               or v_available < abs(v_stock.quantity_delta) then
                raise exception using errcode='23514', message='SJ_STOCK_LOW';
            end if;
        end loop;

        v_inventory_id := private.record_inventory_movement(
            p_business_id,
            p_actor_profile_id,
            'SALE-INVENTORY-' || p_sale_id::text,
            'SALE',
            'SALE',
            v_sale.invoice_number,
            'SALE_CONSUMPTION',
            v_inventory_lines
        );
    else
        v_inventory_id := null;
    end if;

    select jsonb_build_object('method', method, 'amount', amount)
    into v_payment
    from public.payments
    where sale_id = p_sale_id
    limit 1;

    if v_payment is null then
        raise exception using errcode='22023', message='SJ_PAYMENT_REQUIRED';
    end if;

    v_method := v_payment ->> 'method';
    v_amount := (v_payment ->> 'amount')::numeric;

    if v_amount <> v_sale.total_amount then
        raise exception using errcode='22023', message='SJ_PAYMENT_ALLOCATION_MISMATCH';
    end if;

    if v_amount > 0 then
        select id
        into v_account_id
        from public.money_accounts
        where business_id = p_business_id
          and code = case
              when v_method = 'CASH' then 'KAS_SHIFT'
              when v_method = 'QRIS' then 'QRIS_BELUM_CAIR'
              when v_method = 'TRANSFER' then 'BANK'
              when v_method = 'CREDIT' then 'HUTANG_PELANGGAN'
              else null
          end
          and active
        limit 1;

        if v_account_id is null then
            raise exception using errcode='23503', message='SJ_PAYMENT_ACCOUNT_NOT_FOUND';
        end if;

        if v_method = 'CREDIT' then
            if v_sale.customer_id is null then
                raise exception using errcode='23503', message='CUSTOMER_REQUIRED_FOR_DEBT';
            end if;

            v_debt_id := gen_random_uuid();

            v_money_id := private.record_money_movement(
                p_business_id,
                p_actor_profile_id,
                'SALE-MONEY-' || p_sale_id::text,
                'INCOME',
                null,
                v_account_id,
                v_amount,
                'CUSTOMER_DEBT',
                v_debt_id::text,
                'CUSTOMER_DEBT_SALE'
            );

            insert into public.customer_debts (
                id,
                business_id,
                customer_id,
                sale_id,
                original_amount,
                receivable_movement_id,
                created_by
            ) values (
                v_debt_id,
                p_business_id,
                v_sale.customer_id,
                p_sale_id,
                v_amount,
                v_money_id,
                p_actor_profile_id
            );
        else
            if v_method not in ('CASH','QRIS','TRANSFER') then
                raise exception using errcode='22023', message='SJ_PAYMENT_METHOD_UNSUPPORTED';
            end if;

            v_money_id := private.record_money_movement(
                p_business_id,
                p_actor_profile_id,
                'SALE-MONEY-' || p_sale_id::text,
                'INCOME',
                null,
                v_account_id,
                v_amount,
                'SALE',
                v_sale.invoice_number,
                'SALE_PAYMENT'
            );
        end if;

    else
        if v_method <> 'CASH' or v_sale.total_amount <> 0 then
            raise exception using errcode='22023', message='SJ_ZERO_TOTAL_PAYMENT_METHOD_INVALID';
        end if;
        v_money_id := null;
        v_debt_id := null;
    end if;

    v_receipt_id := private.record_operation_success(
        p_business_id,
        'SALE-POSTING-' || p_sale_id::text,
        'SALE_POSTING',
        v_payload_hash,
        'SALE',
        p_sale_id,
        p_actor_profile_id
    );

    insert into public.audit_events (
        business_id,
        actor_profile_id,
        operation_receipt_id,
        event_type,
        entity_type,
        entity_id,
        metadata
    ) values (
        p_business_id,
        p_actor_profile_id,
        v_receipt_id,
        'SALE_POSTED',
        'SALE',
        p_sale_id,
        jsonb_build_object(
            'inventory_movement_id', v_inventory_id,
            'inventory_basis', v_inventory_basis,
            'money_movement_id', v_money_id,
            'customer_debt_id', v_debt_id,
            'receipt_id', v_receipt_id,
            'sale_id', p_sale_id,
            'invoice_number', v_sale.invoice_number
        )
    );

    return jsonb_build_object(
        'success', true,
        'sale_id', p_sale_id,
        'inventory_movement_id', v_inventory_id,
        'inventory_basis', v_inventory_basis,
        'money_movement_id', v_money_id,
        'customer_debt_id', v_debt_id,
        'status', 'POSTED'
    );
end;
$$;
create or replace function public.refund_sale(
    p_sale_id uuid,
    p_stock_disposition text,
    p_refund_method text,
    p_reason text,
    p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_sale public.sales%rowtype;
    v_stock_disposition text;
    v_refund_method text;
    v_payment_method text;
    v_payment_amount numeric(18,2);
    v_payment_count integer;
    v_refund uuid;
    v_payload_hash text;
    v_lock record;
    v_receipt uuid;
    v_original_inventory uuid;
    v_inventory_lines jsonb;
    v_inventory_movement uuid;
    v_original_money uuid;
    v_payout_money uuid;
    v_debt_cancel_money uuid;
    v_debt public.customer_debts%rowtype;
    v_paid numeric(18,2) := 0;
    v_balance numeric(18,2) := 0;
    v_payout numeric(18,2) := 0;
    v_receivable_cancel numeric(18,2) := 0;
    v_source_account uuid;
    v_receivable_account uuid;
    v_shift uuid;
    v_cash_tx uuid;
begin
    v_authority := public.get_my_authority();
    v_business := (v_authority ->> 'business_id')::uuid;
    v_actor := (v_authority ->> 'profile_id')::uuid;
    v_stock_disposition := upper(btrim(coalesce(p_stock_disposition,'')));
    v_refund_method := upper(btrim(coalesce(p_refund_method,'')));

    if v_business is null or v_actor is null
       or not (
           coalesce((v_authority ->> 'owner')::boolean,false)
           or private.has_permission(v_business,'CORRECTION_LIMITED')
       ) then
        raise exception using errcode='42501', message='CORRECTION_LIMITED_REQUIRED';
    end if;

    if v_stock_disposition not in ('RETURN_TO_STOCK','DAMAGED_UNFIT','NO_GOODS_RETURNED') then
        raise exception using errcode='22023', message='SALE_REFUND_STOCK_DISPOSITION_INVALID';
    end if;

    if v_refund_method not in ('CASH','TRANSFER','NONE') then
        raise exception using errcode='22023', message='SALE_REFUND_METHOD_INVALID';
    end if;

    if p_reason is null or length(btrim(p_reason)) = 0 then
        raise exception using errcode='22023', message='SALE_REFUND_REASON_REQUIRED';
    end if;

    select * into v_sale
    from public.sales
    where id = p_sale_id
      and business_id = v_business
    for update;

    if not found then
        raise exception using errcode='23503', message='SALE_NOT_FOUND';
    end if;

    if v_sale.status <> 'COMPLETED' then
        raise exception using errcode='23514', message='SALE_NOT_REFUNDABLE';
    end if;

    select count(*), min(method), coalesce(sum(amount),0)::numeric(18,2)
    into v_payment_count, v_payment_method, v_payment_amount
    from public.payments
    where sale_id = v_sale.id
      and status = 'PAID';

    if v_payment_count <> 1 or v_payment_amount <> v_sale.total_amount then
        raise exception using errcode='23514', message='SALE_REFUND_PAYMENT_SHAPE_UNSUPPORTED';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'sale_id', v_sale.id,
            'stock_disposition', v_stock_disposition,
            'refund_method', v_refund_method,
            'reason', btrim(p_reason)
        )
    );

    select * into v_lock
    from private.lock_operation(
        v_business, p_idempotency_key, 'SALE_REFUND', v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'SALE_REFUND' or v_lock.result_id is null then
            raise exception using errcode='23505', message='SJ_IDEMPOTENCY_CONFLICT';
        end if;

        return (
            select jsonb_build_object(
                'refund_id', r.id,
                'sale_id', r.sale_id,
                'payout_amount', r.payout_amount,
                'receivable_cancelled_amount', r.receivable_cancelled_amount,
                'stock_disposition', r.stock_disposition,
                'refund_method', r.refund_method,
                'already_posted', true
            )
            from public.sale_refunds r
            where r.id = v_lock.result_id
        );
    end if;

    if exists (
        select 1 from public.sale_refunds r
        where r.business_id = v_business and r.sale_id = v_sale.id
    ) then
        raise exception using errcode='23505', message='SALE_ALREADY_REFUNDED';
    end if;

    if exists (
        select 1 from public.sale_corrections c
        where c.business_id = v_business and c.sale_id = v_sale.id
    ) then
        raise exception using errcode='23505', message='SALE_ALREADY_CORRECTED';
    end if;

    if v_refund_method = 'TRANSFER'
       and not private.has_permission(v_business,'PAYMENT_TRANSFER') then
        raise exception using errcode='42501', message='SJ_PERMISSION_DENIED';
    end if;

    if v_payment_method = 'CREDIT' then
        select * into v_debt
        from public.customer_debts
        where business_id = v_business
          and sale_id = v_sale.id
        for update;

        if not found then
            raise exception using errcode='23503', message='CUSTOMER_DEBT_NOT_FOUND';
        end if;

        select coalesce(sum(amount),0)::numeric(18,2)
        into v_paid
        from public.customer_debt_payments
        where debt_id = v_debt.id;

        v_balance := (v_debt.original_amount - v_paid)::numeric(18,2);
        v_payout := v_paid;
        v_receivable_cancel := v_balance;

        if v_payout = 0 and v_refund_method <> 'NONE' then
            raise exception using errcode='22023', message='SALE_REFUND_CREDIT_METHOD_MUST_BE_NONE';
        end if;
        if v_payout > 0 and v_refund_method not in ('CASH','TRANSFER') then
            raise exception using errcode='22023', message='SALE_REFUND_CREDIT_PAYOUT_METHOD_REQUIRED';
        end if;
    else
        v_payout := v_sale.total_amount;
        v_receivable_cancel := 0;

        if v_payout = 0 then
            if v_refund_method <> 'NONE' then
                raise exception using errcode='22023', message='SALE_REFUND_ZERO_TOTAL_METHOD_MUST_BE_NONE';
            end if;
        elsif v_refund_method not in ('CASH','TRANSFER') then
            raise exception using errcode='22023', message='SALE_REFUND_PAYOUT_METHOD_REQUIRED';
        end if;
    end if;

    v_refund := gen_random_uuid();

    if v_stock_disposition = 'RETURN_TO_STOCK' then
        select m.id
        into v_original_inventory
        from public.inventory_movements m
        where m.business_id = v_business
          and m.source_type = 'SALE'
          and m.source_ref = v_sale.invoice_number
        order by m.created_at
        limit 1;

        if v_original_inventory is not null then
            select jsonb_agg(
                jsonb_build_object(
                    'line_no', l.line_no,
                    'stock_item_id', l.stock_item_id,
                    'location_id', l.location_id,
                    'quantity_delta', l.quantity_delta * -1
                )
                order by l.line_no
            )
            into v_inventory_lines
            from public.inventory_movement_lines l
            where l.movement_id = v_original_inventory;

            v_inventory_movement := private.record_inventory_movement(
                v_business,
                v_actor,
                p_idempotency_key || ':INVENTORY',
                'REFUND',
                'SALE_REFUND',
                v_refund::text,
                'SALE_REFUND_RETURN_TO_STOCK',
                v_inventory_lines,
                p_reverses_movement_id => v_original_inventory
            );
        end if;
    end if;

    if v_payout > 0 then
        if v_refund_method = 'CASH' then
            select s.id
            into v_shift
            from public.shifts s
            where s.business_id = v_business
              and s.location_id = v_sale.location_id
              and s.cashier_profile_id = v_actor
              and s.status = 'OPEN'
            limit 1
            for update;

            if v_shift is null then
                raise exception using errcode='42501', message='SJ_SHIFT_NOT_OPEN';
            end if;

            if private.cs05_shift_expected_cash(v_shift) < v_payout then
                raise exception using errcode='23514', message='SALE_REFUND_INSUFFICIENT_SHIFT_CASH';
            end if;

            select id into v_source_account
            from public.money_accounts
            where business_id = v_business and code='KAS_SHIFT' and active;
        else
            select id into v_source_account
            from public.money_accounts
            where business_id = v_business and code='BANK' and active;

            if v_source_account is null
               or private.finance_account_balance(v_business,v_source_account) < v_payout then
                raise exception using errcode='23514', message='FINANCE_INSUFFICIENT_BALANCE';
            end if;
        end if;

        if v_source_account is null then
            raise exception using errcode='23503', message='SALE_REFUND_SOURCE_ACCOUNT_MISSING';
        end if;

        if v_payment_method <> 'CREDIT' then
            select mm.id
            into v_original_money
            from public.money_movements mm
            where mm.business_id = v_business
              and mm.source_type = 'SALE'
              and mm.source_ref = v_sale.invoice_number
              and mm.reason_code = 'SALE_PAYMENT'
            order by mm.created_at
            limit 1;
        end if;

        v_payout_money := private.record_money_movement(
            v_business,
            v_actor,
            p_idempotency_key || ':PAYOUT',
            'REVERSAL',
            v_source_account,
            null,
            v_payout,
            'SALE_REFUND',
            v_refund::text,
            'SALE_REFUND_PAYOUT',
            p_reverses_movement_id => v_original_money
        );

        if v_refund_method = 'CASH' then
            insert into public.cash_transactions (
                business_id, location_id, shift_id, cashier_profile_id,
                transaction_type, amount, reference_type, reference_id, notes
            ) values (
                v_business, v_sale.location_id, v_shift, v_actor,
                'REFUND', v_payout, 'SALE_REFUND', v_refund,
                'Refund ' || v_sale.invoice_number || ': ' || btrim(p_reason)
            ) returning id into v_cash_tx;
        end if;
    end if;

    if v_receivable_cancel > 0 then
        select id into v_receivable_account
        from public.money_accounts
        where business_id = v_business
          and code = 'HUTANG_PELANGGAN'
          and active;

        if v_receivable_account is null then
            raise exception using errcode='23503', message='CUSTOMER_DEBT_ACCOUNT_MISSING';
        end if;

        v_debt_cancel_money := private.record_money_movement(
            v_business,
            v_actor,
            p_idempotency_key || ':DEBT_CANCEL',
            'REVERSAL',
            v_receivable_account,
            null,
            v_receivable_cancel,
            'SALE_REFUND',
            v_refund::text,
            'CUSTOMER_DEBT_REFUND_CANCEL',
            p_reverses_movement_id => v_debt.receivable_movement_id
        );
    end if;

    insert into public.sale_refunds (
        id, business_id, sale_id, original_payment_method,
        stock_disposition, refund_method, sale_total,
        payout_amount, receivable_cancelled_amount,
        inventory_movement_id, payout_money_movement_id,
        debt_cancel_movement_id, shift_id, cash_transaction_id,
        actor_profile_id, reason
    ) values (
        v_refund, v_business, v_sale.id, v_payment_method,
        v_stock_disposition, v_refund_method, v_sale.total_amount,
        v_payout, v_receivable_cancel,
        v_inventory_movement, v_payout_money,
        v_debt_cancel_money, v_shift, v_cash_tx,
        v_actor, btrim(p_reason)
    );

    v_receipt := private.record_operation_success(
        v_business,
        p_idempotency_key,
        'SALE_REFUND',
        v_payload_hash,
        'SALE_REFUND',
        v_refund,
        v_actor
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor, v_receipt,
        'SALE_REFUNDED', 'SALE_REFUND', v_refund,
        jsonb_build_object(
            'sale_id', v_sale.id,
            'invoice_number', v_sale.invoice_number,
            'original_payment_method', v_payment_method,
            'refund_method', v_refund_method,
            'stock_disposition', v_stock_disposition,
            'sale_total', v_sale.total_amount,
            'payout_amount', v_payout,
            'receivable_cancelled_amount', v_receivable_cancel,
            'inventory_movement_id', v_inventory_movement,
            'payout_money_movement_id', v_payout_money,
            'debt_cancel_movement_id', v_debt_cancel_money,
            'cash_transaction_id', v_cash_tx
        )
    );

    return jsonb_build_object(
        'refund_id', v_refund,
        'sale_id', v_sale.id,
        'payout_amount', v_payout,
        'receivable_cancelled_amount', v_receivable_cancel,
        'stock_disposition', v_stock_disposition,
        'refund_method', v_refund_method,
        'already_posted', false
    );
end;
$$;
create or replace function public.correct_sale(
    p_sale_id uuid,
    p_reason text,
    p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_sale public.sales%rowtype;
    v_payment_method text;
    v_payment_amount numeric(18,2);
    v_payment_count integer;
    v_correction uuid;
    v_payload_hash text;
    v_lock record;
    v_receipt uuid;
    v_original_inventory uuid;
    v_inventory_lines jsonb;
    v_inventory_reversal uuid;
    v_original_money uuid;
    v_original_account uuid;
    v_money_reversal uuid;
    v_debt public.customer_debts%rowtype;
    v_paid numeric(18,2) := 0;
    v_cash_adjustment uuid;
begin
    v_authority := public.get_my_authority();
    v_business := (v_authority ->> 'business_id')::uuid;
    v_actor := (v_authority ->> 'profile_id')::uuid;

    if v_business is null or v_actor is null
       or not (
           coalesce((v_authority ->> 'owner')::boolean,false)
           or private.has_permission(v_business,'CORRECTION_LIMITED')
       ) then
        raise exception using errcode='42501', message='CORRECTION_LIMITED_REQUIRED';
    end if;

    if p_reason is null or length(btrim(p_reason)) = 0 then
        raise exception using errcode='22023', message='SALE_CORRECTION_REASON_REQUIRED';
    end if;

    select * into v_sale
    from public.sales
    where id=p_sale_id and business_id=v_business
    for update;

    if not found then
        raise exception using errcode='23503', message='SALE_NOT_FOUND';
    end if;

    if v_sale.status <> 'COMPLETED' then
        raise exception using errcode='23514', message='SALE_NOT_CORRECTABLE';
    end if;

    if v_sale.shift_id is null or not exists (
        select 1 from public.shifts sh
        where sh.id=v_sale.shift_id
          and sh.business_id=v_business
          and sh.status='OPEN'
    ) then
        raise exception using errcode='23514', message='SALE_CORRECTION_SHIFT_CLOSED_UNSUPPORTED';
    end if;

    select count(*), min(method), coalesce(sum(amount),0)::numeric(18,2)
    into v_payment_count,v_payment_method,v_payment_amount
    from public.payments
    where sale_id=v_sale.id and status='PAID';

    if v_payment_count <> 1 or v_payment_amount <> v_sale.total_amount then
        raise exception using errcode='23514', message='SALE_CORRECTION_PAYMENT_SHAPE_UNSUPPORTED';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'sale_id',v_sale.id,
            'reason',btrim(p_reason)
        )
    );

    select * into v_lock
    from private.lock_operation(
        v_business,p_idempotency_key,'SALE_CORRECTION',v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'SALE_CORRECTION' or v_lock.result_id is null then
            raise exception using errcode='23505', message='SJ_IDEMPOTENCY_CONFLICT';
        end if;

        return (
            select jsonb_build_object(
                'correction_id',c.id,
                'sale_id',c.sale_id,
                'inventory_reversal_movement_id',c.inventory_reversal_movement_id,
                'money_reversal_movement_id',c.money_reversal_movement_id,
                'cash_adjustment_transaction_id',c.cash_adjustment_transaction_id,
                'already_posted',true
            )
            from public.sale_corrections c
            where c.id=v_lock.result_id
        );
    end if;

    if exists (
        select 1 from public.sale_refunds r
        where r.business_id=v_business and r.sale_id=v_sale.id
    ) then
        raise exception using errcode='23505', message='SALE_ALREADY_REFUNDED';
    end if;

    if exists (
        select 1 from public.sale_corrections c
        where c.business_id=v_business and c.sale_id=v_sale.id
    ) then
        raise exception using errcode='23505', message='SALE_ALREADY_CORRECTED';
    end if;

    if v_payment_method='CREDIT' then
        select * into v_debt
        from public.customer_debts
        where business_id=v_business and sale_id=v_sale.id
        for update;

        if not found then
            raise exception using errcode='23503', message='CUSTOMER_DEBT_NOT_FOUND';
        end if;

        select coalesce(sum(amount),0)::numeric(18,2)
        into v_paid
        from public.customer_debt_payments
        where debt_id=v_debt.id;

        if v_paid > 0 then
            raise exception using errcode='23514', message='SALE_CORRECTION_PAID_DEBT_UNSUPPORTED';
        end if;
    end if;

    v_correction := gen_random_uuid();

    select m.id
    into v_original_inventory
    from public.inventory_movements m
    where m.business_id=v_business
      and m.source_type='SALE'
      and m.source_ref=v_sale.invoice_number
    order by m.created_at
    limit 1;

    if v_original_inventory is not null then
        select jsonb_agg(
            jsonb_build_object(
                'line_no',line.line_no,
                'stock_item_id',line.stock_item_id,
                'location_id',line.location_id,
                'quantity_delta',line.quantity_delta * -1
            )
            order by line.line_no
        )
        into v_inventory_lines
        from public.inventory_movement_lines line
        where line.movement_id=v_original_inventory;

        v_inventory_reversal := private.record_inventory_movement(
            v_business,
            v_actor,
            p_idempotency_key || ':INVENTORY',
            'CORRECTION',
            'SALE_CORRECTION',
            v_correction::text,
            'SALE_CORRECTION_REVERSAL',
            v_inventory_lines,
            p_reverses_movement_id => v_original_inventory
        );
    end if;

    if v_sale.total_amount > 0 then
        if v_payment_method='CREDIT' then
            v_original_money := v_debt.receivable_movement_id;
        else
            select mm.id
            into v_original_money
            from public.money_movements mm
            where mm.business_id=v_business
              and mm.source_type='SALE'
              and mm.source_ref=v_sale.invoice_number
              and mm.reason_code='SALE_PAYMENT'
            order by mm.created_at
            limit 1;
        end if;

        if v_original_money is null then
            raise exception using errcode='23503', message='SALE_CORRECTION_MONEY_MOVEMENT_MISSING';
        end if;

        select mm.to_account_id
        into v_original_account
        from public.money_movements mm
        where mm.id=v_original_money
          and mm.business_id=v_business;

        if v_original_account is null then
            raise exception using errcode='23503', message='SALE_CORRECTION_MONEY_ACCOUNT_MISSING';
        end if;

        if v_payment_method <> 'CREDIT'
           and private.finance_account_balance(v_business,v_original_account) < v_sale.total_amount then
            raise exception using errcode='23514', message='SALE_CORRECTION_ACCOUNT_BALANCE_INSUFFICIENT';
        end if;

        v_money_reversal := private.record_money_movement(
            v_business,
            v_actor,
            p_idempotency_key || ':MONEY',
            'REVERSAL',
            v_original_account,
            null,
            v_sale.total_amount,
            'SALE_CORRECTION',
            v_correction::text,
            'SALE_CORRECTION_REVERSAL',
            p_reverses_movement_id => v_original_money
        );

        if v_payment_method='CASH' then
            if v_sale.shift_id is null then
                raise exception using errcode='23503', message='SALE_CORRECTION_CASH_SHIFT_MISSING';
            end if;

            insert into public.cash_transactions(
                business_id,location_id,shift_id,cashier_profile_id,
                transaction_type,amount,reference_type,reference_id,notes
            ) values (
                v_business,v_sale.location_id,v_sale.shift_id,v_actor,
                'ADJUSTMENT',v_sale.total_amount * -1,'SALE_CORRECTION',v_correction,
                'Koreksi ' || v_sale.invoice_number || ': ' || btrim(p_reason)
            )
            returning id into v_cash_adjustment;
        end if;

    else
        v_original_money := null;
        v_money_reversal := null;
        v_cash_adjustment := null;
    end if;

    insert into public.sale_corrections(
        id,business_id,sale_id,original_payment_method,sale_total,
        inventory_reversal_movement_id,money_reversal_movement_id,
        cash_adjustment_transaction_id,actor_profile_id,reason
    ) values (
        v_correction,v_business,v_sale.id,v_payment_method,v_sale.total_amount,
        v_inventory_reversal,v_money_reversal,
        v_cash_adjustment,v_actor,btrim(p_reason)
    );

    v_receipt := private.record_operation_success(
        v_business,p_idempotency_key,'SALE_CORRECTION',v_payload_hash,
        'SALE_CORRECTION',v_correction,v_actor
    );

    insert into public.audit_events(
        business_id,actor_profile_id,operation_receipt_id,
        event_type,entity_type,entity_id,metadata
    ) values (
        v_business,v_actor,v_receipt,
        'SALE_CORRECTED','SALE_CORRECTION',v_correction,
        jsonb_build_object(
            'sale_id',v_sale.id,
            'invoice_number',v_sale.invoice_number,
            'original_payment_method',v_payment_method,
            'sale_total',v_sale.total_amount,
            'inventory_reversal_movement_id',v_inventory_reversal,
            'money_reversal_movement_id',v_money_reversal,
            'cash_adjustment_transaction_id',v_cash_adjustment
        )
    );

    return jsonb_build_object(
        'correction_id',v_correction,
        'sale_id',v_sale.id,
        'inventory_reversal_movement_id',v_inventory_reversal,
        'money_reversal_movement_id',v_money_reversal,
        'cash_adjustment_transaction_id',v_cash_adjustment,
        'already_posted',false
    );
end;
$$;
create or replace view private.sale_line_read_projection
with (security_invoker = true)
as
select
    li.sale_id,
    li.line_no,
    li.stock_item_id,
    li.sale_product_id,
    li.variant_id,
    coalesce(li.product_code_snapshot, si.code) as code,
    coalesce(li.product_name_snapshot, si.display_name) as display_name,
    li.variant_code_snapshot as variant_code,
    li.variant_name_snapshot as variant_name,
    li.fulfillment_mode_snapshot as fulfillment_mode,
    coalesce(sp.category_code, si.sale_category) as category_code,
    case
        when li.variant_id is not null then 'VARIANT:' || li.variant_id::text
        else 'STOCK:' || li.stock_item_id::text
    end as product_key,
    li.quantity,
    li.unit_price,
    li.subtotal,
    li.line_note
from public.sale_items li
left join public.stock_items si on si.id=li.stock_item_id
left join public.sale_products sp on sp.id=li.sale_product_id
where coalesce(li.product_code_snapshot,si.code) is not null
  and coalesce(li.product_name_snapshot,si.display_name) is not null;

revoke all on table private.sale_line_read_projection
from public, anon, authenticated, service_role;
create or replace function public.transaction_history_search(
    p_date_from date default null,
    p_date_to date default null,
    p_invoice_number text default null,
    p_product text default null,
    p_user text default null,
    p_payment_method text default null,
    p_amount_min numeric default null,
    p_amount_max numeric default null,
    p_status text default null,
    p_limit integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_profile uuid;
    v_permissions jsonb;
    v_owner boolean;
    v_can_all boolean;
    v_can_own boolean;
    v_payment_method text;
    v_status text;
    v_limit integer;
begin
    v_authority := public.get_my_authority();
    v_business := (v_authority ->> 'business_id')::uuid;
    v_profile := (v_authority ->> 'profile_id')::uuid;
    v_permissions := coalesce(v_authority -> 'permissions','[]'::jsonb);
    v_owner := coalesce((v_authority ->> 'owner')::boolean,false);
    v_can_all := v_owner or (v_permissions ? 'HISTORY_ALL');
    v_can_own := v_can_all or (v_permissions ? 'HISTORY_OWN');

    if v_business is null or v_profile is null or not v_can_own then
        raise exception using errcode='42501', message='HISTORY_READ_REQUIRED';
    end if;

    if p_date_from is not null and p_date_to is not null and p_date_from > p_date_to then
        raise exception using errcode='22023', message='HISTORY_DATE_RANGE_INVALID';
    end if;
    if p_amount_min is not null and p_amount_min < 0 then
        raise exception using errcode='22023', message='HISTORY_AMOUNT_INVALID';
    end if;
    if p_amount_max is not null and p_amount_max < 0 then
        raise exception using errcode='22023', message='HISTORY_AMOUNT_INVALID';
    end if;
    if p_amount_min is not null and p_amount_max is not null and p_amount_min > p_amount_max then
        raise exception using errcode='22023', message='HISTORY_AMOUNT_RANGE_INVALID';
    end if;

    v_payment_method := nullif(upper(btrim(coalesce(p_payment_method,''))),'');
    if v_payment_method is not null
       and v_payment_method not in ('CASH','QRIS','TRANSFER','CREDIT') then
        raise exception using errcode='22023', message='HISTORY_PAYMENT_METHOD_INVALID';
    end if;

    v_status := nullif(upper(btrim(coalesce(p_status,''))),'');
    if v_status is not null and v_status not in ('COMPLETED','VOID','REFUNDED','CORRECTED') then
        raise exception using errcode='22023', message='HISTORY_STATUS_INVALID';
    end if;

    v_limit := least(greatest(coalesce(p_limit,100),1),200);

    return coalesce((
        select jsonb_agg(q.payload order by q.created_at desc)
        from (
            select
                s.created_at,
                jsonb_build_object(
                    'sale_id', s.id,
                    'invoice_number', s.invoice_number,
                    'business_date', coalesce(sh.opened_at::date,s.created_at::date),
                    'created_at', s.created_at,
                    'status', case when correction.id is not null then 'CORRECTED' when refund.id is not null then 'REFUNDED' else s.status end,
                    'subtotal', s.subtotal,
                    'discount_amount', s.discount_amount,
                    'discount_type', s.discount_type,
                    'discount_value', s.discount_value,
                    'discount_reason', s.discount_reason,
                    'discount_approved_by', s.discount_approved_by,
                    'discount_approved_by_name', (
                        select p.display_name
                        from public.profiles p
                        where p.id=s.discount_approved_by
                    ),
                    'total_amount', s.total_amount,
                    'cashier_profile_id', s.cashier_profile_id,
                    'cashier_name', cashier.display_name,
                    'cashier_username', uli.normalized_username,
                    'customer_name', customer.display_name,
                    'location_name', loc.display_name,
                    'payment_method', (
                        select string_agg(pay.method, ', ' order by pay.created_at)
                        from public.payments pay where pay.sale_id=s.id
                    ),
                    'payments', coalesce((
                        select jsonb_agg(jsonb_build_object(
                            'method',pay.method,
                            'amount',pay.amount,
                            'tendered_amount',pay.tendered_amount,
                            'change_amount',pay.change_amount,
                            'status',pay.status,
                            'created_at',pay.created_at
                        ) order by pay.created_at)
                        from public.payments pay where pay.sale_id=s.id
                    ),'[]'::jsonb),
                    'items', coalesce((
                        select jsonb_agg(jsonb_build_object(
                            'line_no',line.line_no,
                            'stock_item_id',line.stock_item_id,
                            'sale_product_id',line.sale_product_id,
                            'variant_id',line.variant_id,
                            'code',line.code,
                            'display_name',line.display_name,
                            'variant_code',line.variant_code,
                            'variant_name',line.variant_name,
                            'fulfillment_mode',line.fulfillment_mode,
                            'category_code',line.category_code,
                            'line_note',line.line_note,
                            'quantity',line.quantity,
                            'unit_price',line.unit_price,
                            'subtotal',line.subtotal
                        ) order by line.line_no)
                        from private.sale_line_read_projection line
                        where line.sale_id=s.id
                    ),'[]'::jsonb),
                    'customer_debt', (
                        select jsonb_build_object(
                            'debt_id', db.debt_id,
                            'original_amount', db.original_amount,
                            'paid_amount', db.paid_amount,
                            'balance', db.balance,
                            'status', db.status
                        )
                        from public.customer_debt_balances db
                        where db.sale_id=s.id
                    ),
                    'refund', case when refund.id is null then null else jsonb_build_object(
                        'refund_id', refund.id,
                        'stock_disposition', refund.stock_disposition,
                        'refund_method', refund.refund_method,
                        'sale_total', refund.sale_total,
                        'payout_amount', refund.payout_amount,
                        'receivable_cancelled_amount', refund.receivable_cancelled_amount,
                        'reason', refund.reason,
                        'created_at', refund.created_at
                    ) end,
                    'correction', case when correction.id is null then null else jsonb_build_object(
                        'correction_id', correction.id,
                        'original_payment_method', correction.original_payment_method,
                        'sale_total', correction.sale_total,
                        'inventory_reversal_movement_id', correction.inventory_reversal_movement_id,
                        'money_reversal_movement_id', correction.money_reversal_movement_id,
                        'cash_adjustment_transaction_id', correction.cash_adjustment_transaction_id,
                        'reason', correction.reason,
                        'created_at', correction.created_at
                    ) end,
                    'note', s.note
                ) as payload
            from public.sales s
            join public.profiles cashier on cashier.id=s.cashier_profile_id
            left join public.user_login_identities uli on uli.profile_id=s.cashier_profile_id
            left join public.customers customer on customer.id=s.customer_id
            join public.locations loc on loc.id=s.location_id
            left join public.shifts sh on sh.id=s.shift_id
            left join public.sale_refunds refund on refund.sale_id=s.id
            left join public.sale_corrections correction on correction.sale_id=s.id
            where s.business_id=v_business
              and (v_can_all or s.cashier_profile_id=v_profile)
              and (p_date_from is null or coalesce(sh.opened_at::date,s.created_at::date) >= p_date_from)
              and (p_date_to is null or coalesce(sh.opened_at::date,s.created_at::date) <= p_date_to)
              and (
                  nullif(btrim(coalesce(p_invoice_number,'')),'') is null
                  or lower(s.invoice_number) like '%' || lower(btrim(p_invoice_number)) || '%'
              )
              and (
                  nullif(btrim(coalesce(p_product,'')),'') is null
                  or exists (
                      select 1
                      from private.sale_line_read_projection line
                      where line.sale_id=s.id
                        and (
                            lower(line.display_name) like '%' || lower(btrim(p_product)) || '%'
                            or lower(line.code) like '%' || lower(btrim(p_product)) || '%'
                            or lower(coalesce(line.variant_name,'')) like '%' || lower(btrim(p_product)) || '%'
                            or lower(coalesce(line.variant_code,'')) like '%' || lower(btrim(p_product)) || '%'
                        )
                  )
              )
              and (
                  nullif(btrim(coalesce(p_user,'')),'') is null
                  or lower(cashier.display_name) like '%' || lower(btrim(p_user)) || '%'
                  or lower(coalesce(uli.normalized_username,'')) like '%' || lower(btrim(p_user)) || '%'
              )
              and (
                  v_payment_method is null
                  or exists (
                      select 1 from public.payments pay
                      where pay.sale_id=s.id and pay.method=v_payment_method
                  )
              )
              and (p_amount_min is null or s.total_amount >= p_amount_min)
              and (p_amount_max is null or s.total_amount <= p_amount_max)
              and (
                  v_status is null
                  or case when correction.id is not null then 'CORRECTED' when refund.id is not null then 'REFUNDED' else s.status end = v_status
              )
            order by s.created_at desc
            limit v_limit
        ) q
    ),'[]'::jsonb);
end;
$$;
create or replace function public.checkout_sale_v2(
    p_operation_id uuid,
    p_location_id uuid,
    p_items jsonb,
    p_payment jsonb,
    p_discount jsonb,
    p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
    v_record jsonb;
    v_post jsonb;
    v_sale uuid;
    v_invoice text;
    v_subtotal numeric(18,2);
    v_discount_amount numeric(18,2);
    v_total_amount numeric(18,2);
    v_payment_method text;
    v_tendered_amount numeric(18,2);
    v_change_amount numeric(18,2);
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if v_business is null or v_actor is null then
        raise exception using errcode='42501', message='SJ_AUTHORITY_DENIED';
    end if;

    v_record := private.record_sale_v2(
        p_operation_id,v_business,p_location_id,p_items,p_payment,p_discount,p_note
    );

    v_sale := coalesce(
        nullif(v_record ->> 'sale_id','')::uuid,
        nullif(v_record ->> 'result_id','')::uuid
    );

    if v_sale is null then
        raise exception using errcode='55000', message='SJ_SALE_RESULT_MISSING';
    end if;

    v_post := private.post_sale_transaction(v_business,v_actor,v_sale);

    select s.invoice_number,s.subtotal,s.discount_amount,s.total_amount,
           p.method,p.tendered_amount,p.change_amount
    into v_invoice,v_subtotal,v_discount_amount,v_total_amount,
         v_payment_method,v_tendered_amount,v_change_amount
    from public.sales s
    join public.payments p on p.sale_id=s.id and p.status='PAID'
    where s.id=v_sale
    limit 1;

    return jsonb_build_object(
        'success',true,
        'sale_id',v_sale,
        'invoice_number',v_invoice,
        'subtotal',v_subtotal,
        'discount_amount',v_discount_amount,
        'total_amount',v_total_amount,
        'payment_method',v_payment_method,
        'tendered_amount',v_tendered_amount,
        'change_amount',v_change_amount,
        'customer_debt_id',v_post ->> 'customer_debt_id',
        'inventory_basis',v_post ->> 'inventory_basis',
        'already_posted',coalesce((v_post ->> 'already_posted')::boolean,false)
    );
end;
$$;

revoke execute on function public.checkout_sale_v2(uuid,uuid,jsonb,jsonb,jsonb,text)
from public, anon, authenticated, service_role;
grant execute on function public.checkout_sale_v2(uuid,uuid,jsonb,jsonb,jsonb,text)
to authenticated;

create or replace function public.checkout_sale_v2(
    p_operation_id uuid,
    p_location_id uuid,
    p_items jsonb,
    p_payment jsonb,
    p_note text default null
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
    select public.checkout_sale_v2(
        p_operation_id,
        p_location_id,
        p_items,
        case
            when upper(btrim(coalesce(p_payment ->> 'method','')))='CASH'
                 and not (p_payment ? 'tendered_amount')
                then p_payment || jsonb_build_object(
                    'tendered_amount',
                    coalesce((p_payment ->> 'amount')::numeric,0)
                )
            else p_payment
        end,
        null::jsonb,
        p_note
    );
$$;

revoke execute on function public.checkout_sale_v2(uuid,uuid,jsonb,jsonb,text)
from public, anon, authenticated, service_role;
grant execute on function public.checkout_sale_v2(uuid,uuid,jsonb,jsonb,text)
to authenticated;


revoke execute on function private.post_sale_transaction(uuid,uuid,uuid)
from public, anon, authenticated, service_role;

revoke execute on function public.refund_sale(uuid,text,text,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.refund_sale(uuid,text,text,text,text) to authenticated;

revoke execute on function public.correct_sale(uuid,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.correct_sale(uuid,text,text) to authenticated;

revoke execute on function public.transaction_history_search(date,date,text,text,text,text,numeric,numeric,text,integer)
from public, anon, authenticated, service_role;
grant execute on function public.transaction_history_search(date,date,text,text,text,text,numeric,numeric,text,integer)
to authenticated;

comment on column public.sales.discount_type is 'Immutable sale-level discount type: NONE, AMOUNT, or PERCENT.';
comment on column public.payments.tendered_amount is 'Cash presented by customer. Null for legacy cash facts and non-cash payments.';
comment on column public.payments.change_amount is 'Cash change returned. Revenue remains payments.amount / sales.total_amount.';
comment on column public.sale_items.line_note is 'Immutable optional item note captured at sale time.';
