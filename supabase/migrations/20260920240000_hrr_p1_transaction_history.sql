-- HRR-P1: Transaction History Foundation
-- Read-only individual transaction search. This is not an aggregate report.

insert into public.permission_definitions (code, display_name, category)
values
    ('HISTORY_OWN', 'Riwayat Sendiri', 'RIWAYAT'),
    ('HISTORY_ALL', 'Riwayat Semua', 'RIWAYAT')
on conflict (code) do update
set display_name = excluded.display_name,
    category = excluded.category,
    active = true;

create or replace function public.transaction_history_search(
    p_date_from date default null,
    p_date_to date default null,
    p_invoice_number text default null,
    p_product text default null,
    p_user text default null,
    p_payment_method text default null,
    p_amount_min numeric default null,
    p_amount_max numeric default null,
    p_status text default null,
    p_limit integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_profile uuid;
    v_permissions jsonb;
    v_owner boolean;
    v_can_all boolean;
    v_can_own boolean;
    v_payment_method text;
    v_status text;
    v_limit integer;
begin
    v_authority := public.get_my_authority();
    v_business := (v_authority ->> 'business_id')::uuid;
    v_profile := (v_authority ->> 'profile_id')::uuid;
    v_permissions := coalesce(v_authority -> 'permissions', '[]'::jsonb);
    v_owner := coalesce((v_authority ->> 'owner')::boolean, false);
    v_can_all := v_owner or (v_permissions ? 'HISTORY_ALL');
    v_can_own := v_can_all or (v_permissions ? 'HISTORY_OWN');

    if v_business is null or v_profile is null or not v_can_own then
        raise exception using errcode = '42501', message = 'HISTORY_READ_REQUIRED';
    end if;

    if p_date_from is not null and p_date_to is not null and p_date_from > p_date_to then
        raise exception using errcode = '22023', message = 'HISTORY_DATE_RANGE_INVALID';
    end if;
    if p_amount_min is not null and p_amount_min < 0 then
        raise exception using errcode = '22023', message = 'HISTORY_AMOUNT_INVALID';
    end if;
    if p_amount_max is not null and p_amount_max < 0 then
        raise exception using errcode = '22023', message = 'HISTORY_AMOUNT_INVALID';
    end if;
    if p_amount_min is not null and p_amount_max is not null and p_amount_min > p_amount_max then
        raise exception using errcode = '22023', message = 'HISTORY_AMOUNT_RANGE_INVALID';
    end if;

    v_payment_method := nullif(upper(btrim(coalesce(p_payment_method, ''))), '');
    if v_payment_method is not null
       and v_payment_method not in ('CASH', 'QRIS', 'TRANSFER', 'CREDIT') then
        raise exception using errcode = '22023', message = 'HISTORY_PAYMENT_METHOD_INVALID';
    end if;

    v_status := nullif(upper(btrim(coalesce(p_status, ''))), '');
    if v_status is not null and v_status not in ('COMPLETED', 'VOID', 'REFUNDED') then
        raise exception using errcode = '22023', message = 'HISTORY_STATUS_INVALID';
    end if;

    v_limit := least(greatest(coalesce(p_limit, 100), 1), 200);

    return coalesce((
        select jsonb_agg(q.payload order by q.created_at desc)
        from (
            select
                s.created_at,
                jsonb_build_object(
                    'sale_id', s.id,
                    'invoice_number', s.invoice_number,
                    'business_date', coalesce(sh.opened_at::date, s.created_at::date),
                    'created_at', s.created_at,
                    'status', s.status,
                    'subtotal', s.subtotal,
                    'discount_amount', s.discount_amount,
                    'total_amount', s.total_amount,
                    'cashier_profile_id', s.cashier_profile_id,
                    'cashier_name', cashier.display_name,
                    'cashier_username', uli.normalized_username,
                    'customer_name', customer.display_name,
                    'location_name', loc.display_name,
                    'payment_method', (
                        select string_agg(pay.method, ', ' order by pay.created_at)
                        from public.payments pay where pay.sale_id = s.id
                    ),
                    'payments', coalesce((
                        select jsonb_agg(jsonb_build_object(
                            'method', pay.method,
                            'amount', pay.amount,
                            'status', pay.status,
                            'created_at', pay.created_at
                        ) order by pay.created_at)
                        from public.payments pay where pay.sale_id = s.id
                    ), '[]'::jsonb),
                    'items', coalesce((
                        select jsonb_agg(jsonb_build_object(
                            'line_no', line.line_no,
                            'stock_item_id', line.stock_item_id,
                            'code', item.code,
                            'display_name', item.display_name,
                            'quantity', line.quantity,
                            'unit_price', line.unit_price,
                            'subtotal', line.subtotal
                        ) order by line.line_no)
                        from public.sale_items line
                        join public.stock_items item on item.id = line.stock_item_id
                        where line.sale_id = s.id
                    ), '[]'::jsonb),
                    'note', s.note
                ) as payload
            from public.sales s
            join public.profiles cashier on cashier.id = s.cashier_profile_id
            left join public.user_login_identities uli on uli.profile_id = s.cashier_profile_id
            left join public.customers customer on customer.id = s.customer_id
            join public.locations loc on loc.id = s.location_id
            left join public.shifts sh on sh.id = s.shift_id
            where s.business_id = v_business
              and (v_can_all or s.cashier_profile_id = v_profile)
              and (p_date_from is null or coalesce(sh.opened_at::date, s.created_at::date) >= p_date_from)
              and (p_date_to is null or coalesce(sh.opened_at::date, s.created_at::date) <= p_date_to)
              and (
                  nullif(btrim(coalesce(p_invoice_number, '')), '') is null
                  or lower(s.invoice_number) like '%' || lower(btrim(p_invoice_number)) || '%'
              )
              and (
                  nullif(btrim(coalesce(p_product, '')), '') is null
                  or exists (
                      select 1
                      from public.sale_items line
                      join public.stock_items item on item.id = line.stock_item_id
                      where line.sale_id = s.id
                        and (
                            lower(item.display_name) like '%' || lower(btrim(p_product)) || '%'
                            or lower(item.code) like '%' || lower(btrim(p_product)) || '%'
                        )
                  )
              )
              and (
                  nullif(btrim(coalesce(p_user, '')), '') is null
                  or lower(cashier.display_name) like '%' || lower(btrim(p_user)) || '%'
                  or lower(coalesce(uli.normalized_username, '')) like '%' || lower(btrim(p_user)) || '%'
              )
              and (
                  v_payment_method is null
                  or exists (
                      select 1 from public.payments pay
                      where pay.sale_id = s.id and pay.method = v_payment_method
                  )
              )
              and (p_amount_min is null or s.total_amount >= p_amount_min)
              and (p_amount_max is null or s.total_amount <= p_amount_max)
              and (v_status is null or s.status = v_status)
            order by s.created_at desc
            limit v_limit
        ) q
    ), '[]'::jsonb);
end;
$$;

revoke execute on function public.transaction_history_search(
    date, date, text, text, text, text, numeric, numeric, text, integer
) from public, anon, authenticated, service_role;
grant execute on function public.transaction_history_search(
    date, date, text, text, text, text, numeric, numeric, text, integer
) to authenticated;
