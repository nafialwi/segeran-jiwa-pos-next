-- FIN-P5: Supplier Payable Foundation
-- Canonical finance authority remains public.money_movements.

insert into public.money_accounts (
    business_id, code, display_name, account_type, active
)
select id, 'UTANG_PEMASOK', 'Utang Pemasok', 'OTHER', true
from public.businesses
on conflict (business_id, code) do update
set display_name = excluded.display_name,
    account_type = excluded.account_type,
    active = true;

create table public.supplier_payables (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    supplier_id uuid not null references public.suppliers(id) on delete restrict,
    purchase_order_id uuid not null references public.purchase_orders(id) on delete restrict,
    goods_receipt_id uuid not null unique references public.goods_receipts(id) on delete restrict,
    invoice_reference text,
    original_amount numeric(18,2) not null check (original_amount > 0),
    liability_movement_id uuid not null unique references public.money_movements(id) on delete restrict,
    created_by uuid not null references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now(),
    constraint supplier_payables_invoice_reference_nonempty
        check (invoice_reference is null or length(btrim(invoice_reference)) > 0)
);

create index supplier_payables_business_created_idx
    on public.supplier_payables(business_id, created_at desc);
create index supplier_payables_supplier_created_idx
    on public.supplier_payables(supplier_id, created_at desc);
create index supplier_payables_purchase_order_idx
    on public.supplier_payables(purchase_order_id);
create index supplier_payables_created_by_idx
    on public.supplier_payables(created_by);

create trigger supplier_payables_immutable
before update or delete on public.supplier_payables
for each row execute function private.prevent_fact_mutation();

alter table public.supplier_payables enable row level security;
revoke all on table public.supplier_payables from public, anon, authenticated;
grant select on table public.supplier_payables to authenticated;

create policy supplier_payables_authorized_read
on public.supplier_payables
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and (
        coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
        or (public.get_my_authority() -> 'permissions' ? 'PURCHASE_MANAGE')
    )
);

create table public.supplier_payable_payments (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    payable_id uuid not null references public.supplier_payables(id) on delete restrict,
    supplier_id uuid not null references public.suppliers(id) on delete restrict,
    actor_profile_id uuid not null references public.profiles(id) on delete restrict,
    source_account_id uuid not null references public.money_accounts(id) on delete restrict,
    amount numeric(18,2) not null check (amount > 0),
    money_movement_id uuid not null unique references public.money_movements(id) on delete restrict,
    created_at timestamptz not null default now()
);

create index supplier_payable_payments_business_created_idx
    on public.supplier_payable_payments(business_id, created_at desc);
create index supplier_payable_payments_payable_created_idx
    on public.supplier_payable_payments(payable_id, created_at desc);
create index supplier_payable_payments_supplier_created_idx
    on public.supplier_payable_payments(supplier_id, created_at desc);
create index supplier_payable_payments_actor_idx
    on public.supplier_payable_payments(actor_profile_id);
create index supplier_payable_payments_source_account_idx
    on public.supplier_payable_payments(source_account_id);

create trigger supplier_payable_payments_immutable
before update or delete on public.supplier_payable_payments
for each row execute function private.prevent_fact_mutation();

alter table public.supplier_payable_payments enable row level security;
revoke all on table public.supplier_payable_payments from public, anon, authenticated;
grant select on table public.supplier_payable_payments to authenticated;

create policy supplier_payable_payments_authorized_read
on public.supplier_payable_payments
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and (
        coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
        or (public.get_my_authority() -> 'permissions' ? 'PURCHASE_MANAGE')
    )
);

create view public.supplier_payable_balances
with (security_invoker = true)
as
select
    d.id as payable_id,
    d.business_id,
    d.supplier_id,
    s.display_name as supplier_name,
    d.purchase_order_id,
    d.goods_receipt_id,
    d.invoice_reference,
    d.original_amount,
    coalesce(sum(p.amount), 0)::numeric(18,2) as paid_amount,
    (d.original_amount - coalesce(sum(p.amount), 0))::numeric(18,2) as balance,
    case
        when coalesce(sum(p.amount), 0) = 0 then 'OPEN'
        when coalesce(sum(p.amount), 0) < d.original_amount then 'PARTIAL'
        else 'PAID'
    end as status,
    d.created_at
from public.supplier_payables d
join public.suppliers s on s.id = d.supplier_id
left join public.supplier_payable_payments p on p.payable_id = d.id
group by d.id, d.business_id, d.supplier_id, s.display_name,
         d.purchase_order_id, d.goods_receipt_id, d.invoice_reference,
         d.original_amount, d.created_at;

revoke all on table public.supplier_payable_balances from public, anon, authenticated;
grant select on table public.supplier_payable_balances to authenticated;

