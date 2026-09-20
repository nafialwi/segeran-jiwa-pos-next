begin;

do $$
begin
    if not exists (
        select 1 from pg_indexes
        where schemaname='public'
          and tablename='business_expenses'
          and indexname='business_expenses_location_idx'
    ) then
        raise exception 'FIN_P2B1_LOCATION_INDEX_MISSING';
    end if;

    if not exists (
        select 1 from pg_indexes
        where schemaname='public'
          and tablename='business_expenses'
          and indexname='business_expenses_funding_account_idx'
    ) then
        raise exception 'FIN_P2B1_FUNDING_INDEX_MISSING';
    end if;
end
$$;

rollback;
