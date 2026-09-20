-- FIN-P6: Expense approval by amount/category.
-- Pending approval never changes cash or the canonical money ledger.

create table public.expense_approval_rules (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    category_code text not null default '*',
    min_amount numeric(18,2) not null check (min_amount >= 0),
    active boolean not null default true,
    created_by uuid not null references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (business_id, category_code),
    constraint expense_approval_rules_category_valid
        check (length(btrim(category_code)) > 0)
);

create index expense_approval_rules_created_by_idx
    on public.expense_approval_rules(created_by);

alter table public.expense_approval_rules enable row level security;
revoke all on table public.expense_approval_rules from public, anon, authenticated;
grant select on table public.expense_approval_rules to authenticated;

create policy expense_approval_rules_owner_read
on public.expense_approval_rules
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
);

create table public.expense_approval_requests (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    location_id uuid not null references public.locations(id) on delete restrict,
    shift_id uuid not null references public.shifts(id) on delete restrict,
    actor_profile_id uuid not null references public.profiles(id) on delete restrict,
    rule_id uuid not null references public.expense_approval_rules(id) on delete restrict,
    category_code text not null,
    description text not null,
    amount numeric(18,2) not null check (amount > 0),
    created_at timestamptz not null default now(),
    constraint expense_approval_requests_category_nonempty
        check (length(btrim(category_code)) > 0),
    constraint expense_approval_requests_description_nonempty
        check (length(btrim(description)) > 0)
);

create index expense_approval_requests_business_created_idx
    on public.expense_approval_requests(business_id, created_at desc);
create index expense_approval_requests_shift_created_idx
    on public.expense_approval_requests(shift_id, created_at desc);
create index expense_approval_requests_actor_created_idx
    on public.expense_approval_requests(actor_profile_id, created_at desc);
create index expense_approval_requests_rule_idx
    on public.expense_approval_requests(rule_id);
create index expense_approval_requests_location_idx
    on public.expense_approval_requests(location_id);

create trigger expense_approval_requests_immutable
before update or delete on public.expense_approval_requests
for each row execute function private.prevent_fact_mutation();

alter table public.expense_approval_requests enable row level security;
revoke all on table public.expense_approval_requests from public, anon, authenticated;
grant select on table public.expense_approval_requests to authenticated;

create policy expense_approval_requests_scoped_read
on public.expense_approval_requests
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and (
        coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
        or actor_profile_id = (public.get_my_authority() ->> 'profile_id')::uuid
    )
);

create table public.expense_approval_decisions (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    request_id uuid not null unique references public.expense_approval_requests(id) on delete restrict,
    request_actor_profile_id uuid not null references public.profiles(id) on delete restrict,
    decision text not null check (decision in ('APPROVED','REJECTED')),
    decided_by uuid not null references public.profiles(id) on delete restrict,
    reason text,
    business_expense_id uuid references public.business_expenses(id) on delete restrict,
    created_at timestamptz not null default now(),
    constraint expense_approval_decisions_result_valid check (
        (decision = 'APPROVED' and business_expense_id is not null)
        or (decision = 'REJECTED' and business_expense_id is null)
    ),
    constraint expense_approval_decisions_reason_nonempty
        check (reason is null or length(btrim(reason)) > 0)
);

create index expense_approval_decisions_business_created_idx
    on public.expense_approval_decisions(business_id, created_at desc);
create index expense_approval_decisions_actor_idx
    on public.expense_approval_decisions(request_actor_profile_id);
create index expense_approval_decisions_decided_by_idx
    on public.expense_approval_decisions(decided_by);
create index expense_approval_decisions_expense_idx
    on public.expense_approval_decisions(business_expense_id)
    where business_expense_id is not null;

create trigger expense_approval_decisions_immutable
before update or delete on public.expense_approval_decisions
for each row execute function private.prevent_fact_mutation();

alter table public.expense_approval_decisions enable row level security;
revoke all on table public.expense_approval_decisions from public, anon, authenticated;
grant select on table public.expense_approval_decisions to authenticated;

create policy expense_approval_decisions_scoped_read
on public.expense_approval_decisions
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and (
        coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
        or request_actor_profile_id = (public.get_my_authority() ->> 'profile_id')::uuid
    )
);

