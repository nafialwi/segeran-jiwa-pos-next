begin;
do $$
declare
  v_business uuid;
  v_profile uuid := '00000000-0000-0000-0000-000000000501';
  v_auth uuid := '00000000-0000-0000-0000-000000000502';
  v_cash uuid;
  v_bank uuid;
  v_transfer uuid;
  v_replay uuid;
  v_expense uuid;
  v_reversal uuid;
  b_cash numeric;
  b_bank numeric;
begin
  select id into v_business from public.businesses where code='SJ';
  select id into v_cash from public.money_accounts where business_id=v_business and code='KAS_UTAMA';
  select id into v_bank from public.money_accounts where business_id=v_business and code='BANK';
  insert into public.profiles(id,auth_user_id,display_name) values(v_profile,v_auth,'CS02 Money Test');
  insert into public.business_memberships(business_id,profile_id,role_code) values(v_business,v_profile,'OWNER');

  perform private.record_money_movement(v_business,v_profile,'cs02-money-open','OPENING_BALANCE',null,v_cash,100000,'TEST','OPEN-1','TEST',null);
  select balance into b_cash from public.money_balances where business_id=v_business and account_id=v_cash;
  if b_cash <> 100000 then raise exception 'CS02_MONEY_OPENING_BALANCE_FAILED'; end if;

  v_transfer := private.record_money_movement(v_business,v_profile,'cs02-money-transfer','TRANSFER',v_cash,v_bank,25000,'TEST','TR-1','TEST',null);
  select balance into b_cash from public.money_balances where business_id=v_business and account_id=v_cash;
  select balance into b_bank from public.money_balances where business_id=v_business and account_id=v_bank;
  if b_cash <> 75000 or b_bank <> 25000 then raise exception 'CS02_MONEY_TRANSFER_BALANCE_FAILED'; end if;

  v_replay := private.record_money_movement(v_business,v_profile,'cs02-money-transfer','TRANSFER',v_cash,v_bank,25000,'TEST','TR-1','TEST',null);
  if v_replay <> v_transfer then raise exception 'CS02_MONEY_REPLAY_ID_FAILED'; end if;
  select balance into b_cash from public.money_balances where business_id=v_business and account_id=v_cash;
  select balance into b_bank from public.money_balances where business_id=v_business and account_id=v_bank;
  if b_cash <> 75000 or b_bank <> 25000 then raise exception 'CS02_MONEY_REPLAY_CHANGED_BALANCE'; end if;

  begin
    perform private.record_money_movement(v_business,v_profile,'cs02-money-transfer','TRANSFER',v_cash,v_bank,26000,'TEST','TR-1','TEST',null);
    raise exception 'CS02_MONEY_CONFLICT_NOT_RAISED';
  exception when unique_violation then if position('SJ_IDEMPOTENCY_CONFLICT' in sqlerrm)=0 then raise; end if; end;

  v_expense := private.record_money_movement(v_business,v_profile,'cs02-money-expense','EXPENSE',v_cash,null,10000,'TEST','EXP-1','TEST',null);
  select balance into b_cash from public.money_balances where business_id=v_business and account_id=v_cash;
  if b_cash <> 65000 then raise exception 'CS02_MONEY_EXPENSE_BALANCE_FAILED'; end if;

  v_reversal := private.record_money_movement(v_business,v_profile,'cs02-money-reversal','REVERSAL',null,v_cash,10000,'TEST','REV-1','REVERSAL',v_expense);
  if v_reversal is null or v_reversal = v_expense then raise exception 'CS02_MONEY_REVERSAL_ID_FAILED'; end if;
  if not exists(select 1 from public.money_movements where id=v_expense) then raise exception 'CS02_MONEY_ORIGINAL_MISSING_AFTER_REVERSAL'; end if;
end $$;
rollback;
