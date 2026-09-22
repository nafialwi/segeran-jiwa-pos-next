-- C2-B: variant sale execution + immutable consumption snapshots.
--
-- The existing public.checkout_sale remains available for RC1 compatibility.
-- C2-B adds public.checkout_sale_v2 and upgrades the single canonical
-- post-sale transaction function so both legacy and V2 sales still reach the
-- same inventory and money engines.
--
-- Refund/correction continue to reverse the original inventory movement.
-- They are deliberately not reimplemented here.

alter table public.sale_items
    alter column stock_item_id drop not null,
    add column sale_product_id uuid references public.sale_products(id) on delete restrict,
    add column variant_id uuid references public.product_variants(id) on delete restrict,
    add column product_code_snapshot text,
    add column product_name_snapshot text,
    add column variant_code_snapshot text,
    add column variant_name_snapshot text,
    add column fulfillment_mode_snapshot text;

alter table public.sale_items
    add constraint sale_items_source_present
        check (stock_item_id is not null or variant_id is not null),
    add constraint sale_items_v2_snapshot_shape
        check (
            variant_id is null
            or (
                sale_product_id is not null
                and length(btrim(product_code_snapshot)) > 0
                and length(btrim(product_name_snapshot)) > 0
                and length(btrim(variant_code_snapshot)) > 0
                and length(btrim(variant_name_snapshot)) > 0
                and fulfillment_mode_snapshot in (
                    'DIRECT_STOCK',
                    'MAKE_TO_ORDER',
                    'PREPRODUCED'
                )
            )
        );

create index sale_items_variant_idx
    on public.sale_items(variant_id)
    where variant_id is not null;

create table public.sale_item_component_snapshots (
    sale_id uuid not null,
    sale_line_no integer not null,
    component_line_no integer not null,
    stock_item_id uuid not null references public.stock_items(id) on delete restrict,
    component_role text not null,
    quantity_per_unit numeric(18,3) not null,
    quantity_total numeric(18,3) not null,
    inventory_tracked_snapshot boolean not null,
    stock_item_code_snapshot text not null,
    stock_item_name_snapshot text not null,
    created_at timestamptz not null default now(),
    primary key (sale_id, sale_line_no, component_line_no),
    unique (sale_id, sale_line_no, stock_item_id),
    foreign key (sale_id, sale_line_no)
        references public.sale_items(sale_id, line_no)
        on delete restrict,
    constraint sale_item_component_snapshots_line_positive
        check (sale_line_no > 0 and component_line_no > 0),
    constraint sale_item_component_snapshots_role_valid
        check (component_role in ('INGREDIENT','PACKAGING','FINISHED_GOOD')),
    constraint sale_item_component_snapshots_quantity_positive
        check (quantity_per_unit > 0 and quantity_total > 0),
    constraint sale_item_component_snapshots_code_nonempty
        check (length(btrim(stock_item_code_snapshot)) > 0),
    constraint sale_item_component_snapshots_name_nonempty
        check (length(btrim(stock_item_name_snapshot)) > 0)
);

create index sale_item_component_snapshots_stock_idx
    on public.sale_item_component_snapshots(stock_item_id);

create trigger sale_item_component_snapshots_immutable
before update or delete on public.sale_item_component_snapshots
for each row execute function private.prevent_fact_mutation();

alter table public.sale_item_component_snapshots enable row level security;

create policy sale_item_component_snapshots_member_read
on public.sale_item_component_snapshots
for select
to authenticated
using (
    exists (
        select 1
        from public.sales s
        where s.id = sale_id
          and private.is_active_member(s.business_id)
    )
);

revoke all on table public.sale_item_component_snapshots
from public, anon, authenticated;

