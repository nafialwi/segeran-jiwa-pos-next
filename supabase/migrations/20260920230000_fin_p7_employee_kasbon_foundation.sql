-- FIN-P7: Employee Kasbon Foundation
-- Blueprint boundary: Kasbon Karyawan is separate from customer debt and is
-- used only for employees. Repayment/deduction mechanics remain intentionally
-- out of scope until later authority is locked.

insert into public.money_accounts (
    business_id,
    code,
    display_name,
    account_type,
    active
)
select
    b.id,
    'KASBON_KARYAWAN',
    'Kasbon Karyawan',
    'OTHER',
    true
from public.businesses b
where b.code = 'SJ'
on conflict (business_id, code) do update
set display_name = excluded.display_name,
    account_type = excluded.account_type,
    active = true;

create table public.employee_kasbons (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    employee_profile_id uuid not null references public.profiles(id) on delete restrict,
    original_amount numeric(18,2) not null check (original_amount > 0),
    funding_account_id uuid not null references public.money_accounts(id) on delete restrict,
    money_movement_id uuid not null unique references public.money_movements(id) on delete restrict,
    created_by uuid not null references public.profiles(id) on delete restrict,
    note text,
    created_at timestamptz not null default now()
);

create index employee_kasbons_business_created_idx
    on public.employee_kasbons(business_id, created_at desc);
create index employee_kasbons_employee_created_idx
    on public.employee_kasbons(employee_profile_id, created_at desc);
create index employee_kasbons_funding_account_idx
    on public.employee_kasbons(funding_account_id);
create index employee_kasbons_created_by_idx
    on public.employee_kasbons(created_by);

create trigger employee_kasbons_immutable
before update or delete on public.employee_kasbons
for each row execute function private.prevent_fact_mutation();

alter table public.employee_kasbons enable row level security;
revoke all on table public.employee_kasbons from public, anon, authenticated;
grant select on table public.employee_kasbons to authenticated;

create policy employee_kasbons_owner_read
on public.employee_kasbons
for select
to authenticated
using (
    (public.get_my_authority() ->> 'business_id')::uuid = business_id
    and coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
);

create view public.employee_kasbon_balances
with (security_invoker = true)
as
select
    k.id as kasbon_id,
    k.business_id,
    k.employee_profile_id,
    p.display_name as employee_name,
    k.original_amount,
    0::numeric(18,2) as paid_amount,
    k.original_amount::numeric(18,2) as balance,
    'OPEN'::text as status,
    k.funding_account_id,
    k.money_movement_id,
    k.note,
    k.created_at
from public.employee_kasbons k
join public.profiles p on p.id = k.employee_profile_id;

revoke all on table public.employee_kasbon_balances
from public, anon, authenticated;
grant select on table public.employee_kasbon_balances to authenticated;

