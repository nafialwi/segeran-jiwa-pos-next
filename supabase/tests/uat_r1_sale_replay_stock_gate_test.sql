begin;
do $$
declare d text;
begin
  d := pg_get_functiondef('private.record_sale(uuid,uuid,uuid,jsonb,jsonb,text)'::regprocedure);
  if position('lock_operation' in d) = 0 or position('SJ_STOCK_LOW' in d) = 0 then
    raise exception 'UAT_R1_RECORD_SALE_GATE_MISSING';
  end if;
end $$;
rollback;
