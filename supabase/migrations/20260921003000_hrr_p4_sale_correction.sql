-- HRR-P4: distinct completed-sale Correction / Reversal authority.
-- Blueprint rule: Correction is not Refund. Original business facts remain immutable.

-- Cash correction is an accounting adjustment, not a customer refund.
-- Preserve strict positive amounts for every existing cash type; only ADJUSTMENT
-- may carry a signed non-zero value so expected-cash can represent corrections.
alter table public.cash_transactions
    drop constraint cash_transactions_amount_check;

alter table public.cash_transactions
    add constraint cash_transactions_amount_check
    check (
        (transaction_type = 'ADJUSTMENT' and amount <> 0)
        or
        (transaction_type <> 'ADJUSTMENT' and amount > 0)
    );

create table public.sale_corrections (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    sale_id uuid not null unique references public.sales(id) on delete restrict,
    original_payment_method text not null
        check (original_payment_method in ('CASH','QRIS','TRANSFER','CREDIT')),
    sale_total numeric(18,2) not null check (sale_total >= 0),
    inventory_reversal_movement_id uuid unique
        references public.inventory_movements(id) on delete restrict,
    money_reversal_movement_id uuid not null unique
        references public.money_movements(id) on delete restrict,
    cash_adjustment_transaction_id uuid unique
        references public.cash_transactions(id) on delete restrict,
    actor_profile_id uuid not null references public.profiles(id) on delete restrict,
    reason text not null check (length(btrim(reason)) > 0),
    created_at timestamptz not null default now()
);

create index sale_corrections_business_created_idx
    on public.sale_corrections(business_id, created_at desc);
create index sale_corrections_actor_created_idx
    on public.sale_corrections(actor_profile_id, created_at desc);

create trigger sale_corrections_immutable
before update or delete on public.sale_corrections
for each row execute function private.prevent_fact_mutation();

alter table public.sale_corrections enable row level security;
revoke all on table public.sale_corrections from public, anon, authenticated;
grant select on table public.sale_corrections to authenticated;

