begin;

-- C2-A source/runtime regression is intentionally read-only against the new
-- domain model. Fixtures are not needed because the migration backfills the
-- currently sale-enabled stock items.

do $$
declare
    v_expected integer;
    v_products integer;
    v_variants integer;
    v_components integer;
    v_catalog_def text;
begin
    select count(*)
    into v_expected
    from public.stock_items si
    where si.active
      and si.sale_enabled
      and si.sale_price is not null
      and si.sale_price > 0;

    select count(*)
    into v_products
    from public.sale_products sp
    join public.stock_items si
      on si.id = sp.legacy_stock_item_id
     and si.business_id = sp.business_id
    where si.active
      and si.sale_enabled
      and si.sale_price is not null
      and si.sale_price > 0;

    if v_products <> v_expected then
        raise exception 'C2A_DIRECT_STOCK_BACKFILL_FAILED';
    end if;

    select count(*)
    into v_variants
    from public.product_variants v
    join public.sale_products sp on sp.id = v.product_id
    where sp.legacy_stock_item_id is not null
      and v.fulfillment_mode = 'DIRECT_STOCK'
      and v.is_default
      and v.sale_stock_item_id = sp.legacy_stock_item_id;

    if v_variants <> v_expected then
        raise exception 'C2A_DIRECT_STOCK_VARIANT_BACKFILL_FAILED';
    end if;

    select count(*)
    into v_components
    from public.variant_sale_components c
    join public.product_variants v on v.id = c.variant_id
    join public.sale_products sp on sp.id = v.product_id
    where sp.legacy_stock_item_id is not null
      and c.component_role = 'FINISHED_GOOD'
      and c.stock_item_id = v.sale_stock_item_id
      and c.quantity_per_unit = 1.000;

    if v_components <> v_expected then
        raise exception 'C2A_DIRECT_STOCK_COMPONENT_BACKFILL_FAILED';
    end if;

    v_catalog_def := pg_get_functiondef(
        'public.sales_catalog_v2(uuid)'::regprocedure
    );

    if position('SALE_EXECUTE' in v_catalog_def) = 0
       or position('SJ_SHIFT_NOT_OPEN' in v_catalog_def) = 0
       or position('variant_sale_components' in v_catalog_def) = 0 then
        raise exception 'C2A_SALES_CATALOG_V2_CONTRACT_FAILED';
    end if;
end $$;

rollback;
