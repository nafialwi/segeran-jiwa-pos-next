-- C11-F0B — Operational Message
-- Narrow, permission-bounded instruction channel from authorized management to cashiers.
-- This is not a general chat system.

insert into public.permission_definitions (code, display_name, category, active)
values ('OPERATIONAL_MESSAGE_MANAGE', 'Kelola Pesan Operasional', 'OPERASIONAL', true)
on conflict (code) do update
set display_name = excluded.display_name,
    category = excluded.category,
    active = excluded.active;

create table public.operational_messages (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    author_profile_id uuid not null references public.profiles(id) on delete restrict,
    title text not null,
    body text not null,
    priority text not null default 'NORMAL',
    target_kind text not null,
    target_profile_id uuid references public.profiles(id) on delete restrict,
    valid_from timestamptz not null default now(),
    valid_until timestamptz not null,
    cancelled_at timestamptz,
    cancelled_by_profile_id uuid references public.profiles(id) on delete restrict,
    cancel_reason text,
    created_at timestamptz not null default now(),
    constraint operational_messages_title_nonempty
      check (length(btrim(title)) between 1 and 120),
    constraint operational_messages_body_nonempty
      check (length(btrim(body)) between 1 and 1200),
    constraint operational_messages_priority_valid
      check (priority in ('NORMAL','HIGH')),
    constraint operational_messages_target_kind_valid
      check (target_kind in ('ALL_CASHIERS','PROFILE')),
    constraint operational_messages_target_shape
      check (
        (target_kind = 'ALL_CASHIERS' and target_profile_id is null)
        or
        (target_kind = 'PROFILE' and target_profile_id is not null)
      ),
    constraint operational_messages_valid_window
      check (valid_until > valid_from),
    constraint operational_messages_cancel_shape
      check (
        (cancelled_at is null and cancelled_by_profile_id is null)
        or
        (cancelled_at is not null and cancelled_by_profile_id is not null)
      )
);

create table public.operational_message_reads (
    message_id uuid not null references public.operational_messages(id) on delete restrict,
    profile_id uuid not null references public.profiles(id) on delete restrict,
    read_at timestamptz not null default now(),
    primary key (message_id, profile_id)
);

create index operational_messages_business_active_idx
on public.operational_messages (business_id, valid_until desc, created_at desc);

create index operational_messages_target_profile_idx
on public.operational_messages (business_id, target_profile_id)
where target_profile_id is not null;

create index operational_message_reads_profile_idx
on public.operational_message_reads (profile_id, read_at desc);

alter table public.operational_messages enable row level security;
alter table public.operational_message_reads enable row level security;

revoke all on table public.operational_messages
from public, anon, authenticated, service_role;
revoke all on table public.operational_message_reads
from public, anon, authenticated, service_role;

create or replace function public.operational_message_capability()
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id','')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id','')::uuid;

    if v_business is null or v_actor is null then
        return false;
    end if;

    return private.has_permission(v_business, 'OPERATIONAL_MESSAGE_MANAGE');
end;
$$;

revoke execute on function public.operational_message_capability()
from public, anon, authenticated, service_role;
grant execute on function public.operational_message_capability()
to authenticated;

create or replace function public.operational_message_options()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id','')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id','')::uuid;

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'OPERATIONAL_MESSAGE_MANAGE') then
        raise exception using errcode='42501', message='SJ_OPERATIONAL_MESSAGE_MANAGE_DENIED';
    end if;

    return jsonb_build_object(
        'profiles',
        coalesce((
            select jsonb_agg(
                jsonb_build_object(
                    'profile_id', p.id,
                    'display_name', p.display_name,
                    'username', uli.normalized_username,
                    'role_code', m.role_code
                )
                order by p.display_name
            )
            from public.business_memberships m
            join public.profiles p on p.id = m.profile_id
            join public.user_login_identities uli on uli.profile_id = p.id
            join public.access_roles r on r.code = m.role_code
            where m.business_id = v_business
              and m.active
              and p.status = 'ACTIVE'
              and r.active
              and not r.owner_level
        ), '[]'::jsonb)
    );
end;
$$;

revoke execute on function public.operational_message_options()
from public, anon, authenticated, service_role;
grant execute on function public.operational_message_options()
to authenticated;

