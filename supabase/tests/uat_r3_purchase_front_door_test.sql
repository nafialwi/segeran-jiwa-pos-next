begin;
do $$
begin
  if to_regprocedure('public.purchase_create_supplier(text,text,text,text)') is null then
    raise exception 'UAT_R3_SUPPLIER_RPC_MISSING';
  end if;
  if to_regprocedure('public.purchase_create_item(text,text,text,uuid,text)') is null then
    raise exception 'UAT_R3_ITEM_RPC_MISSING';
  end if;
  if to_regprocedure('public.purchase_create_order(uuid,uuid,jsonb,text,text)') is null then
    raise exception 'UAT_R3_ORDER_RPC_MISSING';
  end if;
  if to_regprocedure('public.purchase_create_goods_receipt(uuid,jsonb,text,text)') is null then
    raise exception 'UAT_R3_GRN_RPC_MISSING';
  end if;
  if to_regprocedure('public.purchase_direct_buy(uuid,uuid,jsonb,text,text)') is null then
    raise exception 'UAT_R3_DIRECT_BUY_RPC_MISSING';
  end if;
  if to_regprocedure('public.purchase_front_door_options()') is null then
    raise exception 'UAT_R3_OPTIONS_RPC_MISSING';
  end if;
end $$;
rollback;
