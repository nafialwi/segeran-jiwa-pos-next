-- ==========================================
-- CS-06 P1: Inventory Foundation (Products, Suppliers, Units)
-- ==========================================

-- 1. UNITS (Satuan)
create table public.units (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    code text not null,
    display_name text not null,
    system boolean not null default false,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    unique (business_id, code),
    constraint units_code_format check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,15}$'),
    constraint units_display_name_nonempty check (length(btrim(display_name)) > 0)
);
create index units_business_id_idx on public.units(business_id);
alter table public.units enable row level security;
create policy "Tenant isolation for units" on public.units
    for all using (business_id = (auth.jwt() ->> 'business_id')::uuid)
    with check (business_id = (auth.jwt() ->> 'business_id')::uuid);

-- 2. SUPPLIERS (Vendor)
create table public.suppliers (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    code text not null,
    display_name text not null,
    contact_name text,
    phone text,
    email text,
    address text,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    unique (business_id, code),
    constraint suppliers_code_format check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
    constraint suppliers_display_name_nonempty check (length(btrim(display_name)) > 0)
);
create index suppliers_business_id_idx on public.suppliers(business_id);
alter table public.suppliers enable row level security;
create policy "Tenant isolation for suppliers" on public.suppliers
    for all using (business_id = (auth.jwt() ->> 'business_id')::uuid)
    with check (business_id = (auth.jwt() ->> 'business_id')::uuid);

-- 3. PRODUCTS (Master Produk)
create table public.products (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    sku text not null,
    display_name text not null,
    description text,
    category text,
    base_unit_id uuid not null references public.units(id) on delete restrict,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    unique (business_id, sku),
    constraint products_sku_format check (sku ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
    constraint products_display_name_nonempty check (length(btrim(display_name)) > 0)
);
create index products_business_id_idx on public.products(business_id);
create index products_base_unit_id_idx on public.products(base_unit_id);
alter table public.products enable row level security;
create policy "Tenant isolation for products" on public.products
    for all using (business_id = (auth.jwt() ->> 'business_id')::uuid)
    with check (business_id = (auth.jwt() ->> 'business_id')::uuid);

-- 4. PRODUCT_UNITS (Konversi Unit per Produk)
create table public.product_units (
    id uuid primary key default gen_random_uuid(),
    product_id uuid not null references public.products(id) on delete cascade,
    unit_id uuid not null references public.units(id) on delete restrict,
    conversion_factor numeric(18,6) not null check (conversion_factor > 0),
    barcode text,
    unique (product_id, unit_id)
);
create unique index product_units_unique_barcode_idx on public.product_units(barcode) where barcode is not null;
create index product_units_product_id_idx on public.product_units(product_id);
alter table public.product_units enable row level security;
create policy "Tenant isolation for product_units" on public.product_units
    for all using (exists (select 1 from public.products p where p.id = product_id and p.business_id = (auth.jwt() ->> 'business_id')::uuid))
    with check (exists (select 1 from public.products p where p.id = product_id and p.business_id = (auth.jwt() ->> 'business_id')::uuid));

-- 5. PRODUCT_SUPPLIERS (Harga Beli, MOQ, Lead Time)
create table public.product_suppliers (
    id uuid primary key default gen_random_uuid(),
    product_id uuid not null references public.products(id) on delete cascade,
    supplier_id uuid not null references public.suppliers(id) on delete cascade,
    purchase_price numeric(18,4) not null check (purchase_price >= 0),
    currency text not null default 'IDR',
    moq integer not null default 1 check (moq > 0),
    lead_time_days integer not null default 0 check (lead_time_days >= 0),
    is_preferred boolean not null default false,
    unique (product_id, supplier_id)
);
create index product_suppliers_product_id_idx on public.product_suppliers(product_id);
create index product_suppliers_supplier_id_idx on public.product_suppliers(supplier_id);
alter table public.product_suppliers enable row level security;
create policy "Tenant isolation for product_suppliers" on public.product_suppliers
    for all using (exists (select 1 from public.products p where p.id = product_id and p.business_id = (auth.jwt() ->> 'business_id')::uuid))
    with check (exists (select 1 from public.products p where p.id = product_id and p.business_id = (auth.jwt() ->> 'business_id')::uuid));