create or replace function private.record_sale_v2(
    p_operation_id uuid,
    p_business_id uuid,
    p_location_id uuid,
    p_items jsonb,
    p_payment jsonb,
    p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor uuid;
    v_shift uuid;
    v_invoice text;
    v_sale_id uuid;
    v_request_items jsonb := '[]'::jsonb;
    v_resolved_items jsonb := '[]'::jsonb;
    v_item jsonb;
    v_variant_id uuid;
    v_qty numeric;
    v_subtotal numeric(18,2) := 0;
    v_line integer := 0;
    v_payment_method text;
    v_requested_amount numeric(18,2);
    v_payment_amount numeric(18,2);
    v_customer uuid;
    v_payload_hash text;
    v_lock record;
    v_product_id uuid;
    v_product_code text;
    v_product_name text;
    v_variant_code text;
    v_variant_name text;
    v_fulfillment_mode text;
    v_sale_stock_item_id uuid;
    v_price numeric(18,2);
    v_component_count integer;
    v_finished_good_match_count integer;
    v_invalid_component_count integer;
    v_precision_bad_count integer;
begin
    v_actor := private.current_profile_id();

    if p_operation_id is null then
        raise exception using errcode='22023', message='SJ_OPERATION_REQUIRED';
    end if;

    if v_actor is null
       or not private.has_permission(p_business_id, 'SALE_EXECUTE') then
        raise exception using errcode='42501', message='SJ_PERMISSION_DENIED';
    end if;

    if not exists (
        select 1
        from public.locations l
        where l.id = p_location_id
          and l.business_id = p_business_id
          and l.active
    ) then
        raise exception using errcode='23503', message='SJ_LOCATION_NOT_FOUND';
    end if;

    select s.id
    into v_shift
    from public.shifts s
    where s.business_id = p_business_id
      and s.location_id = p_location_id
      and s.cashier_profile_id = v_actor
      and s.status = 'OPEN'
    limit 1;

    if v_shift is null then
        raise exception using errcode='42501', message='SJ_SHIFT_NOT_OPEN';
    end if;

    if p_items is null
       or jsonb_typeof(p_items) <> 'array'
       or jsonb_array_length(p_items) = 0 then
        raise exception using errcode='22023', message='SJ_INVALID_ITEM';
    end if;

    if (
        select count(*) <> count(distinct value ->> 'variant_id')
        from jsonb_array_elements(p_items)
    ) then
        raise exception using errcode='22023', message='SJ_INVALID_ITEM';
    end if;

    for v_item in
        select value
        from jsonb_array_elements(p_items)
    loop
        begin
            v_variant_id := nullif(v_item ->> 'variant_id','')::uuid;
            v_qty := (v_item ->> 'quantity')::numeric;
        exception when invalid_text_representation then
            raise exception using errcode='22023', message='SJ_INVALID_ITEM';
        end;

        if v_variant_id is null or v_qty is null or v_qty <= 0 then
            raise exception using errcode='22023', message='SJ_INVALID_ITEM';
        end if;

        v_request_items := v_request_items || jsonb_build_array(
            jsonb_build_object(
                'variant_id', v_variant_id,
                'quantity', v_qty
            )
        );
    end loop;

    v_payment_method := upper(btrim(coalesce(p_payment ->> 'method','')));

    if v_payment_method not in ('CASH','QRIS','TRANSFER','CREDIT') then
        raise exception using errcode='22023', message='SJ_PAYMENT_METHOD_UNSUPPORTED';
    end if;

    if v_payment_method = 'QRIS'
       and not private.has_permission(p_business_id, 'PAYMENT_QRIS') then
        raise exception using errcode='42501', message='SJ_PERMISSION_DENIED';
    end if;

    if v_payment_method = 'TRANSFER'
       and not private.has_permission(p_business_id, 'PAYMENT_TRANSFER') then
        raise exception using errcode='42501', message='SJ_PERMISSION_DENIED';
    end if;

    if v_payment_method = 'CREDIT' then
        if not private.has_permission(p_business_id, 'CUSTOMER_DEBT_MANAGE') then
            raise exception using errcode='42501', message='SJ_PERMISSION_DENIED';
        end if;

        begin
            v_customer := nullif(p_payment ->> 'customer_id','')::uuid;
        exception when invalid_text_representation then
            raise exception using errcode='22023', message='CUSTOMER_REQUIRED_FOR_DEBT';
        end;
    else
        begin
            v_requested_amount := nullif(p_payment ->> 'amount','')::numeric;
        exception when invalid_text_representation then
            raise exception using errcode='22023', message='SJ_PAYMENT_INVALID';
        end;

        if v_requested_amount is null or v_requested_amount <= 0 then
            raise exception using errcode='22023', message='SJ_PAYMENT_INVALID';
        end if;
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'actor', v_actor,
            'location_id', p_location_id,
            'items', v_request_items,
            'payment', jsonb_build_object(
                'method', v_payment_method,
                'amount', v_requested_amount,
                'customer_id', v_customer
            ),
            'note', p_note
        )
    );

    select *
    into v_lock
    from private.lock_operation(
        p_business_id,
        p_operation_id::text,
        'SALE_CREATE_V2',
        v_payload_hash
    );

    if v_lock.replay then
        return jsonb_build_object(
            'success', true,
            'replay', true,
            'receipt_id', v_lock.receipt_id,
            'result_id', v_lock.result_id
        );
    end if;

    if v_payment_method = 'CREDIT' then
        if v_customer is null or not exists (
            select 1
            from public.customers c
            where c.id = v_customer
              and c.business_id = p_business_id
              and c.active
        ) then
            raise exception using errcode='23503', message='CUSTOMER_REQUIRED_FOR_DEBT';
        end if;
    end if;

    for v_item in
        select value
        from jsonb_array_elements(v_request_items)
    loop
        v_variant_id := (v_item ->> 'variant_id')::uuid;
        v_qty := (v_item ->> 'quantity')::numeric;

        select
            p.id,
            p.code,
            p.display_name,
            v.code,
            v.display_name,
            v.fulfillment_mode,
            v.sale_stock_item_id,
            v.sale_price
        into
            v_product_id,
            v_product_code,
            v_product_name,
            v_variant_code,
            v_variant_name,
            v_fulfillment_mode,
            v_sale_stock_item_id,
            v_price
        from public.product_variants v
        join public.sale_products p
          on p.id = v.product_id
         and p.business_id = v.business_id
        where v.id = v_variant_id
          and v.business_id = p_business_id
          and v.active
          and p.active;

        if not found or v_price is null or v_price <= 0 then
            raise exception using errcode='22023', message='SJ_VARIANT_INVALID';
        end if;

        select count(*)
        into v_component_count
        from public.variant_sale_components c
        where c.variant_id = v_variant_id;

        if v_component_count = 0 then
            raise exception using errcode='23514', message='SJ_VARIANT_COMPONENTS_MISSING';
        end if;

        select count(*)
        into v_invalid_component_count
        from public.variant_sale_components c
        left join public.stock_items si
          on si.id = c.stock_item_id
         and si.business_id = p_business_id
        where c.variant_id = v_variant_id
          and (
              si.id is null
              or not si.active
              or (
                  v_fulfillment_mode = 'MAKE_TO_ORDER'
                  and c.component_role = 'FINISHED_GOOD'
              )
          );

        if v_invalid_component_count > 0 then
            raise exception using errcode='23514', message='SJ_VARIANT_COMPONENT_SHAPE_INVALID';
        end if;

        if v_fulfillment_mode in ('DIRECT_STOCK','PREPRODUCED') then
            select count(*)
            into v_finished_good_match_count
            from public.variant_sale_components c
            where c.variant_id = v_variant_id
              and c.component_role = 'FINISHED_GOOD'
              and c.stock_item_id = v_sale_stock_item_id;

            if v_sale_stock_item_id is null or v_finished_good_match_count <> 1 then
                raise exception using errcode='23514', message='SJ_VARIANT_COMPONENT_SHAPE_INVALID';
            end if;
        end if;

        select count(*)
        into v_precision_bad_count
        from public.variant_sale_components c
        where c.variant_id = v_variant_id
          and (c.quantity_per_unit * v_qty) <> round(c.quantity_per_unit * v_qty, 3);

        if v_precision_bad_count > 0 then
            raise exception using errcode='22023', message='SJ_VARIANT_COMPONENT_PRECISION_UNSUPPORTED';
        end if;

        v_subtotal := v_subtotal + (v_qty * v_price);

        v_resolved_items := v_resolved_items || jsonb_build_array(
            jsonb_build_object(
                'sale_product_id', v_product_id,
                'variant_id', v_variant_id,
                'product_code_snapshot', v_product_code,
                'product_name_snapshot', v_product_name,
                'variant_code_snapshot', v_variant_code,
                'variant_name_snapshot', v_variant_name,
                'fulfillment_mode_snapshot', v_fulfillment_mode,
                'sale_stock_item_id', v_sale_stock_item_id,
                'quantity', v_qty,
                'unit_price', v_price
            )
        );
    end loop;

    if v_subtotal <= 0 then
        raise exception using errcode='22023', message='SJ_INVALID_ITEM';
    end if;

    if v_payment_method = 'CREDIT' then
        v_payment_amount := v_subtotal;
    else
        v_payment_amount := v_requested_amount;

        if v_payment_amount <> v_subtotal then
            raise exception using errcode='22023', message='SJ_PAYMENT_ALLOCATION_MISMATCH';
        end if;
    end if;

    v_invoice := private.generate_sale_invoice();

    insert into public.sales (
        business_id,
        location_id,
        shift_id,
        customer_id,
        invoice_number,
        cashier_profile_id,
        status,
        subtotal,
        discount_amount,
        total_amount,
        note
    ) values (
        p_business_id,
        p_location_id,
        v_shift,
        v_customer,
        v_invoice,
        v_actor,
        'COMPLETED',
        v_subtotal,
        0,
        v_subtotal,
        p_note
    )
    returning id into v_sale_id;

    for v_item in
        select value
        from jsonb_array_elements(v_resolved_items)
    loop
        v_line := v_line + 1;

        insert into public.sale_items (
            sale_id,
            line_no,
            stock_item_id,
            quantity,
            unit_price,
            subtotal,
            sale_product_id,
            variant_id,
            product_code_snapshot,
            product_name_snapshot,
            variant_code_snapshot,
            variant_name_snapshot,
            fulfillment_mode_snapshot
        ) values (
            v_sale_id,
            v_line,
            nullif(v_item ->> 'sale_stock_item_id','')::uuid,
            (v_item ->> 'quantity')::numeric,
            (v_item ->> 'unit_price')::numeric,
            (v_item ->> 'quantity')::numeric * (v_item ->> 'unit_price')::numeric,
            (v_item ->> 'sale_product_id')::uuid,
            (v_item ->> 'variant_id')::uuid,
            v_item ->> 'product_code_snapshot',
            v_item ->> 'product_name_snapshot',
            v_item ->> 'variant_code_snapshot',
            v_item ->> 'variant_name_snapshot',
            v_item ->> 'fulfillment_mode_snapshot'
        );

        insert into public.sale_item_component_snapshots (
            sale_id,
            sale_line_no,
            component_line_no,
            stock_item_id,
            component_role,
            quantity_per_unit,
            quantity_total,
            inventory_tracked_snapshot,
            stock_item_code_snapshot,
            stock_item_name_snapshot
        )
        select
            v_sale_id,
            v_line,
            c.line_no,
            c.stock_item_id,
            c.component_role,
            c.quantity_per_unit,
            (c.quantity_per_unit * (v_item ->> 'quantity')::numeric)::numeric(18,3),
            si.inventory_tracked,
            si.code,
            si.display_name
        from public.variant_sale_components c
        join public.stock_items si
          on si.id = c.stock_item_id
         and si.business_id = p_business_id
        where c.variant_id = (v_item ->> 'variant_id')::uuid
        order by c.line_no;
    end loop;

    insert into public.payments (
        sale_id,
        method,
        amount,
        status,
        verified_by
    ) values (
        v_sale_id,
        v_payment_method,
        v_payment_amount,
        'PAID',
        v_actor
    );

    perform private.record_operation_success(
        p_business_id,
        p_operation_id::text,
        'SALE_CREATE_V2',
        v_payload_hash,
        'SALE',
        v_sale_id,
        v_actor
    );

    return jsonb_build_object(
        'success', true,
        'sale_id', v_sale_id,
        'invoice_number', v_invoice,
        'status', 'COMPLETED'
    );
