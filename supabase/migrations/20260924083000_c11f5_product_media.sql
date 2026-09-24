-- C11-F5: Product Media & Catalog Completion
--
-- Adds one presentation image per sale product without changing stock, sale,
-- inventory, finance, shift, BOM, or historical sale authorities.
-- Product media is optional and fail-closed on older backends.

alter table public.sale_products
    add column if not exists image_path text;

alter table public.sale_products
    drop constraint if exists sale_products_image_path_shape;

alter table public.sale_products
    add constraint sale_products_image_path_shape
    check (
        image_path is null
        or (
            split_part(image_path, '/', 1) = business_id::text
            and split_part(image_path, '/', 2) = id::text
            and split_part(image_path, '/', 4) = ''
            and lower(split_part(image_path, '/', 3))
                ~ '^[0-9a-f-]{36}\.(webp|jpg|jpeg|png)$'
        )
    );

insert into storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
) values (
    'product-media',
    'product-media',
    true,
    2097152,
    array['image/webp','image/jpeg','image/png']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists product_media_tenant_read on storage.objects;
create policy product_media_tenant_read
on storage.objects
for select
to authenticated
using (
    bucket_id = 'product-media'
    and (storage.foldername(name))[1]
        = (public.get_my_authority() ->> 'business_id')
    and exists (
        select 1
        from public.sale_products p
        where p.business_id
            = (public.get_my_authority() ->> 'business_id')::uuid
          and p.id::text = (storage.foldername(name))[2]
    )
);

drop policy if exists product_media_manager_insert on storage.objects;
create policy product_media_manager_insert
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'product-media'
    and (storage.foldername(name))[1]
        = (public.get_my_authority() ->> 'business_id')
    and private.has_permission(
        (public.get_my_authority() ->> 'business_id')::uuid,
        'PRODUCT_MANAGE'
    )
    and exists (
        select 1
        from public.sale_products p
        where p.business_id
            = (public.get_my_authority() ->> 'business_id')::uuid
          and p.id::text = (storage.foldername(name))[2]
    )
);
drop policy if exists product_media_manager_update on storage.objects;
create policy product_media_manager_update
on storage.objects
for update
to authenticated
using (
    bucket_id = 'product-media'
    and (storage.foldername(name))[1]
        = (public.get_my_authority() ->> 'business_id')
    and private.has_permission(
        (public.get_my_authority() ->> 'business_id')::uuid,
        'PRODUCT_MANAGE'
    )
)
with check (
    bucket_id = 'product-media'
    and (storage.foldername(name))[1]
        = (public.get_my_authority() ->> 'business_id')
    and private.has_permission(
        (public.get_my_authority() ->> 'business_id')::uuid,
        'PRODUCT_MANAGE'
    )
    and exists (
        select 1
        from public.sale_products p
        where p.business_id
            = (public.get_my_authority() ->> 'business_id')::uuid
          and p.id::text = (storage.foldername(name))[2]
    )
);

drop policy if exists product_media_manager_delete on storage.objects;
create policy product_media_manager_delete
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'product-media'
    and (storage.foldername(name))[1]
        = (public.get_my_authority() ->> 'business_id')
    and private.has_permission(
        (public.get_my_authority() ->> 'business_id')::uuid,
        'PRODUCT_MANAGE'
    )
    and exists (
        select 1
        from public.sale_products p
        where p.business_id
            = (public.get_my_authority() ->> 'business_id')::uuid
          and p.id::text = (storage.foldername(name))[2]
    )
);

create or replace function public.product_media_capability()
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

    return private.has_permission(v_business, 'PRODUCT_MANAGE')
        and exists (
            select 1
            from storage.buckets b
            where b.id = 'product-media'
        );
end;
$$;

