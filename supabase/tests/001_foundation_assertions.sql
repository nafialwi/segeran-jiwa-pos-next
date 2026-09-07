begin;
do $$
begin
  if not exists (
    select 1 from private.schema_versions
    where version = 1
      and milestone = 'CS-02'
      and blueprint_baseline = '1.0'
      and source_anchor = 'c7bce7498b27eab6d5f8c1981597f068ca4f6f53'
  ) then raise exception 'CS02_SCHEMA_AUTHORITY_INVALID'; end if;
  if (select count(*) from public.businesses where code='SJ') <> 1 then raise exception 'CS02_BUSINESS_SEED_INVALID'; end if;
  if (select count(*) from public.locations where code in ('GUDANG','GERAI')) <> 2 then raise exception 'CS02_LOCATION_SEED_INVALID'; end if;
  if (select count(*) from public.money_accounts where code in ('KAS_UTAMA','BANK','QRIS_BELUM_CAIR','QRIS_SUDAH_CAIR')) <> 4 then raise exception 'CS02_MONEY_ACCOUNT_SEED_INVALID'; end if;
end $$;
rollback;
