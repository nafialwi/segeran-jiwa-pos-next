-- FIN-P5B: Supplier read authority bridge.
-- Purchase users need supplier reads, while ordinary cashiers must not gain them.

drop policy if exists "Tenant isolation for suppliers" on public.suppliers;
drop policy if exists suppliers_purchase_read on public.suppliers;

create policy suppliers_purchase_read
on public.suppliers
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and (
        coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
        or (public.get_my_authority() -> 'permissions' ? 'PURCHASE_MANAGE')
    )
);

revoke all on table public.suppliers from anon, authenticated;
grant select on table public.suppliers to authenticated;
