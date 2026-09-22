-- C2-A: Sale Product / Variant / Sale-Stage Component Foundation
--
-- This migration separates POS presentation from stock authority without
-- replacing any existing sale, inventory, finance, refund, or correction writer.
--
-- Consumption-stage authority:
--   SALE       -> public.variant_sale_components
--   PRODUCTION -> existing public.boms / public.bom_lines
--
-- Production-stage recipe authority remains public.boms. C2-A intentionally
-- does not duplicate production recipes in a second variant component table.

create table public.sale_products (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    code text not null,
    display_name text not null,
    category_code text,
    description text,
    active boolean not null default true,
    legacy_stock_item_id uuid references public.stock_items(id) on delete restrict,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (business_id, code),
    constraint sale_products_code_format
        check (code ~ '^[A-Z0-9][A-Z0-9_-]{0,63}$'),
    constraint sale_products_display_name_nonempty
        check (length(btrim(display_name)) > 0)
);

create unique index sale_products_legacy_stock_item_unique
    on public.sale_products(business_id, legacy_stock_item_id)
    where legacy_stock_item_id is not null;

create index sale_products_business_active_category_idx
    on public.sale_products(business_id, active, category_code, display_name);

create table public.product_variants (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    product_id uuid not null references public.sale_products(id) on delete restrict,
    code text not null,
    display_name text not null,
    fulfillment_mode text not null,
    sale_stock_item_id uuid references public.stock_items(id) on delete restrict,
    sale_price numeric(18,2) not null,
    active boolean not null default true,
    is_default boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (product_id, code),
    constraint product_variants_code_format
        check (code ~ '^[A-Z0-9][A-Z0-9_-]{0,63}$'),
    constraint product_variants_display_name_nonempty
        check (length(btrim(display_name)) > 0),
    constraint product_variants_fulfillment_mode_valid
        check (fulfillment_mode in ('DIRECT_STOCK', 'MAKE_TO_ORDER', 'PREPRODUCED')),
    constraint product_variants_sale_price_positive
        check (sale_price > 0),
    constraint product_variants_stock_shape
        check (
            (
                fulfillment_mode in ('DIRECT_STOCK', 'PREPRODUCED')
                and sale_stock_item_id is not null
            )
            or (
                fulfillment_mode = 'MAKE_TO_ORDER'
                and sale_stock_item_id is null
            )
        )
);

create unique index product_variants_one_default_per_product_idx
    on public.product_variants(product_id)
    where is_default;

create index product_variants_business_active_idx
    on public.product_variants(business_id, active, product_id);

create index product_variants_sale_stock_item_idx
    on public.product_variants(sale_stock_item_id)
    where sale_stock_item_id is not null;

create table public.variant_sale_components (
    variant_id uuid not null references public.product_variants(id) on delete cascade,
    line_no integer not null,
    stock_item_id uuid not null references public.stock_items(id) on delete restrict,
    component_role text not null,
    quantity_per_unit numeric(18,3) not null,
    created_at timestamptz not null default now(),
    primary key (variant_id, line_no),
    unique (variant_id, stock_item_id),
    constraint variant_sale_components_line_no_positive
        check (line_no > 0),
    constraint variant_sale_components_role_valid
        check (component_role in ('INGREDIENT', 'PACKAGING', 'FINISHED_GOOD')),
    constraint variant_sale_components_quantity_positive
        check (quantity_per_unit > 0)
);

create index variant_sale_components_stock_item_idx
    on public.variant_sale_components(stock_item_id);

alter table public.sale_products enable row level security;
alter table public.product_variants enable row level security;
alter table public.variant_sale_components enable row level security;

create policy sale_products_tenant_read
on public.sale_products
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
);

create policy product_variants_tenant_read
on public.product_variants
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
);

create policy variant_sale_components_tenant_read
on public.variant_sale_components
for select
to authenticated
using (
    exists (
        select 1
        from public.product_variants v
        where v.id = variant_id
          and v.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    )
);

revoke all on table public.sale_products
from public, anon, authenticated;

revoke all on table public.product_variants
from public, anon, authenticated;

revoke all on table public.variant_sale_components
from public, anon, authenticated;

grant select on table public.sale_products to authenticated;
grant select on table public.product_variants to authenticated;
grant select on table public.variant_sale_components to authenticated;

