-- CS-05-P2 SHIFT BACKEND LOGIC
-- Implements: R-01 lifecycle, R-02 immutability, R-04 reconciliation,
--             AC-01 open guard, AC-03 close+reconcile, AC-05 ownership/immutability
-- Permission binding (shift.open/shift.close) deferred to CS-03 integration.

alter table public.shifts
    add column config_snapshot jsonb not null default '{}'::jsonb,
    add column expected_cash numeric(18, 2),
    add column actual_cash numeric(18, 2),
    add column variance numeric(18, 2) generated always as (actual_cash - expected_cash) stored;

comment on column public.shifts.config_snapshot is 'Immutable snapshot of configuration captured at shift open (R-02)';
comment on column public.shifts.variance is 'Calculated: actual_cash - expected_cash (R-04)';


create function private.cs05_open_shift(
    p_business uuid,
    p_location uuid,
    p_actor uuid,
    p_opening numeric,
    p_config jsonb default '{}'::jsonb
) returns uuid
language plpgsql
as $$
declare
    v_shift uuid;
begin
    if exists (
        select 1 from public.shifts
        where cashier_profile_id = p_actor and status = 'OPEN'
    ) then
        raise exception 'CS05: actor already has an open shift (AC-01)';
    end if;

    insert into public.shifts(business_id, location_id, cashier_profile_id, opening_balance, config_snapshot)
    values (p_business, p_location, p_actor, p_opening, p_config)
    returning id into v_shift;

    return v_shift;
end;
$$;


create function private.cs05_close_shift(
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

    select coalesce(sum(amount), 0) into v_expected
    from public.cash_transactions
    where shift_id = p_shift and transaction_type = 'SALE';

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


create view public.cs05_sales_by_shift as
select
    shift_id,
    business_id,
    location_id,
    sum(amount) as gross_cash_sales,
    count(*) as sale_count
from public.cash_transactions
where transaction_type = 'SALE'
group by shift_id, business_id, location_id;

comment on view public.cs05_sales_by_shift is 'AC-02 sales_by_shift aggregation over cash SALE transactions';


create function private.cs05_shift_immutable() returns trigger
language plpgsql
as $$
begin
    if old.status = 'CLOSED' then
        raise exception 'CS05: closed shifts are immutable (AC-05)';
    end if;
    if new.cashier_profile_id is distinct from old.cashier_profile_id then
        raise exception 'CS05: shift actor is immutable (R-02)';
    end if;
    if new.config_snapshot is distinct from old.config_snapshot then
        raise exception 'CS05: config snapshot is immutable (R-02)';
    end if;
    return new;
end;
$$;

create trigger cs05_shift_immutable
    before update on public.shifts
    for each row execute function private.cs05_shift_immutable();
