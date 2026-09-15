-- CS-06-P3: Purchase Orders (PO)
--
-- ADR-CS06-01: stock_items adalah canonical item authority.
-- PO tidak mengubah stok. Stok naik hanya saat GRN POSTED.

-- 1. purchase_orders (header)
create table public.purchase_orders (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    order_number text not null,
    supplier_id uuid not null references public.suppliers(id) on delete restrict,
    location_id uuid not null references public.locations(id) on delete restrict,
    status text not null default 'DRAFT',
    ordered_at timestamptz not null default now(),
    expected_at timestamptz,
    notes text,
    created_by uuid references public.profiles(id) on delete set null,
    approved_by uuid references public.profiles(id) on delete set null,
    approved_at timestamptz,
    cancelled_by uuid references public.profiles(id) on delete set null,
    cancelled_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (business_id, order_number),
    constraint purchase_orders_status_valid check (
        status in ('DRAFT', 'SUBMITTED', 'APPROVED', 'PARTIALLY_RECEIVED', 'RECEIVED', 'CANCELLED')
    ),
    constraint purchase_orders_order_number_nonempty check (length(btrim(order_number)) > 0)
);
create index purchase_orders_business_id_idx on public.purchase_orders(business_id);
create index purchase_orders_supplier_id_idx on public.purchase_orders(supplier_id);
create index purchase_orders_location_id_idx on public.purchase_orders(location_id);
create index purchase_orders_status_idx on public.purchase_orders(status);
alter table public.purchase_orders enable row level security;
create policy "Tenant isolation for purchase_orders" on public.purchase_orders
    for all using (business_id = (public.get_my_authority() ->> 'business_id')::uuid)
    with check (business_id = (public.get_my_authority() ->> 'business_id')::uuid);

-- 2. purchase_order_lines (detail)
create table public.purchase_order_lines (
    id uuid primary key default gen_random_uuid(),
    purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
    stock_item_id uuid not null references public.stock_items(id) on delete restrict,
    unit_id uuid not null references public.units(id) on delete restrict,
    ordered_quantity numeric(18,4) not null,
    conversion_factor_snapshot numeric(18,6) not null,
    base_quantity numeric(18,4) not null,
    unit_price numeric(18,4) not null,
    discount_amount numeric(18,4) not null default 0,
    tax_amount numeric(18,4) not null default 0,
    line_total numeric(18,4) not null,
    notes text,
    created_at timestamptz not null default now(),
    constraint purchase_order_lines_ordered_qty_positive check (ordered_quantity > 0),
    constraint purchase_order_lines_conversion_positive check (conversion_factor_snapshot > 0),
    constraint purchase_order_lines_base_qty_positive check (base_quantity > 0),
    constraint purchase_order_lines_unit_price_nonneg check (unit_price >= 0),
    constraint purchase_order_lines_discount_nonneg check (discount_amount >= 0),
    constraint purchase_order_lines_tax_nonneg check (tax_amount >= 0)
);
create index purchase_order_lines_po_id_idx on public.purchase_order_lines(purchase_order_id);
create index purchase_order_lines_stock_item_id_idx on public.purchase_order_lines(stock_item_id);
alter table public.purchase_order_lines enable row level security;
create policy "Tenant isolation for purchase_order_lines" on public.purchase_order_lines
    for all using (exists (
        select 1 from public.purchase_orders po
        where po.id = purchase_order_id
          and po.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    ))
    with check (exists (
        select 1 from public.purchase_orders po
        where po.id = purchase_order_id
          and po.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    ));
