insert into private.schema_versions (
    version,
    milestone,
    blueprint_baseline,
    source_anchor
)
values (
    2,
    'CS-03',
    '1.0',
    '498a01968e11f320622cefa822c591e3018f20e4'
);

create table public.user_login_identities (
    profile_id uuid primary key references public.profiles(id) on delete restrict,
    username text not null,
    normalized_username text generated always as (lower(btrim(username))) stored,
    created_at timestamptz not null default now(),
    constraint user_login_username_format
        check (lower(btrim(username)) ~ '^[a-z0-9][a-z0-9_-]{2,31}$'),
    constraint user_login_normalized_unique unique (normalized_username)
);

create table public.permission_definitions (
    code text primary key,
    display_name text not null,
    category text not null,
    active boolean not null default true,
    constraint permission_code_format check (code ~ '^[A-Z][A-Z0-9_]{2,63}$')
);

create table public.role_permissions (
    role_code text not null references public.access_roles(code) on delete restrict,
    permission_code text not null references public.permission_definitions(code) on delete restrict,
    allowed boolean not null default true,
    primary key (role_code, permission_code)
);

create table public.user_permission_overrides (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    profile_id uuid not null references public.profiles(id) on delete restrict,
    permission_code text not null references public.permission_definitions(code) on delete restrict,
    effect text not null,
    set_by_profile_id uuid not null references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (business_id, profile_id, permission_code),
    constraint permission_override_effect_valid check (effect in ('ALLOW', 'DENY'))
);

insert into public.permission_definitions (code, display_name, category)
values
    ('SALE_EXECUTE', 'Jual', 'PENJUALAN'),
    ('SHIFT_OPEN_CLOSE', 'Buka/Tutup Shift', 'SHIFT'),
    ('SHIFT_READ_OWN', 'Ringkasan Shift Sendiri', 'SHIFT'),
    ('EXPENSE_SHIFT_CREATE', 'Catat Pengeluaran Shift', 'SHIFT'),
    ('INVENTORY_READ', 'Lihat Persediaan', 'PERSEDIAAN'),
    ('PAYMENT_QRIS', 'Gunakan QRIS', 'PEMBAYARAN'),
    ('PAYMENT_TRANSFER', 'Gunakan Transfer', 'PEMBAYARAN'),
    ('CUSTOMER_DEBT_MANAGE', 'Kelola Hutang Pelanggan', 'PELANGGAN'),
    ('INVENTORY_TRANSFER', 'Transfer Barang', 'PERSEDIAAN'),
    ('PURCHASE_MANAGE', 'Kelola Pembelian', 'PEMBELIAN'),
    ('PRODUCTION_MANAGE', 'Kelola Produksi', 'PRODUKSI'),
    ('CUSTOMER_MANAGE', 'Kelola Pelanggan', 'PELANGGAN'),
    ('EMPLOYEE_MANAGE', 'Kelola Karyawan', 'KARYAWAN'),
    ('CORRECTION_LIMITED', 'Koreksi Terbatas', 'KOREKSI'),
    ('REPORT_SALES_LIMITED', 'Laporan Penjualan Terbatas', 'LAPORAN'),
    ('REPORT_INVENTORY', 'Laporan Persediaan', 'LAPORAN'),
    ('REPORT_PURCHASE', 'Laporan Pembelian', 'LAPORAN'),
    ('REPORT_PRODUCTION', 'Laporan Produksi', 'LAPORAN'),
    ('SETTINGS_NONCRITICAL', 'Pengaturan Non-Kritis', 'PENGATURAN');

insert into public.role_permissions (role_code, permission_code, allowed)
values
    ('KASIR', 'SALE_EXECUTE', true),
    ('KASIR', 'SHIFT_OPEN_CLOSE', true),
    ('KASIR', 'SHIFT_READ_OWN', true);

create table public.trusted_devices (
    id uuid primary key,
    business_id uuid not null references public.businesses(id) on delete restrict,
    friendly_name text not null,
    device_kind text not null,
    platform_label text not null,
    created_at timestamptz not null default now(),
    last_seen_at timestamptz not null default now(),
    retired_at timestamptz,
    unique (business_id, id),
    constraint trusted_device_name_nonempty check (length(btrim(friendly_name)) > 0),
    constraint trusted_device_kind_valid check (device_kind in ('PERSONAL', 'SHARED'))
);

create table public.user_device_access (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    profile_id uuid not null references public.profiles(id) on delete restrict,
    device_id uuid not null,
    trusted_at timestamptz not null default now(),
    last_seen_at timestamptz not null default now(),
    revoked_at timestamptz,
    revoked_by_profile_id uuid references public.profiles(id) on delete restrict,
    removed_from_active_list_at timestamptz,
    unique (business_id, profile_id, device_id),
    foreign key (business_id, device_id)
        references public.trusted_devices(business_id, id)
        on delete restrict
);