end;
$$;

revoke all on function private.record_sale_v2(uuid,uuid,uuid,jsonb,jsonb,text)
from public, anon, authenticated, service_role;

create or replace function private.post_sale_transaction(
    p_business_id uuid,
    p_actor_profile_id uuid,
    p_sale_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_sale public.sales%rowtype;
    v_inventory_id uuid;
    v_money_id uuid;
    v_receipt_id uuid;
    v_debt_id uuid;
    v_inventory_lines jsonb;
    v_inventory_basis text;
    v_payment jsonb;
    v_payload_hash text;
    v_replay record;
    v_account_id uuid;
    v_method text;
    v_amount numeric;
    v_stock record;
    v_available numeric;
begin
    if p_business_id is null or p_sale_id is null or p_actor_profile_id is null then
        raise exception using errcode='22023', message='SJ_SALE_REQUIRED';
    end if;

    select *
    into v_sale
    from public.sales
    where id = p_sale_id
      and business_id = p_business_id;

    if not found then
        raise exception using errcode='23503', message='SJ_SALE_NOT_FOUND';
    end if;

    if v_sale.cashier_profile_id <> p_actor_profile_id
       or v_sale.shift_id is null
       or not exists (
            select 1
            from public.shifts s
            where s.id = v_sale.shift_id
              and s.business_id = p_business_id
              and s.location_id = v_sale.location_id
              and s.cashier_profile_id = p_actor_profile_id
       ) then
        raise exception using errcode='42501', message='SJ_SALE_ACTOR_SHIFT_MISMATCH';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object('sale_id', p_sale_id)
    );

    select *
    into v_replay
    from private.lock_operation(
        p_business_id,
        'SALE-POSTING-' || p_sale_id::text,
        'SALE_POSTING',
        v_payload_hash
    );

    if v_replay.replay then
        return jsonb_build_object(
            'success', true,
            'already_posted', true,
            'sale_id', p_sale_id,
            'result_id', v_replay.result_id
        );
    end if;

    if exists (
        select 1
        from public.sale_item_component_snapshots sics
        where sics.sale_id = p_sale_id
    ) then
        v_inventory_basis := 'SNAPSHOT_V2';

        select jsonb_agg(
            jsonb_build_object(
                'line_no', x.line_no,
                'stock_item_id', x.stock_item_id,
                'location_id', v_sale.location_id,
                'quantity_delta', x.quantity_total * -1
            )
            order by x.line_no
        )
        into v_inventory_lines
        from (
            select
                row_number() over(order by sics.stock_item_id)::integer as line_no,
                sics.stock_item_id,
                sum(sics.quantity_total)::numeric(18,3) as quantity_total
            from public.sale_item_component_snapshots sics
            where sics.sale_id = p_sale_id
              and sics.inventory_tracked_snapshot
            group by sics.stock_item_id
        ) x;
    else
        v_inventory_basis := 'LEGACY_SALE_ITEM';

        select jsonb_agg(
            jsonb_build_object(
                'line_no', x.line_no,
                'stock_item_id', x.stock_item_id,
                'location_id', v_sale.location_id,
                'quantity_delta', x.quantity_total * -1
            )
            order by x.line_no
        )
        into v_inventory_lines
        from (
            select
                row_number() over(order by sai.stock_item_id)::integer as line_no,
                sai.stock_item_id,
                sum(sai.quantity)::numeric(18,3) as quantity_total
            from public.sale_items sai
            join public.stock_items si
              on si.id = sai.stock_item_id
             and si.business_id = p_business_id
            where sai.sale_id = p_sale_id
              and si.inventory_tracked
            group by sai.stock_item_id
        ) x;
    end if;

    if v_inventory_lines is not null then
        for v_stock in
            select *
            from jsonb_to_recordset(v_inventory_lines) as x(
                line_no integer,
                stock_item_id uuid,
                location_id uuid,
                quantity_delta numeric
            )
            order by stock_item_id
        loop
            perform pg_catalog.pg_advisory_xact_lock(
                pg_catalog.hashtextextended(
                    'C2B:SALE-STOCK:'
                    || p_business_id::text || ':'
                    || v_sale.location_id::text || ':'
                    || v_stock.stock_item_id::text,
                    0
                )
            );

            select coalesce(ib.quantity, 0::numeric)
            into v_available
            from public.inventory_balances ib
            where ib.business_id = p_business_id
              and ib.location_id = v_sale.location_id
              and ib.stock_item_id = v_stock.stock_item_id;

            v_available := coalesce(v_available, 0::numeric);

            if v_stock.quantity_delta >= 0
               or v_available < abs(v_stock.quantity_delta) then
                raise exception using errcode='23514', message='SJ_STOCK_LOW';
            end if;
        end loop;

        v_inventory_id := private.record_inventory_movement(
            p_business_id,
            p_actor_profile_id,
            'SALE-INVENTORY-' || p_sale_id::text,
            'SALE',
            'SALE',
            v_sale.invoice_number,
            'SALE_CONSUMPTION',
            v_inventory_lines
        );
    else
        v_inventory_id := null;
    end if;

    select jsonb_build_object('method', method, 'amount', amount)
    into v_payment
    from public.payments
    where sale_id = p_sale_id
    limit 1;

    if v_payment is null then
        raise exception using errcode='22023', message='SJ_PAYMENT_REQUIRED';
    end if;

    v_method := v_payment ->> 'method';
    v_amount := (v_payment ->> 'amount')::numeric;

    if v_amount <> v_sale.total_amount then
        raise exception using errcode='22023', message='SJ_PAYMENT_ALLOCATION_MISMATCH';
    end if;

    select id
    into v_account_id
    from public.money_accounts
    where business_id = p_business_id
      and code = case
          when v_method = 'CASH' then 'KAS_SHIFT'
          when v_method = 'QRIS' then 'QRIS_BELUM_CAIR'
          when v_method = 'TRANSFER' then 'BANK'
          when v_method = 'CREDIT' then 'HUTANG_PELANGGAN'
          else null
      end
      and active
    limit 1;

    if v_account_id is null then
        raise exception using errcode='23503', message='SJ_PAYMENT_ACCOUNT_NOT_FOUND';
    end if;

    if v_method = 'CREDIT' then
        if v_sale.customer_id is null then
            raise exception using errcode='23503', message='CUSTOMER_REQUIRED_FOR_DEBT';
        end if;

        v_debt_id := gen_random_uuid();

        v_money_id := private.record_money_movement(
            p_business_id,
            p_actor_profile_id,
            'SALE-MONEY-' || p_sale_id::text,
            'INCOME',
            null,
            v_account_id,
            v_amount,
            'CUSTOMER_DEBT',
            v_debt_id::text,
            'CUSTOMER_DEBT_SALE'
        );

        insert into public.customer_debts (
            id,
            business_id,
            customer_id,
            sale_id,
            original_amount,
            receivable_movement_id,
            created_by
        ) values (
            v_debt_id,
            p_business_id,
            v_sale.customer_id,
            p_sale_id,
            v_amount,
            v_money_id,
            p_actor_profile_id
        );
    else
        if v_method not in ('CASH','QRIS','TRANSFER') then
            raise exception using errcode='22023', message='SJ_PAYMENT_METHOD_UNSUPPORTED';
        end if;

        v_money_id := private.record_money_movement(
            p_business_id,
            p_actor_profile_id,
            'SALE-MONEY-' || p_sale_id::text,
            'INCOME',
            null,
            v_account_id,
            v_amount,
            'SALE',
            v_sale.invoice_number,
            'SALE_PAYMENT'
        );
    end if;

    v_receipt_id := private.record_operation_success(
        p_business_id,
        'SALE-POSTING-' || p_sale_id::text,
        'SALE_POSTING',
        v_payload_hash,
        'SALE',
        p_sale_id,
        p_actor_profile_id
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
        p_business_id,
        p_actor_profile_id,
        v_receipt_id,
        'SALE_POSTED',
        'SALE',
        p_sale_id,
        jsonb_build_object(
            'inventory_movement_id', v_inventory_id,
            'inventory_basis', v_inventory_basis,
            'money_movement_id', v_money_id,
            'customer_debt_id', v_debt_id,
            'receipt_id', v_receipt_id,
            'sale_id', p_sale_id,
            'invoice_number', v_sale.invoice_number
        )
    );

    return jsonb_build_object(
        'success', true,
        'sale_id', p_sale_id,
        'inventory_movement_id', v_inventory_id,
        'inventory_basis', v_inventory_basis,
        'money_movement_id', v_money_id,
        'customer_debt_id', v_debt_id,
        'status', 'POSTED'
    );
