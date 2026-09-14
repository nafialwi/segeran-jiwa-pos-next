begin;

do $$
begin
    if not exists (
        select 1
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = 'shifts' and c.relrowsecurity
    ) then
        raise exception 'shifts RLS not enabled';
    end if;

    if not exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = 'shifts' and policyname = 'shifts_member_read'
    ) then
        raise exception 'shifts_member_read missing';
    end if;

    if not exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = 'cash_transactions' and policyname = 'cash_transactions_member_read'
    ) then
        raise exception 'cash_transactions_member_read missing';
    end if;

    if not exists (
        select 1 from pg_policies
        where schemaname = 'public' and tablename = 'handovers' and policyname = 'handovers_member_read'
    ) then
        raise exception 'handovers_member_read missing';
    end if;

    if not exists (
        select 1
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname = 'cs05_open_my_shift'
    ) then
        raise exception 'cs05_open_my_shift missing';
    end if;

    if not exists (
        select 1
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname = 'cs05_close_my_shift'
    ) then
        raise exception 'cs05_close_my_shift missing';
    end if;

    if not exists (
        select 1
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname = 'cs05_resolve_handover'
    ) then
        raise exception 'cs05_resolve_handover missing';
    end if;

    if not has_function_privilege('authenticated', 'public.cs05_open_my_shift(uuid, numeric, jsonb)', 'execute') then
        raise exception 'authenticated cannot execute cs05_open_my_shift';
    end if;

    if not has_function_privilege('authenticated', 'public.cs05_close_my_shift(uuid, numeric, uuid)', 'execute') then
        raise exception 'authenticated cannot execute cs05_close_my_shift';
    end if;

    if not has_function_privilege('authenticated', 'public.cs05_resolve_handover(uuid, boolean)', 'execute') then
        raise exception 'authenticated cannot execute cs05_resolve_handover';
    end if;
end $$;

rollback;
