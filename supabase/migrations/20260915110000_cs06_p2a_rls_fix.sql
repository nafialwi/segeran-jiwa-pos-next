-- CS-06-P2a: Fix RLS policies to use get_my_authority() helper (consistent with CS-05)

-- Drop existing policies that use auth.jwt() directly
drop policy if exists "Tenant isolation for units" on public.units;
drop policy if exists "Tenant isolation for suppliers" on public.suppliers;
drop policy if exists "Tenant isolation for products" on public.products;
drop policy if exists "Tenant isolation for product_units" on public.product_units;
drop policy if exists "Tenant isolation for product_suppliers" on public.product_suppliers;

-- Recreate policies using public.get_my_authority() helper (same as CS-05)
create policy "Tenant isolation for units" on public.units
    for all using (business_id = (public.get_my_authority() ->> 'business_id')::uuid)
    with check (business_id = (public.get_my_authority() ->> 'business_id')::uuid);

create policy "Tenant isolation for suppliers" on public.suppliers
    for all using (business_id = (public.get_my_authority() ->> 'business_id')::uuid)
    with check (business_id = (public.get_my_authority() ->> 'business_id')::uuid);

create policy "Tenant isolation for products" on public.products
    for all using (business_id = (public.get_my_authority() ->> 'business_id')::uuid)
    with check (business_id = (public.get_my_authority() ->> 'business_id')::uuid);

create policy "Tenant isolation for product_units" on public.product_units
    for all using (exists (
        select 1 from public.products p
        where p.id = product_id
          and p.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    ))
    with check (exists (
        select 1 from public.products p
        where p.id = product_id
          and p.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    ));

create policy "Tenant isolation for product_suppliers" on public.product_suppliers
    for all using (exists (
        select 1 from public.products p
        where p.id = product_id
          and p.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    ))
    with check (exists (
        select 1 from public.products p
        where p.id = product_id
          and p.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    ));
