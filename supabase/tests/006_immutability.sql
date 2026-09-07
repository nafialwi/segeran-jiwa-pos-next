begin;
do $$
declare
  v_business uuid;
  v_profile uuid := '00000000-0000-0000-0000-000000000701';
  v_auth uuid := '00000000-0000-0000-0000-000000000702';
  v_item uuid := '00000000-0000-0000-0000-000000000703';
  v_gudang uuid;
  v_cash uuid;
  v_inv uuid;
  v_money uuid;
  v_receipt uuid;
  v_audit uuid;
begin
  select id into v_business from public.businesses where code='SJ';
  select id into v_gudang from public.locations where business_id=v_business and code='GUDANG';
  select id into v_cash from public.money_accounts where business_id=v_business and code='KAS_UTAMA';
  insert into public.profiles(id,auth_user_id,display_name) values(v_profile,v_auth,'CS02 Immutable Test');
  insert into public.business_memberships(business_id,profile_id,role_code) values(v_business,v_profile,'OWNER');
  insert into public.stock_items(id,business_id,code,display_name,item_kind,base_unit) values(v_item,v_business,'CS02_IMM_ITEM','Immutable Test Item','MATERIAL','PCS');

  v_inv := private.record_inventory_movement(v_business,v_profile,'cs02-imm-inv','OPENING','TEST','IMM-I','TEST',jsonb_build_array(jsonb_build_object('line_no',1,'stock_item_id',v_item,'location_id',v_gudang,'quantity_delta',1)),null);
  v_money := private.record_money_movement(v_business,v_profile,'cs02-imm-money','OPENING_BALANCE',null,v_cash,1,'TEST','IMM-M','TEST',null);
  select id into v_receipt from public.operation_receipts where business_id=v_business order by created_at limit 1;
  select id into v_audit from public.audit_events where business_id=v_business order by created_at limit 1;

  begin update public.operation_receipts set command_type=command_type where id=v_receipt; raise exception 'CS02_IMM_RECEIPT_UPDATE_ALLOWED'; exception when sqlstate '55000' then if position('SJ_IMMUTABLE_FACT' in sqlerrm)=0 then raise; end if; end;
  begin delete from public.operation_receipts where id=v_receipt; raise exception 'CS02_IMM_RECEIPT_DELETE_ALLOWED'; exception when sqlstate '55000' then if position('SJ_IMMUTABLE_FACT' in sqlerrm)=0 then raise; end if; end;
  begin update public.audit_events set event_type=event_type where id=v_audit; raise exception 'CS02_IMM_AUDIT_UPDATE_ALLOWED'; exception when sqlstate '55000' then if position('SJ_IMMUTABLE_FACT' in sqlerrm)=0 then raise; end if; end;
  begin delete from public.audit_events where id=v_audit; raise exception 'CS02_IMM_AUDIT_DELETE_ALLOWED'; exception when sqlstate '55000' then if position('SJ_IMMUTABLE_FACT' in sqlerrm)=0 then raise; end if; end;
  begin update public.inventory_movements set reason_code=reason_code where id=v_inv; raise exception 'CS02_IMM_INV_UPDATE_ALLOWED'; exception when sqlstate '55000' then if position('SJ_IMMUTABLE_FACT' in sqlerrm)=0 then raise; end if; end;
  begin delete from public.inventory_movement_lines where movement_id=v_inv; raise exception 'CS02_IMM_INV_LINE_DELETE_ALLOWED'; exception when sqlstate '55000' then if position('SJ_IMMUTABLE_FACT' in sqlerrm)=0 then raise; end if; end;
  begin delete from public.inventory_movements where id=v_inv; raise exception 'CS02_IMM_INV_DELETE_ALLOWED'; exception when sqlstate '55000' then if position('SJ_IMMUTABLE_FACT' in sqlerrm)=0 then raise; end if; end;
  begin update public.money_movements set reason_code=reason_code where id=v_money; raise exception 'CS02_IMM_MONEY_UPDATE_ALLOWED'; exception when sqlstate '55000' then if position('SJ_IMMUTABLE_FACT' in sqlerrm)=0 then raise; end if; end;
  begin delete from public.money_movements where id=v_money; raise exception 'CS02_IMM_MONEY_DELETE_ALLOWED'; exception when sqlstate '55000' then if position('SJ_IMMUTABLE_FACT' in sqlerrm)=0 then raise; end if; end;
end $$;
rollback;
