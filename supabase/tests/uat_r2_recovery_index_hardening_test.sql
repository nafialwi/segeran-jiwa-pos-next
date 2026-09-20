begin;
do $$
begin
  if to_regclass('public.business_checkout_settings_updated_by_idx') is null then
    raise exception 'UAT_R2_CHECKOUT_UPDATED_BY_INDEX_MISSING';
  end if;
  if to_regclass('public.legacy_master_imports_inventory_movement_idx') is null then
    raise exception 'UAT_R2_IMPORT_MOVEMENT_INDEX_MISSING';
  end if;
end $$;
rollback;
