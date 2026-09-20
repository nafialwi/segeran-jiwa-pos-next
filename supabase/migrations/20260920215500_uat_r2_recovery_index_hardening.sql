-- UAT-R2: covering indexes for recovery-owned foreign keys.

create index if not exists business_checkout_settings_updated_by_idx
    on public.business_checkout_settings(updated_by);

create index if not exists legacy_master_imports_inventory_movement_idx
    on public.legacy_master_imports(inventory_movement_id)
    where inventory_movement_id is not null;
