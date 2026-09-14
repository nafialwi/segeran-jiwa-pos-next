begin;

do $$
begin
    if not exists (
        select 1
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname = 'cs05_handover_target'
    ) then
        raise exception 'cs05_handover_target missing';
    end if;

    if not has_function_privilege('authenticated', 'public.cs05_handover_target(text)', 'execute') then
        raise exception 'authenticated cannot execute cs05_handover_target';
    end if;
end $$;

rollback;
