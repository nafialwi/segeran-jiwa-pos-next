-- CS-04-SALES RPC FOUNDATION
-- Segeran Jiwa POS Next
-- Sales transaction orchestration layer


create sequence if not exists private.sale_invoice_sequence;


create or replace function private.generate_sale_invoice()
returns text
language plpgsql
security definer
set search_path = ''
as $$

declare
    v_number bigint;

begin

    v_number := nextval('private.sale_invoice_sequence');

    return
        'SJ-'
        || to_char(now(), 'YYYYMMDD')
        || '-'
        || lpad(v_number::text, 6, '0');

end;

$$;


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
    v_payment_method text;
    v_payment_amount numeric(18,2);

begin

    if not private.has_permission(
        p_business_id,
        'SALE_EXECUTE'
    ) then

        raise exception using
            errcode = '42501',
            message = 'SJ_PERMISSION_DENIED';

    end if;


    v_payload_hash :=
        private.payload_sha256(
            jsonb_build_object(
                'items', p_items,
                'payment', p_payment,
                'note', p_note
            )
        );


    select *
    into v_lock
    from private.lock_operation(
        p_business_id,
        p_operation_id::text,
        'SALE_CREATE',
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


    if p_items is null
       or jsonb_typeof(p_items) <> 'array'
       or jsonb_array_length(p_items) = 0 then

        raise exception using
            errcode = '22023',
            message = 'SJ_INVALID_ITEM';

    end if;


    for v_item in
        select value
        from jsonb_array_elements(p_items)

    loop

        v_line := v_line + 1;

    end loop;

    if v_payment_amount <= 0 then

        raise exception using
            errcode = '22023',
            message = 'SJ_PAYMENT_INVALID';

    end if;


    if v_payment_amount < v_subtotal
       and v_payment_method <> 'CREDIT' then

        raise exception using
            errcode = '22023',
            message = 'SJ_PAYMENT_INVALID';

    end if;


    v_line := 0;


    v_invoice :=
        private.generate_sale_invoice();


    insert into public.sales
    (
        business_id,
        location_id,
        invoice_number,
        cashier_profile_id,
        status,
        subtotal,
        discount_amount,
        total_amount,
        note
    )

    values

    (
        p_business_id,
        p_location_id,
        v_invoice,
        auth.uid(),
        'COMPLETED',
        v_subtotal,
        0,
        v_subtotal,
        p_note
    )

    returning id into v_sale_id;



    for v_item in
        select value
        from jsonb_array_elements(p_items)

    loop

        v_line := v_line + 1;

        insert into public.sale_items
        (
            sale_id,
            line_no,
            stock_item_id,
            quantity,
            unit_price,
            subtotal
        )

        values

        (
            v_sale_id,
            v_line,
            (v_item->>'stock_item_id')::uuid,
            (v_item->>'quantity')::numeric,
            (v_item->>'unit_price')::numeric,
            (
                (v_item->>'quantity')::numeric
                *
                (v_item->>'unit_price')::numeric
            )
        );

        v_subtotal :=
            v_subtotal
            +
            (
                (v_item->>'quantity')::numeric
                *
                (v_item->>'unit_price')::numeric
            );

    end loop;


    v_payment_method :=
        p_payment->>'method';


    v_payment_amount :=
        (p_payment->>'amount')::numeric;


    insert into public.payments
    (
        sale_id,
        method,
        amount,
        status,
        verified_by
    )

    values

    (
        v_sale_id,
        v_payment_method,
        v_payment_amount,
        'PAID',
        auth.uid()
    );

    perform private.record_operation_success(
        p_business_id,
        p_operation_id::text,
        'SALE_CREATE',
        v_payload_hash,
        'SALE',
        v_sale_id,
        auth.uid()
    );


    return jsonb_build_object(

        'success', true,

        'sale_id', v_sale_id,

        'invoice_number', v_invoice,

        'status', 'COMPLETED'

    );

end;

$$;


revoke all
on function private.record_sale(uuid, uuid, uuid, jsonb, jsonb, text)
from public;


grant execute
on function private.record_sale(uuid, uuid, uuid, jsonb, jsonb, text)
to authenticated;