create table public.session_registry (
    session_id uuid primary key,
    business_id uuid not null references public.businesses(id) on delete restrict,
    profile_id uuid not null references public.profiles(id) on delete restrict,
    device_id uuid not null,
    started_at timestamptz not null default now(),
    last_seen_at timestamptz not null default now(),
    revoked_at timestamptz,
    revoked_by_profile_id uuid references public.profiles(id) on delete restrict,
    revoke_reason text,
    foreign key (business_id, device_id)
        references public.trusted_devices(business_id, id)
        on delete restrict
);

create index user_permission_overrides_profile_idx
    on public.user_permission_overrides (business_id, profile_id);

create index user_device_access_profile_idx
    on public.user_device_access (business_id, profile_id);

create index session_registry_profile_idx
    on public.session_registry (business_id, profile_id);

create index session_registry_device_idx
    on public.session_registry (business_id, device_id);

alter table public.user_login_identities enable row level security;
alter table public.permission_definitions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.user_permission_overrides enable row level security;
alter table public.trusted_devices enable row level security;
alter table public.user_device_access enable row level security;
alter table public.session_registry enable row level security;

revoke all on public.user_login_identities from anon, authenticated;
revoke all on public.permission_definitions from anon, authenticated;
revoke all on public.role_permissions from anon, authenticated;
revoke all on public.user_permission_overrides from anon, authenticated;
revoke all on public.trusted_devices from anon, authenticated;
revoke all on public.user_device_access from anon, authenticated;
revoke all on public.session_registry from anon, authenticated;

-- CS-03 Task 3: live session authority and narrow RPCs.

