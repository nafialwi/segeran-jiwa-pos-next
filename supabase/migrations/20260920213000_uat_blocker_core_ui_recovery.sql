-- UAT Blocker Recovery: real Sales UI authority, legacy master bridge,
-- inventory/purchase operational read APIs, and server-authoritative sale prices.

alter table public.stock_items
    add column if not exists sale_price numeric(18,2),
    add column if not exists sale_category text,
    add column if not exists sale_enabled boolean not null default false,
    add column if not exists inventory_tracked boolean not null default true,
    add column if not exists legacy_product_id text;

alter table public.stock_items
    drop constraint if exists stock_items_sale_price_valid,
    add constraint stock_items_sale_price_valid
        check (sale_price is null or sale_price >= 0);

alter table public.stock_items
    drop constraint if exists stock_items_sale_category_nonempty,
    add constraint stock_items_sale_category_nonempty
        check (sale_category is null or length(btrim(sale_category)) > 0);

create unique index if not exists stock_items_business_legacy_product_uidx
    on public.stock_items(business_id, legacy_product_id)
    where legacy_product_id is not null;

create index if not exists stock_items_sale_catalog_idx
    on public.stock_items(business_id, sale_enabled, sale_category, display_name);

create table if not exists public.business_checkout_settings (
    business_id uuid primary key references public.businesses(id) on delete restrict,
    qris_image text,
    updated_by uuid not null references public.profiles(id) on delete restrict,
    updated_at timestamptz not null default now(),
    constraint business_checkout_settings_qris_nonempty
        check (qris_image is null or length(btrim(qris_image)) > 0)
);

alter table public.business_checkout_settings enable row level security;
revoke all on table public.business_checkout_settings from public, anon, authenticated;
grant select on table public.business_checkout_settings to authenticated;

drop policy if exists business_checkout_settings_member_read
on public.business_checkout_settings;

create policy business_checkout_settings_member_read
on public.business_checkout_settings
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and (
        coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
        or (public.get_my_authority() -> 'permissions' ? 'PAYMENT_QRIS')
    )
);

create table if not exists public.legacy_master_imports (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null unique references public.businesses(id) on delete restrict,
    location_id uuid not null references public.locations(id) on delete restrict,
    source_hash text not null,
    menu_count integer not null check (menu_count >= 0),
    tracked_inventory_count integer not null check (tracked_inventory_count >= 0),
    customer_count integer not null check (customer_count >= 0),
    inventory_movement_id uuid references public.inventory_movements(id) on delete restrict,
    imported_by uuid not null references public.profiles(id) on delete restrict,
    created_at timestamptz not null default now(),
    constraint legacy_master_imports_hash_format
        check (source_hash ~ '^[a-f0-9]{64}$')
);

create index if not exists legacy_master_imports_location_idx
    on public.legacy_master_imports(location_id);
create index if not exists legacy_master_imports_imported_by_idx
    on public.legacy_master_imports(imported_by);

create trigger legacy_master_imports_immutable
before update or delete on public.legacy_master_imports
for each row execute function private.prevent_fact_mutation();

alter table public.legacy_master_imports enable row level security;
revoke all on table public.legacy_master_imports from public, anon, authenticated;
grant select on table public.legacy_master_imports to authenticated;

drop policy if exists legacy_master_imports_owner_read
on public.legacy_master_imports;

create policy legacy_master_imports_owner_read
on public.legacy_master_imports
for select
to authenticated
using (
    business_id = (public.get_my_authority() ->> 'business_id')::uuid
    and coalesce((public.get_my_authority() ->> 'owner')::boolean, false)
);

