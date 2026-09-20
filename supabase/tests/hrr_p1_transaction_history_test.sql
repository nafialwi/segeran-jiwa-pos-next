begin;
do $$
declare v_def text;
begin
    if not exists (select 1 from public.permission_definitions where code='HISTORY_OWN' and active) then
        raise exception 'HRR_P1_HISTORY_OWN_MISSING';
    end if;
    if not exists (select 1 from public.permission_definitions where code='HISTORY_ALL' and active) then
        raise exception 'HRR_P1_HISTORY_ALL_MISSING';
    end if;
    v_def := pg_get_functiondef(
      'public.transaction_history_search(date,date,text,text,text,text,numeric,numeric,text,integer)'::regprocedure
    );
    if position('HISTORY_READ_REQUIRED' in v_def)=0
       or position('HISTORY_ALL' in v_def)=0
       or position('HISTORY_OWN' in v_def)=0
       or position('cashier_profile_id = v_profile' in v_def)=0 then
       raise exception 'HRR_P1_SEARCH_AUTHORITY_INVALID';
    end if;
end $$;
rollback;
