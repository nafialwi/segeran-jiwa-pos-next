-- CS-03 forward correction: PostgreSQL has no min(uuid).
-- Preserve the exact-one-active-membership rule without UUID aggregation.
-- Schema version remains 2.

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

    select count(*)
    into v_membership_count
    from public.business_memberships
    where profile_id = v_profile.id
      and active;

    if v_membership_count <> 1 then
        raise exception using errcode = '42501', message = 'SJ_MEMBERSHIP_INVALID';
    end if;

    select business_id
    into v_business_id
    from public.business_memberships
    where profile_id = v_profile.id
      and active
    limit 1;

    v_session_id := private.current_session_id();
    if v_session_id is null or not exists (
        select 1
        from auth.sessions s
        where s.id = v_session_id
          and s.user_id = v_profile.auth_user_id
    ) then
        raise exception using errcode = '42501', message = 'SJ_AUTH_SESSION_INVALID';
    end if;

    insert into public.trusted_devices (id, business_id, friendly_name, device_kind, platform_label)
    values (p_device_id, v_business_id, btrim(p_friendly_name), p_device_kind, btrim(p_platform_label))
    on conflict (id) do update set last_seen_at = now();

    if exists (
        select 1 from public.trusted_devices
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

    if found and (v_access.revoked_at is not null or v_access.removed_from_active_list_at is not null) then
        raise exception using errcode = '42501', message = 'SJ_DEVICE_REVOKED';
    end if;

    insert into public.user_device_access (business_id, profile_id, device_id)
    values (v_business_id, v_profile.id, p_device_id)
    on conflict (business_id, profile_id, device_id) do update set last_seen_at = now();

    update public.session_registry
    set revoked_at = coalesce(revoked_at, now()),
        revoke_reason = coalesce(revoke_reason, 'SWITCH_USER')
    where business_id = v_business_id
      and device_id = p_device_id
      and session_id <> v_session_id
      and revoked_at is null;

    insert into public.session_registry (session_id, business_id, profile_id, device_id)
    values (v_session_id, v_business_id, v_profile.id, p_device_id)
    on conflict (session_id) do update set last_seen_at = now();

    return private.build_authority_json(v_business_id);
end;
$$;

revoke execute on function public.bootstrap_current_session(uuid, text, text, text)
from public, anon, authenticated, service_role;

grant execute on function public.bootstrap_current_session(uuid, text, text, text)
to authenticated;
