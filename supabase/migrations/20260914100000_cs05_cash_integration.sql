-- CS-05-P4 CASH INTEGRATION & RECONCILIATION
-- Captures CASH payments into the cashier open shift, adds cash movements,
-- and exposes per-shift reconciliation. Also corrects expected_cash semantics:
-- expected drawer cash = opening + SALE - REFUND + CASH_IN - CASH_OUT + ADJUSTMENT.

create or replace function private.cs05_shift_expected_cash(p_shift uuid)
returns numeric(18, 2)
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(s.opening_balance, 0)
         + coalesce(agg.sale, 0)
         - coalesce(agg.refund, 0)
         + coalesce(agg.cash_in, 0)
         - coalesce(agg.cash_out, 0)
         + coalesce(agg.adjustment, 0)
    from public.shifts s
    left join lateral (
        select
            sum(t.amount) filter (where t.transaction_type = 'SALE') as sale,
            sum(t.amount) filter (where t.transaction_type = 'REFUND') as refund,
            sum(t.amount) filter (where t.transaction_type = 'CASH_IN') as cash_in,
            sum(t.amount) filter (where t.transaction_type = 'CASH_OUT') as cash_out,
            sum(t.amount) filter (where t.transaction_type = 'ADJUSTMENT') as adjustment
        from public.cash_transactions t
        where t.shift_id = s.id
    ) agg on true
    where s.id = p_shift;
$$;

create function private.cs05_capture_cash_sale()
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

    update public.sales
    set shift_id = v_shift
    where id = new.sale_id and shift_id is null;

    return new;
end;
$$;

create trigger cs05_capture_cash_sale
    after insert on public.payments
    for each row execute function private.cs05_capture_cash_sale();

create or replace function private.cs05_close_shift(
    p_shift uuid,
    p_actor uuid,
    p_actual numeric
) returns numeric
language plpgsql
as $$
declare
    r record;
    v_expected numeric(18, 2);
begin
    select * into r from public.shifts where id = p_shift for update;
    if not found then
        raise exception 'CS05: shift not found';
    end if;
    if r.cashier_profile_id <> p_actor then
        raise exception 'CS05: shift ownership violation (AC-05)';
    end if;
    if r.status <> 'OPEN' then
        raise exception 'CS05: shift is not open';
    end if;

    v_expected := private.cs05_shift_expected_cash(p_shift);

    update public.shifts
    set status = 'CLOSED',
        closed_at = now(),
        expected_cash = v_expected,
        actual_cash = p_actual,
        closing_balance = p_actual
    where id = p_shift;

    return p_actual - v_expected;
end;
$$;

create function public.cs05_add_cash_movement(
    p_type text,
    p_amount numeric,
    p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor uuid;
    v_shift record;
    v_id uuid;
begin
    perform private.cs05_require_shift_permission();
    v_actor := private.cs05_my_profile_id();

    if p_type not in ('CASH_IN', 'CASH_OUT', 'ADJUSTMENT') then
        raise exception using message = 'SJ_CASH_MOVEMENT_TYPE_INVALID';
    end if;

    select id, business_id, location_id into v_shift
    from public.shifts
    where cashier_profile_id = v_actor and status = 'OPEN';

    if v_shift.id is null then
        raise exception using errcode = '42501', message = 'SJ_SHIFT_NOT_OPEN';
    end if;

    insert into public.cash_transactions (
        business_id,
        location_id,
        shift_id,
        cashier_profile_id,
        transaction_type,
        amount,
        notes
    ) values (
        v_shift.business_id,
        v_shift.location_id,
        v_shift.id,
        v_actor,
        p_type,
        p_amount,
        p_notes
    ) returning id into v_id;

    return v_id;
end;
$$;

create function public.cs05_shift_reconciliation(p_shift uuid)
returns table (
    shift_id uuid,
    opening_balance numeric(18, 2),
    sale_total numeric(18, 2),
    refund_total numeric(18, 2),
    cash_in_total numeric(18, 2),
    cash_out_total numeric(18, 2),
    adjustment_total numeric(18, 2),
    expected_cash numeric(18, 2),
    actual_cash numeric(18, 2),
    variance numeric(18, 2)
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_business uuid;
begin
    select business_id into v_business from public.shifts where id = p_shift;
    if v_business is null
        or v_business <> (public.get_my_authority() ->> 'business_id')::uuid then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    return query
    select
        s.id,
        s.opening_balance,
        coalesce(sum(t.amount) filter (where t.transaction_type = 'SALE'), 0),
        coalesce(sum(t.amount) filter (where t.transaction_type = 'REFUND'), 0),
        coalesce(sum(t.amount) filter (where t.transaction_type = 'CASH_IN'), 0),
        coalesce(sum(t.amount) filter (where t.transaction_type = 'CASH_OUT'), 0),
        coalesce(sum(t.amount) filter (where t.transaction_type = 'ADJUSTMENT'), 0),
        private.cs05_shift_expected_cash(s.id),
        s.actual_cash,
        s.variance
    from public.shifts s
    left join public.cash_transactions t on t.shift_id = s.id
    where s.id = p_shift
    group by s.id, s.opening_balance, s.actual_cash, s.variance;
end;
$$;

revoke execute on function private.cs05_shift_expected_cash(uuid) from public, anon, authenticated, service_role;
revoke execute on function private.cs05_capture_cash_sale() from public, anon, authenticated, service_role;
revoke execute on function public.cs05_add_cash_movement(text, numeric, text) from public, anon, authenticated, service_role;
grant execute on function public.cs05_add_cash_movement(text, numeric, text) to authenticated;
revoke execute on function public.cs05_shift_reconciliation(uuid) from public, anon, authenticated, service_role;
grant execute on function public.cs05_shift_reconciliation(uuid) to authenticated;