create policy sale_corrections_authorized_read
on public.sale_corrections
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and (
        coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
        or private.has_permission(business_id, 'CORRECTION_LIMITED')
        or private.has_permission(business_id, 'HISTORY_ALL')
        or (
            private.has_permission(business_id, 'HISTORY_OWN')
            and exists (
                select 1
                from public.sales s
                where s.id = sale_corrections.sale_id
                  and s.business_id = sale_corrections.business_id
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
        when correction.id is not null then 0::numeric(18,2)
        when refund.id is not null then 0::numeric(18,2)
        else (d.original_amount - coalesce(sum(p.amount),0))::numeric(18,2)
    end as balance,
    case
        when correction.id is not null then 'CORRECTED'
        when refund.id is not null then 'REFUNDED'
        when coalesce(sum(p.amount),0) = 0 then 'OPEN'
        when coalesce(sum(p.amount),0) < d.original_amount then 'PARTIAL'
        else 'PAID'
    end as status,
    d.created_at
from public.customer_debts d
join public.customers c on c.id = d.customer_id
left join public.customer_debt_payments p on p.debt_id = d.id
left join public.sale_refunds refund on refund.sale_id = d.sale_id
left join public.sale_corrections correction on correction.sale_id = d.sale_id
group by
    d.id, d.business_id, d.customer_id, c.display_name,
    d.sale_id, d.original_amount, d.created_at, refund.id, correction.id;

create or replace function public.sale_correction_preview(p_sale_id uuid)
returns jsonb
language plpgsql
stable
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
    v_debt public.customer_debts%rowtype;
    v_paid numeric(18,2) := 0;
    v_blocker text;
    v_tracked_lines integer := 0;
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

    select * into v_sale
    from public.sales
    where id=p_sale_id and business_id=v_business;

    if not found then
        raise exception using errcode='23503', message='SALE_NOT_FOUND';
    end if;

    select count(*), min(method), coalesce(sum(amount),0)::numeric(18,2)
    into v_payment_count,v_payment_method,v_payment_amount
    from public.payments
    where sale_id=v_sale.id and status='PAID';

    if v_sale.status <> 'COMPLETED' then
        v_blocker := 'SALE_NOT_CORRECTABLE';
    elsif exists (
        select 1 from public.sale_refunds r
        where r.business_id=v_business and r.sale_id=v_sale.id
    ) then
        v_blocker := 'SALE_ALREADY_REFUNDED';
    elsif exists (
        select 1 from public.sale_corrections c
        where c.business_id=v_business and c.sale_id=v_sale.id
    ) then
        v_blocker := 'SALE_ALREADY_CORRECTED';
    elsif v_payment_count <> 1 or v_payment_amount <> v_sale.total_amount then
        v_blocker := 'SALE_CORRECTION_PAYMENT_SHAPE_UNSUPPORTED';
    end if;

    if v_blocker is null and v_payment_method='CREDIT' then
        select * into v_debt
        from public.customer_debts
        where business_id=v_business and sale_id=v_sale.id;

        if not found then
            v_blocker := 'CUSTOMER_DEBT_NOT_FOUND';
        else
            select coalesce(sum(amount),0)::numeric(18,2)
            into v_paid
            from public.customer_debt_payments
            where debt_id=v_debt.id;

            if v_paid > 0 then
                v_blocker := 'SALE_CORRECTION_PAID_DEBT_UNSUPPORTED';
            end if;
        end if;
    end if;

    select count(*)
    into v_tracked_lines
    from public.sale_items line
    join public.stock_items item on item.id=line.stock_item_id
    where line.sale_id=v_sale.id and item.inventory_tracked;

    return jsonb_build_object(
        'sale_id',v_sale.id,
        'invoice_number',v_sale.invoice_number,
        'can_execute',v_blocker is null,
        'blocker',v_blocker,
        'payment_method',v_payment_method,
        'sale_total',v_sale.total_amount,
        'stock',jsonb_build_object(
            'tracked_lines',v_tracked_lines,
            'action','REVERSE_ORIGINAL_SALE_MOVEMENT'
        ),
        'cash_qris_transfer',case v_payment_method
            when 'CASH' then 'Reverse KAS_SHIFT income and add signed shift ADJUSTMENT'
            when 'QRIS' then 'Reverse QRIS_BELUM_CAIR recorded income'
            when 'TRANSFER' then 'Reverse BANK recorded income'
            else 'No cash/QRIS/transfer receipt'
        end,
        'debt',case
            when v_payment_method='CREDIT' and v_paid=0
                then 'Reverse unpaid customer receivable'
            when v_payment_method='CREDIT'
                then 'BLOCKED: existing debt payment cannot be silently reallocated'
            else 'No customer debt'
        end,
        'hpp',jsonb_build_object(
            'available',false,
            'message','Canonical historical HPP coverage is incomplete; no HPP value is fabricated.'
        ),
        'finance','Create canonical REVERSAL linked to the original sale money movement; this is not Refund and not business expense.'
    );
end;
$$;

revoke execute on function public.sale_correction_preview(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.sale_correction_preview(uuid)
to authenticated;

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

revoke execute on function public.correct_sale(uuid,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.correct_sale(uuid,text,text)
to authenticated;

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
                  or case when correction.id is not null then 'CORRECTED' when refund.id is not null then 'REFUNDED' else s.status end = v_status
              )
            order by s.created_at desc
            limit v_limit
        ) q
    ),'[]'::jsonb);
end;
$$;

create or replace function public.report_run(
    p_report_code text,
    p_date_from date default null,
    p_date_to date default null
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
    v_actor uuid;
    v_owner boolean;
    v_code text;
    v_from date;
    v_to date;
    v_business_name text;
    v_title text;
    v_summary jsonb := '[]'::jsonb;
    v_sections jsonb := '[]'::jsonb;
    v_warnings jsonb := '[]'::jsonb;
    v_rows jsonb;
    v_rows2 jsonb;
    v_rows3 jsonb;
    v_rows4 jsonb;
    v_rows5 jsonb;
    v_rows6 jsonb;
    v_gross numeric := 0;
    v_refunds numeric := 0;
    v_corrections numeric := 0;
    v_expenses numeric := 0;
    v_count bigint := 0;
    v_count2 bigint := 0;
    v_count3 bigint := 0;
    v_qty numeric := 0;
begin
    v_authority := public.get_my_authority();
    v_business := (v_authority ->> 'business_id')::uuid;
    v_actor := (v_authority ->> 'profile_id')::uuid;
    v_owner := coalesce((v_authority ->> 'owner')::boolean, false);
    v_code := upper(btrim(coalesce(p_report_code,'')));
    v_to := coalesce(p_date_to, current_date);
    v_from := coalesce(p_date_from, date_trunc('month', v_to::timestamp)::date);

    if v_business is null or v_actor is null then
        raise exception using errcode='42501', message='REPORT_AUTHORITY_REQUIRED';
    end if;

    if v_from > v_to then
        raise exception using errcode='22023', message='REPORT_DATE_RANGE_INVALID';
    end if;

    if v_code not in ('SALES','PRODUCT','INVENTORY','SHIFT','PURCHASE','FINANCE') then
        raise exception using errcode='22023', message='REPORT_CODE_INVALID';
    end if;

    if v_code in ('SALES','PRODUCT')
       and not (v_owner or private.has_permission(v_business,'REPORT_SALES_LIMITED')) then
        raise exception using errcode='42501', message='REPORT_PERMISSION_DENIED';
    elsif v_code = 'INVENTORY'
       and not (v_owner or private.has_permission(v_business,'REPORT_INVENTORY')) then
        raise exception using errcode='42501', message='REPORT_PERMISSION_DENIED';
    elsif v_code = 'PURCHASE'
       and not (v_owner or private.has_permission(v_business,'REPORT_PURCHASE')) then
        raise exception using errcode='42501', message='REPORT_PERMISSION_DENIED';
    elsif v_code in ('SHIFT','FINANCE') and not v_owner then
        raise exception using errcode='42501', message='REPORT_OWNER_REQUIRED';
    end if;

    select b.display_name into v_business_name
    from public.businesses b
    where b.id=v_business;

    if v_code = 'SALES' then
        v_title := 'Laporan Penjualan';

        select coalesce(sum(s.total_amount),0), count(*)
        into v_gross, v_count
        from public.sales s
        left join public.shifts sh on sh.id=s.shift_id
        where s.business_id=v_business
          and s.status <> 'VOID'
          and coalesce(sh.opened_at::date,s.created_at::date) between v_from and v_to;

        select coalesce(sum(r.sale_total),0), count(*)
        into v_refunds, v_count2
        from public.sale_refunds r
        where r.business_id=v_business
          and r.created_at::date between v_from and v_to;

        select coalesce(sum(c.sale_total),0), count(*)
        into v_corrections, v_count3
        from public.sale_corrections c
        where c.business_id=v_business
          and c.created_at::date between v_from and v_to;

        v_summary := jsonb_build_array(
            jsonb_build_object('label','Transaksi Penjualan','value',v_count,'format','number'),
            jsonb_build_object('label','Penjualan Bruto','value',v_gross,'format','money'),
            jsonb_build_object('label','Refund','value',v_refunds,'format','money'),
            jsonb_build_object('label','Koreksi','value',v_corrections,'format','money'),
            jsonb_build_object('label','Penjualan Bersih','value',v_gross-v_refunds-v_corrections,'format','money')
        );

        select coalesce(jsonb_agg(to_jsonb(x) order by x.event_at desc),'[]'::jsonb)
        into v_rows
        from (
            select
                'PENJUALAN'::text as jenis,
                s.invoice_number as nomor_transaksi,
                coalesce(sh.opened_at::date,s.created_at::date)::text as tanggal,
                s.created_at as event_at,
                cashier.display_name as pengguna,
                loc.display_name as lokasi,
                coalesce((select string_agg(p.method, ', ' order by p.created_at)
                          from public.payments p where p.sale_id=s.id),'—') as metode,
                s.total_amount as nominal,
                case when c.id is not null then 'CORRECTED' when r.id is not null then 'REFUNDED' else s.status end as status
            from public.sales s
            join public.profiles cashier on cashier.id=s.cashier_profile_id
            join public.locations loc on loc.id=s.location_id
            left join public.shifts sh on sh.id=s.shift_id
            left join public.sale_refunds r on r.sale_id=s.id
            left join public.sale_corrections c on c.sale_id=s.id
            where s.business_id=v_business
              and s.status <> 'VOID'
              and coalesce(sh.opened_at::date,s.created_at::date) between v_from and v_to
            union all
            select
                'REFUND'::text,
                s.invoice_number,
                r.created_at::date::text,
                r.created_at,
                actor.display_name,
                loc.display_name,
                r.refund_method,
                r.sale_total * -1,
                'REFUNDED'
            from public.sale_refunds r
            join public.sales s on s.id=r.sale_id
            join public.profiles actor on actor.id=r.actor_profile_id
            join public.locations loc on loc.id=s.location_id
            where r.business_id=v_business
              and r.created_at::date between v_from and v_to
            union all
            select
                'KOREKSI'::text,
                s.invoice_number,
                c.created_at::date::text,
                c.created_at,
                actor.display_name,
                loc.display_name,
                c.original_payment_method,
                c.sale_total * -1,
                'CORRECTED'
            from public.sale_corrections c
            join public.sales s on s.id=c.sale_id
            join public.profiles actor on actor.id=c.actor_profile_id
            join public.locations loc on loc.id=s.location_id
            where c.business_id=v_business
              and c.created_at::date between v_from and v_to
        ) x;

        with sold as (
            select
                li.stock_item_id,
                sum(li.quantity) sold_qty,
                sum(li.subtotal) gross_item_value
            from public.sale_items li
            join public.sales s on s.id=li.sale_id
            left join public.shifts sh on sh.id=s.shift_id
            where s.business_id=v_business
              and s.status <> 'VOID'
              and coalesce(sh.opened_at::date,s.created_at::date) between v_from and v_to
            group by li.stock_item_id
        ), refunded as (
            select
                li.stock_item_id,
                sum(li.quantity) refunded_qty,
                sum(li.subtotal) refunded_item_value
            from public.sale_refunds r
            join public.sale_items li on li.sale_id=r.sale_id
            where r.business_id=v_business
              and r.created_at::date between v_from and v_to
            group by li.stock_item_id
        ), corrected as (
            select
                li.stock_item_id,
                sum(li.quantity) corrected_qty,
                sum(li.subtotal) corrected_item_value
            from public.sale_corrections c
            join public.sale_items li on li.sale_id=c.sale_id
            where c.business_id=v_business
              and c.created_at::date between v_from and v_to
            group by li.stock_item_id
        )
        select coalesce(jsonb_agg(jsonb_build_object(
            'kode',si.code,
            'produk',si.display_name,
            'qty_terjual',coalesce(sold.sold_qty,0),
            'qty_refund',coalesce(refunded.refunded_qty,0),
            'qty_koreksi',coalesce(corrected.corrected_qty,0),
            'qty_bersih',coalesce(sold.sold_qty,0)-coalesce(refunded.refunded_qty,0)-coalesce(corrected.corrected_qty,0),
            'nilai_bruto_item',coalesce(sold.gross_item_value,0),
            'nilai_refund_item',coalesce(refunded.refunded_item_value,0),
            'nilai_koreksi_item',coalesce(corrected.corrected_item_value,0),
            'nilai_bersih_item',coalesce(sold.gross_item_value,0)-coalesce(refunded.refunded_item_value,0)-coalesce(corrected.corrected_item_value,0)
        ) order by (coalesce(sold.gross_item_value,0)-coalesce(refunded.refunded_item_value,0)-coalesce(corrected.corrected_item_value,0)) desc),'[]'::jsonb)
        into v_rows2
        from public.stock_items si
        left join sold on sold.stock_item_id=si.id
        left join refunded on refunded.stock_item_id=si.id
        left join corrected on corrected.stock_item_id=si.id
        where si.business_id=v_business
          and (sold.stock_item_id is not null or refunded.stock_item_id is not null or corrected.stock_item_id is not null);

        with paid as (
            select p.method, sum(p.amount) sales_amount
            from public.payments p
            join public.sales s on s.id=p.sale_id
            left join public.shifts sh on sh.id=s.shift_id
            where s.business_id=v_business
              and s.status <> 'VOID'
              and p.status='PAID'
              and coalesce(sh.opened_at::date,s.created_at::date) between v_from and v_to
            group by p.method
        ), returned as (
            select r.refund_method as method,
                   sum(r.payout_amount) refund_payout,
                   sum(r.receivable_cancelled_amount) receivable_cancelled
            from public.sale_refunds r
            where r.business_id=v_business
              and r.created_at::date between v_from and v_to
            group by r.refund_method
        ), corrected_payment as (
            select c.original_payment_method as method,
                   sum(c.sale_total) correction_total
            from public.sale_corrections c
            where c.business_id=v_business
              and c.created_at::date between v_from and v_to
            group by c.original_payment_method
        ), methods as (
            select method from paid
            union
            select method from returned
            union
            select method from corrected_payment
        )
        select coalesce(jsonb_agg(jsonb_build_object(
            'metode',m.method,
            'penerimaan_penjualan',coalesce(p.sales_amount,0),
            'pengembalian_dana',coalesce(r.refund_payout,0),
            'piutang_dibatalkan',coalesce(r.receivable_cancelled,0),
            'koreksi_pencatatan',coalesce(c.correction_total,0)
        ) order by m.method),'[]'::jsonb)
        into v_rows3
        from methods m
        left join paid p on p.method=m.method
        left join returned r on r.method=m.method
        left join corrected_payment c on c.method=m.method;

        v_sections := jsonb_build_array(
            jsonb_build_object(
                'key','transactions','title','Transaksi',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','jenis','label','Jenis','type','text','width',16),
                    jsonb_build_object('key','nomor_transaksi','label','Nomor Transaksi','type','text','width',22),
                    jsonb_build_object('key','tanggal','label','Tanggal','type','date','width',14),
                    jsonb_build_object('key','pengguna','label','Pengguna','type','text','width',20),
                    jsonb_build_object('key','lokasi','label','Lokasi','type','text','width',18),
                    jsonb_build_object('key','metode','label','Metode','type','text','width',16),
                    jsonb_build_object('key','nominal','label','Nominal','type','money','width',18),
                    jsonb_build_object('key','status','label','Status','type','text','width',14)
                ),
                'rows',v_rows,
                'totals',jsonb_build_array(
                    jsonb_build_object('label','Penjualan Bersih','value',v_gross-v_refunds-v_corrections,'format','money')
                )
            ),
            jsonb_build_object(
                'key','products','title','Produk',
                'note','Nilai item adalah nilai bruto baris sebelum diskon tingkat transaksi.',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','kode','label','Kode','type','text','width',22),
                    jsonb_build_object('key','produk','label','Produk','type','text','width',28),
                    jsonb_build_object('key','qty_terjual','label','Qty Terjual','type','number','width',14),
                    jsonb_build_object('key','qty_refund','label','Qty Refund','type','number','width',14),
                    jsonb_build_object('key','qty_koreksi','label','Qty Koreksi','type','number','width',14),
                    jsonb_build_object('key','qty_bersih','label','Qty Bersih','type','number','width',14),
                    jsonb_build_object('key','nilai_bruto_item','label','Nilai Bruto Item','type','money','width',18),
                    jsonb_build_object('key','nilai_refund_item','label','Nilai Refund Item','type','money','width',18),
                    jsonb_build_object('key','nilai_bersih_item','label','Nilai Bersih Item','type','money','width',18)
                ),
                'rows',v_rows2
            ),
            jsonb_build_object(
                'key','payments','title','Metode Pembayaran',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','metode','label','Metode','type','text','width',18),
                    jsonb_build_object('key','penerimaan_penjualan','label','Penerimaan Penjualan','type','money','width',22),
                    jsonb_build_object('key','pengembalian_dana','label','Pengembalian Dana','type','money','width',20),
                    jsonb_build_object('key','piutang_dibatalkan','label','Piutang Dibatalkan','type','money','width',20),
                    jsonb_build_object('key','koreksi_pencatatan','label','Koreksi Pencatatan','type','money','width',20)
                ),
                'rows',v_rows3
            )
        );

    elsif v_code = 'PRODUCT' then
        v_title := 'Laporan Produk';

        with sold as (
            select li.stock_item_id,sum(li.quantity) sold_qty,sum(li.subtotal) gross_value
            from public.sale_items li
            join public.sales s on s.id=li.sale_id
            left join public.shifts sh on sh.id=s.shift_id
            where s.business_id=v_business
              and s.status <> 'VOID'
              and coalesce(sh.opened_at::date,s.created_at::date) between v_from and v_to
            group by li.stock_item_id
        ), refunded as (
            select li.stock_item_id,sum(li.quantity) refunded_qty,sum(li.subtotal) refunded_value
            from public.sale_refunds r
            join public.sale_items li on li.sale_id=r.sale_id
            where r.business_id=v_business
              and r.created_at::date between v_from and v_to
            group by li.stock_item_id
        ), corrected as (
            select li.stock_item_id,sum(li.quantity) corrected_qty,sum(li.subtotal) corrected_value
            from public.sale_corrections c
            join public.sale_items li on li.sale_id=c.sale_id
            where c.business_id=v_business
              and c.created_at::date between v_from and v_to
            group by li.stock_item_id
        )
        select
            coalesce(jsonb_agg(jsonb_build_object(
                'kode',si.code,'produk',si.display_name,'kategori',si.sale_category,
                'harga_jual',si.sale_price,
                'qty_terjual',coalesce(s.sold_qty,0),
                'qty_refund',coalesce(r.refunded_qty,0),
                'qty_koreksi',coalesce(c.corrected_qty,0),
                'qty_bersih',coalesce(s.sold_qty,0)-coalesce(r.refunded_qty,0)-coalesce(c.corrected_qty,0),
                'nilai_bruto_item',coalesce(s.gross_value,0),
                'nilai_refund_item',coalesce(r.refunded_value,0),
                'nilai_koreksi_item',coalesce(c.corrected_value,0),
                'nilai_bersih_item',coalesce(s.gross_value,0)-coalesce(r.refunded_value,0)-coalesce(c.corrected_value,0)
            ) order by (coalesce(s.sold_qty,0)-coalesce(r.refunded_qty,0)-coalesce(c.corrected_qty,0)) desc,si.display_name),'[]'::jsonb),
            count(*) filter (where s.stock_item_id is not null or r.stock_item_id is not null or c.stock_item_id is not null),
            coalesce(sum(coalesce(s.sold_qty,0)),0),
            coalesce(sum(coalesce(r.refunded_qty,0)),0),
            coalesce(sum(coalesce(c.corrected_qty,0)),0)
        into v_rows,v_count,v_qty,v_refunds,v_corrections
        from public.stock_items si
        left join sold s on s.stock_item_id=si.id
        left join refunded r on r.stock_item_id=si.id
        left join corrected c on c.stock_item_id=si.id
        where si.business_id=v_business
          and (s.stock_item_id is not null or r.stock_item_id is not null or c.stock_item_id is not null);

        v_summary := jsonb_build_array(
            jsonb_build_object('label','Produk Terjual','value',v_count,'format','number'),
            jsonb_build_object('label','Qty Terjual','value',v_qty,'format','number'),
            jsonb_build_object('label','Qty Refund','value',v_refunds,'format','number'),
            jsonb_build_object('label','Qty Koreksi','value',v_corrections,'format','number'),
            jsonb_build_object('label','Qty Bersih','value',v_qty-v_refunds-v_corrections,'format','number')
        );
        v_sections := jsonb_build_array(jsonb_build_object(
            'key','products','title','Kinerja Produk',
            'note','Nilai item adalah nilai bruto baris sebelum diskon tingkat transaksi.',
            'columns',jsonb_build_array(
                jsonb_build_object('key','kode','label','Kode','type','text','width',22),
                jsonb_build_object('key','produk','label','Produk','type','text','width',28),
                jsonb_build_object('key','kategori','label','Kategori','type','text','width',18),
                jsonb_build_object('key','harga_jual','label','Harga Jual','type','money','width',16),
                jsonb_build_object('key','qty_terjual','label','Qty Terjual','type','number','width',14),
                jsonb_build_object('key','qty_refund','label','Qty Refund','type','number','width',14),
                jsonb_build_object('key','qty_koreksi','label','Qty Koreksi','type','number','width',14),
                jsonb_build_object('key','qty_bersih','label','Qty Bersih','type','number','width',14),
                jsonb_build_object('key','nilai_bersih_item','label','Nilai Bersih Item','type','money','width',20)
            ),
            'rows',v_rows
        ));

    elsif v_code = 'INVENTORY' then
        v_title := 'Laporan Persediaan';

        select coalesce(jsonb_agg(to_jsonb(x) order by x.lokasi,x.produk),'[]'::jsonb),
               count(*),
               count(*) filter (where x.quantity > 0)
        into v_rows,v_count,v_count2
        from (
            select
                l.display_name as lokasi,
                si.code as kode,
                si.display_name as produk,
                si.item_kind as jenis,
                si.base_unit as satuan,
                coalesce(ib.quantity,0) as quantity,
                si.inventory_tracked
            from public.locations l
            cross join public.stock_items si
            left join public.inventory_balances ib
              on ib.business_id=v_business
             and ib.location_id=l.id
             and ib.stock_item_id=si.id
            where l.business_id=v_business and l.active
              and si.business_id=v_business and si.active
              and si.inventory_tracked
              and (v_owner or private.has_inventory_location_scope(v_business,v_actor,l.id))
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.tanggal desc,x.lokasi,x.produk),'[]'::jsonb)
        into v_rows2
        from (
            select
                im.created_at::date::text as tanggal,
                l.display_name as lokasi,
                si.code as kode,
                si.display_name as produk,
                im.movement_type as jenis,
                im.reason_code as alasan,
                sum(line.quantity_delta) as perubahan
            from public.inventory_movements im
            join public.inventory_movement_lines line on line.movement_id=im.id
            join public.locations l on l.id=line.location_id
            join public.stock_items si on si.id=line.stock_item_id
            where im.business_id=v_business
              and im.created_at::date between v_from and v_to
              and (v_owner or private.has_inventory_location_scope(v_business,v_actor,l.id))
            group by im.created_at::date,l.display_name,si.code,si.display_name,im.movement_type,im.reason_code
        ) x;

        v_summary := jsonb_build_array(
            jsonb_build_object('label','Baris Saldo Stok','value',v_count,'format','number'),
            jsonb_build_object('label','Baris Stok Positif','value',v_count2,'format','number'),
            jsonb_build_object('label','Snapshot','value',current_date::text,'format','date')
        );
        v_sections := jsonb_build_array(
            jsonb_build_object(
                'key','balances','title','Saldo Persediaan Saat Ini',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','lokasi','label','Lokasi','type','text','width',18),
                    jsonb_build_object('key','kode','label','Kode','type','text','width',22),
                    jsonb_build_object('key','produk','label','Produk','type','text','width',28),
                    jsonb_build_object('key','jenis','label','Jenis','type','text','width',16),
                    jsonb_build_object('key','satuan','label','Satuan','type','text','width',12),
                    jsonb_build_object('key','quantity','label','Jumlah','type','number','width',14)
                ),
                'rows',v_rows
            ),
            jsonb_build_object(
                'key','movements','title','Pergerakan Periode',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','tanggal','label','Tanggal','type','date','width',14),
                    jsonb_build_object('key','lokasi','label','Lokasi','type','text','width',18),
                    jsonb_build_object('key','kode','label','Kode','type','text','width',22),
                    jsonb_build_object('key','produk','label','Produk','type','text','width',28),
                    jsonb_build_object('key','jenis','label','Jenis','type','text','width',16),
                    jsonb_build_object('key','alasan','label','Alasan','type','text','width',24),
                    jsonb_build_object('key','perubahan','label','Perubahan','type','number','width',14)
                ),
                'rows',v_rows2
            )
        );

    elsif v_code = 'SHIFT' then
        v_title := 'Laporan Shift';

        select coalesce(jsonb_agg(to_jsonb(x) order by x.opened_at desc),'[]'::jsonb),
               count(*),
               coalesce(sum(x.sale_total),0),
               coalesce(sum(x.refund_total),0)
        into v_rows,v_count,v_gross,v_refunds
        from (
            select
                s.id as shift_id,
                s.opened_at,
                s.closed_at,
                s.status,
                p.display_name as kasir,
                l.display_name as lokasi,
                s.opening_balance,
                coalesce(a.sale_total,0) sale_total,
                coalesce(a.refund_total,0) refund_total,
                coalesce(a.cash_in_total,0) cash_in_total,
                coalesce(a.cash_out_total,0) cash_out_total,
                coalesce(a.adjustment_total,0) adjustment_total,
                private.cs05_shift_expected_cash(s.id) as expected_cash,
                s.actual_cash,
                s.variance
            from public.shifts s
            join public.profiles p on p.id=s.cashier_profile_id
            join public.locations l on l.id=s.location_id
            left join lateral (
                select
                    sum(ct.amount) filter (where ct.transaction_type='SALE') sale_total,
                    sum(ct.amount) filter (where ct.transaction_type='REFUND') refund_total,
                    sum(ct.amount) filter (where ct.transaction_type='CASH_IN') cash_in_total,
                    sum(ct.amount) filter (where ct.transaction_type='CASH_OUT') cash_out_total,
                    sum(ct.amount) filter (where ct.transaction_type='ADJUSTMENT') adjustment_total
                from public.cash_transactions ct
                where ct.shift_id=s.id
            ) a on true
            where s.business_id=v_business
              and s.opened_at::date between v_from and v_to
        ) x;

        v_summary := jsonb_build_array(
            jsonb_build_object('label','Jumlah Shift','value',v_count,'format','number'),
            jsonb_build_object('label','Penjualan Tunai','value',v_gross,'format','money'),
            jsonb_build_object('label','Refund Tunai','value',v_refunds,'format','money')
        );
        v_sections := jsonb_build_array(jsonb_build_object(
            'key','shifts','title','Shift',
            'columns',jsonb_build_array(
                jsonb_build_object('key','opened_at','label','Buka','type','datetime','width',22),
                jsonb_build_object('key','closed_at','label','Tutup','type','datetime','width',22),
                jsonb_build_object('key','kasir','label','Kasir','type','text','width',20),
                jsonb_build_object('key','lokasi','label','Lokasi','type','text','width',18),
                jsonb_build_object('key','status','label','Status','type','text','width',12),
                jsonb_build_object('key','opening_balance','label','Kas Awal','type','money','width',16),
                jsonb_build_object('key','sale_total','label','Penjualan Tunai','type','money','width',18),
                jsonb_build_object('key','refund_total','label','Refund Tunai','type','money','width',18),
                jsonb_build_object('key','cash_in_total','label','Kas Masuk','type','money','width',16),
                jsonb_build_object('key','cash_out_total','label','Kas Keluar','type','money','width',16),
                jsonb_build_object('key','adjustment_total','label','Koreksi / Penyesuaian','type','money','width',18),
                jsonb_build_object('key','expected_cash','label','Expected Closing','type','money','width',18),
                jsonb_build_object('key','actual_cash','label','Kas Aktual','type','money','width',16),
                jsonb_build_object('key','variance','label','Selisih','type','money','width',16)
            ),
            'rows',v_rows
        ));

    elsif v_code = 'PURCHASE' then
        v_title := 'Laporan Pembelian';

        select coalesce(jsonb_agg(to_jsonb(x) order by x.ordered_at desc),'[]'::jsonb),
               count(*),
               coalesce(sum(x.total),0)
        into v_rows,v_count,v_gross
        from (
            select
                po.order_number,
                po.ordered_at,
                po.status,
                sup.display_name as pemasok,
                loc.display_name as lokasi,
                coalesce(sum(pol.line_total),0) as total
            from public.purchase_orders po
            join public.suppliers sup on sup.id=po.supplier_id
            join public.locations loc on loc.id=po.location_id
            left join public.purchase_order_lines pol on pol.purchase_order_id=po.id
            where po.business_id=v_business
              and po.ordered_at::date between v_from and v_to
            group by po.id,po.order_number,po.ordered_at,po.status,sup.display_name,loc.display_name
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.received_at desc),'[]'::jsonb)
        into v_rows2
        from (
            select
                gr.receipt_number,
                gr.received_at,
                gr.posted_at,
                gr.status,
                po.order_number,
                sup.display_name as pemasok,
                loc.display_name as lokasi,
                coalesce(sum(grl.base_quantity),0) as jumlah_dasar
            from public.goods_receipts gr
            left join public.purchase_orders po on po.id=gr.purchase_order_id
            left join public.suppliers sup on sup.id=po.supplier_id
            join public.locations loc on loc.id=gr.location_id
            left join public.goods_receipt_lines grl on grl.goods_receipt_id=gr.id
            where gr.business_id=v_business
              and gr.received_at::date between v_from and v_to
            group by gr.id,gr.receipt_number,gr.received_at,gr.posted_at,gr.status,
                     po.order_number,sup.display_name,loc.display_name
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
        into v_rows3
        from (
            select
                spb.supplier_name as pemasok,
                spb.invoice_reference as referensi,
                spb.original_amount,
                spb.paid_amount,
                spb.balance,
                spb.status,
                spb.created_at
            from public.supplier_payable_balances spb
            where spb.business_id=v_business
              and spb.created_at::date between v_from and v_to
        ) x;

        v_summary := jsonb_build_array(
            jsonb_build_object('label','Pesanan Pembelian','value',v_count,'format','number'),
            jsonb_build_object('label','Nilai Pesanan','value',v_gross,'format','money'),
            jsonb_build_object('label','Periode','value',v_from::text || ' s.d. ' || v_to::text,'format','text')
        );
        v_sections := jsonb_build_array(
            jsonb_build_object(
                'key','orders','title','Pesanan Pembelian',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','order_number','label','Nomor','type','text','width',22),
                    jsonb_build_object('key','ordered_at','label','Tanggal','type','datetime','width',22),
                    jsonb_build_object('key','pemasok','label','Pemasok','type','text','width',24),
                    jsonb_build_object('key','lokasi','label','Lokasi','type','text','width',18),
                    jsonb_build_object('key','status','label','Status','type','text','width',14),
                    jsonb_build_object('key','total','label','Total','type','money','width',18)
                ),
                'rows',v_rows
            ),
            jsonb_build_object(
                'key','receipts','title','Barang Diterima',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','receipt_number','label','Nomor Terima','type','text','width',22),
                    jsonb_build_object('key','received_at','label','Diterima','type','datetime','width',22),
                    jsonb_build_object('key','order_number','label','Nomor Pesanan','type','text','width',22),
                    jsonb_build_object('key','pemasok','label','Pemasok','type','text','width',24),
                    jsonb_build_object('key','lokasi','label','Lokasi','type','text','width',18),
                    jsonb_build_object('key','status','label','Status','type','text','width',14),
                    jsonb_build_object('key','jumlah_dasar','label','Jumlah Dasar','type','number','width',16)
                ),
                'rows',v_rows2
            ),
            jsonb_build_object(
                'key','payables','title','Utang Pemasok dari Periode',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','pemasok','label','Pemasok','type','text','width',24),
                    jsonb_build_object('key','referensi','label','Referensi','type','text','width',22),
                    jsonb_build_object('key','original_amount','label','Nilai Awal','type','money','width',18),
                    jsonb_build_object('key','paid_amount','label','Dibayar','type','money','width',18),
                    jsonb_build_object('key','balance','label','Sisa','type','money','width',18),
                    jsonb_build_object('key','status','label','Status','type','text','width',14)
                ),
                'rows',v_rows3
            )
        );

    else
        v_title := 'Laporan Keuangan';

        select coalesce(sum(s.total_amount),0)
        into v_gross
        from public.sales s
        left join public.shifts sh on sh.id=s.shift_id
        where s.business_id=v_business
          and s.status <> 'VOID'
          and coalesce(sh.opened_at::date,s.created_at::date) between v_from and v_to;

        select coalesce(sum(r.sale_total),0)
        into v_refunds
        from public.sale_refunds r
        where r.business_id=v_business
          and r.created_at::date between v_from and v_to;

        select coalesce(sum(c.sale_total),0)
        into v_corrections
        from public.sale_corrections c
        where c.business_id=v_business
          and c.created_at::date between v_from and v_to;

        select coalesce(sum(e.amount),0)
        into v_expenses
        from public.business_expenses e
        where e.business_id=v_business
          and e.approval_state='POSTED'
          and e.created_at::date between v_from and v_to;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.akun),'[]'::jsonb)
        into v_rows
        from (
            select ma.code,ma.display_name as akun,ma.account_type as jenis,
                   coalesce(mb.balance,0) as saldo
            from public.money_accounts ma
            left join public.money_balances mb
              on mb.business_id=ma.business_id and mb.account_id=ma.id
            where ma.business_id=v_business and ma.active
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
        into v_rows2
        from (
            select
                mm.created_at,
                mm.movement_type as jenis,
                fa.display_name as dari_akun,
                ta.display_name as ke_akun,
                mm.amount,
                mm.source_type as sumber,
                mm.source_ref as referensi,
                mm.reason_code as alasan
            from public.money_movements mm
            left join public.money_accounts fa on fa.id=mm.from_account_id
            left join public.money_accounts ta on ta.id=mm.to_account_id
            where mm.business_id=v_business
              and mm.created_at::date between v_from and v_to
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
        into v_rows3
        from (
            select e.created_at,e.category_code as kategori,e.description,
                   e.amount,ma.display_name as sumber_dana
            from public.business_expenses e
            join public.money_accounts ma on ma.id=e.funding_account_id
            where e.business_id=v_business
              and e.approval_state='POSTED'
              and e.created_at::date between v_from and v_to
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
        into v_rows4
        from (
            select customer_name as pelanggan,original_amount,paid_amount,balance,status,created_at
            from public.customer_debt_balances
            where business_id=v_business and balance > 0
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
        into v_rows5
        from (
            select supplier_name as pemasok,invoice_reference as referensi,
                   original_amount,paid_amount,balance,status,created_at
            from public.supplier_payable_balances
            where business_id=v_business and balance > 0
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
        into v_rows6
        from (
            select employee_name as karyawan,original_amount,paid_amount,balance,status,note,created_at
            from public.employee_kasbon_balances
            where business_id=v_business and balance > 0
        ) x;

        select count(*) into v_count
        from public.stock_items si
        where si.business_id=v_business and si.sale_enabled and si.active;

        v_warnings := jsonb_build_array(
            'Coverage HPP belum tersedia dari authority data saat ini. Sistem tidak menampilkan Laba Bersih sebagai angka pasti.'
        );
        v_summary := jsonb_build_array(
            jsonb_build_object('label','Penjualan Bruto','value',v_gross,'format','money'),
            jsonb_build_object('label','Refund','value',v_refunds,'format','money'),
            jsonb_build_object('label','Koreksi','value',v_corrections,'format','money'),
            jsonb_build_object('label','Penjualan Bersih','value',v_gross-v_refunds-v_corrections,'format','money'),
            jsonb_build_object('label','Pengeluaran Usaha','value',v_expenses,'format','money'),
            jsonb_build_object('label','Coverage HPP','value','0 / ' || v_count::text || ' produk aktif','format','text'),
            jsonb_build_object('label','Estimasi Laba','value',null,'format','money')
        );
        v_sections := jsonb_build_array(
            jsonb_build_object(
                'key','accounts','title','Ringkasan Saldo Akun',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','code','label','Kode','type','text','width',22),
                    jsonb_build_object('key','akun','label','Akun','type','text','width',28),
                    jsonb_build_object('key','jenis','label','Jenis','type','text','width',16),
                    jsonb_build_object('key','saldo','label','Saldo','type','money','width',18)
                ),'rows',v_rows
            ),
            jsonb_build_object(
                'key','money','title','Arus Uang Periode',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','created_at','label','Waktu','type','datetime','width',22),
                    jsonb_build_object('key','jenis','label','Jenis','type','text','width',16),
                    jsonb_build_object('key','dari_akun','label','Dari Akun','type','text','width',24),
                    jsonb_build_object('key','ke_akun','label','Ke Akun','type','text','width',24),
                    jsonb_build_object('key','amount','label','Nominal','type','money','width',18),
                    jsonb_build_object('key','sumber','label','Sumber','type','text','width',20),
                    jsonb_build_object('key','referensi','label','Referensi','type','text','width',24),
                    jsonb_build_object('key','alasan','label','Alasan','type','text','width',24)
                ),'rows',v_rows2
            ),
            jsonb_build_object(
                'key','expenses','title','Pengeluaran Usaha',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','created_at','label','Waktu','type','datetime','width',22),
                    jsonb_build_object('key','kategori','label','Kategori','type','text','width',20),
                    jsonb_build_object('key','description','label','Keterangan','type','text','width',32),
                    jsonb_build_object('key','amount','label','Nominal','type','money','width',18),
                    jsonb_build_object('key','sumber_dana','label','Sumber Dana','type','text','width',24)
                ),'rows',v_rows3
            ),
            jsonb_build_object(
                'key','customer_debts','title','Hutang Pelanggan',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','pelanggan','label','Pelanggan','type','text','width',24),
                    jsonb_build_object('key','original_amount','label','Nilai Awal','type','money','width',18),
                    jsonb_build_object('key','paid_amount','label','Dibayar','type','money','width',18),
                    jsonb_build_object('key','balance','label','Sisa','type','money','width',18),
                    jsonb_build_object('key','status','label','Status','type','text','width',14)
                ),'rows',v_rows4
            ),
            jsonb_build_object(
                'key','supplier_payables','title','Utang Pemasok',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','pemasok','label','Pemasok','type','text','width',24),
                    jsonb_build_object('key','referensi','label','Referensi','type','text','width',22),
                    jsonb_build_object('key','original_amount','label','Nilai Awal','type','money','width',18),
                    jsonb_build_object('key','paid_amount','label','Dibayar','type','money','width',18),
                    jsonb_build_object('key','balance','label','Sisa','type','money','width',18),
                    jsonb_build_object('key','status','label','Status','type','text','width',14)
                ),'rows',v_rows5
            ),
            jsonb_build_object(
                'key','kasbon','title','Kasbon Karyawan',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','karyawan','label','Karyawan','type','text','width',24),
                    jsonb_build_object('key','original_amount','label','Nilai Awal','type','money','width',18),
                    jsonb_build_object('key','paid_amount','label','Dibayar','type','money','width',18),
                    jsonb_build_object('key','balance','label','Sisa','type','money','width',18),
                    jsonb_build_object('key','status','label','Status','type','text','width',14),
                    jsonb_build_object('key','note','label','Catatan','type','text','width',30)
                ),'rows',v_rows6
            )
        );
    end if;

    return jsonb_build_object(
        'report_code',v_code,
        'report_title',v_title,
        'business_name',v_business_name,
        'period',jsonb_build_object('date_from',v_from,'date_to',v_to),
        'generated_at',now(),
        'summary',v_summary,
        'warnings',v_warnings,
        'sections',v_sections
    );
end;
$$;

revoke execute on function public.report_run(text,date,date)
from public, anon, authenticated, service_role;
grant execute on function public.report_run(text,date,date)
to authenticated;
