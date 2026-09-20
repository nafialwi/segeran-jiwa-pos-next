begin;
do $$
declare v_def text;
begin
  v_def := pg_get_functiondef('public.report_run(text,date,date)'::regprocedure);
  if position('REPORT_SALES_LIMITED' in v_def)=0
     or position('REPORT_INVENTORY' in v_def)=0
     or position('REPORT_PURCHASE' in v_def)=0
     or position('REPORT_OWNER_REQUIRED' in v_def)=0
     or position('has_inventory_location_scope' in v_def)=0
     or position('Coverage HPP' in v_def)=0 then
    raise exception 'HRR_P3_REPORT_CONTRACT_INVALID';
  end if;
  if position('insert into' in lower(v_def))>0
     or position('update ' in lower(v_def))>0
     or position('delete from' in lower(v_def))>0 then
    raise exception 'HRR_P3_REPORT_MUST_BE_READ_ONLY';
  end if;
end $$;
rollback;
