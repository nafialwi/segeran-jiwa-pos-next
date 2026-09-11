-- CS-04 SALE POSTING ENGINE
-- Segeran Jiwa POS Next
-- Transaction orchestration layer


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

    v_inventory_lines jsonb;
    v_payment jsonb;

    v_payload_hash text;
    v_replay record;

begin


    if p_business_id is null
       or p_sale_id is null then

        raise exception using
            errcode = '22023',
            message = 'SJ_SALE_REQUIRED';

    end if;


    select *
    into v_sale
    from public.sales
    where id = p_sale_id
      and business_id = p_business_id;


    if not found then

        raise exception using
            errcode = '23503',
            message = 'SJ_SALE_NOT_FOUND';

    end if;


    v_payload_hash :=
        private.payload_sha256(
            jsonb_build_object(
                'sale_id',
                p_sale_id
            )
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


    select jsonb_agg(
        jsonb_build_object(
            'line_no',
            line_no,

            'stock_item_id',
            stock_item_id,

            'location_id',
            v_sale.location_id,

            'quantity_delta',
            quantity * -1
        )
    )
    into v_inventory_lines

    from public.sale_items

    where sale_id = p_sale_id;



    if v_inventory_lines is null then

        raise exception using
            errcode = '22023',
            message = 'SJ_SALE_ITEMS_REQUIRED';

    end if;



    v_inventory_id :=
        private.record_inventory_movement(
            p_business_id,
            p_actor_profile_id,
            'SALE-INVENTORY-' || p_sale_id::text,
            'SALE',
            'SALE',
            v_sale.invoice_number,
            'SALE_CONSUMPTION',
            v_inventory_lines
        );



    select jsonb_build_object(
        'method',
        method,

        'amount',
        amount
    )

    into v_payment

    from public.payments

    where sale_id = p_sale_id

    limit 1;



    if v_payment is not null then

        declare
            v_account_id uuid;
            v_method text;
            v_amount numeric;
        begin

            v_method :=
                v_payment->>'method';

            if v_method not in ('CASH','QRIS','TRANSFER') then

                raise exception using
                    errcode = '22023',
                    message = 'SJ_PAYMENT_METHOD_UNSUPPORTED';

            end if;

            v_amount :=
                (v_payment->>'amount')::numeric;


            select id
            into v_account_id
            from public.money_accounts
            where business_id = p_business_id
              and code =
                case
                    when v_method = 'CASH'
                        then 'KAS_UTAMA'

                    when v_method = 'QRIS'
                        then 'QRIS_BELUM_CAIR'

                    when v_method = 'TRANSFER'
                        then 'BANK'

                    else null
                end
            limit 1;


            if v_account_id is null then

                raise exception using
                    errcode = '23503',
                    message = 'SJ_PAYMENT_ACCOUNT_NOT_FOUND';

            end if;


            v_money_id :=
                private.record_money_movement(
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

        end;

    end if;



    v_receipt_id :=
        private.record_operation_success(
            p_business_id,
            'SALE-POSTING-' || p_sale_id::text,
            'SALE_POSTING',
            v_payload_hash,
            'SALE',
            p_sale_id,
            p_actor_profile_id
        );


    insert into public.audit_events
    (
        business_id,
        actor_profile_id,
        operation_receipt_id,
        event_type,
        entity_type,
        entity_id,
        metadata
    )

    values
    (
        p_business_id,
        p_actor_profile_id,
        v_receipt_id,
        'SALE_POSTED',
        'SALE',
        p_sale_id,
        jsonb_build_object(
            'inventory_movement_id',
            v_inventory_id,

            'money_movement_id',
            v_money_id,

            'receipt_id',
            v_receipt_id,

            'sale_id',
            p_sale_id,

            'invoice_number',
            v_sale.invoice_number
        )
    );



    return jsonb_build_object(

        'success',
        true,

        'sale_id',
        p_sale_id,

        'inventory_movement_id',
        v_inventory_id,

        'status',
        'POSTED'

    );


end;

$$;


revoke all
on function private.post_sale_transaction(uuid, uuid, uuid)
from public;


grant execute
on function private.post_sale_transaction(uuid, uuid, uuid)
to authenticated;

