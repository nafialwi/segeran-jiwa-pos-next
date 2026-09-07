create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon;
revoke all on schema private from authenticated;

create table private.schema_versions (
    version integer primary key,
    milestone text not null,
    blueprint_baseline text not null,
    source_anchor text not null,
    applied_at timestamptz not null default now(),
    constraint schema_versions_version_positive check (version > 0),
    constraint schema_versions_blueprint_nonempty check (length(btrim(blueprint_baseline)) > 0),
    constraint schema_versions_source_anchor_sha check (source_anchor ~ '^[0-9a-f]{40}$')
);

insert into private.schema_versions (
    version,
    milestone,
    blueprint_baseline,
    source_anchor
)
values (
    1,
    'CS-02',
    '1.0',
    'c7bce7498b27ea6bd5f8c1981597f068ca4f6f53'
);

create or replace function private.prevent_fact_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    raise exception using
        errcode = '55000',
        message = 'SJ_IMMUTABLE_FACT';
end;
$$;