revoke execute on function public.product_media_capability()
from public, anon, authenticated, service_role;
grant execute on function public.product_media_capability() to authenticated;
create or replace function public.product_media_read_v1()
returns table (
    sale_product_id uuid,
    image_path text
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
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null then
        raise exception using errcode='42501', message='SJ_AUTHORITY_REQUIRED';
    end if;

    return query
    select p.id, p.image_path
    from public.sale_products p
    where p.business_id = v_business;
end;
$$;

revoke execute on function public.product_media_read_v1()
from public, anon, authenticated, service_role;
grant execute on function public.product_media_read_v1() to authenticated;

create or replace function public.set_sale_product_image(
    p_product_id uuid,
    p_image_path text,
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
    v_clean_path text;
    v_previous_path text;
    v_payload jsonb;
    v_payload_hash text;
    v_lock record;
    v_receipt uuid;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id', '')::uuid;
    v_actor := nullif(v_authority ->> 'profile_id', '')::uuid;

    if v_business is null or v_actor is null
       or not private.has_permission(v_business, 'PRODUCT_MANAGE') then
        raise exception using errcode='42501', message='SJ_PRODUCT_MANAGE_DENIED';
    end if;

    if p_product_id is null then
        raise exception using errcode='22023', message='SJ_PRODUCT_MEDIA_PRODUCT_REQUIRED';
    end if;

    select p.image_path
    into v_previous_path
    from public.sale_products p
    where p.id = p_product_id
      and p.business_id = v_business
    for update;

    if not found then
        raise exception using errcode='P0002', message='SJ_PRODUCT_NOT_FOUND';
    end if;

    v_clean_path := nullif(btrim(coalesce(p_image_path, '')), '');

    if v_clean_path is not null and not (
        split_part(v_clean_path, '/', 1) = v_business::text
        and split_part(v_clean_path, '/', 2) = p_product_id::text
        and split_part(v_clean_path, '/', 4) = ''
        and lower(split_part(v_clean_path, '/', 3))
            ~ '^[0-9a-f-]{36}\.(webp|jpg|jpeg|png)$'
    ) then
        raise exception using errcode='22023', message='SJ_PRODUCT_MEDIA_PATH_INVALID';
    end if;
    v_payload := jsonb_build_object(
        'product_id', p_product_id,
        'image_path', v_clean_path
    );
    v_payload_hash := private.payload_sha256(v_payload);

    select *
    into v_lock
    from private.lock_operation(
        v_business,
        p_idempotency_key,
        'PRODUCT_MEDIA_SET',
        v_payload_hash
    );

    if v_lock.replay then
        return jsonb_build_object(
            'success', true,
            'replay', true,
            'product_id', p_product_id,
            'image_path', v_clean_path,
            'previous_image_path', v_previous_path
        );
    end if;

    update public.sale_products
    set image_path = v_clean_path,
        updated_at = now()
    where id = p_product_id
      and business_id = v_business;

    v_receipt := private.record_operation_success(
        v_business,
        p_idempotency_key,
        'PRODUCT_MEDIA_SET',
        v_payload_hash,
        'SALE_PRODUCT',
        p_product_id,
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
        case
            when v_clean_path is null then 'SALE_PRODUCT_IMAGE_REMOVED'
            when v_previous_path is null then 'SALE_PRODUCT_IMAGE_ADDED'
            else 'SALE_PRODUCT_IMAGE_REPLACED'
        end,
        'SALE_PRODUCT',
        p_product_id,
        jsonb_build_object(
            'previous_image_path', v_previous_path,
            'image_path', v_clean_path
        )
    );

    return jsonb_build_object(
        'success', true,
        'replay', false,
        'product_id', p_product_id,
        'image_path', v_clean_path,
        'previous_image_path', v_previous_path
    );
end;
$$;

revoke execute on function public.set_sale_product_image(uuid,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.set_sale_product_image(uuid,text,text)
to authenticated;

comment on column public.sale_products.image_path is
'Optional product presentation image path in the product-media bucket. Not historical sale truth.';

comment on function public.product_media_capability() is
'C11-F5 capability probe for PRODUCT_MANAGE actors when product-media storage is installed.';

comment on function public.product_media_read_v1() is
'C11-F5 tenant-scoped read projection of product image paths.';

comment on function public.set_sale_product_image(uuid,text,text) is
'C11-F5 audited/idempotent pointer writer for product presentation media. Storage object write remains RLS bounded.';
