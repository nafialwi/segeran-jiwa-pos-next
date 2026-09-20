-- FIN-P3A: RLS authority bridge.
-- Keep internal permission helpers behind the public authority boundary.
-- RLS policies consume the public authority snapshot instead.

drop policy if exists customers_authorized_read on public.customers;
create policy customers_authorized_read
on public.customers
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and (
        coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
        or (public.get_my_authority() -> 'permissions' ? 'CUSTOMER_MANAGE')
        or (public.get_my_authority() -> 'permissions' ? 'CUSTOMER_DEBT_MANAGE')
    )
);

drop policy if exists customer_debts_authorized_read on public.customer_debts;
create policy customer_debts_authorized_read
on public.customer_debts
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and (
        coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
        or (public.get_my_authority() -> 'permissions' ? 'CUSTOMER_DEBT_MANAGE')
    )
);

drop policy if exists customer_debt_payments_authorized_read on public.customer_debt_payments;
create policy customer_debt_payments_authorized_read
on public.customer_debt_payments
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and (
        coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
        or (public.get_my_authority() -> 'permissions' ? 'CUSTOMER_DEBT_MANAGE')
    )
);