end;
$$;

revoke all on function private.post_sale_transaction(uuid,uuid,uuid)
from public, anon, authenticated, service_role;

create or replace function public.checkout_sale_v2(
    p_operation_id uuid,
    p_location_id uuid,
    p_items jsonb,
    p_payment jsonb,
    p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
    v_record jsonb;
    v_post jsonb;
    v_sale uuid;
    v_invoice text;
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if v_business is null or v_actor is null then
        raise exception using errcode='42501', message='SJ_AUTHORITY_DENIED';
    end if;

    v_record := private.record_sale_v2(
        p_operation_id,
        v_business,
        p_location_id,
        p_items,
        p_payment,
        p_note
    );

    v_sale := coalesce(
        nullif(v_record ->> 'sale_id','')::uuid,
        nullif(v_record ->> 'result_id','')::uuid
    );

    if v_sale is null then
        raise exception using errcode='55000', message='SJ_SALE_RESULT_MISSING';
    end if;

    v_post := private.post_sale_transaction(v_business, v_actor, v_sale);

    select invoice_number
    into v_invoice
    from public.sales
    where id = v_sale;

    return jsonb_build_object(
        'success', true,
        'sale_id', v_sale,
        'invoice_number', v_invoice,
        'customer_debt_id', v_post ->> 'customer_debt_id',
        'inventory_basis', v_post ->> 'inventory_basis',
        'already_posted', coalesce((v_post ->> 'already_posted')::boolean, false)
    );
end;
$$;

revoke execute on function public.checkout_sale_v2(uuid,uuid,jsonb,jsonb,text)
from public, anon, authenticated, service_role;

grant execute on function public.checkout_sale_v2(uuid,uuid,jsonb,jsonb,text)
to authenticated;

comment on table public.sale_item_component_snapshots is
'Immutable sale-time component facts used for V2 inventory posting and historical reversal.';

comment on function public.checkout_sale_v2(uuid,uuid,jsonb,jsonb,text) is
'Variant-based checkout. Existing checkout_sale remains the RC1 compatibility boundary until frontend convergence.';
