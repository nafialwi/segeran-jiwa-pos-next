-- CS-05-P3 HANDOVER TARGET RESOLUTION
-- Resolves a teammate username to a profile id within the caller's business.

create function public.cs05_handover_target(
    p_username text
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_actor uuid;
    v_business uuid;
    v_target uuid;
begin
    perform private.cs05_require_shift_permission();
    v_actor := private.cs05_my_profile_id();
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;

    select p.id into v_target
    from public.profiles p
    join public.business_memberships m on m.profile_id = p.id
    where lower(trim(p_username)) = lower(p.username)
      and m.business_id = v_business
      and p.id <> v_actor;

    if v_target is null then
        raise exception using errcode = '42501', message = 'SJ_HANDOVER_TARGET_INVALID';
    end if;

    return v_target;
end;
$$;

revoke execute on function public.cs05_handover_target(text) from public, anon, authenticated, service_role;
grant execute on function public.cs05_handover_target(text) to authenticated;
