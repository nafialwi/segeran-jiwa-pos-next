begin;

insert into auth.users (id, email, is_sso_user, is_anonymous)
values (
    '00000000-0000-0000-0000-000000000201',
    'owner-test@auth.segeranjiwa.invalid',
    false,
    false
);

insert into auth.sessions (id, user_id)
values (
    '00000000-0000-0000-0000-000000000301',
    '00000000-0000-0000-0000-000000000201'
);

insert into public.profiles (id, auth_user_id, display_name, status)
values (
    '00000000-0000-0000-0000-000000000401',
    '00000000-0000-0000-0000-000000000201',
    'Owner Session Test',
    'ACTIVE'
);

insert into public.user_login_identities (profile_id, username)
values (
    '00000000-0000-0000-0000-000000000401',
    'owner-session-test'
);

insert into public.business_memberships (business_id, profile_id, role_code)
select id, '00000000-0000-0000-0000-000000000401', 'OWNER'
from public.businesses where code = 'SJ';

insert into public.trusted_devices (
    id, business_id, friendly_name, device_kind, platform_label
)
select
    '00000000-0000-0000-0000-000000000501',
    id,
    'Test Device',
    'PERSONAL',
    'TEST'
from public.businesses where code = 'SJ';

insert into public.user_device_access (
    business_id, profile_id, device_id
)
select
    id,
    '00000000-0000-0000-0000-000000000401',
    '00000000-0000-0000-0000-000000000501'
from public.businesses where code = 'SJ';

insert into public.session_registry (
    session_id, business_id, profile_id, device_id
)
select
    '00000000-0000-0000-0000-000000000301',
    id,
    '00000000-0000-0000-0000-000000000401',
    '00000000-0000-0000-0000-000000000501'
from public.businesses where code = 'SJ';

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000000201","role":"authenticated","session_id":"00000000-0000-0000-0000-000000000301"}',
    true
);

do $$
declare
    v_business uuid;
begin
    select id into v_business from public.businesses where code = 'SJ';

    if not private.is_active_member(v_business) then
        raise exception 'CS03_ACTIVE_SESSION_NOT_ACCEPTED';
    end if;

    if not private.is_owner(v_business) then
        raise exception 'CS03_OWNER_SESSION_NOT_ACCEPTED';
    end if;

    if not private.has_permission(v_business, 'SALE_EXECUTE') then
        raise exception 'CS03_OWNER_PERMISSION_NOT_IMPLICIT';
    end if;
end
$$;

reset role;

update public.session_registry
set revoked_at = now(), revoke_reason = 'TEST_REVOKE'
where session_id = '00000000-0000-0000-0000-000000000301';

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000000201","role":"authenticated","session_id":"00000000-0000-0000-0000-000000000301"}',
    true
);

do $$
declare
    v_business uuid;
begin
    select id into v_business from public.businesses where code = 'SJ';

    if private.is_active_member(v_business) then
        raise exception 'CS03_REVOKED_SESSION_STILL_ACTIVE';
    end if;
end
$$;

rollback;
