-- FIN-P3: Customer Debt Foundation.
-- Customer debt originates from a sale; repayment is a transfer, never a new sale.

create table public.customers (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    display_name text not null check (length(btrim(display_name)) > 0),
    phone text,
    active boolean not null default true,
    created_by uuid not null references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index customers_business_name_idx
    on public.customers(business_id, display_name);
create index customers_created_by_idx
    on public.customers(created_by);

alter table public.customers enable row level security;
revoke all on table public.customers from public, anon, authenticated;
grant select on table public.customers to authenticated;

create policy customers_authorized_read
on public.customers
for select
to authenticated
using (
    private.is_owner(business_id)
    or private.has_permission(business_id, 'CUSTOMER_MANAGE')
    or private.has_permission(business_id, 'CUSTOMER_DEBT_MANAGE')
);

alter table public.sales
    add column customer_id uuid references public.customers(id) on delete restrict;

alter table public.sales
    add constraint sales_shift_id_fkey
    foreign key (shift_id) references public.shifts(id) on delete restrict;

create index sales_customer_id_idx on public.sales(customer_id);
create index sales_shift_id_idx on public.sales(shift_id);

insert into public.money_accounts (
    business_id, code, display_name, account_type, active
)
select id, 'HUTANG_PELANGGAN', 'Hutang Pelanggan', 'OTHER', true
from public.businesses
on conflict (business_id, code) do update
set display_name = excluded.display_name,
    account_type = excluded.account_type,
    active = true;

create table public.customer_debts (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    customer_id uuid not null references public.customers(id) on delete restrict,
    sale_id uuid not null unique references public.sales(id) on delete restrict,
    original_amount numeric(18,2) not null check (original_amount > 0),
    receivable_movement_id uuid not null unique references public.money_movements(id) on delete restrict,
    created_by uuid not null references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now()
);

create index customer_debts_business_created_idx
    on public.customer_debts(business_id, created_at desc);
create index customer_debts_customer_created_idx
    on public.customer_debts(customer_id, created_at desc);
create index customer_debts_created_by_idx
    on public.customer_debts(created_by);

create trigger customer_debts_immutable
before update or delete on public.customer_debts
for each row execute function private.prevent_fact_mutation();

alter table public.customer_debts enable row level security;
revoke all on table public.customer_debts from public, anon, authenticated;
grant select on table public.customer_debts to authenticated;

create policy customer_debts_authorized_read
on public.customer_debts
for select
to authenticated
using (
    private.is_owner(business_id)
    or private.has_permission(business_id, 'CUSTOMER_DEBT_MANAGE')
);

create table public.customer_debt_payments (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    debt_id uuid not null references public.customer_debts(id) on delete restrict,
    customer_id uuid not null references public.customers(id) on delete restrict,
    actor_profile_id uuid not null references public.profiles(id) on delete restrict,
    method text not null check (method in ('CASH', 'TRANSFER')),
    amount numeric(18,2) not null check (amount > 0),
    destination_account_id uuid not null references public.money_accounts(id) on delete restrict,
    shift_id uuid references public.shifts(id) on delete restrict,
    cash_transaction_id uuid unique references public.cash_transactions(id) on delete restrict,
    money_movement_id uuid not null unique references public.money_movements(id) on delete restrict,
    created_at timestamptz not null default now(),
    constraint customer_debt_payment_method_shape check (
        (method = 'CASH' and shift_id is not null and cash_transaction_id is not null)
        or
        (method = 'TRANSFER' and shift_id is null and cash_transaction_id is null)
    )
);

create index customer_debt_payments_business_created_idx
    on public.customer_debt_payments(business_id, created_at desc);
create index customer_debt_payments_debt_created_idx
    on public.customer_debt_payments(debt_id, created_at desc);
create index customer_debt_payments_customer_created_idx
    on public.customer_debt_payments(customer_id, created_at desc);
create index customer_debt_payments_actor_idx
    on public.customer_debt_payments(actor_profile_id);
create index customer_debt_payments_destination_idx
    on public.customer_debt_payments(destination_account_id);
create index customer_debt_payments_shift_idx
    on public.customer_debt_payments(shift_id)
    where shift_id is not null;

create trigger customer_debt_payments_immutable
before update or delete on public.customer_debt_payments
for each row execute function private.prevent_fact_mutation();

alter table public.customer_debt_payments enable row level security;
revoke all on table public.customer_debt_payments from public, anon, authenticated;
grant select on table public.customer_debt_payments to authenticated;

create policy customer_debt_payments_authorized_read
on public.customer_debt_payments
for select
to authenticated
using (
    private.is_owner(business_id)
    or private.has_permission(business_id, 'CUSTOMER_DEBT_MANAGE')
);

create view public.customer_debt_balances
with (security_invoker = true)
as
select
    d.id as debt_id,
    d.business_id,
    d.customer_id,
    c.display_name as customer_name,
    d.sale_id,
    d.original_amount,
    coalesce(sum(p.amount), 0)::numeric(18,2) as paid_amount,
    (d.original_amount - coalesce(sum(p.amount), 0))::numeric(18,2) as balance,
    case
        when coalesce(sum(p.amount), 0) = 0 then 'OPEN'
        when coalesce(sum(p.amount), 0) < d.original_amount then 'PARTIAL'
        else 'PAID'
    end as status,
    d.created_at
from public.customer_debts d
join public.customers c on c.id = d.customer_id
left join public.customer_debt_payments p on p.debt_id = d.id
group by d.id, d.business_id, d.customer_id, c.display_name, d.sale_id, d.original_amount, d.created_at;

revoke all on table public.customer_debt_balances from public, anon, authenticated;
grant select on table public.customer_debt_balances to authenticated;

create or replace function public.save_customer(
    p_display_name text,
    p_phone text default null,
    p_customer_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
    v_customer uuid;
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'CUSTOMER_MANAGE') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if p_display_name is null or length(btrim(p_display_name)) = 0 then
        raise exception using errcode = '22023', message = 'CUSTOMER_NAME_REQUIRED';
    end if;

    if p_customer_id is null then
        insert into public.customers (
            business_id, display_name, phone, created_by
        ) values (
            v_business, btrim(p_display_name), nullif(btrim(coalesce(p_phone,'')), ''), v_actor
        ) returning id into v_customer;

        insert into public.audit_events (
            business_id, actor_profile_id, event_type, entity_type, entity_id, metadata
        ) values (
            v_business, v_actor, 'CUSTOMER_CREATED', 'CUSTOMER', v_customer,
            jsonb_build_object('display_name', btrim(p_display_name))
        );
    else
        update public.customers
        set display_name = btrim(p_display_name),
            phone = nullif(btrim(coalesce(p_phone,'')), ''),
            updated_at = now()
        where id = p_customer_id
          and business_id = v_business
        returning id into v_customer;

        if v_customer is null then
            raise exception using errcode = '23503', message = 'CUSTOMER_NOT_FOUND';
        end if;

        insert into public.audit_events (
            business_id, actor_profile_id, event_type, entity_type, entity_id, metadata
        ) values (
            v_business, v_actor, 'CUSTOMER_UPDATED', 'CUSTOMER', v_customer,
            jsonb_build_object('display_name', btrim(p_display_name))
        );
    end if;

    return v_customer;
end;
$$;

revoke execute on function public.save_customer(text,text,uuid)
from public, anon, authenticated, service_role;
grant execute on function public.save_customer(text,text,uuid)
to authenticated;

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
    v_qty numeric;
    v_price numeric;
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

    for v_item in
        select value from jsonb_array_elements(p_items)
    loop
        if v_item->>'stock_item_id' is null
           or v_item->>'quantity' is null
           or v_item->>'unit_price' is null then
            raise exception using errcode = '22023', message = 'SJ_INVALID_ITEM';
        end if;

        v_qty := (v_item->>'quantity')::numeric;
        v_price := (v_item->>'unit_price')::numeric;

        if v_qty <= 0 or v_price < 0 then
            raise exception using errcode = '22023', message = 'SJ_INVALID_ITEM';
        end if;

        v_subtotal := v_subtotal + (v_qty * v_price);
    end loop;

    if v_subtotal <= 0 then
        raise exception using errcode = '22023', message = 'SJ_INVALID_ITEM';
    end if;

    v_payment_method := upper(btrim(coalesce(p_payment->>'method','')));

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
            v_customer := nullif(p_payment->>'customer_id','')::uuid;
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
            v_payment_amount := nullif(p_payment->>'amount','')::numeric;
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
            'items', p_items,
            'payment', p_payment,
            'note', p_note
        )
    );

    select * into v_lock
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
        select value from jsonb_array_elements(p_items)
    loop
        v_line := v_line + 1;
        v_qty := (v_item->>'quantity')::numeric;
        v_price := (v_item->>'unit_price')::numeric;

        insert into public.sale_items (
            sale_id, line_no, stock_item_id, quantity, unit_price, subtotal
        ) values (
            v_sale_id,
            v_line,
            (v_item->>'stock_item_id')::uuid,
            v_qty,
            v_price,
            v_qty * v_price
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
    v_payment jsonb;
    v_payload_hash text;
    v_replay record;
    v_account_id uuid;
    v_method text;
    v_amount numeric;
begin
    if p_business_id is null or p_sale_id is null or p_actor_profile_id is null then
        raise exception using errcode = '22023', message = 'SJ_SALE_REQUIRED';
    end if;

    select * into v_sale
    from public.sales
    where id = p_sale_id
      and business_id = p_business_id;

    if not found then
        raise exception using errcode = '23503', message = 'SJ_SALE_NOT_FOUND';
    end if;

    if v_sale.cashier_profile_id <> p_actor_profile_id
       or v_sale.shift_id is null
       or not exists (
            select 1 from public.shifts s
            where s.id = v_sale.shift_id
              and s.business_id = p_business_id
              and s.location_id = v_sale.location_id
              and s.cashier_profile_id = p_actor_profile_id
       ) then
        raise exception using errcode = '42501', message = 'SJ_SALE_ACTOR_SHIFT_MISMATCH';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object('sale_id', p_sale_id)
    );

    select * into v_replay
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
            'line_no', line_no,
            'stock_item_id', stock_item_id,
            'location_id', v_sale.location_id,
            'quantity_delta', quantity * -1
        )
    ) into v_inventory_lines
    from public.sale_items
    where sale_id = p_sale_id;

    if v_inventory_lines is null then
        raise exception using errcode = '22023', message = 'SJ_SALE_ITEMS_REQUIRED';
    end if;

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

    select jsonb_build_object('method', method, 'amount', amount)
    into v_payment
    from public.payments
    where sale_id = p_sale_id
    limit 1;

    if v_payment is null then
        raise exception using errcode = '22023', message = 'SJ_PAYMENT_REQUIRED';
    end if;

    v_method := v_payment->>'method';
    v_amount := (v_payment->>'amount')::numeric;

    if v_amount <> v_sale.total_amount then
        raise exception using errcode = '22023', message = 'SJ_PAYMENT_ALLOCATION_MISMATCH';
    end if;

    select id into v_account_id
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
        raise exception using errcode = '23503', message = 'SJ_PAYMENT_ACCOUNT_NOT_FOUND';
    end if;

    if v_method = 'CREDIT' then
        if v_sale.customer_id is null then
            raise exception using errcode = '23503', message = 'CUSTOMER_REQUIRED_FOR_DEBT';
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
            id, business_id, customer_id, sale_id, original_amount,
            receivable_movement_id, created_by
        ) values (
            v_debt_id, p_business_id, v_sale.customer_id, p_sale_id, v_amount,
            v_money_id, p_actor_profile_id
        );
    else
        if v_method not in ('CASH','QRIS','TRANSFER') then
            raise exception using errcode = '22023', message = 'SJ_PAYMENT_METHOD_UNSUPPORTED';
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
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        p_business_id,
        p_actor_profile_id,
        v_receipt_id,
        'SALE_POSTED',
        'SALE',
        p_sale_id,
        jsonb_build_object(
            'inventory_movement_id', v_inventory_id,
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
        'money_movement_id', v_money_id,
        'customer_debt_id', v_debt_id,
        'status', 'POSTED'
    );
