begin;

do $$
begin
    if not exists (
        select 1 from information_schema.columns
        where table_schema='public'
          and table_name='stock_items'
          and column_name='sale_price'
    ) then
        raise exception 'UAT_RECOVERY_SALE_PRICE_MISSING';
    end if;

    if to_regclass('public.legacy_master_imports') is null then
        raise exception 'UAT_RECOVERY_IMPORT_TABLE_MISSING';
    end if;

    if to_regclass('public.business_checkout_settings') is null then
        raise exception 'UAT_RECOVERY_CHECKOUT_SETTINGS_MISSING';
    end if;

    if to_regprocedure('public.import_legacy_master(uuid,jsonb,jsonb,jsonb,jsonb,text)') is null then
        raise exception 'UAT_RECOVERY_IMPORT_RPC_MISSING';
    end if;

    if to_regprocedure('public.sales_catalog(uuid)') is null then
        raise exception 'UAT_RECOVERY_SALES_CATALOG_MISSING';
    end if;

    if to_regprocedure('public.inventory_operational_overview()') is null then
        raise exception 'UAT_RECOVERY_INVENTORY_OVERVIEW_MISSING';
    end if;

    if to_regprocedure('public.purchase_operational_overview()') is null then
        raise exception 'UAT_RECOVERY_PURCHASE_OVERVIEW_MISSING';
    end if;
end
$$;

rollback;