create or replace function private.guard_sale_product_tenant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if new.legacy_stock_item_id is not null
       and not exists (
            select 1
            from public.stock_items si
            where si.id = new.legacy_stock_item_id
              and si.business_id = new.business_id
       ) then
        raise exception using errcode='23514', message='SALE_PRODUCT_STOCK_TENANT_MISMATCH';
    end if;

    return new;
end;
$$;

create trigger sale_products_guard_tenant
before insert or update on public.sale_products
for each row execute function private.guard_sale_product_tenant();

create or replace function private.guard_product_variant_tenant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if not exists (
        select 1
        from public.sale_products p
        where p.id = new.product_id
          and p.business_id = new.business_id
    ) then
        raise exception using errcode='23514', message='PRODUCT_VARIANT_PRODUCT_TENANT_MISMATCH';
    end if;

    if new.sale_stock_item_id is not null
       and not exists (
            select 1
            from public.stock_items si
            where si.id = new.sale_stock_item_id
              and si.business_id = new.business_id
       ) then
        raise exception using errcode='23514', message='PRODUCT_VARIANT_STOCK_TENANT_MISMATCH';
    end if;

    return new;
end;
$$;

create trigger product_variants_guard_tenant
before insert or update on public.product_variants
for each row execute function private.guard_product_variant_tenant();

create or replace function private.guard_variant_sale_component_tenant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_business uuid;
begin
    select v.business_id
    into v_business
    from public.product_variants v
    where v.id = new.variant_id;

    if v_business is null then
        raise exception using errcode='23503', message='PRODUCT_VARIANT_NOT_FOUND';
    end if;

    if not exists (
        select 1
        from public.stock_items si
        where si.id = new.stock_item_id
          and si.business_id = v_business
    ) then
        raise exception using errcode='23514', message='VARIANT_COMPONENT_STOCK_TENANT_MISMATCH';
    end if;

    return new;
end;
$$;

create trigger variant_sale_components_guard_tenant
before insert or update on public.variant_sale_components
for each row execute function private.guard_variant_sale_component_tenant();

revoke all on function private.guard_sale_product_tenant()
from public, anon, authenticated;

revoke all on function private.guard_product_variant_tenant()
from public, anon, authenticated;

revoke all on function private.guard_variant_sale_component_tenant()
from public, anon, authenticated;

-- Compatibility backfill.
-- Every current sale-enabled stock item becomes one sale product with one default
-- DIRECT_STOCK variant. This preserves current RC1 behaviour while creating the
-- new presentation/domain layer. No existing stock item is reclassified.
insert into public.sale_products (
    business_id,
    code,
    display_name,
    category_code,
    active,
    legacy_stock_item_id
)
select
    si.business_id,
    si.code,
    si.display_name,
    coalesce(si.sale_category, 'LAINNYA'),
    si.active,
    si.id
from public.stock_items si
where si.active
  and si.sale_enabled
  and si.sale_price is not null
  and si.sale_price > 0;

insert into public.product_variants (
    business_id,
    product_id,
    code,
    display_name,
    fulfillment_mode,
    sale_stock_item_id,
    sale_price,
    active,
    is_default
)
select
    sp.business_id,
    sp.id,
    'DEFAULT',
    sp.display_name,
    'DIRECT_STOCK',
    sp.legacy_stock_item_id,
    si.sale_price,
    true,
    true
from public.sale_products sp
join public.stock_items si
  on si.id = sp.legacy_stock_item_id
 and si.business_id = sp.business_id
where sp.legacy_stock_item_id is not null;

-- C2-A models the existing direct-stock sale as one SALE-stage FINISHED_GOOD
-- component. MAKE_TO_ORDER variants will later define INGREDIENT/PACKAGING rows
-- here. PREPRODUCED variants will consume their finished good here, while their
-- production-stage ingredients/packaging remain exclusively in BOM authority.
insert into public.variant_sale_components (
    variant_id,
    line_no,
    stock_item_id,
    component_role,
    quantity_per_unit
)
select
    v.id,
    1,
    v.sale_stock_item_id,
    'FINISHED_GOOD',
    1.000
from public.product_variants v
where v.fulfillment_mode = 'DIRECT_STOCK'
  and v.sale_stock_item_id is not null;

