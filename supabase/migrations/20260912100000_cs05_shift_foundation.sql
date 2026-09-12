-- CS-05 SHIFT FOUNDATION
-- Segeran Jiwa POS Next
-- Shift, cash transaction, and handover tables


create table public.shifts (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete cascade,
    location_id uuid not null references public.locations(id) on delete cascade,
    cashier_profile_id uuid not null references public.profiles(id) on delete restrict,

    opened_at timestamptz not null default now(),
    closed_at timestamptz,

    opening_balance numeric(18, 2) not null default 0,
    closing_balance numeric(18, 2),

    status text not null default 'OPEN' check (status in ('OPEN', 'CLOSED')),

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint shifts_closed_at_check check (closed_at is null or closed_at >= opened_at),
    constraint shifts_closing_balance_check check (closing_balance is null or status = 'CLOSED'),
    constraint shifts_open_shift_unique unique (business_id, location_id, cashier_profile_id) where (status = 'OPEN')
);


create table public.cash_transactions (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete cascade,
    location_id uuid not null references public.locations(id) on delete cascade,
    shift_id uuid not null references public.shifts(id) on delete cascade,
    cashier_profile_id uuid not null references public.profiles(id) on delete restrict,

    transaction_type text not null check (transaction_type in ('SALE', 'REFUND', 'CASH_IN', 'CASH_OUT', 'ADJUSTMENT')),
    amount numeric(18, 2) not null check (amount > 0),

    reference_type text,
    reference_id uuid,

    notes text,

    created_at timestamptz not null default now()
);


create table public.handovers (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete cascade,
    location_id uuid not null references public.locations(id) on delete cascade,

    from_shift_id uuid not null references public.shifts(id) on delete cascade,
    to_shift_id uuid references public.shifts(id) on delete set null,

    from_cashier_profile_id uuid not null references public.profiles(id) on delete restrict,
    to_cashier_profile_id uuid references public.profiles(id) on delete restrict,

    expected_balance numeric(18, 2) not null,
    actual_balance numeric(18, 2) not null,
    discrepancy numeric(18, 2) generated always as (actual_balance - expected_balance) stored,

    status text not null default 'PENDING' check (status in ('PENDING', 'ACCEPTED', 'REJECTED')),

    notes text,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint handovers_from_to_shift_check check (from_shift_id != to_shift_id or to_shift_id is null)
);


create index idx_shifts_business_location on public.shifts(business_id, location_id);
create index idx_shifts_cashier on public.shifts(cashier_profile_id);
create index idx_shifts_status on public.shifts(status) where (status = 'OPEN');

create index idx_cash_transactions_shift on public.cash_transactions(shift_id);
create index idx_cash_transactions_business_location on public.cash_transactions(business_id, location_id);
create index idx_cash_transactions_type on public.cash_transactions(transaction_type);
create index idx_cash_transactions_created_at on public.cash_transactions(created_at desc);

create index idx_handovers_business_location on public.handovers(business_id, location_id);
create index idx_handovers_from_shift on public.handovers(from_shift_id);
create index idx_handovers_to_shift on public.handovers(to_shift_id) where (to_shift_id is not null);
create index idx_handovers_status on public.handovers(status) where (status = 'PENDING');


comment on table public.shifts is 'Cashier shift records (open/close)';
comment on column public.shifts.opening_balance is 'Cash balance at shift start';
comment on column public.shifts.closing_balance is 'Cash balance at shift end (null if still open)';
comment on column public.shifts.status is 'OPEN or CLOSED';

comment on table public.cash_transactions is 'Cash movements during a shift';
comment on column public.cash_transactions.transaction_type is 'SALE, REFUND, CASH_IN, CASH_OUT, or ADJUSTMENT';
comment on column public.cash_transactions.reference_type is 'Optional: sale, refund, etc.';
comment on column public.cash_transactions.reference_id is 'Optional: ID of referenced record';

comment on table public.handovers is 'Cash handover between shifts';
comment on column public.handovers.discrepancy is 'Calculated: actual_balance - expected_balance';
comment on column public.handovers.status is 'PENDING, ACCEPTED, or REJECTED';