create or replace function public.create_operational_message(
    p_title text,
    p_body text,
    p_priority text,
    p_target_kind text,
    p_target_profile_id uuid,
    p_valid_from timestamptz,
    p_valid_until timestamptz,
    p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_title text;
    v_body text;
    v_priority text;
    v_target_kind text;
    v_valid_from timestamptz;
    v_payload jsonb;
    v_payload_hash text;
    v_lock record;
    v_message_id uuid;
    v_receipt uuid;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id','')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id','')::uuid;

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'OPERATIONAL_MESSAGE_MANAGE') then
        raise exception using errcode='42501', message='SJ_OPERATIONAL_MESSAGE_MANAGE_DENIED';
    end if;

    v_title := btrim(coalesce(p_title,''));
    v_body := btrim(coalesce(p_body,''));
    v_priority := upper(btrim(coalesce(p_priority,'NORMAL')));
    v_target_kind := upper(btrim(coalesce(p_target_kind,'')));
    v_valid_from := coalesce(p_valid_from, now());

    if length(v_title) < 1 or length(v_title) > 120 then
        raise exception using errcode='22023', message='SJ_OPERATIONAL_MESSAGE_TITLE_INVALID';
    end if;
    if length(v_body) < 1 or length(v_body) > 1200 then
        raise exception using errcode='22023', message='SJ_OPERATIONAL_MESSAGE_BODY_INVALID';
    end if;
    if v_priority not in ('NORMAL','HIGH') then
        raise exception using errcode='22023', message='SJ_OPERATIONAL_MESSAGE_PRIORITY_INVALID';
    end if;
    if v_target_kind not in ('ALL_CASHIERS','PROFILE') then
        raise exception using errcode='22023', message='SJ_OPERATIONAL_MESSAGE_TARGET_INVALID';
    end if;
    if p_valid_until is null or p_valid_until <= v_valid_from then
        raise exception using errcode='22023', message='SJ_OPERATIONAL_MESSAGE_WINDOW_INVALID';
    end if;
    if p_valid_until > v_valid_from + interval '30 days' then
        raise exception using errcode='22023', message='SJ_OPERATIONAL_MESSAGE_WINDOW_TOO_LONG';
    end if;

    if v_target_kind = 'ALL_CASHIERS' then
        if p_target_profile_id is not null then
            raise exception using errcode='22023', message='SJ_OPERATIONAL_MESSAGE_TARGET_SHAPE_INVALID';
        end if;
    else
        if p_target_profile_id is null
           or not exists (
              select 1
              from public.business_memberships m
              join public.profiles p on p.id = m.profile_id
              join public.access_roles r on r.code = m.role_code
              where m.business_id = v_business
                and m.profile_id = p_target_profile_id
                and m.active
                and p.status = 'ACTIVE'
                and r.active
                and not r.owner_level
           ) then
            raise exception using errcode='22023', message='SJ_OPERATIONAL_MESSAGE_PROFILE_INVALID';
        end if;
    end if;

    v_payload := jsonb_build_object(
        'title', v_title,
        'body', v_body,
        'priority', v_priority,
        'target_kind', v_target_kind,
        'target_profile_id', p_target_profile_id,
        'valid_from', v_valid_from,
        'valid_until', p_valid_until
    );
    v_payload_hash := private.payload_sha256(v_payload);

    select * into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'OPERATIONAL_MESSAGE_CREATE',
        v_payload_hash
    );

    if v_lock.replay then
        return jsonb_build_object(
            'success', true,
            'replay', true,
            'message_id', v_lock.result_id
        );
    end if;

    insert into public.operational_messages (
        business_id,
        author_profile_id,
        title,
        body,
        priority,
        target_kind,
        target_profile_id,
        valid_from,
        valid_until
    ) values (
        v_business,
        v_actor,
        v_title,
        v_body,
        v_priority,
        v_target_kind,
        case when v_target_kind='PROFILE' then p_target_profile_id else null end,
        v_valid_from,
        p_valid_until
    )
    returning id into v_message_id;

    v_receipt := private.record_operation_success(
        v_business,
        p_idempotency_key,
        'OPERATIONAL_MESSAGE_CREATE',
        v_payload_hash,
        'OPERATIONAL_MESSAGE',
        v_message_id,
        v_actor
    );

    insert into public.audit_events (
        business_id,
        actor_profile_id,
        operation_receipt_id,
        event_type,
        entity_type,
        entity_id,
        metadata
    ) values (
        v_business,
        v_actor,
        v_receipt,
        'OPERATIONAL_MESSAGE_CREATED',
        'OPERATIONAL_MESSAGE',
        v_message_id,
        jsonb_build_object(
            'priority', v_priority,
            'target_kind', v_target_kind,
            'target_profile_id', p_target_profile_id,
            'valid_until', p_valid_until
        )
    );

    return jsonb_build_object(
        'success', true,
        'replay', false,
        'message_id', v_message_id
    );
