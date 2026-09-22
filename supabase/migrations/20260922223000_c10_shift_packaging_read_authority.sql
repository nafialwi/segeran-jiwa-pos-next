-- C10 UAT blocker: shift packaging read authority.
-- Replaces frontend direct reads of protected sales facts with one authenticated RPC.

create or replace function public.shift_packaging_usage(p_shift uuid)
returns table (
    stock_item_id uuid,
    stock_item_code_snapshot text,
    stock_item_name_snapshot text,
    theoretical_usage numeric
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_profile uuid;
    v_owner boolean;
begin
    v_authority := public.get_my_authority();
    v_business := nullif(v_authority ->> 'business_id','')::uuid;
    v_profile := nullif(v_authority ->> 'profile_id','')::uuid;
    v_owner := coalesce((v_authority ->> 'owner')::boolean,false);

    if v_business is null or v_profile is null then
        raise exception using errcode='42501', message='SHIFT_PACKAGING_AUTHORITY_REQUIRED';
    end if;
    if not exists (
        select 1
        from public.shifts s
        where s.id = p_shift
          and s.business_id = v_business
          and (v_owner or s.cashier_profile_id = v_profile)
    ) then
        raise exception using errcode='42501', message='SHIFT_PACKAGING_READ_DENIED';
    end if;

    return query
    select
        snap.stock_item_id,
        max(snap.stock_item_code_snapshot)::text,
        max(snap.stock_item_name_snapshot)::text,
        sum(snap.quantity_total)::numeric
    from public.sales sale
    join public.sale_item_component_snapshots snap
      on snap.sale_id = sale.id
    where sale.business_id = v_business
      and sale.shift_id = p_shift
      and snap.component_role = 'PACKAGING'
    group by snap.stock_item_id
    order by max(snap.stock_item_name_snapshot);
end;
$$;
revoke execute on function public.shift_packaging_usage(uuid)
from public, anon, authenticated, service_role;

grant execute on function public.shift_packaging_usage(uuid)
to authenticated;

comment on function public.shift_packaging_usage(uuid) is
'Authenticated shift-scoped packaging usage projection. Reads immutable sale component snapshots without granting direct sales table access.';
