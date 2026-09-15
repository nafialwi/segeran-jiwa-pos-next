-- CS-06-P2B: Inventory Balances (stock per product per location)

create table public.inventory_balances (
    id uuid primary key default gen_random_uuid(),
    product_id uuid not null references public.products(id) on delete cascade,
    location_id uuid not null references public.locations(id) on delete restrict,
    quantity numeric(18,6) not null default 0 check (quantity >= 0),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (product_id, location_id)
);
create index inventory_balances_product_id_idx on public.inventory_balances(product_id);
create index inventory_balances_location_id_idx on public.inventory_balances(location_id);
alter table public.inventory_balances enable row level security;
create policy "Tenant isolation for inventory_balances" on public.inventory_balances
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
