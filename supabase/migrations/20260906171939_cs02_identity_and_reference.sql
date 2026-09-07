create table public.businesses (
    id uuid primary key default gen_random_uuid(),
    code text not null unique,
    display_name text not null,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint businesses_code_format check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
    constraint businesses_display_name_nonempty check (length(btrim(display_name)) > 0)
);

create table public.profiles (
    id uuid primary key default gen_random_uuid(),
    auth_user_id uuid not null unique,
    display_name text not null,
    status text not null default 'ACTIVE',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint profiles_display_name_nonempty check (length(btrim(display_name)) > 0),
    constraint profiles_status_valid check (status in ('ACTIVE', 'LEAVE', 'DISABLED'))
);

create table public.access_roles (
    code text primary key,
    display_name text not null,
    owner_level boolean not null default false,
    active boolean not null default true
);

insert into public.access_roles (code, display_name, owner_level)
values
    ('OWNER', 'Owner', true),
    ('KASIR', 'Kasir', false);

create table public.business_memberships (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    profile_id uuid not null references public.profiles(id) on delete restrict,
    role_code text not null references public.access_roles(code) on delete restrict,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    unique (business_id, profile_id)
);

create table public.locations (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    code text not null,
    display_name text not null,
    location_type text not null,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    unique (business_id, code),
    constraint locations_type_valid check (location_type in ('WAREHOUSE', 'STORE')),
    constraint locations_code_format check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
    constraint locations_display_name_nonempty check (length(btrim(display_name)) > 0)
);

create table public.stock_items (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    code text not null,
    display_name text not null,
    item_kind text not null,
    base_unit text not null,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (business_id, code),
    constraint stock_items_kind_valid check (
        item_kind in ('MATERIAL', 'FINISHED_GOOD', 'PACKAGING', 'OTHER')
    ),
    constraint stock_items_code_format check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,63}$'),
    constraint stock_items_display_name_nonempty check (length(btrim(display_name)) > 0),
    constraint stock_items_base_unit_nonempty check (length(btrim(base_unit)) > 0)
);

create table public.money_accounts (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    code text not null,
    display_name text not null,
    account_type text not null,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    unique (business_id, code),
    constraint money_accounts_type_valid check (
        account_type in ('CASH', 'BANK', 'QRIS_UNSETTLED', 'QRIS_SETTLED', 'OTHER')
    ),
    constraint money_accounts_code_format check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,63}$'),
    constraint money_accounts_display_name_nonempty check (length(btrim(display_name)) > 0)
);

insert into public.businesses (code, display_name)
values ('SJ', 'Segeran Jiwa');

insert into public.locations (
    business_id,
    code,
    display_name,
    location_type
)
select id, 'GUDANG', 'Gudang', 'WAREHOUSE'
from public.businesses
where code = 'SJ';

insert into public.locations (
    business_id,
    code,
    display_name,
    location_type
)
select id, 'GERAI', 'Gerai', 'STORE'
from public.businesses
where code = 'SJ';

insert into public.money_accounts (
    business_id,
    code,
    display_name,
    account_type
)
select businesses.id, seed.code, seed.display_name, seed.account_type
from public.businesses
cross join (
    values
        ('KAS_UTAMA', 'Kas Utama', 'CASH'),
        ('BANK', 'Bank', 'BANK'),
        ('QRIS_BELUM_CAIR', 'QRIS Belum Cair', 'QRIS_UNSETTLED'),
        ('QRIS_SUDAH_CAIR', 'QRIS Sudah Cair', 'QRIS_SETTLED')
) as seed(code, display_name, account_type)
where businesses.code = 'SJ';