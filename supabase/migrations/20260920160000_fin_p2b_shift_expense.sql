-- FIN-P2B: Shift Expense Fact + CASH sale account alignment.

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
                        then 'KAS_SHIFT'

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



-- FIN-P2B business expense authority.

create table public.business_expenses (
    id uuid primary key,
    business_id uuid not null references public.businesses(id) on delete restrict,
    location_id uuid not null references public.locations(id) on delete restrict,
    shift_id uuid not null references public.shifts(id) on delete restrict,
    actor_profile_id uuid not null references public.profiles(id) on delete restrict,
    amount numeric(18, 2) not null check (amount > 0),
    category_code text not null check (length(btrim(category_code)) > 0),
    description text not null check (length(btrim(description)) > 0),
    funding_account_id uuid not null references public.money_accounts(id) on delete restrict,
    approval_state text not null default 'NOT_REQUIRED'
        check (approval_state in ('NOT_REQUIRED', 'PENDING', 'APPROVED', 'REJECTED')),
    money_movement_id uuid not null unique references public.money_movements(id) on delete restrict,
    cash_transaction_id uuid not null unique references public.cash_transactions(id) on delete restrict,
    created_at timestamptz not null default now()
);

create index business_expenses_business_created_idx on public.business_expenses(business_id, created_at desc);
create index business_expenses_shift_created_idx on public.business_expenses(shift_id, created_at desc);
create index business_expenses_actor_created_idx on public.business_expenses(actor_profile_id, created_at desc);

alter table public.business_expenses enable row level security;
revoke all on table public.business_expenses from public, anon, authenticated;
grant select on table public.business_expenses to authenticated;

create policy business_expenses_scope_read
on public.business_expenses
for select
to authenticated
using (
    private.is_owner(business_id)
    or (
        private.is_active_member(business_id)
        and actor_profile_id = private.current_profile_id()
        and exists (
            select 1 from public.shifts s
            where s.id = public.business_expenses.shift_id
              and s.business_id = public.business_expenses.business_id
              and s.cashier_profile_id = private.current_profile_id()
        )
    )
);

drop policy if exists cash_transactions_member_read on public.cash_transactions;
drop policy if exists cash_transactions_scope_read on public.cash_transactions;

create policy cash_transactions_scope_read
on public.cash_transactions
for select
to authenticated
using (
    private.is_owner(business_id)
    or (
        private.is_active_member(business_id)
        and exists (
            select 1 from public.shifts s
            where s.id = public.cash_transactions.shift_id
              and s.business_id = public.cash_transactions.business_id
              and s.cashier_profile_id = private.current_profile_id()
        )
    )
);

create or replace function private.guard_business_expense_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    raise exception using errcode = '55000', message = 'FINANCE_EXPENSE_IMMUTABLE';
end;
$$;

create trigger business_expenses_immutable
before update or delete on public.business_expenses
for each row execute function private.guard_business_expense_mutation();

revoke execute on function private.guard_business_expense_mutation()
from public, anon, authenticated, service_role;

create or replace function public.finance_post_shift_expense(
    p_category_code text,
    p_description text,
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
    v_shift uuid;
    v_location uuid;
    v_shift_cash uuid;
    v_expense uuid;
    v_money uuid;
    v_cash_tx uuid;
    v_payload_hash text;
    v_lock record;
    v_receipt uuid;
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if not private.has_permission(v_business, 'EXPENSE_SHIFT_CREATE') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if p_amount is null or p_amount <= 0 then
        raise exception using errcode = '22023', message = 'FINANCE_SHIFT_EXPENSE_AMOUNT_INVALID';
    end if;
    if p_category_code is null or length(btrim(p_category_code)) = 0 then
        raise exception using errcode = '22023', message = 'FINANCE_SHIFT_EXPENSE_CATEGORY_REQUIRED';
    end if;
    if p_description is null or length(btrim(p_description)) = 0 then
        raise exception using errcode = '22023', message = 'FINANCE_SHIFT_EXPENSE_DESCRIPTION_REQUIRED';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'actor', v_actor,
            'category_code', upper(btrim(p_category_code)),
            'description', btrim(p_description),
            'amount', p_amount
        )
    );

    select * into v_lock
    from private.lock_operation(v_business, p_idempotency_key, 'SHIFT_EXPENSE', v_payload_hash);

    if v_lock.replay then
        if v_lock.result_type <> 'BUSINESS_EXPENSE' or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;
        return v_lock.result_id;
    end if;

    select s.id, s.location_id
    into v_shift, v_location
    from public.shifts s
    where s.business_id = v_business
      and s.cashier_profile_id = v_actor
      and s.status = 'OPEN'
    for update;

    if v_shift is null then
        raise exception using errcode = '42501', message = 'SJ_SHIFT_NOT_OPEN';
    end if;

    select id into v_shift_cash
    from public.money_accounts
    where business_id = v_business and code = 'KAS_SHIFT' and active;

    if v_shift_cash is null then
        raise exception using errcode = '23503', message = 'FINANCE_SHIFT_ACCOUNT_MISSING';
    end if;

    if private.finance_account_balance(v_business, v_shift_cash) < p_amount then
        raise exception using errcode = '23514', message = 'FINANCE_SHIFT_CASH_INSUFFICIENT';
    end if;

    v_expense := gen_random_uuid();

    v_money := private.record_money_movement(
        v_business, v_actor, p_idempotency_key || ':MONEY', 'EXPENSE',
        v_shift_cash, null, p_amount, 'SHIFT_EXPENSE', v_expense::text,
        upper(btrim(p_category_code)), null
    );

    insert into public.cash_transactions (
        business_id, location_id, shift_id, cashier_profile_id,
        transaction_type, amount, reference_type, reference_id, notes
    ) values (
        v_business, v_location, v_shift, v_actor,
        'CASH_OUT', p_amount, 'BUSINESS_EXPENSE', v_expense, btrim(p_description)
    ) returning id into v_cash_tx;

    insert into public.business_expenses (
        id, business_id, location_id, shift_id, actor_profile_id,
        amount, category_code, description, funding_account_id,
        approval_state, money_movement_id, cash_transaction_id
    ) values (
        v_expense, v_business, v_location, v_shift, v_actor,
        p_amount, upper(btrim(p_category_code)), btrim(p_description), v_shift_cash,
        'NOT_REQUIRED', v_money, v_cash_tx
    );

    v_receipt := private.record_operation_success(
        v_business, p_idempotency_key, 'SHIFT_EXPENSE', v_payload_hash,
        'BUSINESS_EXPENSE', v_expense, v_actor
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor, v_receipt,
        'SHIFT_EXPENSE_CREATED', 'BUSINESS_EXPENSE', v_expense,
        jsonb_build_object(
            'shift_id', v_shift,
            'category_code', upper(btrim(p_category_code)),
            'amount', p_amount,
            'money_movement_id', v_money,
            'cash_transaction_id', v_cash_tx,
            'approval_state', 'NOT_REQUIRED'
        )
    );

    return v_expense;
end;
$$;

revoke execute on function public.finance_post_shift_expense(text, text, numeric, text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_post_shift_expense(text, text, numeric, text)
to authenticated;

create or replace function public.cs05_add_cash_movement(
    p_type text,
    p_amount numeric,
    p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
    raise exception using errcode = '55000', message = 'FINANCE_CASH_MOVEMENT_SOURCE_REQUIRED';
end;
$$;

revoke execute on function public.cs05_add_cash_movement(text, numeric, text)
from public, anon, authenticated, service_role;
grant execute on function public.cs05_add_cash_movement(text, numeric, text)
to authenticated;
