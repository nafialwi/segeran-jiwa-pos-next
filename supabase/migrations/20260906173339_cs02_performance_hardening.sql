create index audit_events_business_id_idx on public.audit_events (business_id);
create index audit_events_actor_profile_id_idx on public.audit_events (actor_profile_id);
create index audit_events_operation_receipt_id_idx on public.audit_events (operation_receipt_id);
create index business_memberships_profile_id_idx on public.business_memberships (profile_id);
create index business_memberships_role_code_idx on public.business_memberships (role_code);
create index inventory_movement_lines_stock_item_id_idx on public.inventory_movement_lines (stock_item_id);
create index inventory_movement_lines_location_id_idx on public.inventory_movement_lines (location_id);
create index inventory_movements_business_id_idx on public.inventory_movements (business_id);
create index inventory_movements_actor_profile_id_idx on public.inventory_movements (actor_profile_id);
create index money_movements_business_id_idx on public.money_movements (business_id);
create index money_movements_actor_profile_id_idx on public.money_movements (actor_profile_id);
create index money_movements_from_account_id_idx on public.money_movements (from_account_id);
create index money_movements_to_account_id_idx on public.money_movements (to_account_id);
create index operation_receipts_actor_profile_id_idx on public.operation_receipts (actor_profile_id);

drop policy profiles_self_read on public.profiles;
drop policy profiles_owner_read on public.profiles;

create policy profiles_authorized_read on public.profiles
for select to authenticated
using (
    auth_user_id = (select auth.uid())
    or exists (
        select 1
        from public.business_memberships m
        where m.profile_id = profiles.id
          and private.is_owner(m.business_id)
    )
);