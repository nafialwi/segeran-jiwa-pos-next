-- CS-06-P4: Goods Receipt Note (GRN) + Ledger Posting
--
-- GRN POSTED adalah satu-satunya cara menaikkan stok dari Purchase.
-- PO tidak mengubah stok.

-- 1. goods_receipts (header)
create table public.goods_receipts (
    id uuid primary key default gen_random_uuid(),
    business_id uuid not null references public.businesses(id) on delete restrict,
    receipt_number text not null,
    purchase_order_id uuid not null references public.purchase_orders(id) on delete restrict,
    location_id uuid not null references public.locations(id) on delete restrict,
    status text not null default 'DRAFT',
    received_at timestamptz not null default now(),
    received_by uuid references public.profiles(id) on delete set null,
    posted_at timestamptz,
    posted_by uuid references public.profiles(id) on delete set null,
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (business_id, receipt_number),
    constraint goods_receipts_status_valid check (
        status in ('DRAFT', 'RECEIVED', 'POSTED', 'CANCELLED')
    ),
    constraint goods_receipts_receipt_number_nonempty check (length(btrim(receipt_number)) > 0)
);
create index goods_receipts_business_id_idx on public.goods_receipts(business_id);
create index goods_receipts_po_id_idx on public.goods_receipts(purchase_order_id);
create index goods_receipts_status_idx on public.goods_receipts(status);
alter table public.goods_receipts enable row level security;
create policy "Tenant isolation for goods_receipts" on public.goods_receipts
    for all using (business_id = (public.get_my_authority() ->> 'business_id')::uuid)
    with check (business_id = (public.get_my_authority() ->> 'business_id')::uuid);

-- 2. goods_receipt_lines (detail)
create table public.goods_receipt_lines (
    id uuid primary key default gen_random_uuid(),
    goods_receipt_id uuid not null references public.goods_receipts(id) on delete cascade,
    purchase_order_line_id uuid not null references public.purchase_order_lines(id) on delete restrict,
    stock_item_id uuid not null references public.stock_items(id) on delete restrict,
    unit_id uuid not null references public.units(id) on delete restrict,
    received_quantity numeric(18,4) not null,
    conversion_factor_snapshot numeric(18,6) not null,
    base_quantity numeric(18,4) not null,
    created_at timestamptz not null default now(),
    constraint goods_receipt_lines_received_qty_positive check (received_quantity > 0),
    constraint goods_receipt_lines_conversion_positive check (conversion_factor_snapshot > 0),
    constraint goods_receipt_lines_base_qty_positive check (base_quantity > 0)
);
create index goods_receipt_lines_gr_id_idx on public.goods_receipt_lines(goods_receipt_id);
create index goods_receipt_lines_stock_item_id_idx on public.goods_receipt_lines(stock_item_id);
alter table public.goods_receipt_lines enable row level security;
create policy "Tenant isolation for goods_receipt_lines" on public.goods_receipt_lines
    for all using (exists (
        select 1 from public.goods_receipts gr
        where gr.id = goods_receipt_id
          and gr.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    ))
    with check (exists (
        select 1 from public.goods_receipts gr
        where gr.id = goods_receipt_id
          and gr.business_id = (public.get_my_authority() ->> 'business_id')::uuid
    ));

-- 3. Function: post_goods_receipt (atomic ledger posting)
create or replace function public.post_goods_receipt(p_goods_receipt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_business uuid;
    v_gr record;
    v_po record;
    v_movement_id uuid;
    v_line record;
    v_line_no integer := 0;
    v_received_total numeric;
    v_ordered_total numeric;
    v_all_received boolean := true;
begin
    -- Verify authority
    v_business := (public.get_my_authority() ->> 'business_id')::uuid;
    if v_business is null then
        raise exception 'NO_AUTHORITY';
    end if;

    -- Lock GRN
    select * into v_gr from public.goods_receipts
    where id = p_goods_receipt_id and business_id = v_business
    for update;

    if not found then
        raise exception 'GRN_NOT_FOUND';
    end if;

    -- Verify GRN status
    if v_gr.status = 'POSTED' then
        raise exception 'GRN_ALREADY_POSTED';
    end if;
    if v_gr.status not in ('DRAFT', 'RECEIVED') then
        raise exception 'GRN_INVALID_STATUS';
    end if;

    -- Lock PO
    select * into v_po from public.purchase_orders
    where id = v_gr.purchase_order_id and business_id = v_business
    for update;

    if not found then
        raise exception 'PO_NOT_FOUND';
    end if;

    if v_po.status not in ('APPROVED', 'PARTIALLY_RECEIVED') then
        raise exception 'PO_INVALID_STATUS';
    end if;

    -- Create inventory_movement
    insert into public.inventory_movements(
        business_id, movement_type, source_type, source_ref, reason_code, actor_profile_id
    ) values (
        v_business, 'PURCHASE_RECEIPT', 'GOODS_RECEIPT', v_gr.receipt_number, 'GRN_POSTED', null
    ) returning id into v_movement_id;

    -- Create inventory_movement_lines
    for v_line in
        select grl.stock_item_id, grl.location_id, grl.base_quantity
        from public.goods_receipt_lines grl
        where grl.goods_receipt_id = p_goods_receipt_id
    loop
        v_line_no := v_line_no + 1;
        insert into public.inventory_movement_lines(
            movement_id, line_no, stock_item_id, location_id, quantity_delta
        ) values (
            v_movement_id, v_line_no, v_line.stock_item_id, v_gr.location_id, v_line.base_quantity
        );
    end loop;

    -- Update GRN = POSTED
    update public.goods_receipts
    set status = 'POSTED', posted_at = now(), updated_at = now()
    where id = p_goods_receipt_id;

    -- Update PO status based on received vs ordered
    select coalesce(sum(grl.base_quantity), 0) into v_received_total
    from public.goods_receipt_lines grl
    join public.goods_receipts gr on gr.id = grl.goods_receipt_id
    where gr.purchase_order_id = v_po.id
      and gr.status = 'POSTED';

    select coalesce(sum(pol.base_quantity), 0) into v_ordered_total
    from public.purchase_order_lines pol
    where pol.purchase_order_id = v_po.id;

    if v_received_total >= v_ordered_total then
        update public.purchase_orders set status = 'RECEIVED', updated_at = now() where id = v_po.id;
    else
        update public.purchase_orders set status = 'PARTIALLY_RECEIVED', updated_at = now() where id = v_po.id;
    end if;

    return jsonb_build_object('success', true, 'movement_id', v_movement_id, 'po_status', case when v_received_total >= v_ordered_total then 'RECEIVED' else 'PARTIALLY_RECEIVED' end);
end;
$$;

-- Grant execute to authenticated
revoke all on function public.post_goods_receipt(uuid) from public;
grant execute on function public.post_goods_receipt(uuid) to authenticated;