end;
$$;

revoke execute on function public.create_operational_message(text,text,text,text,uuid,timestamptz,timestamptz,text)
from public, anon, authenticated, service_role;
grant execute on function public.create_operational_message(text,text,text,text,uuid,timestamptz,timestamptz,text)
to authenticated;

create or replace function public.cancel_operational_message(
    p_message_id uuid,
    p_reason text,
    p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_reason text;
    v_payload jsonb;
    v_payload_hash text;
    v_lock record;
    v_receipt uuid;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id','')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id','')::uuid;

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'OPERATIONAL_MESSAGE_MANAGE') then
        raise exception using errcode='42501', message='SJ_OPERATIONAL_MESSAGE_MANAGE_DENIED';
    end if;

    v_reason := nullif(btrim(coalesce(p_reason,'')), '');
    if v_reason is not null and length(v_reason) > 240 then
        raise exception using errcode='22023', message='SJ_OPERATIONAL_MESSAGE_CANCEL_REASON_INVALID';
    end if;

    if not exists (
        select 1 from public.operational_messages m
        where m.id = p_message_id and m.business_id = v_business
    ) then
        raise exception using errcode='P0002', message='SJ_OPERATIONAL_MESSAGE_NOT_FOUND';
    end if;

    v_payload := jsonb_build_object('message_id', p_message_id, 'reason', v_reason);
    v_payload_hash := private.payload_sha256(v_payload);

    select * into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'OPERATIONAL_MESSAGE_CANCEL',
        v_payload_hash
    );

    if v_lock.replay then
        return jsonb_build_object('success', true, 'replay', true, 'message_id', p_message_id);
    end if;

    update public.operational_messages
    set cancelled_at = coalesce(cancelled_at, now()),
        cancelled_by_profile_id = coalesce(cancelled_by_profile_id, v_actor),
        cancel_reason = coalesce(cancel_reason, v_reason)
    where id = p_message_id
      and business_id = v_business;

    v_receipt := private.record_operation_success(
        v_business,
        p_idempotency_key,
        'OPERATIONAL_MESSAGE_CANCEL',
        v_payload_hash,
        'OPERATIONAL_MESSAGE',
        p_message_id,
        v_actor
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor, v_receipt,
        'OPERATIONAL_MESSAGE_CANCELLED', 'OPERATIONAL_MESSAGE', p_message_id,
        jsonb_build_object('reason', v_reason)
    );

    return jsonb_build_object('success', true, 'replay', false, 'message_id', p_message_id);
end;
$$;

revoke execute on function public.cancel_operational_message(uuid,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.cancel_operational_message(uuid,text,text)
to authenticated;

create or replace function public.my_operational_messages(p_limit integer default 5)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_role text;
    v_limit integer;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id','')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id','')::uuid;
    v_role := nullif(v_authority ->> 'role_code','');
    v_limit := greatest(1, least(coalesce(p_limit,5), 20));

    if v_business is null or v_actor is null then
        raise exception using errcode='42501', message='SJ_OPERATIONAL_MESSAGE_READ_DENIED';
    end if;

    return coalesce((
        select jsonb_agg(to_jsonb(x) order by x.priority_rank desc, x.created_at desc)
        from (
            select
                m.id,
                m.title,
                m.body,
                m.priority,
                case when m.priority='HIGH' then 2 else 1 end as priority_rank,
                m.target_kind,
                m.valid_from,
                m.valid_until,
                m.created_at,
                author.display_name as author_name,
                r.read_at
            from public.operational_messages m
            join public.profiles author on author.id = m.author_profile_id
            left join public.operational_message_reads r
              on r.message_id = m.id and r.profile_id = v_actor
            where m.business_id = v_business
              and m.cancelled_at is null
              and now() >= m.valid_from
              and now() < m.valid_until
              and (
                    (m.target_kind='ALL_CASHIERS' and v_role='KASIR')
                    or
                    (m.target_kind='PROFILE' and m.target_profile_id=v_actor)
              )
            order by case when m.priority='HIGH' then 2 else 1 end desc, m.created_at desc
            limit v_limit
        ) x
    ), '[]'::jsonb);