create view public.expense_approval_queue
with (security_invoker = true)
as
select
    r.id as request_id,
    r.business_id,
    r.location_id,
    r.shift_id,
    r.actor_profile_id,
    r.rule_id,
    r.category_code,
    r.description,
    r.amount,
    r.created_at as requested_at,
    coalesce(d.decision, 'PENDING') as status,
    d.id as decision_id,
    d.decided_by,
    d.reason as decision_reason,
    d.business_expense_id,
    d.created_at as decided_at
from public.expense_approval_requests r
left join public.expense_approval_decisions d on d.request_id = r.id;

revoke all on table public.expense_approval_queue from public, anon, authenticated;
grant select on table public.expense_approval_queue to authenticated;

create or replace function private.finance_matching_expense_rule(
    p_business_id uuid,
    p_category_code text,
    p_amount numeric
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
    select r.id
    from public.expense_approval_rules r
    where r.business_id = p_business_id
      and r.active
      and r.category_code in ('*', upper(btrim(p_category_code)))
      and p_amount >= r.min_amount
    order by
      case when r.category_code = upper(btrim(p_category_code)) then 0 else 1 end,
      r.min_amount desc,
      r.created_at
    limit 1;
$$;

revoke all on function private.finance_matching_expense_rule(uuid,text,numeric)
from public, anon, authenticated, service_role;

create or replace function private.finance_post_shift_expense_fact(
    p_business_id uuid,
    p_actor_profile_id uuid,
    p_shift_id uuid,
    p_location_id uuid,
    p_category_code text,
    p_description text,
    p_amount numeric,
    p_approval_state text,
    p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_shift_cash uuid;
    v_expense uuid;
    v_money uuid;
    v_cash_tx uuid;
begin
    if p_approval_state not in ('NOT_REQUIRED','APPROVED') then
        raise exception using errcode = '22023', message = 'FINANCE_EXPENSE_APPROVAL_STATE_INVALID';
    end if;

    perform 1
    from public.shifts s
    where s.id = p_shift_id
      and s.business_id = p_business_id
      and s.location_id = p_location_id
      and s.cashier_profile_id = p_actor_profile_id
      and s.status = 'OPEN'
    for update;

    if not found then
        raise exception using errcode = '55000', message = 'FINANCE_EXPENSE_APPROVAL_SHIFT_NOT_OPEN';
    end if;

    select id into v_shift_cash
    from public.money_accounts
    where business_id = p_business_id
      and code = 'KAS_SHIFT'
      and active;

    if v_shift_cash is null then
        raise exception using errcode = '23503', message = 'FINANCE_SHIFT_ACCOUNT_MISSING';
    end if;

    if private.finance_account_balance(p_business_id, v_shift_cash) < p_amount then
        raise exception using errcode = '23514', message = 'FINANCE_SHIFT_CASH_INSUFFICIENT';
    end if;

    v_expense := gen_random_uuid();

    v_money := private.record_money_movement(
        p_business_id,
        p_actor_profile_id,
        p_idempotency_key || ':MONEY',
        'EXPENSE',
        v_shift_cash,
        null,
        p_amount,
        'SHIFT_EXPENSE',
        v_expense::text,
        upper(btrim(p_category_code)),
        null
    );

    insert into public.cash_transactions (
        business_id, location_id, shift_id, cashier_profile_id,
        transaction_type, amount, reference_type, reference_id, notes
    ) values (
        p_business_id, p_location_id, p_shift_id, p_actor_profile_id,
        'CASH_OUT', p_amount, 'BUSINESS_EXPENSE', v_expense, btrim(p_description)
    ) returning id into v_cash_tx;

    insert into public.business_expenses (
        id, business_id, location_id, shift_id, actor_profile_id,
        amount, category_code, description, funding_account_id,
        approval_state, money_movement_id, cash_transaction_id
    ) values (
        v_expense, p_business_id, p_location_id, p_shift_id, p_actor_profile_id,
        p_amount, upper(btrim(p_category_code)), btrim(p_description), v_shift_cash,
        p_approval_state, v_money, v_cash_tx
    );

    return v_expense;
end;
$$;

revoke all on function private.finance_post_shift_expense_fact(
    uuid,uuid,uuid,uuid,text,text,numeric,text,text
) from public, anon, authenticated, service_role;

create or replace function public.finance_set_expense_approval_rule(
    p_category_code text,
    p_min_amount numeric,
    p_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_category text;
    v_rule uuid;
begin
    v_authority := public.get_my_authority();
    v_business := (v_authority ->> 'business_id')::uuid;
    v_actor := (v_authority ->> 'profile_id')::uuid;

    if not coalesce((v_authority ->> 'owner')::boolean, false) then
        raise exception using errcode = '42501', message = 'FINANCE_OWNER_REQUIRED';
    end if;

    if p_min_amount is null or p_min_amount < 0 then
        raise exception using errcode = '22023', message = 'FINANCE_EXPENSE_APPROVAL_MIN_AMOUNT_INVALID';
    end if;

    v_category := upper(btrim(coalesce(p_category_code, '')));
    if v_category = '' then
        v_category := '*';
    end if;

    insert into public.expense_approval_rules (
        business_id, category_code, min_amount, active, created_by
    ) values (
        v_business, v_category, p_min_amount, coalesce(p_active,true), v_actor
    )
    on conflict (business_id, category_code) do update
    set min_amount = excluded.min_amount,
        active = excluded.active,
        updated_at = now()
    returning id into v_rule;

    insert into public.audit_events (
        business_id, actor_profile_id, event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor,
        'EXPENSE_APPROVAL_RULE_SET', 'EXPENSE_APPROVAL_RULE', v_rule,
        jsonb_build_object(
            'category_code', v_category,
            'min_amount', p_min_amount,
            'active', coalesce(p_active,true)
        )
    );

    return v_rule;
end;
$$;

revoke execute on function public.finance_set_expense_approval_rule(text,numeric,boolean)
from public, anon, authenticated, service_role;
grant execute on function public.finance_set_expense_approval_rule(text,numeric,boolean)
to authenticated;

create or replace function public.finance_post_shift_expense(
    p_category_code text,
    p_description text,
    p_amount numeric,
    p_idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
    v_shift uuid;
    v_location uuid;
    v_rule uuid;
    v_expense uuid;
    v_payload_hash text;
    v_lock record;
    v_receipt uuid;
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'EXPENSE_SHIFT_CREATE') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if p_amount is null or p_amount <= 0 then
        raise exception using errcode = '22023', message = 'FINANCE_SHIFT_EXPENSE_AMOUNT_INVALID';
    end if;
    if p_category_code is null or length(btrim(p_category_code)) = 0 then
        raise exception using errcode = '22023', message = 'FINANCE_SHIFT_EXPENSE_CATEGORY_REQUIRED';
    end if;
    if p_description is null or length(btrim(p_description)) = 0 then
        raise exception using errcode = '22023', message = 'FINANCE_SHIFT_EXPENSE_DESCRIPTION_REQUIRED';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'actor', v_actor,
            'category_code', upper(btrim(p_category_code)),
            'description', btrim(p_description),
            'amount', p_amount
        )
    );

    select * into v_lock
    from private.lock_operation(v_business, p_idempotency_key, 'SHIFT_EXPENSE', v_payload_hash);

    if v_lock.replay then
        if v_lock.result_type <> 'BUSINESS_EXPENSE' or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;
        return v_lock.result_id;
    end if;

    select s.id, s.location_id
    into v_shift, v_location
    from public.shifts s
    where s.business_id = v_business
      and s.cashier_profile_id = v_actor
      and s.status = 'OPEN';

    if v_shift is null then
        raise exception using errcode = '42501', message = 'SJ_SHIFT_NOT_OPEN';
    end if;

    v_rule := private.finance_matching_expense_rule(
        v_business, p_category_code, p_amount
    );

    if v_rule is not null then
        raise exception using errcode = '55000', message = 'FINANCE_EXPENSE_APPROVAL_REQUIRED';
    end if;

    v_expense := private.finance_post_shift_expense_fact(
        v_business, v_actor, v_shift, v_location,
        p_category_code, p_description, p_amount,
        'NOT_REQUIRED', p_idempotency_key
    );

    v_receipt := private.record_operation_success(
        v_business, p_idempotency_key, 'SHIFT_EXPENSE', v_payload_hash,
        'BUSINESS_EXPENSE', v_expense, v_actor
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor, v_receipt,
        'SHIFT_EXPENSE_CREATED', 'BUSINESS_EXPENSE', v_expense,
        jsonb_build_object(
            'shift_id', v_shift,
            'category_code', upper(btrim(p_category_code)),
            'amount', p_amount,
            'approval_state', 'NOT_REQUIRED'
        )
    );

    return v_expense;
end;
$$;

revoke execute on function public.finance_post_shift_expense(text,text,numeric,text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_post_shift_expense(text,text,numeric,text)
to authenticated;

create or replace function public.finance_submit_shift_expense(
    p_category_code text,
    p_description text,
    p_amount numeric,
    p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
    v_shift uuid;
    v_location uuid;
    v_rule uuid;
    v_expense uuid;
    v_request uuid;
    v_payload_hash text;
    v_lock record;
    v_receipt uuid;
    v_status text;
    v_decided_expense uuid;
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'EXPENSE_SHIFT_CREATE') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if p_amount is null or p_amount <= 0 then
        raise exception using errcode = '22023', message = 'FINANCE_SHIFT_EXPENSE_AMOUNT_INVALID';
    end if;
    if p_category_code is null or length(btrim(p_category_code)) = 0 then
        raise exception using errcode = '22023', message = 'FINANCE_SHIFT_EXPENSE_CATEGORY_REQUIRED';
    end if;
    if p_description is null or length(btrim(p_description)) = 0 then
        raise exception using errcode = '22023', message = 'FINANCE_SHIFT_EXPENSE_DESCRIPTION_REQUIRED';
    end if;

    select s.id, s.location_id
    into v_shift, v_location
    from public.shifts s
    where s.business_id = v_business
      and s.cashier_profile_id = v_actor
      and s.status = 'OPEN';

    if v_shift is null then
        raise exception using errcode = '42501', message = 'SJ_SHIFT_NOT_OPEN';
    end if;

    v_rule := private.finance_matching_expense_rule(
        v_business, p_category_code, p_amount
    );

    if v_rule is null then
        v_expense := public.finance_post_shift_expense(
            p_category_code, p_description, p_amount, p_idempotency_key
        );
        return jsonb_build_object(
            'status','POSTED',
            'expense_id',v_expense,
            'request_id',null
        );
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'actor', v_actor,
            'shift_id', v_shift,
            'rule_id', v_rule,
            'category_code', upper(btrim(p_category_code)),
            'description', btrim(p_description),
            'amount', p_amount
        )
    );

    select * into v_lock
    from private.lock_operation(
        v_business, p_idempotency_key, 'EXPENSE_APPROVAL_REQUEST', v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'EXPENSE_APPROVAL_REQUEST'
           or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;

        select coalesce(d.decision,'PENDING'), d.business_expense_id
        into v_status, v_decided_expense
        from public.expense_approval_requests r
        left join public.expense_approval_decisions d on d.request_id = r.id
        where r.id = v_lock.result_id;

        return jsonb_build_object(
            'status',v_status,
            'expense_id',v_decided_expense,
            'request_id',v_lock.result_id
        );
    end if;

    insert into public.expense_approval_requests (
        business_id, location_id, shift_id, actor_profile_id, rule_id,
        category_code, description, amount
    ) values (
        v_business, v_location, v_shift, v_actor, v_rule,
        upper(btrim(p_category_code)), btrim(p_description), p_amount
    ) returning id into v_request;

    v_receipt := private.record_operation_success(
        v_business, p_idempotency_key, 'EXPENSE_APPROVAL_REQUEST',
        v_payload_hash, 'EXPENSE_APPROVAL_REQUEST', v_request, v_actor
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_actor, v_receipt,
        'EXPENSE_APPROVAL_REQUESTED', 'EXPENSE_APPROVAL_REQUEST', v_request,
        jsonb_build_object(
            'shift_id', v_shift,
            'rule_id', v_rule,
            'category_code', upper(btrim(p_category_code)),
            'amount', p_amount
        )
    );

    return jsonb_build_object(
        'status','PENDING',
        'expense_id',null,
        'request_id',v_request
    );
end;
$$;

revoke execute on function public.finance_submit_shift_expense(text,text,numeric,text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_submit_shift_expense(text,text,numeric,text)
to authenticated;

create or replace function public.finance_decide_expense_request(
    p_request_id uuid,
    p_approve boolean,
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
    v_owner uuid;
    v_request public.expense_approval_requests%rowtype;
    v_decision uuid;
    v_expense uuid;
    v_payload_hash text;
    v_lock record;
    v_receipt uuid;
    v_existing public.expense_approval_decisions%rowtype;
begin
    v_authority := public.get_my_authority();
    v_business := (v_authority ->> 'business_id')::uuid;
    v_owner := (v_authority ->> 'profile_id')::uuid;

    if not coalesce((v_authority ->> 'owner')::boolean, false) then
        raise exception using errcode = '42501', message = 'FINANCE_OWNER_REQUIRED';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'request_id', p_request_id,
            'approve', coalesce(p_approve,false),
            'reason', nullif(btrim(coalesce(p_reason,'')), '')
        )
    );

    select * into v_lock
    from private.lock_operation(
        v_business, p_idempotency_key, 'EXPENSE_APPROVAL_DECISION', v_payload_hash
    );

    if v_lock.replay then
        if v_lock.result_type <> 'EXPENSE_APPROVAL_DECISION'
           or v_lock.result_id is null then
            raise exception using errcode = '23505', message = 'SJ_IDEMPOTENCY_CONFLICT';
        end if;

        select * into v_existing
        from public.expense_approval_decisions
        where id = v_lock.result_id;

        return jsonb_build_object(
            'status',v_existing.decision,
            'request_id',v_existing.request_id,
            'decision_id',v_existing.id,
            'expense_id',v_existing.business_expense_id
        );
    end if;

    select * into v_request
    from public.expense_approval_requests
    where id = p_request_id
      and business_id = v_business
    for update;

    if not found then
        raise exception using errcode = '23503', message = 'FINANCE_EXPENSE_APPROVAL_REQUEST_NOT_FOUND';
    end if;

    if exists (
        select 1 from public.expense_approval_decisions
        where request_id = v_request.id
    ) then
        raise exception using errcode = '23505', message = 'FINANCE_EXPENSE_APPROVAL_ALREADY_DECIDED';
    end if;

    if coalesce(p_approve,false) then
        if not exists (
            select 1 from public.shifts s
            where s.id = v_request.shift_id
              and s.business_id = v_business
              and s.status = 'OPEN'
        ) then
            raise exception using errcode = '55000', message = 'FINANCE_EXPENSE_APPROVAL_SHIFT_NOT_OPEN';
        end if;

        v_expense := private.finance_post_shift_expense_fact(
            v_business,
            v_request.actor_profile_id,
            v_request.shift_id,
            v_request.location_id,
            v_request.category_code,
            v_request.description,
            v_request.amount,
            'APPROVED',
            p_idempotency_key || ':APPROVED'
        );
    else
        v_expense := null;
    end if;

    insert into public.expense_approval_decisions (
        business_id, request_id, request_actor_profile_id,
        decision, decided_by, reason, business_expense_id
    ) values (
        v_business, v_request.id, v_request.actor_profile_id,
        case when coalesce(p_approve,false) then 'APPROVED' else 'REJECTED' end,
        v_owner, nullif(btrim(coalesce(p_reason,'')), ''), v_expense
    ) returning id into v_decision;

    v_receipt := private.record_operation_success(
        v_business, p_idempotency_key, 'EXPENSE_APPROVAL_DECISION',
        v_payload_hash, 'EXPENSE_APPROVAL_DECISION', v_decision, v_owner
    );

    insert into public.audit_events (
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        v_business, v_owner, v_receipt,
        case when coalesce(p_approve,false)
             then 'EXPENSE_APPROVAL_APPROVED'
             else 'EXPENSE_APPROVAL_REJECTED'
        end,
        'EXPENSE_APPROVAL_REQUEST', v_request.id,
        jsonb_build_object(
            'decision_id', v_decision,
            'request_actor_profile_id', v_request.actor_profile_id,
            'shift_id', v_request.shift_id,
            'amount', v_request.amount,
            'business_expense_id', v_expense
        )
    );

    return jsonb_build_object(
        'status',case when coalesce(p_approve,false) then 'APPROVED' else 'REJECTED' end,
        'request_id',v_request.id,
        'decision_id',v_decision,
        'expense_id',v_expense
    );
end;
$$;

revoke execute on function public.finance_decide_expense_request(uuid,boolean,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.finance_decide_expense_request(uuid,boolean,text,text)
to authenticated;