create or replace function public.sales_catalog(p_location_id uuid)
returns table (
    stock_item_id uuid,
    code text,
    display_name text,
    category_code text,
    unit_price numeric,
    inventory_tracked boolean,
    quantity numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_business uuid;
    v_actor uuid;
begin
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    v_actor := private.current_profile_id();

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'SALE_EXECUTE') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if not exists (
        select 1
        from public.shifts s
        where s.business_id = v_business
          and s.location_id = p_location_id
          and s.cashier_profile_id = v_actor
          and s.status = 'OPEN'
    ) then
        raise exception using errcode = '42501', message = 'SJ_SHIFT_NOT_OPEN';
    end if;

    return query
    select
        si.id,
        si.code,
        si.display_name,
        coalesce(si.sale_category, 'LAINNYA'),
        si.sale_price,
        si.inventory_tracked,
        case
            when si.inventory_tracked
                then coalesce(ib.quantity, 0::numeric)
            else null::numeric
        end
    from public.stock_items si
    left join public.inventory_balances ib
      on ib.business_id = si.business_id
     and ib.stock_item_id = si.id
     and ib.location_id = p_location_id
    where si.business_id = v_business
      and si.active
      and si.sale_enabled
      and si.sale_price is not null
      and si.sale_price > 0
    order by coalesce(si.sale_category, 'LAINNYA'), si.display_name;
end;
$$;

