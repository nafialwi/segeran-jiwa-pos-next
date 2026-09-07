begin;
do $$
declare
  v_business uuid;
  v_business_b uuid := '00000000-0000-0000-0000-000000000410';
  v_profile uuid := '00000000-0000-0000-0000-000000000401';
  v_auth uuid := '00000000-0000-0000-0000-000000000402';
  v_item uuid := '00000000-0000-0000-0000-000000000403';
  v_gudang uuid;
  v_gerai uuid;
  v_foreign_location uuid := '00000000-0000-0000-0000-000000000411';
  v_transfer uuid;
  v_replay uuid;
  v_reversal uuid;
  q_gudang numeric;
  q_gerai numeric;
begin
  select id into v_business from public.businesses where code='SJ';
  select id into v_gudang from public.locations where business_id=v_business and code='GUDANG';
  select id into v_gerai from public.locations where business_id=v_business and code='GERAI';
  insert into public.profiles(id,auth_user_id,display_name) values(v_profile,v_auth,'CS02 Inventory Test');
  insert into public.business_memberships(business_id,profile_id,role_code) values(v_business,v_profile,'OWNER');
  insert into public.stock_items(id,business_id,code,display_name,item_kind,base_unit) values(v_item,v_business,'CS02_TEST_ITEM','CS02 Test Item','MATERIAL','PCS');
  insert into public.businesses(id,code,display_name) values(v_business_b,'CS02B','CS02 Foreign Business');
  insert into public.locations(id,business_id,code,display_name,location_type) values(v_foreign_location,v_business_b,'FOREIGN','Foreign Store','STORE');

  perform private.record_inventory_movement(v_business,v_profile,'cs02-inv-open','OPENING','TEST','OPEN-1','TEST',jsonb_build_array(jsonb_build_object('line_no',1,'stock_item_id',v_item,'location_id',v_gudang,'quantity_delta',10)),null);
  select quantity into q_gudang from public.inventory_balances where business_id=v_business and stock_item_id=v_item and location_id=v_gudang;
  if q_gudang <> 10 then raise exception 'CS02_INVENTORY_OPENING_BALANCE_FAILED'; end if;

  v_transfer := private.record_inventory_movement(v_business,v_profile,'cs02-inv-transfer','TRANSFER','TEST','MOVE-1','TEST',jsonb_build_array(jsonb_build_object('line_no',1,'stock_item_id',v_item,'location_id',v_gudang,'quantity_delta',-3),jsonb_build_object('line_no',2,'stock_item_id',v_item,'location_id',v_gerai,'quantity_delta',3)),null);
  select quantity into q_gudang from public.inventory_balances where business_id=v_business and stock_item_id=v_item and location_id=v_gudang;
  select quantity into q_gerai from public.inventory_balances where business_id=v_business and stock_item_id=v_item and location_id=v_gerai;
  if q_gudang <> 7 or q_gerai <> 3 then raise exception 'CS02_INVENTORY_TRANSFER_BALANCE_FAILED'; end if;

  v_replay := private.record_inventory_movement(v_business,v_profile,'cs02-inv-transfer','TRANSFER','TEST','MOVE-1','TEST',jsonb_build_array(jsonb_build_object('line_no',1,'stock_item_id',v_item,'location_id',v_gudang,'quantity_delta',-3),jsonb_build_object('line_no',2,'stock_item_id',v_item,'location_id',v_gerai,'quantity_delta',3)),null);
  if v_replay <> v_transfer then raise exception 'CS02_INVENTORY_REPLAY_ID_FAILED'; end if;
  select quantity into q_gudang from public.inventory_balances where business_id=v_business and stock_item_id=v_item and location_id=v_gudang;
  select quantity into q_gerai from public.inventory_balances where business_id=v_business and stock_item_id=v_item and location_id=v_gerai;
  if q_gudang <> 7 or q_gerai <> 3 then raise exception 'CS02_INVENTORY_REPLAY_CHANGED_BALANCE'; end if;

  begin
    perform private.record_inventory_movement(v_business,v_profile,'cs02-inv-transfer','TRANSFER','TEST','MOVE-CHANGED','TEST',jsonb_build_array(jsonb_build_object('line_no',1,'stock_item_id',v_item,'location_id',v_gudang,'quantity_delta',-1)),null);
    raise exception 'CS02_INVENTORY_CONFLICT_NOT_RAISED';
  exception when unique_violation then if position('SJ_IDEMPOTENCY_CONFLICT' in sqlerrm)=0 then raise; end if; end;

  begin
    perform private.record_inventory_movement(v_business,v_profile,'cs02-inv-foreign','TEST','TEST','FOREIGN-1','TEST',jsonb_build_array(jsonb_build_object('line_no',1,'stock_item_id',v_item,'location_id',v_foreign_location,'quantity_delta',1)),null);
    raise exception 'CS02_INVENTORY_FOREIGN_LOCATION_NOT_REJECTED';
  exception when invalid_parameter_value then if position('SJ_INVENTORY_LINE_INVALID' in sqlerrm)=0 then raise; end if; end;

  v_reversal := private.record_inventory_movement(v_business,v_profile,'cs02-inv-reversal','REVERSAL','TEST','REV-1','REVERSAL',jsonb_build_array(jsonb_build_object('line_no',1,'stock_item_id',v_item,'location_id',v_gudang,'quantity_delta',3),jsonb_build_object('line_no',2,'stock_item_id',v_item,'location_id',v_gerai,'quantity_delta',-3)),v_transfer);
  if v_reversal is null or v_reversal = v_transfer then raise exception 'CS02_INVENTORY_REVERSAL_ID_FAILED'; end if;
  if not exists(select 1 from public.inventory_movements where id=v_transfer) then raise exception 'CS02_INVENTORY_ORIGINAL_MISSING_AFTER_REVERSAL'; end if;
end $$;
rollback;