end;
$$;

revoke execute on function public.my_operational_messages(integer)
from public, anon, authenticated, service_role;
grant execute on function public.my_operational_messages(integer)
to authenticated;

create or replace function public.mark_operational_message_read(p_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_role text;
    v_rows integer;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id','')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id','')::uuid;
    v_role := nullif(v_authority ->> 'role_code','');

    if v_business is null or v_actor is null then
        raise exception using errcode='42501', message='SJ_OPERATIONAL_MESSAGE_READ_DENIED';
    end if;

    if not exists (
        select 1
        from public.operational_messages m
        where m.id = p_message_id
          and m.business_id = v_business
          and m.cancelled_at is null
          and now() >= m.valid_from
          and now() < m.valid_until
          and (
                (m.target_kind='ALL_CASHIERS' and v_role='KASIR')
                or
                (m.target_kind='PROFILE' and m.target_profile_id=v_actor)
          )
    ) then
        raise exception using errcode='42501', message='SJ_OPERATIONAL_MESSAGE_READ_DENIED';
    end if;

    insert into public.operational_message_reads(message_id, profile_id, read_at)
    values (p_message_id, v_actor, now())
    on conflict (message_id, profile_id) do nothing;

    get diagnostics v_rows = row_count;

    if v_rows > 0 then
        insert into public.audit_events (
            business_id, actor_profile_id, event_type, entity_type, entity_id, metadata
        ) values (
            v_business, v_actor,
            'OPERATIONAL_MESSAGE_READ', 'OPERATIONAL_MESSAGE', p_message_id,
            '{}'::jsonb
        );
    end if;

    return jsonb_build_object('success', true, 'message_id', p_message_id);
end;
$$;

revoke execute on function public.mark_operational_message_read(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.mark_operational_message_read(uuid)
to authenticated;

create or replace function public.manage_operational_messages(p_limit integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_limit integer;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id','')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id','')::uuid;
    v_limit := greatest(1, least(coalesce(p_limit,30), 100));

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'OPERATIONAL_MESSAGE_MANAGE') then
        raise exception using errcode='42501', message='SJ_OPERATIONAL_MESSAGE_MANAGE_DENIED';
    end if;

    return coalesce((
        select jsonb_agg(to_jsonb(x) order by x.created_at desc)
        from (
            select
                m.id,
                m.title,
                m.body,
                m.priority,
                m.target_kind,
                m.target_profile_id,
                target.display_name as target_profile_name,
                m.valid_from,
                m.valid_until,
                m.created_at,
                m.cancelled_at,
                m.cancel_reason,
                author.display_name as author_name,
                (select count(*)::integer
                   from public.operational_message_reads r
                  where r.message_id=m.id) as read_count,
                case
                  when m.target_kind='PROFILE' then 1
                  else (
                    select count(*)::integer
                    from public.business_memberships bm
                    join public.profiles p on p.id=bm.profile_id
                    where bm.business_id=v_business
                      and bm.active
                      and bm.role_code='KASIR'
                      and p.status='ACTIVE'
                  )
                end as recipient_count
            from public.operational_messages m
            join public.profiles author on author.id=m.author_profile_id
            left join public.profiles target on target.id=m.target_profile_id
            where m.business_id=v_business
            order by m.created_at desc
            limit v_limit
        ) x
    ), '[]'::jsonb);
end;
$$;

revoke execute on function public.manage_operational_messages(integer)
from public, anon, authenticated, service_role;
grant execute on function public.manage_operational_messages(integer)
to authenticated;

comment on table public.operational_messages is
'C11-F0B management-to-cashier operational instructions. Narrow announcement channel; not general chat.';
comment on table public.operational_message_reads is
'C11-F0B read acknowledgements for operational instructions.';
comment on function public.create_operational_message(text,text,text,text,uuid,timestamptz,timestamptz,text) is
'Permission-bounded, audited, idempotent creation of a time-bounded operational instruction.';
comment on function public.my_operational_messages(integer) is
'Authenticated inbox containing only currently active messages targeted to the current actor.';
comment on function public.mark_operational_message_read(uuid) is
'Recipient acknowledgement for one currently active targeted operational message.';
