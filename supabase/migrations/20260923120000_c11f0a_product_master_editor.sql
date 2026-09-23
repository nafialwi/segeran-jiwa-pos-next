-- C11-F0A: Product Master Editor
--
-- Additive, permission-bounded management of sale_products, product_variants,
-- and sale-stage variant components. Historical sales remain immutable because
-- checkout already snapshots product/variant/component facts at sale time.
--
-- IMPORTANT: this migration does not alter inventory posting, BOM authority,
-- finance authority, shift authority, or historical sale facts.

insert into public.permission_definitions (code, display_name, category, active)
values ('PRODUCT_MANAGE', 'Kelola Produk Jual', 'PRODUK', true)
on conflict (code) do update
set display_name = excluded.display_name,
    category = excluded.category,
    active = excluded.active;

create or replace function public.product_master_capability()
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
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        return false;
    end if;

    return private.has_permission(v_business, 'PRODUCT_MANAGE');
end;
$$;

revoke execute on function public.product_master_capability()
from public, anon, authenticated, service_role;
grant execute on function public.product_master_capability() to authenticated;

create or replace function public.save_sale_product_master(
    p_product_id uuid,
    p_code text,
    p_display_name text,
    p_category_code text,
    p_description text,
    p_active boolean,
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
    v_payload jsonb;
    v_payload_hash text;
    v_lock record;
    v_product public.sale_products%rowtype;
    v_product_id uuid;
    v_code text;
    v_category text;
    v_created boolean := false;
    v_receipt uuid;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'PRODUCT_MANAGE') then
        raise exception using errcode='42501', message='SJ_PRODUCT_MANAGE_DENIED';
    end if;

    v_code := upper(btrim(coalesce(p_code, '')));
    v_category := nullif(upper(btrim(coalesce(p_category_code, ''))), '');

    if v_code !~ '^[A-Z0-9][A-Z0-9_-]{0,63}$' then
        raise exception using errcode='22023', message='SJ_PRODUCT_CODE_INVALID';
    end if;
    if p_display_name is null or length(btrim(p_display_name)) = 0 then
        raise exception using errcode='22023', message='SJ_PRODUCT_NAME_REQUIRED';
    end if;
    if length(btrim(p_display_name)) > 160 then
        raise exception using errcode='22023', message='SJ_PRODUCT_NAME_TOO_LONG';
    end if;
    if v_category is not null and length(v_category) > 64 then
        raise exception using errcode='22023', message='SJ_PRODUCT_CATEGORY_TOO_LONG';
    end if;

    v_payload := jsonb_build_object(
        'product_id', p_product_id,
        'code', v_code,
        'display_name', btrim(p_display_name),
        'category_code', v_category,
        'description', nullif(btrim(coalesce(p_description, '')), ''),
        'active', coalesce(p_active, true)
    );
    v_payload_hash := private.payload_sha256(v_payload);

    select *
    into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'PRODUCT_MASTER_SAVE',
        v_payload_hash
    );

    if v_lock.replay then
        select *
        into v_product
        from public.sale_products p
        where p.id = v_lock.result_id
          and p.business_id = v_business;

        if not found then
            raise exception using errcode='P0002', message='SJ_PRODUCT_REPLAY_RESULT_MISSING';
        end if;

        return jsonb_build_object(
            'success', true,
            'replay', true,
            'product_id', v_product.id,
            'created', false
        );
    end if;

    if p_product_id is null then
        insert into public.sale_products (
            business_id,
            code,
            display_name,
            category_code,
            description,
            active,
            updated_at
        ) values (
            v_business,
            v_code,
            btrim(p_display_name),
            v_category,
            nullif(btrim(coalesce(p_description, '')), ''),
            coalesce(p_active, true),
            now()
        )
        returning id into v_product_id;
        v_created := true;
    else
        select p.id
        into v_product_id
        from public.sale_products p
        where p.id = p_product_id
          and p.business_id = v_business
        for update;

        if not found then
            raise exception using errcode='P0002', message='SJ_PRODUCT_NOT_FOUND';
        end if;

        update public.sale_products
        set code = v_code,
            display_name = btrim(p_display_name),
            category_code = v_category,
            description = nullif(btrim(coalesce(p_description, '')), ''),
            active = coalesce(p_active, true),
            updated_at = now()
        where id = v_product_id
          and business_id = v_business;
    end if;

    v_receipt := private.record_operation_success(
        v_business,
        p_idempotency_key,
        'PRODUCT_MASTER_SAVE',
        v_payload_hash,
        'SALE_PRODUCT',
        v_product_id,
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
        case when v_created then 'SALE_PRODUCT_CREATED' else 'SALE_PRODUCT_UPDATED' end,
        'SALE_PRODUCT',
        v_product_id,
        jsonb_build_object(
            'code', v_code,
            'active', coalesce(p_active, true),
            'category_code', v_category
        )
    );

    return jsonb_build_object(
        'success', true,
        'replay', false,
        'product_id', v_product_id,
        'created', v_created
    );