end;
$$;

revoke execute on function private.record_sale(uuid,uuid,uuid,jsonb,jsonb,text)
from public, anon, authenticated, service_role;
revoke execute on function private.post_sale_transaction(uuid,uuid,uuid)
from public, anon, authenticated, service_role;

create or replace function public.checkout_sale(
    p_operation_id uuid,
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
    v_business uuid;
    v_actor uuid;
    v_record jsonb;
    v_post jsonb;
    v_sale uuid;
    v_invoice text;
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if v_business is null or v_actor is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    v_record := private.record_sale(
        p_operation_id, v_business, p_location_id, p_items, p_payment, p_note
    );

    v_sale := coalesce(
        nullif(v_record->>'sale_id','')::uuid,
        nullif(v_record->>'result_id','')::uuid
    );

    if v_sale is null then
        raise exception using errcode = '55000', message = 'SJ_SALE_RESULT_MISSING';
    end if;

    v_post := private.post_sale_transaction(v_business, v_actor, v_sale);

    select invoice_number into v_invoice from public.sales where id = v_sale;

    return jsonb_build_object(
        'success', true,
        'sale_id', v_sale,
        'invoice_number', v_invoice,
        'customer_debt_id', v_post->>'customer_debt_id',
        'already_posted', coalesce((v_post->>'already_posted')::boolean, false)
    );
end;
$$;

revoke execute on function public.checkout_sale(uuid,uuid,jsonb,jsonb,text)
from public, anon, authenticated, service_role;
grant execute on function public.checkout_sale(uuid,uuid,jsonb,jsonb,text)
to authenticated;

create or replace function public.finance_pay_customer_debt(
    p_debt_id uuid,
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
    v_debt public.customer_debts%rowtype;
    v_method text;
    v_paid numeric(18,2);
    v_balance numeric(18,2);
    v_receivable uuid;
    v_destination uuid;
    v_shift uuid;
    v_location uuid;
    v_payment uuid;
    v_money uuid;
    v_cash_tx uuid;
    v_payload_hash text;
    v_lock record;
    v_receipt uuid;
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();
    v_method := upper(btrim(coalesce(p_method,'')));

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'CUSTOMER_DEBT_MANAGE') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if p_amount is null or p_amount <= 0 then
        raise exception using errcode = '22023', message = 'CUSTOMER_DEBT_PAYMENT_AMOUNT_INVALID';
    end if;

    if v_method not in ('CASH','TRANSFER') then
        raise exception using errcode = '22023', message = 'CUSTOMER_DEBT_PAYMENT_METHOD_INVALID';
    end if;

    if v_method = 'TRANSFER'
       and not private.has_permission(v_business, 'PAYMENT_TRANSFER') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'actor', v_actor,
            'debt_id', p_debt_id,
            'method', v_method,
            'amount', p_amount
        )
    );

    select * into v_lock
    from private.lock_operation(
        v_business, p_idempotency_key, 'CUSTOMER_DEBT_PAYMENT', v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'CUSTOMER_DEBT_PAYMENT'
           or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;
        return v_lock.result_id;
    end if;

    select * into v_debt
    from public.customer_debts d
    where d.id = p_debt_id
      and d.business_id = v_business
    for update;

    if not found then
        raise exception using errcode = '23503', message = 'CUSTOMER_DEBT_NOT_FOUND';
    end if;

    select coalesce(sum(p.amount),0)::numeric(18,2)
    into v_paid
    from public.customer_debt_payments p
    where p.debt_id = v_debt.id;

    v_balance := v_debt.original_amount - v_paid;

    if p_amount > v_balance then
        raise exception using errcode = '23514', message = 'CUSTOMER_DEBT_OVERPAYMENT';
    end if;

    select id into v_receivable
    from public.money_accounts
    where business_id = v_business
      and code = 'HUTANG_PELANGGAN'
      and active;

    if v_receivable is null then
        raise exception using errcode = '23503', message = 'CUSTOMER_DEBT_ACCOUNT_MISSING';
    end if;

    if v_method = 'CASH' then
        select s.id, s.location_id
        into v_shift, v_location
        from public.shifts s
        where s.business_id = v_business
          and s.cashier_profile_id = v_actor
          and s.status = 'OPEN'
        limit 1
        for update;

        if v_shift is null then
            raise exception using errcode = '42501', message = 'SJ_SHIFT_NOT_OPEN';
        end if;

        select id into v_destination
        from public.money_accounts
        where business_id = v_business
          and code = 'KAS_SHIFT'
          and active;
    else
        select id into v_destination
        from public.money_accounts
        where business_id = v_business
          and code = 'BANK'
          and active;
    end if;

    if v_destination is null then
        raise exception using errcode = '23503', message = 'CUSTOMER_DEBT_DESTINATION_ACCOUNT_MISSING';
    end if;

    v_payment := gen_random_uuid();

    v_money := private.record_money_movement(
        v_business,
        v_actor,
        p_idempotency_key || ':MONEY',
        'TRANSFER',
        v_receivable,
        v_destination,
        p_amount,
        'CUSTOMER_DEBT_PAYMENT',
        v_payment::text,
        'CUSTOMER_DEBT_PAYMENT'
    );

    if v_method = 'CASH' then
        insert into public.cash_transactions (
            business_id, location_id, shift_id, cashier_profile_id,
            transaction_type, amount, reference_type, reference_id, notes
        ) values (
            v_business, v_location, v_shift, v_actor,
            'CASH_IN', p_amount, 'CUSTOMER_DEBT_PAYMENT', v_payment,
            'Pembayaran Hutang Pelanggan'
        ) returning id into v_cash_tx;
    end if;

    insert into public.customer_debt_payments (
        id, business_id, debt_id, customer_id, actor_profile_id,
        method, amount, destination_account_id, shift_id,
        cash_transaction_id, money_movement_id
    ) values (
        v_payment, v_business, v_debt.id, v_debt.customer_id, v_actor,
        v_method, p_amount, v_destination, v_shift,
        v_cash_tx, v_money
    );

    v_receipt := private.record_operation_success(
        v_business,
        p_idempotency_key,
        'CUSTOMER_DEBT_PAYMENT',
        v_payload_hash,
        'CUSTOMER_DEBT_PAYMENT',
        v_payment,
        v_actor
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor, v_receipt,
        'CUSTOMER_DEBT_PAYMENT_RECORDED',
        'CUSTOMER_DEBT_PAYMENT',
        v_payment,
        jsonb_build_object(
            'debt_id', v_debt.id,
            'customer_id', v_debt.customer_id,
            'method', v_method,
            'amount', p_amount,
            'money_movement_id', v_money,
            'cash_transaction_id', v_cash_tx
        )
    );

    return v_payment;
end;
$$;

revoke execute on function public.finance_pay_customer_debt(uuid,text,numeric,text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_pay_customer_debt(uuid,text,numeric,text)
to authenticated;
