-- FIN-P4: QRIS Settlement & Daily Finance Reconciliation.
-- Keuangan remains the only money ledger.

create table public.qris_settlements (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    settlement_date date not null,
    provider_reference text not null check (length(btrim(provider_reference)) > 0),
    gross_amount numeric(18,2) not null check (gross_amount > 0),
    provider_fee numeric(18,2) not null default 0 check (provider_fee >= 0),
    net_amount numeric(18,2) generated always as (gross_amount - provider_fee) stored,
    actor_profile_id uuid not null references public.profiles(id) on delete restrict,
    gross_settlement_movement_id uuid not null unique references public.money_movements(id) on delete restrict,
    fee_movement_id uuid unique references public.money_movements(id) on delete restrict,
    bank_transfer_movement_id uuid not null unique references public.money_movements(id) on delete restrict,
    created_at timestamptz not null default now(),
    unique (business_id, provider_reference),
    constraint qris_settlement_fee_less_than_gross check (provider_fee < gross_amount)
);

create index qris_settlements_business_date_idx
    on public.qris_settlements(business_id, settlement_date, created_at desc);
create index qris_settlements_actor_idx
    on public.qris_settlements(actor_profile_id);

create trigger qris_settlements_immutable
before update or delete on public.qris_settlements
for each row execute function private.prevent_fact_mutation();

alter table public.qris_settlements enable row level security;
revoke all on table public.qris_settlements from public, anon, authenticated;
grant select on table public.qris_settlements to authenticated;

create policy qris_settlements_owner_read
on public.qris_settlements
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
);

create table public.finance_daily_reconciliations (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    business_date date not null,
    expected_cash numeric(18,2) not null,
    counted_cash numeric(18,2) not null check (counted_cash >= 0),
    cash_variance numeric(18,2) not null,
    qris_recorded numeric(18,2) not null check (qris_recorded >= 0),
    qris_settled numeric(18,2) not null check (qris_settled >= 0),
    qris_variance numeric(18,2) not null,
    transfer_recorded numeric(18,2) not null check (transfer_recorded >= 0),
    transfer_received numeric(18,2) not null check (transfer_received >= 0),
    transfer_variance numeric(18,2) not null,
    stock_status text not null check (stock_status in ('SESUAI','PERLU_DIPERIKSA','NOT_CHECKED')),
    result text not null check (result in ('SESUAI','PERLU_DIPERIKSA')),
    actor_profile_id uuid not null references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now()
);

create index finance_daily_reconciliations_business_date_idx
    on public.finance_daily_reconciliations(business_id, business_date, created_at desc);
create index finance_daily_reconciliations_actor_idx
    on public.finance_daily_reconciliations(actor_profile_id);

create trigger finance_daily_reconciliations_immutable
before update or delete on public.finance_daily_reconciliations
for each row execute function private.prevent_fact_mutation();

alter table public.finance_daily_reconciliations enable row level security;
revoke all on table public.finance_daily_reconciliations from public, anon, authenticated;
grant select on table public.finance_daily_reconciliations to authenticated;

create policy finance_daily_reconciliations_owner_read
on public.finance_daily_reconciliations
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
);

