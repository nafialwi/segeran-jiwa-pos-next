create or replace function private.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
    select p.id
    from public.profiles p
    where p.auth_user_id = auth.uid()
      and p.status = 'ACTIVE'
    limit 1;
$$;

create or replace function private.is_active_member(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.business_memberships m
        join public.profiles p on p.id = m.profile_id
        where m.business_id = p_business_id
          and m.active
          and p.status = 'ACTIVE'
          and p.auth_user_id = auth.uid()
    );
$$;

create or replace function private.is_owner(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.business_memberships m
        join public.profiles p on p.id = m.profile_id
        join public.access_roles r on r.code = m.role_code
        where m.business_id = p_business_id
          and m.active
          and p.status = 'ACTIVE'
          and p.auth_user_id = auth.uid()
          and r.owner_level
          and r.active
    );
$$;

alter table public.businesses enable row level security;
alter table public.profiles enable row level security;
alter table public.access_roles enable row level security;
alter table public.business_memberships enable row level security;
alter table public.locations enable row level security;
alter table public.stock_items enable row level security;
alter table public.money_accounts enable row level security;
alter table public.operation_receipts enable row level security;
alter table public.audit_events enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.inventory_movement_lines enable row level security;
alter table public.money_movements enable row level security;

create policy businesses_member_read on public.businesses
for select to authenticated
using (private.is_active_member(id));

create policy profiles_self_read on public.profiles
for select to authenticated
using (auth_user_id = auth.uid());

create policy profiles_owner_read on public.profiles
for select to authenticated
using (
    exists (
        select 1 from public.business_memberships m
        where m.profile_id = profiles.id
          and private.is_owner(m.business_id)
    )
);

create policy access_roles_authenticated_read on public.access_roles
for select to authenticated
using (true);

create policy memberships_owner_read on public.business_memberships
for select to authenticated
using (private.is_owner(business_id));

create policy locations_member_read on public.locations
for select to authenticated
using (private.is_active_member(business_id));

create policy stock_items_member_read on public.stock_items
for select to authenticated
using (private.is_active_member(business_id));

create policy money_accounts_member_read on public.money_accounts
for select to authenticated
using (private.is_active_member(business_id));

create policy operation_receipts_member_read on public.operation_receipts
for select to authenticated
using (private.is_active_member(business_id));

create policy audit_events_member_read on public.audit_events
for select to authenticated
using (private.is_active_member(business_id));

create policy inventory_movements_member_read on public.inventory_movements
for select to authenticated
using (private.is_active_member(business_id));

create policy inventory_movement_lines_member_read on public.inventory_movement_lines
for select to authenticated
using (
    exists (
        select 1
        from public.inventory_movements m
        where m.id = inventory_movement_lines.movement_id
          and private.is_active_member(m.business_id)
    )
);

create policy money_movements_member_read on public.money_movements
for select to authenticated
using (private.is_active_member(business_id));

revoke insert, update, delete on public.operation_receipts from anon, authenticated;
revoke insert, update, delete on public.audit_events from anon, authenticated;
revoke insert, update, delete on public.inventory_movements from anon, authenticated;
revoke insert, update, delete on public.inventory_movement_lines from anon, authenticated;
revoke insert, update, delete on public.money_movements from anon, authenticated;

revoke all on function private.record_inventory_movement(uuid, uuid, text, text, text, text, text, jsonb, uuid) from public, anon, authenticated;
revoke all on function private.record_money_movement(uuid, uuid, text, text, uuid, uuid, numeric, text, text, text, uuid) from public, anon, authenticated;
revoke all on function private.lock_operation(uuid, text, text, text) from public, anon, authenticated;
revoke all on function private.record_operation_success(uuid, text, text, text, text, uuid, uuid) from public, anon, authenticated;
revoke all on function private.payload_sha256(jsonb) from public, anon, authenticated;

revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.current_profile_id() to authenticated;
grant execute on function private.is_active_member(uuid) to authenticated;
grant execute on function private.is_owner(uuid) to authenticated;