-- CS-06-P2C: Migrate to stock_items as canonical item master
--
-- ADR-CS06-01: stock_items adalah canonical item authority.
-- products (CS-06-P1) deprecated, capability dipindahkan ke stock_items.

-- 1. Extend stock_items: tambah base_unit_id FK ke units
alter table public.stock_items
    add column if not exists base_unit_id uuid references public.units(id) on delete restrict;

-- 2. stock_item_units (pengganti product_units)
create table public.stock_item_units (
    id uuid primary key default gen_random_uuid(),
    stock_item_id uuid not null references public.stock_items(id) on delete cascade,
    unit_id uuid not null references public.units(id) on delete restrict,
    conversion_factor numeric(18,6) not null check (conversion_factor > 0),
    is_base_unit boolean not null default false,
    barcode text,
    created_at timestamptz not null default now(),
    unique (stock_item_id, unit_id)
);
create index stock_item_units_stock_item_id_idx on public.stock_item_units(stock_item_id);
create index stock_item_units_unit_id_idx on public.stock_item_units(unit_id);
create unique index stock_item_units_barcode_idx on public.stock_item_units(barcode) where barcode is not null;
alter table public.stock_item_units enable row level security;
create policy "Tenant isolation for stock_item_units" on public.stock_item_units
    for all using (exists (
        select 1 from public.stock_items si
        where si.id = stock_item_id
          and si.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    ))
    with check (exists (
        select 1 from public.stock_items si
        where si.id = stock_item_id
          and si.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    ));

-- 3. stock_item_suppliers (pengganti product_suppliers)
create table public.stock_item_suppliers (
    id uuid primary key default gen_random_uuid(),
    stock_item_id uuid not null references public.stock_items(id) on delete cascade,
    supplier_id uuid not null references public.suppliers(id) on delete cascade,
    purchase_price numeric(18,4) not null check (purchase_price >= 0),
    currency text not null default 'IDR',
    moq integer not null default 1 check (moq > 0),
    lead_time_days integer not null default 0 check (lead_time_days >= 0),
    is_preferred boolean not null default false,
    created_at timestamptz not null default now(),
    unique (stock_item_id, supplier_id)
);
create index stock_item_suppliers_stock_item_id_idx on public.stock_item_suppliers(stock_item_id);
create index stock_item_suppliers_supplier_id_idx on public.stock_item_suppliers(supplier_id);
alter table public.stock_item_suppliers enable row level security;
create policy "Tenant isolation for stock_item_suppliers" on public.stock_item_suppliers
    for all using (exists (
        select 1 from public.stock_items si
        where si.id = stock_item_id
          and si.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    ))
    with check (exists (
        select 1 from public.stock_items si
        where si.id = stock_item_id
          and si.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    ));

-- 4. Deprecation notice untuk products (tidak drop, hanya tandai)
comment on table public.products is 'DEPRECATED (ADR-CS06-01): Gunakan stock_items sebagai canonical item master. Capability dipindahkan ke stock_item_units dan stock_item_suppliers.';
comment on table public.product_units is 'DEPRECATED (ADR-CS06-01): Gunakan stock_item_units.';
comment on table public.product_suppliers is 'DEPRECATED (ADR-CS06-01): Gunakan stock_item_suppliers.';