create or replace function private.normalize_username(p_username text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
    select lower(btrim(p_username));
$$;

create or replace function private.current_session_id()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
    raw text;
begin
    raw := auth.jwt() ->> 'session_id';
    if raw is null or raw = '' then
        return null;
    end if;
    return raw::uuid;
exception when invalid_text_representation then
    return null;
end;
$$;

create or replace function private.current_session_allowed(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.profiles p
        join public.session_registry sr
          on sr.profile_id = p.id
         and sr.business_id = p_business_id
        join public.user_device_access uda
          on uda.profile_id = p.id
         and uda.business_id = sr.business_id
         and uda.device_id = sr.device_id
        join public.trusted_devices td
          on td.business_id = sr.business_id
         and td.id = sr.device_id
        where p.auth_user_id = (select auth.uid())
          and p.status = 'ACTIVE'
          and sr.session_id = private.current_session_id()
          and sr.revoked_at is null
          and uda.revoked_at is null
          and uda.removed_from_active_list_at is null
          and td.retired_at is null
          and exists (
              select 1
              from auth.sessions s
              where s.id = sr.session_id
                and s.user_id = p.auth_user_id
          )
    );
$$;

create or replace function private.is_active_member(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select private.current_session_allowed(p_business_id)
       and exists (
           select 1
           from public.business_memberships m
           where m.business_id = p_business_id
             and m.profile_id = private.current_profile_id()
             and m.active
       );
$$;

create or replace function private.is_owner(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select private.is_active_member(p_business_id)
       and exists (
           select 1
           from public.business_memberships m
           join public.access_roles r on r.code = m.role_code
           where m.business_id = p_business_id
             and m.profile_id = private.current_profile_id()
             and m.active
             and r.active
             and r.owner_level
       );
$$;

create or replace function private.has_permission(
    p_business_id uuid,
    p_permission_code text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    with actor as (
        select m.profile_id, m.role_code, r.owner_level
        from public.business_memberships m
        join public.access_roles r on r.code = m.role_code
        where m.business_id = p_business_id
          and m.profile_id = private.current_profile_id()
          and m.active
          and r.active
          and private.is_active_member(p_business_id)
    ),
    definition as (
        select code
        from public.permission_definitions
        where code = p_permission_code
          and active
    ),
    override_value as (
        select o.effect
        from public.user_permission_overrides o
        join actor a on a.profile_id = o.profile_id
        where o.business_id = p_business_id
          and o.permission_code = p_permission_code
    ),
    preset as (
        select rp.allowed
        from public.role_permissions rp
        join actor a on a.role_code = rp.role_code
        where rp.permission_code = p_permission_code
    )
    select exists(select 1 from definition)
       and exists(select 1 from actor)
       and (
           coalesce((select owner_level from actor limit 1), false)
           or (
               not coalesce((select effect = 'DENY' from override_value), false)
               and (
                   coalesce((select effect = 'ALLOW' from override_value), false)
                   or (
                       not exists(select 1 from override_value)
                       and coalesce((select allowed from preset), false)
                   )
               )
           )
       );
$$;

create or replace function private.build_authority_json(p_business_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
    select jsonb_build_object(
        'profile_id', p.id,
        'business_id', m.business_id,
        'username', uli.normalized_username,
        'display_name', p.display_name,
        'status', p.status,
        'role_code', m.role_code,
        'owner', r.owner_level,
        'permissions', coalesce((
            select jsonb_agg(pd.code order by pd.code)
            from public.permission_definitions pd
            where pd.active
              and private.has_permission(m.business_id, pd.code)
        ), '[]'::jsonb),
        'session_id', private.current_session_id(),
        'device_id', sr.device_id,
        'device_kind', td.device_kind
    )
    from public.profiles p
    join public.user_login_identities uli on uli.profile_id = p.id
    join public.business_memberships m on m.profile_id = p.id and m.active
    join public.access_roles r on r.code = m.role_code and r.active
    join public.session_registry sr
      on sr.profile_id = p.id
     and sr.business_id = m.business_id
     and sr.session_id = private.current_session_id()
    join public.trusted_devices td
      on td.business_id = sr.business_id
     and td.id = sr.device_id
    where p.auth_user_id = (select auth.uid())
      and m.business_id = p_business_id
      and private.is_active_member(m.business_id);
$$;

create or replace function public.bootstrap_current_session(
    p_device_id uuid,
    p_device_kind text,
    p_friendly_name text,
    p_platform_label text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_profile public.profiles%rowtype;
    v_business_id uuid;
    v_session_id uuid;
    v_membership_count integer;
    v_access public.user_device_access%rowtype;
begin
    if p_device_id is null then
        raise exception using errcode = '22023', message = 'SJ_DEVICE_ID_REQUIRED';
    end if;
    if p_device_kind not in ('PERSONAL', 'SHARED') then
        raise exception using errcode = '22023', message = 'SJ_DEVICE_KIND_INVALID';
    end if;
    if length(btrim(p_friendly_name)) = 0 or length(btrim(p_platform_label)) = 0 then
        raise exception using errcode = '22023', message = 'SJ_DEVICE_LABEL_REQUIRED';
    end if;

    select * into v_profile
    from public.profiles
    where auth_user_id = (select auth.uid());

    if not found then
        raise exception using errcode = '42501', message = 'SJ_PROFILE_NOT_BOUND';
    end if;
    if v_profile.status <> 'ACTIVE' then
        raise exception using errcode = '42501', message = 'SJ_ACCOUNT_NOT_ACTIVE';
    end if;

    select count(*), min(business_id)
    into v_membership_count, v_business_id
    from public.business_memberships
    where profile_id = v_profile.id
      and active;

    if v_membership_count <> 1 then
        raise exception using errcode = '42501', message = 'SJ_MEMBERSHIP_INVALID';
    end if;

    v_session_id := private.current_session_id();
    if v_session_id is null or not exists (
        select 1
        from auth.sessions s
        where s.id = v_session_id
          and s.user_id = v_profile.auth_user_id
    ) then
        raise exception using errcode = '42501', message = 'SJ_AUTH_SESSION_INVALID';
    end if;

    insert into public.trusted_devices (
        id, business_id, friendly_name, device_kind, platform_label
    )
    values (
        p_device_id, v_business_id, btrim(p_friendly_name), p_device_kind, btrim(p_platform_label)
    )
    on conflict (id) do update
    set last_seen_at = now();

    if exists (
        select 1
        from public.trusted_devices
        where id = p_device_id
          and (business_id <> v_business_id or retired_at is not null)
    ) then
        raise exception using errcode = '42501', message = 'SJ_DEVICE_RETIRED';
    end if;

    select * into v_access
    from public.user_device_access
    where business_id = v_business_id
      and profile_id = v_profile.id
      and device_id = p_device_id;

    if found and (
        v_access.revoked_at is not null
        or v_access.removed_from_active_list_at is not null
    ) then
        raise exception using errcode = '42501', message = 'SJ_DEVICE_REVOKED';
    end if;

    insert into public.user_device_access (
        business_id, profile_id, device_id
    )
    values (
        v_business_id, v_profile.id, p_device_id
    )
    on conflict (business_id, profile_id, device_id) do update
    set last_seen_at = now();

    update public.session_registry
    set revoked_at = coalesce(revoked_at, now()),
        revoke_reason = coalesce(revoke_reason, 'SWITCH_USER')
    where business_id = v_business_id
      and device_id = p_device_id
      and session_id <> v_session_id
      and revoked_at is null;

    insert into public.session_registry (
        session_id, business_id, profile_id, device_id
    )
    values (
        v_session_id, v_business_id, v_profile.id, p_device_id
    )
    on conflict (session_id) do update
    set last_seen_at = now();

    return private.build_authority_json(v_business_id);
end;
$$;

create or replace function public.get_my_authority()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_business_id uuid;
begin
    select sr.business_id into v_business_id
    from public.session_registry sr
    where sr.session_id = private.current_session_id();

    if v_business_id is null or not private.is_active_member(v_business_id) then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    return private.build_authority_json(v_business_id);
end;
$$;

create or replace function public.revoke_my_session()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.session_registry
    set revoked_at = coalesce(revoked_at, now()),
        revoke_reason = coalesce(revoke_reason, 'SELF_SIGN_OUT')
    where session_id = private.current_session_id()
      and profile_id = private.current_profile_id();
end;
$$;

create or replace function private.bootstrap_first_owner(
    p_auth_user_id uuid,
    p_username text,
    p_display_name text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_business_id uuid;
    v_profile_id uuid;
    v_normalized text;
    v_expected_email text;
    v_actual_email text;
begin
    v_normalized := private.normalize_username(p_username);
    if v_normalized !~ '^[a-z0-9][a-z0-9_-]{2,31}$' then
        raise exception using errcode = '22023', message = 'SJ_USERNAME_INVALID';
    end if;

    if exists (
        select 1
        from public.business_memberships m
        join public.access_roles r on r.code = m.role_code
        where m.active and r.owner_level
    ) then
        raise exception using errcode = '23505', message = 'SJ_OWNER_ALREADY_BOOTSTRAPPED';
    end if;

    select id into v_business_id
    from public.businesses
    where code = 'SJ' and active;

    if v_business_id is null then
        raise exception using errcode = '23503', message = 'SJ_BUSINESS_MISSING';
    end if;

    v_expected_email := v_normalized || '@auth.segeranjiwa.invalid';

    select email into v_actual_email
    from auth.users
    where id = p_auth_user_id
      and deleted_at is null;

    if v_actual_email is distinct from v_expected_email then
        raise exception using errcode = '23514', message = 'SJ_AUTH_IDENTITY_MISMATCH';
    end if;

    insert into public.profiles (auth_user_id, display_name)
    values (p_auth_user_id, btrim(p_display_name))
    returning id into v_profile_id;

    insert into public.user_login_identities (profile_id, username)
    values (v_profile_id, v_normalized);

    insert into public.business_memberships (
        business_id, profile_id, role_code
    )
    values (
        v_business_id, v_profile_id, 'OWNER'
    );

    insert into public.audit_events (
        business_id, actor_profile_id, event_type, entity_type, entity_id, metadata
    )
    values (
        v_business_id, v_profile_id, 'OWNER_BOOTSTRAPPED', 'PROFILE', v_profile_id,
        jsonb_build_object('username', v_normalized)
    );

    return v_profile_id;
end;
$$;

create or replace function private.assert_cs03_owner_actor(
    p_business_id uuid,
    p_actor_auth_user_id uuid,
    p_actor_session_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_profile_id uuid;
begin
    select p.id into v_profile_id
    from public.profiles p
    join public.business_memberships m on m.profile_id = p.id
    join public.access_roles r on r.code = m.role_code
    join public.session_registry sr
      on sr.profile_id = p.id
     and sr.business_id = m.business_id
     and sr.session_id = p_actor_session_id
    join public.user_device_access uda
      on uda.business_id = sr.business_id
     and uda.profile_id = sr.profile_id
     and uda.device_id = sr.device_id
    join public.trusted_devices td
      on td.business_id = sr.business_id
     and td.id = sr.device_id
    where p.auth_user_id = p_actor_auth_user_id
      and p.status = 'ACTIVE'
      and m.business_id = p_business_id
      and m.active
      and r.active
      and r.owner_level
      and sr.revoked_at is null
      and uda.revoked_at is null
      and uda.removed_from_active_list_at is null
      and td.retired_at is null
      and exists (
          select 1
          from auth.sessions s
          where s.id = p_actor_session_id
            and s.user_id = p_actor_auth_user_id
      );

    if v_profile_id is null then
        raise exception using errcode = '42501', message = 'SJ_OWNER_AUTHORITY_REQUIRED';
    end if;

    return v_profile_id;
end;
$$;

create or replace function public.cs03_admin_bind_staff(
    p_business_id uuid,
    p_actor_auth_user_id uuid,
    p_actor_session_id uuid,
    p_target_auth_user_id uuid,
    p_username text,
    p_display_name text,
    p_role_code text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor_profile_id uuid;
    v_profile_id uuid;
    v_normalized text;
    v_expected_email text;
    v_actual_email text;
    v_role_owner boolean;
begin
    v_actor_profile_id := private.assert_cs03_owner_actor(
        p_business_id, p_actor_auth_user_id, p_actor_session_id
    );

    select r.owner_level into v_role_owner
    from public.access_roles r
    where r.code = p_role_code
      and r.active;

    if v_role_owner is null or v_role_owner then
        raise exception using errcode = '42501', message = 'SJ_ROLE_OWNER_NOT_ASSIGNABLE';
    end if;

    v_normalized := private.normalize_username(p_username);
    if v_normalized !~ '^[a-z0-9][a-z0-9_-]{2,31}$' then
        raise exception using errcode = '22023', message = 'SJ_USERNAME_INVALID';
    end if;

    v_expected_email := v_normalized || '@auth.segeranjiwa.invalid';
    select u.email into v_actual_email
    from auth.users u
    where u.id = p_target_auth_user_id
      and u.deleted_at is null;

    if v_actual_email is distinct from v_expected_email then
        raise exception using errcode = '23514', message = 'SJ_AUTH_IDENTITY_MISMATCH';
    end if;

    insert into public.profiles (auth_user_id, display_name)
    values (p_target_auth_user_id, btrim(p_display_name))
    returning id into v_profile_id;

    insert into public.user_login_identities (profile_id, username)
    values (v_profile_id, v_normalized);

    insert into public.business_memberships (
        business_id, profile_id, role_code
    )
    values (
        p_business_id, v_profile_id, p_role_code
    );

    insert into public.audit_events (
        business_id, actor_profile_id, event_type, entity_type, entity_id, metadata
    )
    values (
        p_business_id, v_actor_profile_id, 'USER_CREATED', 'PROFILE', v_profile_id,
        jsonb_build_object(
            'username', v_normalized,
            'display_name', btrim(p_display_name),
            'role_code', p_role_code
        )
    );

    return v_profile_id;
end;
$$;

create or replace function public.cs03_admin_set_status(
    p_business_id uuid,
    p_actor_auth_user_id uuid,
    p_actor_session_id uuid,
    p_target_profile_id uuid,
    p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor_profile_id uuid;
    v_old_status text;
    v_owner_level boolean;
begin
    v_actor_profile_id := private.assert_cs03_owner_actor(
        p_business_id, p_actor_auth_user_id, p_actor_session_id
    );

    if p_status not in ('ACTIVE', 'LEAVE', 'DISABLED') then
        raise exception using errcode = '22023', message = 'SJ_STATUS_INVALID';
    end if;

    select p.status, r.owner_level
    into v_old_status, v_owner_level
    from public.profiles p
    join public.business_memberships m on m.profile_id = p.id
    join public.access_roles r on r.code = m.role_code
    where p.id = p_target_profile_id
      and m.business_id = p_business_id
      and m.active
      and r.active;

    if v_old_status is null then
        raise exception using errcode = '42501', message = 'SJ_TARGET_NOT_IN_BUSINESS';
    end if;
    if v_owner_level then
        raise exception using errcode = '42501', message = 'SJ_TARGET_OWNER_PROTECTED';
    end if;

    update public.profiles
    set status = p_status,
        updated_at = now()
    where id = p_target_profile_id;

    if p_status in ('LEAVE', 'DISABLED') then
        update public.session_registry
        set revoked_at = coalesce(revoked_at, now()),
            revoked_by_profile_id = coalesce(revoked_by_profile_id, v_actor_profile_id),
            revoke_reason = coalesce(revoke_reason, 'USER_STATUS_' || p_status)
        where business_id = p_business_id
          and profile_id = p_target_profile_id
          and revoked_at is null;
    end if;

    insert into public.audit_events (
        business_id, actor_profile_id, event_type, entity_type, entity_id, metadata
    )
    values (
        p_business_id, v_actor_profile_id, 'USER_STATUS_CHANGED', 'PROFILE', p_target_profile_id,
        jsonb_build_object('old_status', v_old_status, 'new_status', p_status)
    );
end;
$$;

create or replace function public.cs03_admin_set_permission_override(
    p_business_id uuid,
    p_actor_auth_user_id uuid,
    p_actor_session_id uuid,
    p_target_profile_id uuid,
    p_permission_code text,
    p_effect text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor_profile_id uuid;
    v_owner_level boolean;
begin
    v_actor_profile_id := private.assert_cs03_owner_actor(
        p_business_id, p_actor_auth_user_id, p_actor_session_id
    );

    select r.owner_level into v_owner_level
    from public.business_memberships m
    join public.access_roles r on r.code = m.role_code
    where m.business_id = p_business_id
      and m.profile_id = p_target_profile_id
      and m.active
      and r.active;

    if v_owner_level is null then
        raise exception using errcode = '42501', message = 'SJ_TARGET_NOT_IN_BUSINESS';
    end if;
    if v_owner_level then
        raise exception using errcode = '42501', message = 'SJ_TARGET_OWNER_PROTECTED';
    end if;

    if not exists (
        select 1
        from public.permission_definitions pd
        where pd.code = p_permission_code
          and pd.active
    ) then
        raise exception using errcode = '22023', message = 'SJ_PERMISSION_UNKNOWN';
    end if;

    if p_effect not in ('ALLOW', 'DENY', 'INHERIT') then
        raise exception using errcode = '22023', message = 'SJ_PERMISSION_EFFECT_INVALID';
    end if;

    if p_effect = 'INHERIT' then
        delete from public.user_permission_overrides
        where business_id = p_business_id
          and profile_id = p_target_profile_id
          and permission_code = p_permission_code;
    else
        insert into public.user_permission_overrides (
            business_id,
            profile_id,
            permission_code,
            effect,
            set_by_profile_id
        )
        values (
            p_business_id,
            p_target_profile_id,
            p_permission_code,
            p_effect,
            v_actor_profile_id
        )
        on conflict (business_id, profile_id, permission_code) do update
        set effect = excluded.effect,
            set_by_profile_id = excluded.set_by_profile_id,
            updated_at = now();
    end if;

    insert into public.audit_events (
        business_id, actor_profile_id, event_type, entity_type, entity_id, metadata
    )
    values (
        p_business_id, v_actor_profile_id, 'USER_PERMISSION_CHANGED', 'PROFILE', p_target_profile_id,
        jsonb_build_object('permission_code', p_permission_code, 'effect', p_effect)
    );
end;
$$;

create or replace function public.cs03_admin_revoke_device(
    p_business_id uuid,
    p_actor_auth_user_id uuid,
    p_actor_session_id uuid,
    p_target_profile_id uuid,
    p_device_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor_profile_id uuid;
begin
    v_actor_profile_id := private.assert_cs03_owner_actor(
        p_business_id, p_actor_auth_user_id, p_actor_session_id
    );

    if not exists (
        select 1
        from public.business_memberships m
        where m.business_id = p_business_id
          and m.profile_id = p_target_profile_id
          and m.active
    ) then
        raise exception using errcode = '42501', message = 'SJ_TARGET_NOT_IN_BUSINESS';
    end if;

    if not exists (
        select 1
        from public.user_device_access uda
        where uda.business_id = p_business_id
          and uda.profile_id = p_target_profile_id
          and uda.device_id = p_device_id
    ) then
        raise exception using errcode = '22023', message = 'SJ_DEVICE_ACCESS_NOT_FOUND';
    end if;

    update public.user_device_access
    set revoked_at = coalesce(revoked_at, now()),
        revoked_by_profile_id = coalesce(revoked_by_profile_id, v_actor_profile_id)
    where business_id = p_business_id
      and profile_id = p_target_profile_id
      and device_id = p_device_id;

    update public.session_registry
    set revoked_at = coalesce(revoked_at, now()),
        revoked_by_profile_id = coalesce(revoked_by_profile_id, v_actor_profile_id),
        revoke_reason = coalesce(revoke_reason, 'DEVICE_REVOKED')
    where business_id = p_business_id
      and profile_id = p_target_profile_id
      and device_id = p_device_id
      and revoked_at is null;

    insert into public.audit_events (
        business_id, actor_profile_id, event_type, entity_type, entity_id, metadata
    )
    values (
        p_business_id, v_actor_profile_id, 'DEVICE_REVOKED', 'DEVICE', p_device_id,
        jsonb_build_object('profile_id', p_target_profile_id)
    );
end;
$$;

create or replace function public.cs03_admin_remove_device(
    p_business_id uuid,
    p_actor_auth_user_id uuid,
    p_actor_session_id uuid,
    p_target_profile_id uuid,
    p_device_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor_profile_id uuid;
    v_revoked_at timestamptz;
begin
    v_actor_profile_id := private.assert_cs03_owner_actor(
        p_business_id, p_actor_auth_user_id, p_actor_session_id
    );

    if not exists (
        select 1
        from public.business_memberships m
        where m.business_id = p_business_id
          and m.profile_id = p_target_profile_id
          and m.active
    ) then
        raise exception using errcode = '42501', message = 'SJ_TARGET_NOT_IN_BUSINESS';
    end if;

    select uda.revoked_at into v_revoked_at
    from public.user_device_access uda
    where uda.business_id = p_business_id
      and uda.profile_id = p_target_profile_id
      and uda.device_id = p_device_id;

    if not found then
        raise exception using errcode = '22023', message = 'SJ_DEVICE_ACCESS_NOT_FOUND';
    end if;
    if v_revoked_at is null then
        raise exception using errcode = '42501', message = 'SJ_DEVICE_MUST_BE_REVOKED_FIRST';
    end if;

    update public.user_device_access
    set removed_from_active_list_at = coalesce(removed_from_active_list_at, now())
    where business_id = p_business_id
      and profile_id = p_target_profile_id
      and device_id = p_device_id;

    insert into public.audit_events (
        business_id, actor_profile_id, event_type, entity_type, entity_id, metadata
    )
    values (
        p_business_id, v_actor_profile_id, 'DEVICE_REMOVED', 'DEVICE', p_device_id,
        jsonb_build_object('profile_id', p_target_profile_id)
    );
end;
$$;

create or replace function public.cs03_admin_rename_device(
    p_business_id uuid,
    p_actor_auth_user_id uuid,
    p_actor_session_id uuid,
    p_device_id uuid,
    p_friendly_name text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor_profile_id uuid;
    v_old_name text;
begin
    v_actor_profile_id := private.assert_cs03_owner_actor(
        p_business_id, p_actor_auth_user_id, p_actor_session_id
    );

    if length(btrim(p_friendly_name)) = 0 then
        raise exception using errcode = '22023', message = 'SJ_DEVICE_LABEL_REQUIRED';
    end if;

    select td.friendly_name into v_old_name
    from public.trusted_devices td
    where td.business_id = p_business_id
      and td.id = p_device_id;

    if v_old_name is null then
        raise exception using errcode = '22023', message = 'SJ_DEVICE_NOT_FOUND';
    end if;

    update public.trusted_devices
    set friendly_name = btrim(p_friendly_name),
        last_seen_at = last_seen_at
    where business_id = p_business_id
      and id = p_device_id;

    insert into public.audit_events (
        business_id, actor_profile_id, event_type, entity_type, entity_id, metadata
    )
    values (
        p_business_id, v_actor_profile_id, 'DEVICE_RENAMED', 'DEVICE', p_device_id,
        jsonb_build_object('old_name', v_old_name, 'new_name', btrim(p_friendly_name))
    );
end;
$$;

create or replace function public.cs03_admin_get_target_auth_user(
    p_business_id uuid,
    p_actor_auth_user_id uuid,
    p_actor_session_id uuid,
    p_target_profile_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_actor_profile_id uuid;
    v_auth_user_id uuid;
    v_owner_level boolean;
begin
    v_actor_profile_id := private.assert_cs03_owner_actor(
        p_business_id, p_actor_auth_user_id, p_actor_session_id
    );

    select p.auth_user_id, r.owner_level
    into v_auth_user_id, v_owner_level
    from public.profiles p
    join public.business_memberships m on m.profile_id = p.id
    join public.access_roles r on r.code = m.role_code
    where p.id = p_target_profile_id
      and m.business_id = p_business_id
      and m.active
      and r.active;

    if v_auth_user_id is null then
        raise exception using errcode = '42501', message = 'SJ_TARGET_NOT_IN_BUSINESS';
    end if;
    if v_owner_level then
        raise exception using errcode = '42501', message = 'SJ_TARGET_OWNER_PROTECTED';
    end if;

    return v_auth_user_id;
end;
$$;

create or replace function public.cs03_admin_record_password_reset(
    p_business_id uuid,
    p_actor_auth_user_id uuid,
    p_actor_session_id uuid,
    p_target_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor_profile_id uuid;
    v_owner_level boolean;
begin
    v_actor_profile_id := private.assert_cs03_owner_actor(
        p_business_id, p_actor_auth_user_id, p_actor_session_id
    );

    select r.owner_level into v_owner_level
    from public.business_memberships m
    join public.access_roles r on r.code = m.role_code
    where m.business_id = p_business_id
      and m.profile_id = p_target_profile_id
      and m.active
      and r.active;

    if v_owner_level is null then
        raise exception using errcode = '42501', message = 'SJ_TARGET_NOT_IN_BUSINESS';
    end if;
    if v_owner_level then
        raise exception using errcode = '42501', message = 'SJ_TARGET_OWNER_PROTECTED';
    end if;

    insert into public.audit_events (
        business_id, actor_profile_id, event_type, entity_type, entity_id, metadata
    )
    values (
        p_business_id, v_actor_profile_id, 'PASSWORD_RESET', 'PROFILE', p_target_profile_id,
        '{}'::jsonb
    );
end;
$$;

create or replace function public.owner_list_users()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_business_id uuid;
begin
    select sr.business_id into v_business_id
    from public.session_registry sr
    where sr.session_id = private.current_session_id();

    if v_business_id is null or not private.is_owner(v_business_id) then
        raise exception using errcode = '42501', message = 'SJ_OWNER_AUTHORITY_REQUIRED';
    end if;

    return coalesce((
        select jsonb_agg(
            jsonb_build_object(
                'profile_id', p.id,
                'username', uli.normalized_username,
                'display_name', p.display_name,
                'status', p.status,
                'role_code', m.role_code,
                'permission_overrides', coalesce((
                    select jsonb_agg(
                        jsonb_build_object(
                            'permission_code', o.permission_code,
                            'effect', o.effect
                        )
                        order by o.permission_code
                    )
                    from public.user_permission_overrides o
                    where o.business_id = v_business_id
                      and o.profile_id = p.id
                ), '[]'::jsonb)
            )
            order by uli.normalized_username
        )
        from public.business_memberships m
        join public.profiles p on p.id = m.profile_id
        join public.user_login_identities uli on uli.profile_id = p.id
        where m.business_id = v_business_id
          and m.active
    ), '[]'::jsonb);
end;
$$;

create or replace function public.owner_list_devices(p_profile_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_business_id uuid;
begin
    select sr.business_id into v_business_id
    from public.session_registry sr
    where sr.session_id = private.current_session_id();

    if v_business_id is null or not private.is_owner(v_business_id) then
        raise exception using errcode = '42501', message = 'SJ_OWNER_AUTHORITY_REQUIRED';
    end if;

    return coalesce((
        select jsonb_agg(
            jsonb_build_object(
                'profile_id', uda.profile_id,
                'device_id', td.id,
                'friendly_name', td.friendly_name,
                'device_kind', td.device_kind,
                'platform_label', td.platform_label,
                'last_seen_at', greatest(uda.last_seen_at, td.last_seen_at),
                'revoked', uda.revoked_at is not null,
                'removed', uda.removed_from_active_list_at is not null,
                'retired', td.retired_at is not null
            )
            order by greatest(uda.last_seen_at, td.last_seen_at) desc
        )
        from public.user_device_access uda
        join public.trusted_devices td
          on td.business_id = uda.business_id
         and td.id = uda.device_id
        where uda.business_id = v_business_id
          and (p_profile_id is null or uda.profile_id = p_profile_id)
    ), '[]'::jsonb);
end;
$$;

-- Private helpers are callable only from trusted definer code / SQL administration.
revoke execute on function private.current_session_allowed(uuid)
from public, anon, authenticated, service_role;
revoke execute on function private.has_permission(uuid, text)
from public, anon, authenticated, service_role;
revoke execute on function private.build_authority_json(uuid)
from public, anon, authenticated, service_role;
revoke execute on function private.bootstrap_first_owner(uuid, text, text)
from public, anon, authenticated, service_role;
revoke execute on function private.assert_cs03_owner_actor(uuid, uuid, uuid)
from public, anon, authenticated, service_role;

-- Authenticated app-session RPCs.
revoke execute on function public.bootstrap_current_session(uuid, text, text, text)
from public, anon, authenticated, service_role;
grant execute on function public.bootstrap_current_session(uuid, text, text, text)
to authenticated;

revoke execute on function public.get_my_authority()
from public, anon, authenticated, service_role;
grant execute on function public.get_my_authority()
to authenticated;

revoke execute on function public.revoke_my_session()
from public, anon, authenticated, service_role;
grant execute on function public.revoke_my_session()
to authenticated;

revoke execute on function public.owner_list_users()
from public, anon, authenticated, service_role;
grant execute on function public.owner_list_users()
to authenticated;

revoke execute on function public.owner_list_devices(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.owner_list_devices(uuid)
to authenticated;

-- Service-only admin RPCs used by Edge Functions.
revoke execute on function public.cs03_admin_bind_staff(uuid, uuid, uuid, uuid, text, text, text)
from public, anon, authenticated, service_role;
grant execute on function public.cs03_admin_bind_staff(uuid, uuid, uuid, uuid, text, text, text)
to service_role;

revoke execute on function public.cs03_admin_set_status(uuid, uuid, uuid, uuid, text)
from public, anon, authenticated, service_role;
grant execute on function public.cs03_admin_set_status(uuid, uuid, uuid, uuid, text)
to service_role;

revoke execute on function public.cs03_admin_set_permission_override(uuid, uuid, uuid, uuid, text, text)
from public, anon, authenticated, service_role;
grant execute on function public.cs03_admin_set_permission_override(uuid, uuid, uuid, uuid, text, text)
to service_role;

revoke execute on function public.cs03_admin_revoke_device(uuid, uuid, uuid, uuid, uuid)
from public, anon, authenticated, service_role;
grant execute on function public.cs03_admin_revoke_device(uuid, uuid, uuid, uuid, uuid)
to service_role;

revoke execute on function public.cs03_admin_remove_device(uuid, uuid, uuid, uuid, uuid)
from public, anon, authenticated, service_role;
grant execute on function public.cs03_admin_remove_device(uuid, uuid, uuid, uuid, uuid)
to service_role;

revoke execute on function public.cs03_admin_rename_device(uuid, uuid, uuid, uuid, text)
from public, anon, authenticated, service_role;
grant execute on function public.cs03_admin_rename_device(uuid, uuid, uuid, uuid, text)
to service_role;

revoke execute on function public.cs03_admin_get_target_auth_user(uuid, uuid, uuid, uuid)
from public, anon, authenticated, service_role;
grant execute on function public.cs03_admin_get_target_auth_user(uuid, uuid, uuid, uuid)
to service_role;

revoke execute on function public.cs03_admin_record_password_reset(uuid, uuid, uuid, uuid)
from public, anon, authenticated, service_role;
grant execute on function public.cs03_admin_record_password_reset(uuid, uuid, uuid, uuid)
to service_role;
