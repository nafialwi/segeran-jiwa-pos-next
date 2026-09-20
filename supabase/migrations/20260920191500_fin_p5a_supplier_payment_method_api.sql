-- FIN-P5A: Supplier payable payment method API.
-- Clients choose a human payment method; the server resolves canonical accounts.

drop function if exists public.finance_pay_supplier_payable(uuid, uuid, numeric, text);

create or replace function public.finance_pay_supplier_payable(
    p_payable_id uuid,
    p_method text,
    p_amount numeric,
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
    v_payable public.supplier_payables%rowtype;
    v_method text;
    v_source_account uuid;
    v_source_code text;
    v_liability_account uuid;
    v_paid numeric(18,2);
    v_balance numeric(18,2);
    v_payment uuid;
    v_money uuid;
    v_payload_hash text;
    v_lock record;
    v_receipt uuid;
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();
    v_method := upper(btrim(coalesce(p_method, '')));

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'PURCHASE_MANAGE') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if p_amount is null or p_amount <= 0 then
        raise exception using errcode = '22023', message = 'SUPPLIER_PAYABLE_PAYMENT_AMOUNT_INVALID';
    end if;

    if v_method not in ('CASH', 'TRANSFER') then
        raise exception using errcode = '22023', message = 'SUPPLIER_PAYABLE_PAYMENT_METHOD_INVALID';
    end if;

    if v_method = 'TRANSFER'
       and not private.has_permission(v_business, 'PAYMENT_TRANSFER') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'payable_id', p_payable_id,
            'method', v_method,
            'amount', p_amount
        )
    );

    select * into v_lock
    from private.lock_operation(
        v_business, p_idempotency_key, 'SUPPLIER_PAYABLE_PAYMENT', v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'SUPPLIER_PAYABLE_PAYMENT'
           or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;
        return v_lock.result_id;
    end if;

    select * into v_payable
    from public.supplier_payables
    where id = p_payable_id
      and business_id = v_business
    for update;

    if not found then
        raise exception using errcode = '23503', message = 'SUPPLIER_PAYABLE_NOT_FOUND';
    end if;

    v_source_code := case
        when v_method = 'CASH' then 'KAS_UTAMA'
        when v_method = 'TRANSFER' then 'BANK'
    end;

    select id into v_source_account
    from public.money_accounts
    where business_id = v_business
      and code = v_source_code
      and active;

    if v_source_account is null then
        raise exception using errcode = '23503', message = 'SUPPLIER_PAYABLE_PAYMENT_SOURCE_MISSING';
    end if;

    if private.finance_account_balance(v_business, v_source_account) < p_amount then
        raise exception using errcode = '23514', message = 'FINANCE_INSUFFICIENT_BALANCE';
    end if;

    select coalesce(sum(amount),0)::numeric(18,2)
    into v_paid
    from public.supplier_payable_payments
    where payable_id = v_payable.id;

    v_balance := v_payable.original_amount - v_paid;

    if p_amount > v_balance then
        raise exception using errcode = '23514', message = 'SUPPLIER_PAYABLE_OVERPAYMENT';
    end if;

    select id into v_liability_account
    from public.money_accounts
    where business_id = v_business
      and code = 'UTANG_PEMASOK'
      and active;

    if v_liability_account is null then
        raise exception using errcode = '23503', message = 'SUPPLIER_PAYABLE_ACCOUNT_MISSING';
    end if;

    v_payment := gen_random_uuid();

    v_money := private.record_money_movement(
        v_business,
        v_actor,
        p_idempotency_key || ':MONEY',
        'TRANSFER',
        v_source_account,
        v_liability_account,
        p_amount,
        'SUPPLIER_PAYABLE_PAYMENT',
        v_payment::text,
        'SUPPLIER_PAYABLE_PAYMENT',
        null
    );

    insert into public.supplier_payable_payments (
        id, business_id, payable_id, supplier_id, actor_profile_id,
        source_account_id, amount, money_movement_id
    ) values (
        v_payment, v_business, v_payable.id, v_payable.supplier_id, v_actor,
        v_source_account, p_amount, v_money
    );

    v_receipt := private.record_operation_success(
        v_business, p_idempotency_key, 'SUPPLIER_PAYABLE_PAYMENT',
        v_payload_hash, 'SUPPLIER_PAYABLE_PAYMENT', v_payment, v_actor
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor, v_receipt,
        'SUPPLIER_PAYABLE_PAYMENT_CREATED', 'SUPPLIER_PAYABLE_PAYMENT', v_payment,
        jsonb_build_object(
            'payable_id', v_payable.id,
            'supplier_id', v_payable.supplier_id,
            'method', v_method,
            'source_account_code', v_source_code,
            'amount', p_amount,
            'money_movement_id', v_money
        )
    );

    return v_payment;
end;
$$;

revoke execute on function public.finance_pay_supplier_payable(uuid,text,numeric,text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_pay_supplier_payable(uuid,text,numeric,text)
to authenticated;
