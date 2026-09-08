begin;

insert into public.profiles (auth_user_id, display_name)
values
    ('00000000-0000-0000-0000-000000000101', 'Owner Test'),
    ('00000000-0000-0000-0000-000000000102', 'Kasir Test');

insert into public.user_login_identities (profile_id, username)
select id, case display_name
    when 'Owner Test' then 'Owner_Test'
    else 'kasir-1'
end
from public.profiles
where display_name in ('Owner Test', 'Kasir Test');

do $$
declare
    owner_normalized text;
    kasir_normalized text;
begin
    select normalized_username into owner_normalized
    from public.user_login_identities uli
    join public.profiles p on p.id = uli.profile_id
    where p.display_name = 'Owner Test';

    select normalized_username into kasir_normalized
    from public.user_login_identities uli
    join public.profiles p on p.id = uli.profile_id
    where p.display_name = 'Kasir Test';

    if owner_normalized <> 'owner_test' then
        raise exception 'CS03_USERNAME_NORMALIZATION_FAILED';
    end if;

    if kasir_normalized <> 'kasir-1' then
        raise exception 'CS03_USERNAME_NORMALIZATION_FAILED';
    end if;

    if not exists (
        select 1
        from public.role_permissions
        where role_code = 'KASIR'
          and permission_code = 'SALE_EXECUTE'
          and allowed
    ) then
        raise exception 'CS03_KASIR_PRESET_MISSING';
    end if;

    if exists (
        select 1
        from public.role_permissions
        where role_code = 'KASIR'
          and permission_code in (
              'REPORT_SALES_LIMITED',
              'REPORT_INVENTORY',
              'REPORT_PURCHASE',
              'REPORT_PRODUCTION'
          )
    ) then
        raise exception 'CS03_KASIR_REPORT_SCOPE_TOO_BROAD';
    end if;
end
$$;

rollback;
