begin;

do $$
begin
    if to_regprocedure('public.finance_open_shift_from_main_cash(uuid,numeric,jsonb,text)') is null then
        raise exception 'FIN_P2A_FUNDED_OPEN_RPC_MISSING';
    end if;

    if not exists (
        select 1 from information_schema.columns
        where table_schema='public' and table_name='shifts'
          and column_name='opening_source_type'
    ) then
        raise exception 'FIN_P2A_SOURCE_TYPE_MISSING';
    end if;

    if not exists (
        select 1 from information_schema.columns
        where table_schema='public' and table_name='shifts'
          and column_name='opening_money_movement_id'
    ) then
        raise exception 'FIN_P2A_MOVEMENT_LINK_MISSING';
    end if;
end
$$;

rollback;
