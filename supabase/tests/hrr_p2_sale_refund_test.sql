begin;

do $$
declare v_def text;
begin
  if to_regclass('public.sale_refunds') is null then
    raise exception 'HRR_P2_REFUND_TABLE_MISSING';
  end if;

  v_def := pg_get_functiondef(
    'public.refund_sale(uuid,text,text,text,text)'::regprocedure
  );

  if position('CORRECTION_LIMITED' in v_def)=0
     or position('RETURN_TO_STOCK' in v_def)=0
     or position('DAMAGED_UNFIT' in v_def)=0
     or position('NO_GOODS_RETURNED' in v_def)=0
     or position('SALE_ALREADY_REFUNDED' in v_def)=0
     or position('record_inventory_movement' in v_def)=0
     or position('record_money_movement' in v_def)=0 then
    raise exception 'HRR_P2_COMMAND_CONTRACT_INVALID';
  end if;

  if position('update public.sales' in lower(v_def))>0
     or position('update public.payments' in lower(v_def))>0
     or position('update public.customer_debts' in lower(v_def))>0 then
    raise exception 'HRR_P2_MUTATES_ORIGINAL_FACT';
  end if;
end $$;

rollback;
