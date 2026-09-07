begin;
insert into public.businesses(id,code,display_name) values('00000000-0000-0000-0000-000000000620','CS02B','CS02 Business B');
insert into public.locations(id,business_id,code,display_name,location_type) values('00000000-0000-0000-0000-000000000621','00000000-0000-0000-0000-000000000620','BSTORE','B Store','STORE');
insert into public.profiles(id,auth_user_id,display_name) values
('00000000-0000-0000-0000-000000000601','00000000-0000-0000-0000-000000000611','CS02 Owner A'),
('00000000-0000-0000-0000-000000000602','00000000-0000-0000-0000-000000000612','CS02 Kasir A'),
('00000000-0000-0000-0000-000000000603','00000000-0000-0000-0000-000000000613','CS02 User B');
insert into public.business_memberships(business_id,profile_id,role_code)
select id,'00000000-0000-0000-0000-000000000601','OWNER' from public.businesses where code='SJ';
insert into public.business_memberships(business_id,profile_id,role_code)
select id,'00000000-0000-0000-0000-000000000602','KASIR' from public.businesses where code='SJ';
insert into public.business_memberships(business_id,profile_id,role_code) values('00000000-0000-0000-0000-000000000620','00000000-0000-0000-0000-000000000603','OWNER');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000611',true);
do $$ begin
  if (select count(*) from public.businesses) <> 1 or not exists(select 1 from public.businesses where code='SJ') then raise exception 'CS02_RLS_OWNER_BUSINESS_VISIBILITY_FAILED'; end if;
  if not exists(select 1 from public.profiles where auth_user_id='00000000-0000-0000-0000-000000000612') then raise exception 'CS02_RLS_OWNER_PROFILE_VISIBILITY_FAILED'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000612',true);
do $$ begin
  if not exists(select 1 from public.locations where code='GUDANG') or not exists(select 1 from public.locations where code='GERAI') then raise exception 'CS02_RLS_KASIR_REFERENCE_READ_FAILED'; end if;
  if exists(select 1 from public.locations where code='BSTORE') then raise exception 'CS02_RLS_CROSS_BUSINESS_LOCATION_VISIBLE'; end if;
  begin
    insert into public.inventory_movements(business_id,movement_type,source_type,source_ref,reason_code) select id,'TEST','TEST','RLS-TEST','TEST' from public.businesses where code='SJ';
    raise exception 'CS02_RLS_DIRECT_INVENTORY_WRITE_NOT_DENIED';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.money_movements(business_id,movement_type,to_account_id,amount,source_type,source_ref,reason_code)
    select b.id,'INCOME',a.id,1,'TEST','RLS-TEST','TEST' from public.businesses b join public.money_accounts a on a.business_id=b.id and a.code='KAS_UTAMA' where b.code='SJ';
    raise exception 'CS02_RLS_DIRECT_MONEY_WRITE_NOT_DENIED';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000699',true);
do $$ begin
  if exists(select 1 from public.businesses) then raise exception 'CS02_RLS_UNKNOWN_USER_CAN_READ_BUSINESS'; end if;
end $$;
reset role;
rollback;
