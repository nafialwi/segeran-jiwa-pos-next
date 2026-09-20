-- HRR-P2: immutable full-sale Refund / Reversal authority.
-- Original sale/payment/debt/inventory/money facts remain untouched.

create table public.sale_refunds (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    sale_id uuid not null unique references public.sales(id) on delete restrict,
    original_payment_method text not null
        check (original_payment_method in ('CASH','QRIS','TRANSFER','CREDIT')),
    stock_disposition text not null
        check (stock_disposition in ('RETURN_TO_STOCK','DAMAGED_UNFIT','NO_GOODS_RETURNED')),
    refund_method text not null
        check (refund_method in ('CASH','TRANSFER','NONE')),
    sale_total numeric(18,2) not null check (sale_total >= 0),
    payout_amount numeric(18,2) not null check (payout_amount >= 0),
    receivable_cancelled_amount numeric(18,2) not null check (receivable_cancelled_amount >= 0),
    inventory_movement_id uuid unique references public.inventory_movements(id) on delete restrict,
    payout_money_movement_id uuid unique references public.money_movements(id) on delete restrict,
    debt_cancel_movement_id uuid unique references public.money_movements(id) on delete restrict,
    shift_id uuid references public.shifts(id) on delete restrict,
    cash_transaction_id uuid unique references public.cash_transactions(id) on delete restrict,
    actor_profile_id uuid not null references public.profiles(id) on delete restrict,
    reason text not null check (length(btrim(reason)) > 0),
    created_at timestamptz not null default now()
);

create index sale_refunds_business_created_idx
    on public.sale_refunds(business_id, created_at desc);
create index sale_refunds_actor_created_idx
    on public.sale_refunds(actor_profile_id, created_at desc);

create trigger sale_refunds_immutable
before update or delete on public.sale_refunds
for each row execute function private.prevent_fact_mutation();

alter table public.sale_refunds enable row level security;
revoke all on table public.sale_refunds from public, anon, authenticated;
grant select on table public.sale_refunds to authenticated;

create policy sale_refunds_authorized_read
on public.sale_refunds
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and (
        coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
        or private.has_permission(business_id, 'HISTORY_ALL')
        or private.has_permission(business_id, 'CUSTOMER_DEBT_MANAGE')
        or (
            private.has_permission(business_id, 'HISTORY_OWN')
            and exists (
                select 1
                from public.sales s
                where s.id = sale_refunds.sale_id
                  and s.business_id = sale_refunds.business_id
                  and s.cashier_profile_id = private.current_profile_id()
            )
        )
    )
);

create or replace view public.customer_debt_balances
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
    case
        when r.id is not null then 0::numeric(18,2)
        else (d.original_amount - coalesce(sum(p.amount),0))::numeric(18,2)
    end as balance,
    case
        when r.id is not null then 'REFUNDED'
        when coalesce(sum(p.amount),0) = 0 then 'OPEN'
        when coalesce(sum(p.amount),0) < d.original_amount then 'PARTIAL'
        else 'PAID'
    end as status,
    d.created_at
from public.customer_debts d
join public.customers c on c.id = d.customer_id
left join public.customer_debt_payments p on p.debt_id = d.id
left join public.sale_refunds r on r.sale_id = d.sale_id
group by
    d.id, d.business_id, d.customer_id, c.display_name,
    d.sale_id, d.original_amount, d.created_at, r.id;

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

        if v_refund_method not in ('CASH','TRANSFER') then
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

revoke execute on function public.refund_sale(uuid,text,text,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.refund_sale(uuid,text,text,text,text)
to authenticated;

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
    if v_status is not null and v_status not in ('COMPLETED','VOID','REFUNDED') then
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
                    'status', case when refund.id is not null then 'REFUNDED' else s.status end,
                    'subtotal', s.subtotal,
                    'discount_amount', s.discount_amount,
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
                            'status',pay.status,
                            'created_at',pay.created_at
                        ) order by pay.created_at)
                        from public.payments pay where pay.sale_id=s.id
                    ),'[]'::jsonb),
                    'items', coalesce((
                        select jsonb_agg(jsonb_build_object(
                            'line_no',line.line_no,
                            'stock_item_id',line.stock_item_id,
                            'code',item.code,
                            'display_name',item.display_name,
                            'quantity',line.quantity,
                            'unit_price',line.unit_price,
                            'subtotal',line.subtotal
                        ) order by line.line_no)
                        from public.sale_items line
                        join public.stock_items item on item.id=line.stock_item_id
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
                    'note', s.note
                ) as payload
            from public.sales s
            join public.profiles cashier on cashier.id=s.cashier_profile_id
            left join public.user_login_identities uli on uli.profile_id=s.cashier_profile_id
            left join public.customers customer on customer.id=s.customer_id
            join public.locations loc on loc.id=s.location_id
            left join public.shifts sh on sh.id=s.shift_id
            left join public.sale_refunds refund on refund.sale_id=s.id
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
                      from public.sale_items line
                      join public.stock_items item on item.id=line.stock_item_id
                      where line.sale_id=s.id
                        and (
                            lower(item.display_name) like '%' || lower(btrim(p_product)) || '%'
                            or lower(item.code) like '%' || lower(btrim(p_product)) || '%'
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
                  or case when refund.id is not null then 'REFUNDED' else s.status end = v_status
              )
            order by s.created_at desc
            limit v_limit
        ) q
    ),'[]'::jsonb);
end;
$$;
