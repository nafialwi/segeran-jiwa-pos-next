-- C10 UAT blocker: Owner finance overview authority.
-- The Owner UI must not depend on direct authenticated reads across finance facts/views.

create or replace function public.finance_owner_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_owner boolean;
    v_accounts jsonb;
    v_customer_debts jsonb;
    v_supplier_payables jsonb;
    v_employee_kasbons jsonb;
    v_employees jsonb;
    v_reconciliations jsonb;
    v_qris_settlements jsonb;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_owner := coalesce((v_authority ->> 'owner')::boolean, false);

    if v_business is null or not v_owner then
        raise exception using
            errcode = '42501',
            message = 'SJ_OWNER_FINANCE_AUTHORITY_REQUIRED';
    end if;

    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.code), '[]'::jsonb)
    into v_accounts
    from (
        select
            a.id,
            a.code,
            a.display_name,
            a.account_type,
            coalesce(b.balance, 0)::numeric(18,2) as balance
        from public.money_accounts a
        left join public.money_balances b
          on b.business_id = a.business_id
         and b.account_id = a.id
        where a.business_id = v_business
        order by a.code
    ) row_data;
    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.created_at desc), '[]'::jsonb)
    into v_customer_debts
    from (
        select
            debt_id,
            customer_name,
            original_amount,
            paid_amount,
            balance,
            status,
            created_at
        from public.customer_debt_balances
        where business_id = v_business
          and balance > 0
        order by created_at desc
    ) row_data;

    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.created_at desc), '[]'::jsonb)
    into v_supplier_payables
    from (
        select
            payable_id,
            supplier_name,
            invoice_reference,
            original_amount,
            paid_amount,
            balance,
            status,
            created_at
        from public.supplier_payable_balances
        where business_id = v_business
          and balance > 0
        order by created_at desc
    ) row_data;

    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.created_at desc), '[]'::jsonb)
    into v_employee_kasbons
    from (
        select
            kasbon_id,
            employee_profile_id,
            employee_name,
            original_amount,
            paid_amount,
            balance,
            status,
            note,
            created_at
        from public.employee_kasbon_balances
        where business_id = v_business
        order by created_at desc
    ) row_data;

    v_employees := public.owner_list_users();
    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.business_date desc, row_data.created_at desc), '[]'::jsonb)
    into v_reconciliations
    from (
        select
            id,
            business_date,
            expected_cash,
            counted_cash,
            cash_variance,
            qris_recorded,
            qris_settled,
            qris_variance,
            transfer_recorded,
            transfer_received,
            transfer_variance,
            stock_status,
            result,
            created_at
        from public.finance_daily_reconciliations
        where business_id = v_business
        order by business_date desc, created_at desc
        limit 10
    ) row_data;

    select coalesce(jsonb_agg(to_jsonb(row_data) order by row_data.settlement_date desc, row_data.created_at desc), '[]'::jsonb)
    into v_qris_settlements
    from (
        select
            id,
            settlement_date,
            provider_reference,
            gross_amount,
            provider_fee,
            net_amount,
            created_at
        from public.qris_settlements
        where business_id = v_business
        order by settlement_date desc, created_at desc
        limit 10
    ) row_data;

    return jsonb_build_object(
        'accounts', v_accounts,
        'customerDebts', v_customer_debts,
        'supplierPayables', v_supplier_payables,
        'employeeKasbons', v_employee_kasbons,
        'employees', coalesce(v_employees, '[]'::jsonb),
        'reconciliations', v_reconciliations,
        'qrisSettlements', v_qris_settlements
    );
end;
$$;
revoke execute on function public.finance_owner_overview()
from public, anon, authenticated, service_role;

grant execute on function public.finance_owner_overview()
to authenticated;

comment on function public.finance_owner_overview() is
'Owner-only finance read projection. Prevents frontend direct reads across protected finance and sales-derived facts.';
