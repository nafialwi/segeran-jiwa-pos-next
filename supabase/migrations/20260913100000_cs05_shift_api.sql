-- CS-05-P3 SHIFT API
-- RLS read policies + authenticated RPC wrappers for the shift UI.
-- Business rules stay in private CS-05 functions; wrappers only bind session identity.

alter table public.shifts enable row level security;
alter table public.cash_transactions enable row level security;
alter table public.handovers enable row level security;

create policy shifts_member_read on public.shifts
for select to authenticated
using (private.is_active_member(business_id));

create policy cash_transactions_member_read on public.cash_transactions
for select to authenticated
using (private.is_active_member(business_id));

create policy handovers_member_read on public.handovers
for select to authenticated
using (private.is_active_member(business_id));

grant select on public.shifts to authenticated;
grant select on public.cash_transactions to authenticated;
grant select on public.handovers to authenticated;
grant select on public.cs05_sales_by_shift to authenticated;

create function private.cs05_require_shift_permission()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    if (public.get_my_authority() ->> 'status') is distinct from 'ACTIVE'
        or not (public.get_my_authority() -> 'permissions' ? 'SHIFT_OPEN_CLOSE') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;
end;
$$;

create function private.cs05_my_profile_id()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_profile uuid;
begin
    select id into v_profile from public.profiles where auth_user_id = auth.uid();
    if v_profile is null then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;
    return v_profile;
end;
$$;

revoke execute on function private.cs05_require_shift_permission() from public, anon, authenticated, service_role;
revoke execute on function private.cs05_my_profile_id() from public, anon, authenticated, service_role;

create function public.cs05_open_my_shift(
    p_location uuid,
    p_opening numeric,
    p_config jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor uuid;
    v_business uuid;
begin
    perform private.cs05_require_shift_permission();
    v_actor := private.cs05_my_profile_id();

    select business_id into v_business from public.locations where id = p_location;
    if v_business is null
        or v_business <> (public.get_my_authority() ->> 'business_id')::uuid then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    return private.cs05_open_shift(v_business, p_location, v_actor, p_opening, p_config);
end;
$$;

create function public.cs05_close_my_shift(
    p_shift uuid,
    p_actual numeric,
    p_to_profile uuid default null
)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor uuid;
    v_business uuid;
    v_variance numeric;
begin
    perform private.cs05_require_shift_permission();
    v_actor := private.cs05_my_profile_id();

    select business_id into v_business from public.shifts where id = p_shift;
    if v_business is null
        or v_business <> (public.get_my_authority() ->> 'business_id')::uuid then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;

    if p_to_profile is not null then
        if p_to_profile = v_actor
            or not exists (
                select 1 from public.business_memberships m
                where m.profile_id = p_to_profile and m.business_id = v_business
            ) then
            raise exception using errcode = '42501', message = 'SJ_HANDOVER_TARGET_INVALID';
        end if;
    end if;

    select private.cs05_close_shift(p_shift, v_actor, p_actual) into v_variance;

    if p_to_profile is not null then
        insert into public.handovers (
            business_id,
            location_id,
            from_shift_id,
            from_cashier_profile_id,
            to_cashier_profile_id,
            expected_balance,
            actual_balance
        )
        select
            s.business_id,
            s.location_id,
            s.id,
            s.cashier_profile_id,
            p_to_profile,
            coalesce(s.expected_cash, 0),
            p_actual
        from public.shifts s
        where s.id = p_shift;
    end if;

    return v_variance;
end;
$$;

create function public.cs05_resolve_handover(
    p_handover uuid,
    p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor uuid;
    r record;
begin
    perform private.cs05_require_shift_permission();
    v_actor := private.cs05_my_profile_id();

    select * into r from public.handovers where id = p_handover for update;
    if not found then
        raise exception using errcode = '42501', message = 'SJ_AUTHORITY_DENIED';
    end if;
    if r.status <> 'PENDING' then
        raise exception using message = 'SJ_HANDOVER_NOT_PENDING';
    end if;
    if r.to_cashier_profile_id is distinct from v_actor then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if p_accept then
        update public.handovers
        set status = 'ACCEPTED',
            to_shift_id = (
                select id from public.shifts
                where cashier_profile_id = v_actor and status = 'OPEN'
            ),
            updated_at = now()
        where id = p_handover;
    else
        update public.handovers
        set status = 'REJECTED',
            updated_at = now()
        where id = p_handover;
    end if;
end;
$$;

revoke execute on function public.cs05_open_my_shift(uuid, numeric, jsonb) from public, anon, authenticated, service_role;
grant execute on function public.cs05_open_my_shift(uuid, numeric, jsonb) to authenticated;
revoke execute on function public.cs05_close_my_shift(uuid, numeric, uuid) from public, anon, authenticated, service_role;
grant execute on function public.cs05_close_my_shift(uuid, numeric, uuid) to authenticated;
revoke execute on function public.cs05_resolve_handover(uuid, boolean) from public, anon, authenticated, service_role;
grant execute on function public.cs05_resolve_handover(uuid, boolean) to authenticated;
