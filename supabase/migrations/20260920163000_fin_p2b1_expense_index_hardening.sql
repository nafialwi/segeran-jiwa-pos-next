-- FIN-P2B1: Expense index hardening.
-- Cover foreign keys reported by the hosted performance advisor.

create index if not exists business_expenses_location_idx
    on public.business_expenses(location_id);

create index if not exists business_expenses_funding_account_idx
    on public.business_expenses(funding_account_id);
