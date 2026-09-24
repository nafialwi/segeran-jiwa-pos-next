-- C11-F5.1a: Product Media Storage policy permission bridge
--
-- Supabase Storage evaluates storage.objects policies through the Storage API
-- execution role. Direct calls from those policies to the private permission
-- helper fail because that helper intentionally has no authenticated execute grant.
--
-- Keep the same authority semantics by reading PRODUCT_MANAGE from the
-- authenticated, SECURITY DEFINER public.get_my_authority() projection instead.

drop policy if exists product_media_manager_insert on storage.objects;
create policy product_media_manager_insert
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'product-media'
    and (storage.foldername(name))[1]
        = (public.get_my_authority() ->> 'business_id')
    and coalesce(
        (public.get_my_authority() -> 'permissions') ? 'PRODUCT_MANAGE',
        false
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
    and coalesce(
        (public.get_my_authority() -> 'permissions') ? 'PRODUCT_MANAGE',
        false
    )
)
with check (
    bucket_id = 'product-media'
    and (storage.foldername(name))[1]
        = (public.get_my_authority() ->> 'business_id')
    and coalesce(
        (public.get_my_authority() -> 'permissions') ? 'PRODUCT_MANAGE',
        false
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
    and coalesce(
        (public.get_my_authority() -> 'permissions') ? 'PRODUCT_MANAGE',
        false
    )
    and exists (
        select 1
        from public.sale_products p
        where p.business_id
            = (public.get_my_authority() ->> 'business_id')::uuid
          and p.id::text = (storage.foldername(name))[2]
    )
);

comment on policy product_media_manager_insert on storage.objects is
'C11-F5.1a: tenant/product bounded Product Media insert using public authority projection.';

comment on policy product_media_manager_update on storage.objects is
'C11-F5.1a: tenant/Product Manage bounded Product Media update using public authority projection.';

comment on policy product_media_manager_delete on storage.objects is
'C11-F5.1a: tenant/product bounded Product Media delete using public authority projection.';