create or replace function public.sales_catalog_v2(p_location_id uuid)
returns table (
    sale_product_id uuid,
    product_code text,
    product_name text,
    category_code text,
    variant_id uuid,
    variant_code text,
    variant_name text,
    fulfillment_mode text,
    unit_price numeric,
    inventory_managed boolean,
    available_quantity numeric,
    sale_stock_item_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'SALE_EXECUTE') then
        raise exception using errcode='42501', message='SJ_PERMISSION_DENIED';
    end if;

    if not exists (
        select 1
        from public.shifts s
        where s.business_id = v_business
          and s.location_id = p_location_id
          and s.cashier_profile_id = v_actor
          and s.status = 'OPEN'
    ) then
        raise exception using errcode='42501', message='SJ_SHIFT_NOT_OPEN';
    end if;

    return query
    select
        p.id,
        p.code,
        p.display_name,
        coalesce(p.category_code, 'LAINNYA'),
        v.id,
        v.code,
        v.display_name,
        v.fulfillment_mode,
        v.sale_price,
        case
            when v.fulfillment_mode in ('DIRECT_STOCK','PREPRODUCED')
                then coalesce(sale_si.inventory_tracked, false)
            when v.fulfillment_mode = 'MAKE_TO_ORDER'
                then coalesce(cap.tracked_component_count, 0) > 0
            else false
        end,
        case
            when v.fulfillment_mode in ('DIRECT_STOCK','PREPRODUCED')
                 and coalesce(sale_si.inventory_tracked, false)
                then coalesce(sale_ib.quantity, 0::numeric)
            when v.fulfillment_mode = 'MAKE_TO_ORDER'
                 and coalesce(cap.tracked_component_count, 0) > 0
                then coalesce(cap.capacity, 0::numeric)
            else null::numeric
        end,
        v.sale_stock_item_id
    from public.sale_products p
    join public.product_variants v
      on v.product_id = p.id
     and v.business_id = p.business_id
    left join public.stock_items sale_si
      on sale_si.id = v.sale_stock_item_id
     and sale_si.business_id = v.business_id
    left join public.inventory_balances sale_ib
      on sale_ib.business_id = v.business_id
     and sale_ib.location_id = p_location_id
     and sale_ib.stock_item_id = v.sale_stock_item_id
    left join lateral (
        select
            count(*) filter (where component_si.inventory_tracked) as tracked_component_count,
            count(*) as component_count,
            min(
                floor(
                    coalesce(component_ib.quantity, 0::numeric)
                    / component.quantity_per_unit
                )
            ) filter (where component_si.inventory_tracked) as capacity
        from public.variant_sale_components component
        join public.stock_items component_si
          on component_si.id = component.stock_item_id
         and component_si.business_id = v.business_id
        left join public.inventory_balances component_ib
          on component_ib.business_id = v.business_id
         and component_ib.location_id = p_location_id
         and component_ib.stock_item_id = component.stock_item_id
        where component.variant_id = v.id
    ) cap on true
    where p.business_id = v_business
      and p.active
      and v.active
      and v.sale_price > 0
      and (
          (
              v.fulfillment_mode in ('DIRECT_STOCK','PREPRODUCED')
              and v.sale_stock_item_id is not null
          )
          or (
              v.fulfillment_mode = 'MAKE_TO_ORDER'
              and coalesce(cap.component_count, 0) > 0
          )
      )
    order by
        coalesce(p.category_code, 'LAINNYA'),
        p.display_name,
        case when v.is_default then 0 else 1 end,
        v.display_name;
end;
$$;

revoke execute on function public.sales_catalog_v2(uuid)
from public, anon, authenticated, service_role;

grant execute on function public.sales_catalog_v2(uuid) to authenticated;

comment on table public.sale_products is
'POS presentation authority. Stock authority remains public.stock_items.';

comment on table public.product_variants is
'POS sale variant authority. fulfillment_mode separates DIRECT_STOCK, MAKE_TO_ORDER, and PREPRODUCED behaviour.';

comment on table public.variant_sale_components is
'SALE-stage component mapping only. PRODUCTION-stage recipe authority remains public.boms/public.bom_lines.';

comment on function public.sales_catalog_v2(uuid) is
'Permission/shift-bounded Product/Variant catalog. Additive to legacy sales_catalog during convergence.';