revoke execute on function public.sales_catalog(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.sales_catalog(uuid) to authenticated;

create or replace function public.inventory_operational_overview()
returns table (
    location_id uuid,
    location_name text,
    stock_item_id uuid,
    code text,
    display_name text,
    item_kind text,
    base_unit text,
    quantity numeric,
    sale_enabled boolean,
    sale_price numeric,
    sale_category text,
    inventory_tracked boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_owner boolean;
begin
    v_authority := public.get_my_authority();
    v_business := (v_authority ->> 'business_id')::uuid;
    v_actor := (v_authority ->> 'profile_id')::uuid;
    v_owner := coalesce((v_authority ->> 'owner')::boolean, false);

    if v_business is null or v_actor is null
       or not (
            v_owner
            or private.has_permission(v_business, 'INVENTORY_READ')
       ) then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    return query
    select
        l.id,
        l.display_name,
        si.id,
        si.code,
        si.display_name,
        si.item_kind,
        si.base_unit,
        coalesce(ib.quantity, 0::numeric),
        si.sale_enabled,
        si.sale_price,
        si.sale_category,
        si.inventory_tracked
    from public.locations l
    cross join public.stock_items si
    left join public.inventory_balances ib
      on ib.business_id = v_business
     and ib.location_id = l.id
     and ib.stock_item_id = si.id
    where l.business_id = v_business
      and l.active
      and si.business_id = v_business
      and si.active
      and (
        v_owner
        or private.has_inventory_location_scope(v_business, v_actor, l.id)
      )
    order by l.display_name, si.display_name;
end;
$$;

revoke execute on function public.inventory_operational_overview()
from public, anon, authenticated, service_role;
grant execute on function public.inventory_operational_overview()
to authenticated;

create or replace function public.purchase_operational_overview()
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
    v_orders jsonb;
    v_receipts jsonb;
    v_payables jsonb;
begin
    v_authority := public.get_my_authority();
    v_business := (v_authority ->> 'business_id')::uuid;
    v_owner := coalesce((v_authority ->> 'owner')::boolean, false);

    if v_business is null
       or not (
            v_owner
            or private.has_permission(v_business, 'PURCHASE_MANAGE')
       ) then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_orders
    from (
        select
            po.id,
            po.order_number,
            po.status,
            po.ordered_at,
            po.expected_at,
            s.display_name as supplier_name,
            l.display_name as location_name
        from public.purchase_orders po
        join public.suppliers s on s.id = po.supplier_id
        join public.locations l on l.id = po.location_id
        where po.business_id = v_business
        order by po.ordered_at desc
        limit 50
    ) x;

    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_receipts
    from (
        select
            gr.id,
            gr.receipt_number,
            gr.status,
            gr.received_at,
            gr.posted_at,
            po.order_number,
            l.display_name as location_name
        from public.goods_receipts gr
        left join public.purchase_orders po on po.id = gr.purchase_order_id
        join public.locations l on l.id = gr.location_id
        where gr.business_id = v_business
        order by gr.received_at desc
        limit 50
    ) x;

    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_payables
    from (
        select
            b.payable_id,
            b.supplier_name,
            b.invoice_reference,
            b.original_amount,
            b.paid_amount,
            b.balance,
            b.status,
            b.created_at
        from public.supplier_payable_balances b
        where b.business_id = v_business
        order by b.created_at desc
        limit 50
    ) x;

    return jsonb_build_object(
        'orders', v_orders,
        'receipts', v_receipts,
        'payables', v_payables
    );
end;
$$;

revoke execute on function public.purchase_operational_overview()
from public, anon, authenticated, service_role;
grant execute on function public.purchase_operational_overview()
to authenticated;

create or replace function public.import_legacy_master(
    p_location_id uuid,
    p_menu jsonb,
    p_inventory jsonb,
    p_customers jsonb,
    p_settings jsonb,
    p_source_hash text
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
    v_import_id uuid;
    v_inventory_movement uuid;
    v_item jsonb;
    v_customer jsonb;
    v_legacy_id text;
    v_name text;
    v_category text;
    v_code text;
    v_price numeric;
    v_qty numeric;
    v_tracked boolean;
    v_archived boolean;
    v_stock_item uuid;
    v_lines jsonb := '[]'::jsonb;
    v_line_no integer := 0;
    v_menu_count integer := 0;
    v_tracked_count integer := 0;
    v_customer_count integer := 0;
    v_qris text;
    v_customer_name text;
    v_customer_phone text;
begin
    v_authority := public.get_my_authority();
    v_business := (v_authority ->> 'business_id')::uuid;
    v_actor := (v_authority ->> 'profile_id')::uuid;

    if v_business is null or v_actor is null
       or not coalesce((v_authority ->> 'owner')::boolean, false) then
        raise exception using errcode = '42501', message = 'FINANCE_OWNER_REQUIRED';
    end if;

    if p_source_hash is null
       or lower(p_source_hash) !~ '^[a-f0-9]{64}$' then
        raise exception using errcode = '22023', message = 'LEGACY_IMPORT_HASH_INVALID';
    end if;

    if p_menu is null or jsonb_typeof(p_menu) <> 'array' then
        raise exception using errcode = '22023', message = 'LEGACY_IMPORT_MENU_INVALID';
    end if;

    if p_inventory is null or jsonb_typeof(p_inventory) <> 'object' then
        raise exception using errcode = '22023', message = 'LEGACY_IMPORT_INVENTORY_INVALID';
    end if;

    if p_customers is null or jsonb_typeof(p_customers) <> 'array' then
        raise exception using errcode = '22023', message = 'LEGACY_IMPORT_CUSTOMERS_INVALID';
    end if;

    if p_settings is null or jsonb_typeof(p_settings) <> 'object' then
        raise exception using errcode = '22023', message = 'LEGACY_IMPORT_SETTINGS_INVALID';
    end if;

    perform 1
    from public.locations l
    where l.id = p_location_id
      and l.business_id = v_business
      and l.active;

    if not found then
        raise exception using errcode = '23503', message = 'SJ_LOCATION_NOT_FOUND';
    end if;

    perform pg_advisory_xact_lock(hashtextextended('LEGACY_MASTER:' || v_business::text, 0));

    if exists (
        select 1
        from public.legacy_master_imports i
        where i.business_id = v_business
    ) then
        raise exception using errcode = '55000', message = 'LEGACY_MASTER_ALREADY_IMPORTED';
    end if;

    for v_item in
        select value from jsonb_array_elements(p_menu)
    loop
        v_legacy_id := nullif(btrim(coalesce(v_item ->> 'id', '')), '');
        v_name := upper(btrim(coalesce(v_item ->> 'n', v_item ->> 'name', '')));
        v_category := upper(btrim(coalesce(v_item ->> 'c', v_item ->> 'category', 'LAINNYA')));
        v_tracked := lower(coalesce(v_item ->> 'trackStock', 'false')) in ('true','1','yes');
        v_archived := lower(coalesce(v_item ->> 'archived', 'false')) in ('true','1','yes');

        if v_legacy_id is null or v_name = '' then
            raise exception using errcode = '22023', message = 'LEGACY_IMPORT_PRODUCT_INVALID';
        end if;

        begin
            v_price := (v_item ->> 'p')::numeric;
        exception when invalid_text_representation then
            raise exception using errcode = '22023', message = 'LEGACY_IMPORT_PRICE_INVALID';
        end;

        if v_price is null or v_price <= 0 then
            raise exception using errcode = '22023', message = 'LEGACY_IMPORT_PRICE_INVALID';
        end if;

        if v_category = '' then
            v_category := 'LAINNYA';
        end if;

        v_code := 'SJLEG_' || upper(substr(md5(v_legacy_id), 1, 16));

        insert into public.stock_items (
            business_id,
            code,
            display_name,
            item_kind,
            base_unit,
            active,
            sale_price,
            sale_category,
            sale_enabled,
            inventory_tracked,
            legacy_product_id
        ) values (
            v_business,
            v_code,
            v_name,
            'FINISHED_GOOD',
            'PCS',
            not v_archived,
            v_price,
            v_category,
            not v_archived,
            v_tracked,
            v_legacy_id
        )
        returning id into v_stock_item;

        v_menu_count := v_menu_count + 1;

        if v_tracked then
            begin
                v_qty := coalesce(nullif(p_inventory ->> v_legacy_id, '')::numeric, 0);
            exception when invalid_text_representation then
                raise exception using errcode = '22023', message = 'LEGACY_IMPORT_STOCK_INVALID';
            end;

            if v_qty < 0 then
                raise exception using errcode = '22023', message = 'LEGACY_IMPORT_STOCK_INVALID';
            end if;

            if v_qty > 0 then
                v_line_no := v_line_no + 1;
                v_lines := v_lines || jsonb_build_array(
                    jsonb_build_object(
                        'line_no', v_line_no,
                        'stock_item_id', v_stock_item,
                        'location_id', p_location_id,
                        'quantity_delta', v_qty
                    )
                );
                v_tracked_count := v_tracked_count + 1;
            end if;
        end if;
    end loop;

    if jsonb_array_length(v_lines) > 0 then
        v_inventory_movement := private.record_inventory_movement(
            v_business,
            v_actor,
            'LEGACY-MASTER-' || lower(p_source_hash),
            'OPENING_BALANCE',
            'LEGACY_IMPORT',
            lower(p_source_hash),
            'LEGACY_MASTER_MIGRATION',
            v_lines
        );
    end if;

    for v_customer in
        select value from jsonb_array_elements(p_customers)
    loop
        v_customer_name := upper(btrim(coalesce(
            v_customer ->> 'name',
            v_customer ->> 'display_name',
            v_customer ->> 'nama',
            ''
        )));
        v_customer_phone := nullif(btrim(coalesce(
            v_customer ->> 'phone',
            v_customer ->> 'telp',
            v_customer ->> 'wa',
            ''
        )), '');

        if v_customer_name <> ''
           and not exists (
                select 1
                from public.customers c
                where c.business_id = v_business
                  and upper(c.display_name) = v_customer_name
           ) then
            insert into public.customers (
                business_id, display_name, phone, active, created_by
            ) values (
                v_business, v_customer_name, v_customer_phone, true, v_actor
            );
            v_customer_count := v_customer_count + 1;
        end if;
    end loop;

    v_qris := nullif(btrim(coalesce(p_settings ->> 'qris', '')), '');

    insert into public.business_checkout_settings (
        business_id, qris_image, updated_by
    ) values (
        v_business, v_qris, v_actor
    )
    on conflict (business_id) do update
    set qris_image = excluded.qris_image,
        updated_by = excluded.updated_by,
        updated_at = now();

    insert into public.legacy_master_imports (
        business_id,
        location_id,
        source_hash,
        menu_count,
        tracked_inventory_count,
        customer_count,
        inventory_movement_id,
        imported_by
    ) values (
        v_business,
        p_location_id,
        lower(p_source_hash),
        v_menu_count,
        v_tracked_count,
        v_customer_count,
        v_inventory_movement,
        v_actor
    )
    returning id into v_import_id;

    insert into public.audit_events (
        business_id,
        actor_profile_id,
        event_type,
        entity_type,
        entity_id,
        metadata
    ) values (
        v_business,
        v_actor,
        'LEGACY_MASTER_IMPORTED',
        'LEGACY_MASTER_IMPORT',
        v_import_id,
        jsonb_build_object(
            'source_hash', lower(p_source_hash),
            'location_id', p_location_id,
            'menu_count', v_menu_count,
            'tracked_inventory_count', v_tracked_count,
            'customer_count', v_customer_count,
            'inventory_movement_id', v_inventory_movement,
            'qris_present', v_qris is not null
        )
    );

    return jsonb_build_object(
        'import_id', v_import_id,
        'menu_count', v_menu_count,
        'tracked_inventory_count', v_tracked_count,
        'customer_count', v_customer_count,
        'inventory_movement_id', v_inventory_movement,
        'qris_present', v_qris is not null
    );
end;
$$;

revoke execute on function public.import_legacy_master(uuid,jsonb,jsonb,jsonb,jsonb,text)
from public, anon, authenticated, service_role;
grant execute on function public.import_legacy_master(uuid,jsonb,jsonb,jsonb,jsonb,text)
to authenticated;

create or replace function private.record_sale(
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
    v_invoice text;
    v_sale_id uuid;
    v_lock record;
    v_payload_hash text;
    v_subtotal numeric(18,2) := 0;
    v_line integer := 0;
    v_item jsonb;
    v_normalized_items jsonb := '[]'::jsonb;
    v_item_id uuid;
    v_qty numeric;
    v_price numeric;
    v_inventory_tracked boolean;
    v_available numeric;
    v_payment_method text;
    v_payment_amount numeric(18,2);
    v_actor uuid;
    v_shift uuid;
    v_customer uuid;
begin
    v_actor := private.current_profile_id();

    if v_actor is null
       or not private.has_permission(p_business_id, 'SALE_EXECUTE') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if not exists (
        select 1 from public.locations l
        where l.id = p_location_id
          and l.business_id = p_business_id
          and l.active
    ) then
        raise exception using errcode = '23503', message = 'SJ_LOCATION_NOT_FOUND';
    end if;

    select s.id into v_shift
    from public.shifts s
    where s.business_id = p_business_id
      and s.location_id = p_location_id
      and s.cashier_profile_id = v_actor
      and s.status = 'OPEN'
    limit 1;

    if v_shift is null then
        raise exception using errcode = '42501', message = 'SJ_SHIFT_NOT_OPEN';
    end if;

    if p_items is null
       or jsonb_typeof(p_items) <> 'array'
       or jsonb_array_length(p_items) = 0 then
        raise exception using errcode = '22023', message = 'SJ_INVALID_ITEM';
    end if;

    if (
        select count(*) <> count(distinct value ->> 'stock_item_id')
        from jsonb_array_elements(p_items)
    ) then
        raise exception using errcode = '22023', message = 'SJ_INVALID_ITEM';
    end if;

    for v_item in
        select value from jsonb_array_elements(p_items)
    loop
        begin
            v_item_id := nullif(v_item ->> 'stock_item_id', '')::uuid;
            v_qty := (v_item ->> 'quantity')::numeric;
        exception when invalid_text_representation then
            raise exception using errcode = '22023', message = 'SJ_INVALID_ITEM';
        end;

        if v_item_id is null or v_qty is null or v_qty <= 0 then
            raise exception using errcode = '22023', message = 'SJ_INVALID_ITEM';
        end if;

        select si.sale_price, si.inventory_tracked
        into v_price, v_inventory_tracked
        from public.stock_items si
        where si.id = v_item_id
          and si.business_id = p_business_id
          and si.active
          and si.sale_enabled
        for update;

        if not found or v_price is null or v_price <= 0 then
            raise exception using errcode = '22023', message = 'SJ_SALE_PRICE_INVALID';
        end if;

        if v_inventory_tracked then
            select coalesce(ib.quantity, 0)
            into v_available
            from public.inventory_balances ib
            where ib.business_id = p_business_id
              and ib.location_id = p_location_id
              and ib.stock_item_id = v_item_id;

            v_available := coalesce(v_available, 0);

            if v_available < v_qty then
                raise exception using errcode = '23514', message = 'SJ_STOCK_LOW';
            end if;
        end if;

        v_subtotal := v_subtotal + (v_qty * v_price);
        v_normalized_items := v_normalized_items || jsonb_build_array(
            jsonb_build_object(
                'stock_item_id', v_item_id,
                'quantity', v_qty,
                'unit_price', v_price
            )
        );
    end loop;

    if v_subtotal <= 0 then
        raise exception using errcode = '22023', message = 'SJ_INVALID_ITEM';
    end if;

    v_payment_method := upper(btrim(coalesce(p_payment ->> 'method','')));

    if v_payment_method not in ('CASH','QRIS','TRANSFER','CREDIT') then
        raise exception using errcode = '22023', message = 'SJ_PAYMENT_METHOD_UNSUPPORTED';
    end if;

    if v_payment_method = 'QRIS'
       and not private.has_permission(p_business_id, 'PAYMENT_QRIS') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if v_payment_method = 'TRANSFER'
       and not private.has_permission(p_business_id, 'PAYMENT_TRANSFER') then
        raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
    end if;

    if v_payment_method = 'CREDIT' then
        if not private.has_permission(p_business_id, 'CUSTOMER_DEBT_MANAGE') then
            raise exception using errcode = '42501', message = 'SJ_PERMISSION_DENIED';
        end if;

        begin
            v_customer := nullif(p_payment ->> 'customer_id','')::uuid;
        exception when invalid_text_representation then
            raise exception using errcode = '22023', message = 'CUSTOMER_REQUIRED_FOR_DEBT';
        end;

        if v_customer is null or not exists (
            select 1 from public.customers c
            where c.id = v_customer
              and c.business_id = p_business_id
              and c.active
        ) then
            raise exception using errcode = '23503', message = 'CUSTOMER_REQUIRED_FOR_DEBT';
        end if;

        v_payment_amount := v_subtotal;
    else
        begin
            v_payment_amount := nullif(p_payment ->> 'amount','')::numeric;
        exception when invalid_text_representation then
            raise exception using errcode = '22023', message = 'SJ_PAYMENT_INVALID';
        end;

        if v_payment_amount is null
           or v_payment_amount <= 0
           or v_payment_amount <> v_subtotal then
            raise exception using errcode = '22023', message = 'SJ_PAYMENT_ALLOCATION_MISMATCH';
        end if;
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object(
            'actor', v_actor,
            'location_id', p_location_id,
            'items', v_normalized_items,
            'payment', jsonb_build_object(
                'method', v_payment_method,
                'amount', v_payment_amount,
                'customer_id', v_customer
            ),
            'note', p_note
        )
    );

    select * into v_lock
    from private.lock_operation(
        p_business_id, p_operation_id::text, 'SALE_CREATE', v_payload_hash
    );

    if v_lock.replay then
        return jsonb_build_object(
            'success', true,
            'replay', true,
            'receipt_id', v_lock.receipt_id,
            'result_id', v_lock.result_id
        );
    end if;

    v_invoice := private.generate_sale_invoice();

    insert into public.sales (
        business_id, location_id, shift_id, customer_id,
        invoice_number, cashier_profile_id, status,
        subtotal, discount_amount, total_amount, note
    ) values (
        p_business_id, p_location_id, v_shift, v_customer,
        v_invoice, v_actor, 'COMPLETED',
        v_subtotal, 0, v_subtotal, p_note
    ) returning id into v_sale_id;

    for v_item in
        select value from jsonb_array_elements(v_normalized_items)
    loop
        v_line := v_line + 1;

        insert into public.sale_items (
            sale_id, line_no, stock_item_id, quantity, unit_price, subtotal
        ) values (
            v_sale_id,
            v_line,
            (v_item ->> 'stock_item_id')::uuid,
            (v_item ->> 'quantity')::numeric,
            (v_item ->> 'unit_price')::numeric,
            (v_item ->> 'quantity')::numeric * (v_item ->> 'unit_price')::numeric
        );
    end loop;

    insert into public.payments (
        sale_id, method, amount, status, verified_by
    ) values (
        v_sale_id, v_payment_method, v_payment_amount, 'PAID', v_actor
    );

    perform private.record_operation_success(
        p_business_id,
        p_operation_id::text,
        'SALE_CREATE',
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

revoke all on function private.record_sale(uuid,uuid,uuid,jsonb,jsonb,text)
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
    v_payment jsonb;
    v_payload_hash text;
    v_replay record;
    v_account_id uuid;
    v_method text;
    v_amount numeric;
begin
    if p_business_id is null or p_sale_id is null or p_actor_profile_id is null then
        raise exception using errcode = '22023', message = 'SJ_SALE_REQUIRED';
    end if;

    select * into v_sale
    from public.sales
    where id = p_sale_id
      and business_id = p_business_id;

    if not found then
        raise exception using errcode = '23503', message = 'SJ_SALE_NOT_FOUND';
    end if;

    if v_sale.cashier_profile_id <> p_actor_profile_id
       or v_sale.shift_id is null
       or not exists (
            select 1 from public.shifts s
            where s.id = v_sale.shift_id
              and s.business_id = p_business_id
              and s.location_id = v_sale.location_id
              and s.cashier_profile_id = p_actor_profile_id
       ) then
        raise exception using errcode = '42501', message = 'SJ_SALE_ACTOR_SHIFT_MISMATCH';
    end if;

    v_payload_hash := private.payload_sha256(
        jsonb_build_object('sale_id', p_sale_id)
    );

    select * into v_replay
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

    select jsonb_agg(
        jsonb_build_object(
            'line_no', sai.line_no,
            'stock_item_id', sai.stock_item_id,
            'location_id', v_sale.location_id,
            'quantity_delta', sai.quantity * -1
        )
        order by sai.line_no
    ) into v_inventory_lines
    from public.sale_items sai
    join public.stock_items si on si.id = sai.stock_item_id
    where sai.sale_id = p_sale_id
      and si.inventory_tracked;

    if v_inventory_lines is not null then
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
        raise exception using errcode = '22023', message = 'SJ_PAYMENT_REQUIRED';
    end if;

    v_method := v_payment ->> 'method';
    v_amount := (v_payment ->> 'amount')::numeric;

    if v_amount <> v_sale.total_amount then
        raise exception using errcode = '22023', message = 'SJ_PAYMENT_ALLOCATION_MISMATCH';
    end if;

    select id into v_account_id
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
        raise exception using errcode = '23503', message = 'SJ_PAYMENT_ACCOUNT_NOT_FOUND';
    end if;

    if v_method = 'CREDIT' then
        if v_sale.customer_id is null then
            raise exception using errcode = '23503', message = 'CUSTOMER_REQUIRED_FOR_DEBT';
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
            id, business_id, customer_id, sale_id, original_amount,
            receivable_movement_id, created_by
        ) values (
            v_debt_id, p_business_id, v_sale.customer_id, p_sale_id, v_amount,
            v_money_id, p_actor_profile_id
        );
    else
        if v_method not in ('CASH','QRIS','TRANSFER') then
            raise exception using errcode = '22023', message = 'SJ_PAYMENT_METHOD_UNSUPPORTED';
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
        business_id, actor_profile_id, operation_receipt_id,
        event_type, entity_type, entity_id, metadata
    ) values (
        p_business_id,
        p_actor_profile_id,
        v_receipt_id,
        'SALE_POSTED',
        'SALE',
        p_sale_id,
        jsonb_build_object(
            'inventory_movement_id', v_inventory_id,
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
        'money_movement_id', v_money_id,
        'customer_debt_id', v_debt_id,
        'status', 'POSTED'
    );
end;
$$;

revoke all on function private.post_sale_transaction(uuid,uuid,uuid)
from public, anon, authenticated, service_role;