create or replace function public.finance_create_employee_kasbon(
    p_employee_profile_id uuid,
    p_source_method text,
    p_amount numeric,
    p_note text,
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
    v_method text;
    v_source_account uuid;
    v_source_code text;
    v_kasbon_account uuid;
    v_kasbon uuid;
    v_money uuid;
    v_payload_hash text;
    v_lock record;
    v_receipt uuid;
begin
    v_authority := public.get_my_authority();
    v_business := (v_authority ->> 'business_id')::uuid;
    v_actor := (v_authority ->> 'profile_id')::uuid;
    v_method := upper(btrim(coalesce(p_source_method, '')));

    if v_business is null
       or v_actor is null
       or not coalesce((v_authority ->> 'owner')::boolean, false) then
        raise exception using errcode = '42501', message = 'FINANCE_OWNER_REQUIRED';
    end if;

    if p_employee_profile_id is null then
        raise exception using errcode = '22023', message = 'EMPLOYEE_KASBON_EMPLOYEE_REQUIRED';
    end if;

    if p_amount is null or p_amount <= 0 then
        raise exception using errcode = '22023', message = 'EMPLOYEE_KASBON_AMOUNT_INVALID';
    end if;

    if v_method not in ('CASH', 'TRANSFER') then
        raise exception using errcode = '22023', message = 'EMPLOYEE_KASBON_SOURCE_METHOD_INVALID';
    end if;

    v_source_code := case when v_method = 'CASH' then 'KAS_UTAMA' else 'BANK' end;

    select id into v_source_account
    from public.money_accounts
    where business_id = v_business
      and code = v_source_code
      and active;

    select id into v_kasbon_account
    from public.money_accounts
    where business_id = v_business
      and code = 'KASBON_KARYAWAN'
      and active;

    if v_source_account is null or v_kasbon_account is null then
        raise exception using errcode = '55000', message = 'EMPLOYEE_KASBON_ACCOUNT_MISSING';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'employee_profile_id', p_employee_profile_id,
            'source_method', v_method,
            'amount', p_amount::numeric(18,2),
            'note', nullif(btrim(coalesce(p_note, '')), '')
        )
    );

    select * into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'EMPLOYEE_KASBON_CREATE',
        v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'EMPLOYEE_KASBON'
           or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;

        select k.money_movement_id
        into v_money
        from public.employee_kasbons k
        where k.id = v_lock.result_id
          and k.business_id = v_business;

        if v_money is null then
            raise exception using errcode = '55000', message = 'EMPLOYEE_KASBON_REPLAY_RESULT_MISSING';
        end if;

        return jsonb_build_object(
            'kasbon_id', v_lock.result_id,
            'money_movement_id', v_money,
            'already_posted', true
        );
    end if;

    if not exists (
        select 1
        from public.business_memberships m
        join public.access_roles r
          on r.code = m.role_code
         and r.active
        where m.business_id = v_business
          and m.profile_id = p_employee_profile_id
          and m.active
          and not r.owner_level
    ) then
        raise exception using errcode = '23503', message = 'EMPLOYEE_KASBON_EMPLOYEE_INVALID';
    end if;

    if private.finance_account_balance(v_business, v_source_account) < p_amount then
        raise exception using errcode = '23514', message = 'FINANCE_INSUFFICIENT_BALANCE';
    end if;

    v_kasbon := gen_random_uuid();

    v_money := private.record_money_movement(
        v_business,
        v_actor,
        p_idempotency_key || ':MONEY',
        'TRANSFER',
        v_source_account,
        v_kasbon_account,
        p_amount,
        'EMPLOYEE_KASBON',
        v_kasbon::text,
        'EMPLOYEE_KASBON_DISBURSEMENT',
        null
    );

    insert into public.employee_kasbons (
        id,
        business_id,
        employee_profile_id,
        original_amount,
        funding_account_id,
        money_movement_id,
        created_by,
        note
    ) values (
        v_kasbon,
        v_business,
        p_employee_profile_id,
        p_amount::numeric(18,2),
        v_source_account,
        v_money,
        v_actor,
        nullif(btrim(coalesce(p_note, '')), '')
    );

    v_receipt := private.record_operation_success(
        v_business,
        p_idempotency_key,
        'EMPLOYEE_KASBON_CREATE',
        v_payload_hash,
        'EMPLOYEE_KASBON',
        v_kasbon,
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
        'EMPLOYEE_KASBON_CREATED',
        'EMPLOYEE_KASBON',
        v_kasbon,
        jsonb_build_object(
            'employee_profile_id', p_employee_profile_id,
            'source_method', v_method,
            'funding_account_id', v_source_account,
            'amount', p_amount::numeric(18,2)
        )
    );

    return jsonb_build_object(
        'kasbon_id', v_kasbon,
        'money_movement_id', v_money,
        'already_posted', false
    );
end;
$$;

revoke execute on function public.finance_create_employee_kasbon(
    uuid, text, numeric, text, text
) from public, anon, authenticated, service_role;
grant execute on function public.finance_create_employee_kasbon(
    uuid, text, numeric, text, text
) to authenticated;