create or replace function public.finance_settle_qris(
    p_settlement_date date,
    p_provider_reference text,
    p_gross_amount numeric,
    p_provider_fee numeric,
    p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_unsettled uuid;
    v_settled uuid;
    v_bank uuid;
    v_available numeric(18,2);
    v_settlement uuid;
    v_gross_move uuid;
    v_fee_move uuid;
    v_bank_move uuid;
    v_payload_hash text;
    v_lock record;
    v_receipt uuid;
    v_net numeric(18,2);
begin
    v_authority := public.get_my_authority();
    v_business := (v_authority ->> 'business_id')::uuid;
    v_actor := (v_authority ->> 'profile_id')::uuid;

    if not coalesce((v_authority ->> 'owner')::boolean, false) then
        raise exception using errcode = '42501', message = 'SJ_OWNER_AUTHORITY_REQUIRED';
    end if;

    if p_settlement_date is null or p_settlement_date > current_date then
        raise exception using errcode = '22023', message = 'QRIS_SETTLEMENT_DATE_INVALID';
    end if;

    if p_provider_reference is null or length(btrim(p_provider_reference)) = 0 then
        raise exception using errcode = '22023', message = 'QRIS_PROVIDER_REFERENCE_REQUIRED';
    end if;

    if p_gross_amount is null or p_gross_amount <= 0
       or p_provider_fee is null or p_provider_fee < 0
       or p_provider_fee >= p_gross_amount then
        raise exception using errcode = '22023', message = 'QRIS_SETTLEMENT_AMOUNT_INVALID';
    end if;

    v_net := p_gross_amount - p_provider_fee;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'actor', v_actor,
            'settlement_date', p_settlement_date,
            'provider_reference', btrim(p_provider_reference),
            'gross_amount', p_gross_amount,
            'provider_fee', p_provider_fee
        )
    );

    select * into v_lock
    from private.lock_operation(
        v_business, p_idempotency_key, 'QRIS_SETTLEMENT', v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'QRIS_SETTLEMENT'
           or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;
        return v_lock.result_id;
    end if;

    select id into v_unsettled
    from public.money_accounts
    where business_id = v_business and code = 'QRIS_BELUM_CAIR' and active
    for update;

    select id into v_settled
    from public.money_accounts
    where business_id = v_business and code = 'QRIS_SUDAH_CAIR' and active;

    select id into v_bank
    from public.money_accounts
    where business_id = v_business and code = 'BANK' and active;

    if v_unsettled is null or v_settled is null or v_bank is null then
        raise exception using errcode = '23503', message = 'QRIS_FINANCE_ACCOUNT_MISSING';
    end if;

    select coalesce(balance,0)
    into v_available
    from public.money_balances
    where business_id = v_business and account_id = v_unsettled;

    if coalesce(v_available,0) < p_gross_amount then
        raise exception using errcode = '23514', message = 'QRIS_UNSETTLED_BALANCE_INSUFFICIENT';
    end if;

    v_settlement := gen_random_uuid();

    v_gross_move := private.record_money_movement(
        v_business, v_actor, p_idempotency_key || ':GROSS',
        'SETTLEMENT', v_unsettled, v_settled, p_gross_amount,
        'QRIS_SETTLEMENT', v_settlement::text, 'QRIS_GROSS_SETTLEMENT'
    );

    if p_provider_fee > 0 then
        v_fee_move := private.record_money_movement(
            v_business, v_actor, p_idempotency_key || ':FEE',
            'EXPENSE', v_settled, null, p_provider_fee,
            'QRIS_SETTLEMENT', v_settlement::text, 'QRIS_PROVIDER_FEE'
        );
    end if;

    v_bank_move := private.record_money_movement(
        v_business, v_actor, p_idempotency_key || ':BANK',
        'TRANSFER', v_settled, v_bank, v_net,
        'QRIS_SETTLEMENT', v_settlement::text, 'QRIS_NET_TO_BANK'
    );

    insert into public.qris_settlements (
        id, business_id, settlement_date, provider_reference,
        gross_amount, provider_fee, actor_profile_id,
        gross_settlement_movement_id, fee_movement_id,
        bank_transfer_movement_id
    ) values (
        v_settlement, v_business, p_settlement_date, btrim(p_provider_reference),
        p_gross_amount, p_provider_fee, v_actor,
        v_gross_move, v_fee_move, v_bank_move
    );

    v_receipt := private.record_operation_success(
        v_business, p_idempotency_key, 'QRIS_SETTLEMENT',
        v_payload_hash, 'QRIS_SETTLEMENT', v_settlement, v_actor
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor, v_receipt,
        'QRIS_SETTLEMENT_RECORDED', 'QRIS_SETTLEMENT', v_settlement,
        jsonb_build_object(
            'settlement_date', p_settlement_date,
            'provider_reference', btrim(p_provider_reference),
            'gross_amount', p_gross_amount,
            'provider_fee', p_provider_fee,
            'net_amount', v_net,
            'gross_movement_id', v_gross_move,
            'fee_movement_id', v_fee_move,
            'bank_movement_id', v_bank_move
        )
    );

    return v_settlement;
end;
$$;

revoke execute on function public.finance_settle_qris(date,text,numeric,numeric,text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_settle_qris(date,text,numeric,numeric,text)
to authenticated;

create or replace function public.finance_reconcile_day(
    p_business_date date,
    p_counted_cash numeric,
    p_bank_transfer_received numeric,
    p_stock_status text,
    p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_stock_status text;
    v_expected_cash numeric(18,2);
    v_qris_recorded numeric(18,2);
    v_qris_settled numeric(18,2);
    v_transfer_recorded numeric(18,2);
    v_cash_variance numeric(18,2);
    v_qris_variance numeric(18,2);
    v_transfer_variance numeric(18,2);
    v_result text;
    v_id uuid;
    v_payload_hash text;
    v_lock record;
    v_receipt uuid;
begin
    v_authority := public.get_my_authority();
    v_business := (v_authority ->> 'business_id')::uuid;
    v_actor := (v_authority ->> 'profile_id')::uuid;
    v_stock_status := upper(btrim(coalesce(p_stock_status,'NOT_CHECKED')));

    if not coalesce((v_authority ->> 'owner')::boolean, false) then
        raise exception using errcode = '42501', message = 'SJ_OWNER_AUTHORITY_REQUIRED';
    end if;

    if p_business_date is null or p_business_date > current_date then
        raise exception using errcode = '22023', message = 'FINANCE_RECONCILIATION_DATE_INVALID';
    end if;

    if p_counted_cash is null or p_counted_cash < 0
       or p_bank_transfer_received is null or p_bank_transfer_received < 0 then
        raise exception using errcode = '22023', message = 'FINANCE_RECONCILIATION_AMOUNT_INVALID';
    end if;

    if v_stock_status not in ('SESUAI','PERLU_DIPERIKSA','NOT_CHECKED') then
        raise exception using errcode = '22023', message = 'FINANCE_RECONCILIATION_STOCK_STATUS_INVALID';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'actor', v_actor,
            'business_date', p_business_date,
            'counted_cash', p_counted_cash,
            'bank_transfer_received', p_bank_transfer_received,
            'stock_status', v_stock_status
        )
    );

    select * into v_lock
    from private.lock_operation(
        v_business, p_idempotency_key, 'FINANCE_DAILY_RECONCILIATION', v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'FINANCE_DAILY_RECONCILIATION'
           or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;
        return v_lock.result_id;
    end if;

    select coalesce(sum(
        case
            when m.to_account_id = a.id then m.amount
            when m.from_account_id = a.id then -m.amount
            else 0
        end
    ),0)::numeric(18,2)
    into v_expected_cash
    from public.money_accounts a
    left join public.money_movements m
      on m.business_id = a.business_id
     and (m.to_account_id = a.id or m.from_account_id = a.id)
     and m.created_at < (p_business_date + 1)::timestamp
    where a.business_id = v_business
      and a.code in ('KAS_UTAMA','KAS_SHIFT');

    select coalesce(sum(m.amount),0)::numeric(18,2)
    into v_qris_recorded
    from public.money_movements m
    join public.money_accounts a on a.id = m.to_account_id
    where m.business_id = v_business
      and a.code = 'QRIS_BELUM_CAIR'
      and m.movement_type = 'INCOME'
      and m.source_type = 'SALE'
      and m.reason_code = 'SALE_PAYMENT'
      and m.created_at::date = p_business_date;

    select coalesce(sum(s.gross_amount),0)::numeric(18,2)
    into v_qris_settled
    from public.qris_settlements s
    where s.business_id = v_business
      and s.settlement_date = p_business_date;

    select coalesce(sum(m.amount),0)::numeric(18,2)
    into v_transfer_recorded
    from public.money_movements m
    join public.money_accounts a on a.id = m.to_account_id
    where m.business_id = v_business
      and a.code = 'BANK'
      and m.movement_type = 'INCOME'
      and m.source_type = 'SALE'
      and m.reason_code = 'SALE_PAYMENT'
      and m.created_at::date = p_business_date;

    v_cash_variance := p_counted_cash - v_expected_cash;
    v_qris_variance := v_qris_settled - v_qris_recorded;
    v_transfer_variance := p_bank_transfer_received - v_transfer_recorded;

    v_result := case
        when v_cash_variance = 0
         and v_qris_variance = 0
         and v_transfer_variance = 0
         and v_stock_status <> 'PERLU_DIPERIKSA'
        then 'SESUAI'
        else 'PERLU_DIPERIKSA'
    end;

    v_id := gen_random_uuid();

    insert into public.finance_daily_reconciliations (
        id, business_id, business_date,
        expected_cash, counted_cash, cash_variance,
        qris_recorded, qris_settled, qris_variance,
        transfer_recorded, transfer_received, transfer_variance,
        stock_status, result, actor_profile_id
    ) values (
        v_id, v_business, p_business_date,
        v_expected_cash, p_counted_cash, v_cash_variance,
        v_qris_recorded, v_qris_settled, v_qris_variance,
        v_transfer_recorded, p_bank_transfer_received, v_transfer_variance,
        v_stock_status, v_result, v_actor
    );

    v_receipt := private.record_operation_success(
        v_business, p_idempotency_key, 'FINANCE_DAILY_RECONCILIATION',
        v_payload_hash, 'FINANCE_DAILY_RECONCILIATION', v_id, v_actor
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor, v_receipt,
        'FINANCE_DAILY_RECONCILIATION_RECORDED',
        'FINANCE_DAILY_RECONCILIATION', v_id,
        jsonb_build_object(
            'business_date', p_business_date,
            'cash_variance', v_cash_variance,
            'qris_variance', v_qris_variance,
            'transfer_variance', v_transfer_variance,
            'stock_status', v_stock_status,
            'result', v_result
        )
    );

    return v_id;
end;
$$;

revoke execute on function public.finance_reconcile_day(date,numeric,numeric,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_reconcile_day(date,numeric,numeric,text,text)
to authenticated;