end;
$$;

revoke execute on function public.save_sale_product_master(uuid,text,text,text,text,boolean,text)
from public, anon, authenticated, service_role;
grant execute on function public.save_sale_product_master(uuid,text,text,text,text,boolean,text)
to authenticated;
create or replace function public.save_product_variant_master(
    p_variant_id uuid,
    p_product_id uuid,
    p_code text,
    p_display_name text,
    p_fulfillment_mode text,
    p_sale_stock_item_id uuid,
    p_sale_price numeric,
    p_active boolean,
    p_is_default boolean,
    p_components jsonb,
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
    v_payload jsonb;
    v_payload_hash text;
    v_lock record;
    v_variant public.product_variants%rowtype;
    v_variant_id uuid;
    v_code text;
    v_mode text;
    v_created boolean := false;
    v_effective_default boolean;
    v_component jsonb;
    v_component_id uuid;
    v_role text;
    v_quantity numeric;
    v_item_kind text;
    v_seen uuid[] := array[]::uuid[];
    v_line integer;
    v_user_component_count integer := 0;
    v_receipt uuid;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'PRODUCT_MANAGE') then
        raise exception using errcode='42501', message='SJ_PRODUCT_MANAGE_DENIED';
    end if;

    if p_product_id is null
       or not exists (
           select 1
           from public.sale_products p
           where p.id = p_product_id
             and p.business_id = v_business
       ) then
        raise exception using errcode='P0002', message='SJ_PRODUCT_NOT_FOUND';
    end if;

    v_code := upper(btrim(coalesce(p_code, '')));
    v_mode := upper(btrim(coalesce(p_fulfillment_mode, '')));

    if v_code !~ '^[A-Z0-9][A-Z0-9_-]{0,63}$' then
        raise exception using errcode='22023', message='SJ_VARIANT_CODE_INVALID';
    end if;
    if p_display_name is null or length(btrim(p_display_name)) = 0 then
        raise exception using errcode='22023', message='SJ_VARIANT_NAME_REQUIRED';
    end if;
    if length(btrim(p_display_name)) > 160 then
        raise exception using errcode='22023', message='SJ_VARIANT_NAME_TOO_LONG';
    end if;
    if v_mode not in ('DIRECT_STOCK','MAKE_TO_ORDER','PREPRODUCED') then
        raise exception using errcode='22023', message='SJ_VARIANT_MODE_INVALID';
    end if;
    if p_sale_price is null
       or lower(p_sale_price::text) in ('nan','infinity','-infinity')
       or p_sale_price <= 0
       or p_sale_price <> round(p_sale_price, 2) then
        raise exception using errcode='22023', message='SJ_VARIANT_PRICE_INVALID';
    end if;
    if p_components is null or jsonb_typeof(p_components) <> 'array' then
        raise exception using errcode='22023', message='SJ_VARIANT_COMPONENTS_INVALID';
    end if;

    if v_mode = 'MAKE_TO_ORDER' then
        if p_sale_stock_item_id is not null then
            raise exception using errcode='22023', message='SJ_MTO_SALE_STOCK_MUST_BE_NULL';
        end if;
    else
        if p_sale_stock_item_id is null then
            raise exception using errcode='22023', message='SJ_VARIANT_SALE_STOCK_REQUIRED';
        end if;
        if not exists (
            select 1
            from public.stock_items si
            where si.id = p_sale_stock_item_id
              and si.business_id = v_business
              and si.active
        ) then
            raise exception using errcode='22023', message='SJ_VARIANT_SALE_STOCK_INVALID';
        end if;
    end if;

    for v_component in
        select value
        from jsonb_array_elements(p_components)
    loop
        begin
            v_component_id := nullif(v_component ->> 'stock_item_id', '')::uuid;
        exception when invalid_text_representation then
            raise exception using errcode='22023', message='SJ_VARIANT_COMPONENT_ID_INVALID';
        end;

        v_role := upper(btrim(coalesce(v_component ->> 'role', '')));
        begin
            v_quantity := (v_component ->> 'quantity_per_unit')::numeric;
        exception when invalid_text_representation then
            raise exception using errcode='22023', message='SJ_VARIANT_COMPONENT_QUANTITY_INVALID';
        end;

        if v_component_id is null
           or v_role is null
           or v_role not in ('INGREDIENT','PACKAGING') then
            raise exception using errcode='22023', message='SJ_VARIANT_COMPONENT_INVALID';
        end if;
        if v_component_id = any(v_seen) then
            raise exception using errcode='22023', message='SJ_VARIANT_COMPONENT_DUPLICATE';
        end if;
        if v_quantity is null
           or lower(v_quantity::text) in ('nan','infinity','-infinity')
           or v_quantity <= 0
           or v_quantity <> round(v_quantity, 3) then
            raise exception using errcode='22023', message='SJ_VARIANT_COMPONENT_QUANTITY_INVALID';
        end if;

        select si.item_kind
        into v_item_kind
        from public.stock_items si
        where si.id = v_component_id
          and si.business_id = v_business
          and si.active;

        if not found then
            raise exception using errcode='22023', message='SJ_VARIANT_COMPONENT_STOCK_INVALID';
        end if;

        if v_role = 'PACKAGING' and v_item_kind <> 'PACKAGING' then
            raise exception using errcode='22023', message='SJ_VARIANT_PACKAGING_KIND_INVALID';
        end if;
        if v_role = 'INGREDIENT' and v_item_kind not in ('MATERIAL','OTHER') then
            raise exception using errcode='22023', message='SJ_VARIANT_INGREDIENT_KIND_INVALID';
        end if;
        if v_mode in ('DIRECT_STOCK','PREPRODUCED') and v_role = 'INGREDIENT' then
            raise exception using errcode='22023', message='SJ_STOCK_VARIANT_INGREDIENT_NOT_ALLOWED';
        end if;

        v_seen := array_append(v_seen, v_component_id);
        v_user_component_count := v_user_component_count + 1;
    end loop;

    if v_mode = 'MAKE_TO_ORDER' and v_user_component_count = 0 then
        raise exception using errcode='22023', message='SJ_MTO_COMPONENT_REQUIRED';
    end if;

    v_payload := jsonb_build_object(
        'variant_id', p_variant_id,
        'product_id', p_product_id,
        'code', v_code,
        'display_name', btrim(p_display_name),
        'fulfillment_mode', v_mode,
        'sale_stock_item_id', p_sale_stock_item_id,
        'sale_price', p_sale_price,
        'active', coalesce(p_active, true),
        'is_default', coalesce(p_is_default, false),
        'components', p_components
    );
    v_payload_hash := private.payload_sha256(v_payload);

    select *
    into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'PRODUCT_VARIANT_MASTER_SAVE',
        v_payload_hash
    );

    if v_lock.replay then
        select *
        into v_variant
        from public.product_variants v
        where v.id = v_lock.result_id
          and v.business_id = v_business;

        if not found then
            raise exception using errcode='P0002', message='SJ_VARIANT_REPLAY_RESULT_MISSING';
        end if;

        return jsonb_build_object(
            'success', true,
            'replay', true,
            'variant_id', v_variant.id,
            'created', false
        );
    end if;

    v_effective_default := coalesce(p_is_default, false)
        or not exists (
            select 1
            from public.product_variants sibling
            where sibling.product_id = p_product_id
              and sibling.business_id = v_business
              and (p_variant_id is null or sibling.id <> p_variant_id)
              and sibling.is_default
        );

    if v_effective_default then
        update public.product_variants
        set is_default = false,
            updated_at = now()
        where product_id = p_product_id
          and business_id = v_business
          and is_default
          and (p_variant_id is null or id <> p_variant_id);
    end if;

    if p_variant_id is null then
        insert into public.product_variants (
            business_id,
            product_id,
            code,
            display_name,
            fulfillment_mode,
            sale_stock_item_id,
            sale_price,
            active,
            is_default,
            updated_at
        ) values (
            v_business,
            p_product_id,
            v_code,
            btrim(p_display_name),
            v_mode,
            case when v_mode='MAKE_TO_ORDER' then null else p_sale_stock_item_id end,
            p_sale_price,
            coalesce(p_active, true),
            v_effective_default,
            now()
        )
        returning id into v_variant_id;
        v_created := true;
    else
        select v.id
        into v_variant_id
        from public.product_variants v
        where v.id = p_variant_id
          and v.product_id = p_product_id
          and v.business_id = v_business
        for update;

        if not found then
            raise exception using errcode='P0002', message='SJ_VARIANT_NOT_FOUND';
        end if;

        update public.product_variants
        set code = v_code,
            display_name = btrim(p_display_name),
            fulfillment_mode = v_mode,
            sale_stock_item_id = case
                when v_mode='MAKE_TO_ORDER' then null
                else p_sale_stock_item_id
            end,
            sale_price = p_sale_price,
            active = coalesce(p_active, true),
            is_default = v_effective_default,
            updated_at = now()
        where id = v_variant_id
          and business_id = v_business;
    end if;

    delete from public.variant_sale_components
    where variant_id = v_variant_id;

    v_line := 1;

    if v_mode in ('DIRECT_STOCK','PREPRODUCED') then
        insert into public.variant_sale_components (
            variant_id,
            line_no,
            stock_item_id,
            component_role,
            quantity_per_unit
        ) values (
            v_variant_id,
            v_line,
            p_sale_stock_item_id,
            'FINISHED_GOOD',
            1.000
        );
        v_line := v_line + 1;
    end if;

    for v_component in
        select value
        from jsonb_array_elements(p_components)
    loop
        v_component_id := (v_component ->> 'stock_item_id')::uuid;
        v_role := upper(btrim(v_component ->> 'role'));
        v_quantity := (v_component ->> 'quantity_per_unit')::numeric;

        insert into public.variant_sale_components (
            variant_id,
            line_no,
            stock_item_id,
            component_role,
            quantity_per_unit
        ) values (
            v_variant_id,
            v_line,
            v_component_id,
            v_role,
            v_quantity
        );

        v_line := v_line + 1;
    end loop;

    v_receipt := private.record_operation_success(
        v_business,
        p_idempotency_key,
        'PRODUCT_VARIANT_MASTER_SAVE',
        v_payload_hash,
        'PRODUCT_VARIANT',
        v_variant_id,
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
        case when v_created then 'PRODUCT_VARIANT_CREATED' else 'PRODUCT_VARIANT_UPDATED' end,
        'PRODUCT_VARIANT',
        v_variant_id,
        jsonb_build_object(
            'product_id', p_product_id,
            'code', v_code,
            'fulfillment_mode', v_mode,
            'sale_price', p_sale_price,
            'active', coalesce(p_active, true),
            'is_default', v_effective_default,
            'user_component_count', v_user_component_count
        )
    );

    return jsonb_build_object(
        'success', true,
        'replay', false,
        'variant_id', v_variant_id,
        'created', v_created
    );
end;
$$;

revoke execute on function public.save_product_variant_master(
    uuid,uuid,text,text,text,uuid,numeric,boolean,boolean,jsonb,text
)
from public, anon, authenticated, service_role;

grant execute on function public.save_product_variant_master(
    uuid,uuid,text,text,text,uuid,numeric,boolean,boolean,jsonb,text
)
to authenticated;

comment on function public.product_master_capability() is
'C11-F0A product editor capability probe. True only for an authenticated actor with PRODUCT_MANAGE.';

comment on function public.save_sale_product_master(uuid,text,text,text,text,boolean,text) is
'C11-F0A audited/idempotent create-update authority for POS sale product metadata. Historical sale facts remain snapshot-based.';

comment on function public.save_product_variant_master(uuid,uuid,text,text,text,uuid,numeric,boolean,boolean,jsonb,text) is
'C11-F0A audited/idempotent create-update authority for variant pricing, mode, active/default state, and SALE-stage INGREDIENT/PACKAGING components. FINISHED_GOOD is derived server-side for stock modes.';