create or replace function public.finance_create_supplier_payable(
    p_goods_receipt_id uuid,
    p_amount numeric,
    p_invoice_reference text,
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
    v_gr public.goods_receipts%rowtype;
    v_po public.purchase_orders%rowtype;
    v_liability_account uuid;
    v_payable uuid;
    v_money uuid;
    v_payload_hash text;
    v_lock record;
    v_receipt uuid;
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'PURCHASE_MANAGE') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if p_amount is null or p_amount <= 0 then
        raise exception using errcode = '22023', message = 'SUPPLIER_PAYABLE_AMOUNT_INVALID';
    end if;

    if p_invoice_reference is not null
       and length(btrim(p_invoice_reference)) = 0 then
        raise exception using errcode = '22023', message = 'SUPPLIER_PAYABLE_INVOICE_REFERENCE_INVALID';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'goods_receipt_id', p_goods_receipt_id,
            'amount', p_amount,
            'invoice_reference', nullif(btrim(coalesce(p_invoice_reference,'')), '')
        )
    );

    select * into v_lock
    from private.lock_operation(
        v_business, p_idempotency_key, 'SUPPLIER_PAYABLE_CREATE', v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'SUPPLIER_PAYABLE'
           or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;
        return v_lock.result_id;
    end if;

    select * into v_gr
    from public.goods_receipts
    where id = p_goods_receipt_id
      and business_id = v_business
    for update;

    if not found then
        raise exception using errcode = '23503', message = 'SUPPLIER_PAYABLE_GRN_NOT_FOUND';
    end if;

    if v_gr.status <> 'POSTED' then
        raise exception using errcode = '22023', message = 'SUPPLIER_PAYABLE_GRN_NOT_POSTED';
    end if;

    select * into v_po
    from public.purchase_orders
    where id = v_gr.purchase_order_id
      and business_id = v_business;

    if not found then
        raise exception using errcode = '23503', message = 'SUPPLIER_PAYABLE_PO_NOT_FOUND';
    end if;

    if exists (
        select 1 from public.supplier_payables
        where goods_receipt_id = v_gr.id
    ) then
        raise exception using errcode = '23505', message = 'SUPPLIER_PAYABLE_GRN_ALREADY_LINKED';
    end if;

    select id into v_liability_account
    from public.money_accounts
    where business_id = v_business
      and code = 'UTANG_PEMASOK'
      and active;

    if v_liability_account is null then
        raise exception using errcode = '23503', message = 'SUPPLIER_PAYABLE_ACCOUNT_MISSING';
    end if;

    v_payable := gen_random_uuid();

    v_money := private.record_money_movement(
        v_business,
        v_actor,
        p_idempotency_key || ':LIABILITY',
        'ADJUSTMENT',
        v_liability_account,
        null,
        p_amount,
        'SUPPLIER_PAYABLE',
        v_payable::text,
        'SUPPLIER_INVOICE',
        null
    );

    insert into public.supplier_payables (
        id, business_id, supplier_id, purchase_order_id, goods_receipt_id,
        invoice_reference, original_amount, liability_movement_id, created_by
    ) values (
        v_payable, v_business, v_po.supplier_id, v_po.id, v_gr.id,
        nullif(btrim(coalesce(p_invoice_reference,'')), ''),
        p_amount, v_money, v_actor
    );

    v_receipt := private.record_operation_success(
        v_business, p_idempotency_key, 'SUPPLIER_PAYABLE_CREATE',
        v_payload_hash, 'SUPPLIER_PAYABLE', v_payable, v_actor
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor, v_receipt,
        'SUPPLIER_PAYABLE_CREATED', 'SUPPLIER_PAYABLE', v_payable,
        jsonb_build_object(
            'supplier_id', v_po.supplier_id,
            'purchase_order_id', v_po.id,
            'goods_receipt_id', v_gr.id,
            'amount', p_amount,
            'liability_movement_id', v_money
        )
    );

    return v_payable;
end;
$$;

revoke execute on function public.finance_create_supplier_payable(uuid,numeric,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_create_supplier_payable(uuid,numeric,text,text)
to authenticated;

create or replace function public.finance_pay_supplier_payable(
    p_payable_id uuid,
    p_source_account_id uuid,
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

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'PURCHASE_MANAGE') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if p_amount is null or p_amount <= 0 then
        raise exception using errcode = '22023', message = 'SUPPLIER_PAYABLE_PAYMENT_AMOUNT_INVALID';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'payable_id', p_payable_id,
            'source_account_id', p_source_account_id,
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

    select code into v_source_code
    from public.money_accounts
    where id = p_source_account_id
      and business_id = v_business
      and active;

    if v_source_code not in ('KAS_UTAMA','BANK') then
        raise exception using errcode = '22023', message = 'SUPPLIER_PAYABLE_PAYMENT_SOURCE_INVALID';
    end if;

    if v_source_code = 'BANK'
       and not private.has_permission(v_business, 'PAYMENT_TRANSFER') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if private.finance_account_balance(v_business, p_source_account_id) < p_amount then
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
        p_source_account_id,
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
        p_source_account_id, p_amount, v_money
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
            'source_account_id', p_source_account_id,
            'amount', p_amount,
            'money_movement_id', v_money
        )
    );

    return v_payment;
end;
$$;

revoke execute on function public.finance_pay_supplier_payable(uuid,uuid,numeric,text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_pay_supplier_payable(uuid,uuid,numeric,text)
to authenticated;
