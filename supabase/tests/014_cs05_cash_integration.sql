begin;

do $$
declare
    v_business uuid;
    v_profile uuid := '00000000-0000-0000-0000-000000000911';
    v_auth uuid := '00000000-0000-0000-0000-000000000912';
    v_location uuid;
    v_sale uuid;
    v_shift uuid;
    v_cnt integer;
begin
    if not exists (
        select 1
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'private' and p.proname = 'cs05_shift_expected_cash'
    ) then
        raise exception 'private.cs05_shift_expected_cash missing';
    end if;

    if not exists (
        select 1
        from pg_trigger t
        join pg_class c on c.oid = t.tgrelid
        where t.tgname = 'cs05_capture_cash_sale' and c.relname = 'payments'
    ) then
        raise exception 'trigger cs05_capture_cash_sale missing on payments';
    end if;

    if not has_function_privilege('authenticated', 'public.cs05_add_cash_movement(text, numeric, text)', 'execute') then
        raise exception 'authenticated cannot execute cs05_add_cash_movement';
    end if;

    if not has_function_privilege('authenticated', 'public.cs05_shift_reconciliation(uuid)', 'execute') then
        raise exception 'authenticated cannot execute cs05_shift_reconciliation';
    end if;

    select id into v_business from public.businesses where code = 'SJ';
    select id into v_location from public.locations where business_id = v_business and code = 'GERAI';

    insert into public.profiles(id, auth_user_id, display_name)
    values (v_profile, v_auth, 'CS05 P4 Cash Integration Test');

    insert into public.shifts(business_id, location_id, cashier_profile_id, opening_balance)
    values (v_business, v_location, v_profile, 50000)
    returning id into v_shift;

    insert into public.sales(business_id, location_id, invoice_number, cashier_profile_id, status, subtotal, discount_amount, total_amount)
    values (v_business, v_location, 'INV-CS05P4-001', v_profile, 'COMPLETED', 7000, 0, 7000)
    returning id into v_sale;

    insert into public.payments(sale_id, method, amount, status)
    values (v_sale, 'CASH', 7000, 'PAID');

    select count(*) into v_cnt
    from public.cash_transactions
    where shift_id = v_shift
      and transaction_type = 'SALE'
      and reference_id = v_sale;
    if v_cnt <> 1 then
        raise exception 'CS05_P4_CASH_CAPTURE_FAILED';
    end if;

    select shift_id into v_shift
    from public.sales
    where id = v_sale;
    if v_shift is null then
        raise exception 'CS05_P4_SALE_SHIFT_LINK_FAILED';
    end if;

    if private.cs05_shift_expected_cash(v_shift) <> 57000 then
        raise exception 'CS05_P4_EXPECTED_CASH_FAILED';
    end if;
end $$;

rollback;
