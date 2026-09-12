BEGIN;

DO $$
declare
  v_business uuid;
  v_location uuid;
  v_actor_a uuid := '00000000-0000-0000-0000-000000000911';
  v_actor_b uuid := '00000000-0000-0000-0000-000000000912';
  v_auth_a uuid := '00000000-0000-0000-0000-000000000913';
  v_auth_b uuid := '00000000-0000-0000-0000-000000000914';
  v_shift_a uuid;
  v_shift_b uuid;
  v_variance numeric;
  v_sum numeric;
  v_caught boolean;
begin
  select id into v_business from public.businesses where code='SJ';
  select id into v_location from public.locations where business_id=v_business and code='GERAI';

  insert into public.profiles(id, auth_user_id, display_name) values
    (v_actor_a, v_auth_a, 'CS05 P2 Actor A'),
    (v_actor_b, v_auth_b, 'CS05 P2 Actor B');

  v_shift_a := private.cs05_open_shift(v_business, v_location, v_actor_a, 100000.00, '{"locale":"id"}'::jsonb);
  assert v_shift_a is not null, 'AC-01 shift should open';

  v_caught := false;
  begin
    perform private.cs05_open_shift(v_business, v_location, v_actor_a, 0.00);
  exception when others then
    v_caught := true;
  end;
  assert v_caught, 'AC-01 double open should be rejected';

  insert into public.cash_transactions(business_id, location_id, shift_id, cashier_profile_id, transaction_type, amount)
  values (v_business, v_location, v_shift_a, v_actor_a, 'SALE', 25000.00);

  select gross_cash_sales into v_sum from public.cs05_sales_by_shift where shift_id = v_shift_a;
  assert v_sum = 25000.00, 'AC-02 sales_by_shift should aggregate SALE';

  v_variance := private.cs05_close_shift(v_shift_a, v_actor_a, 25000.00);
  assert v_variance = 0, 'R-04 zero variance expected';

  select expected_cash into v_sum from public.shifts where id = v_shift_a;
  assert v_sum = 25000.00, 'AC-03 expected cash from SALE sum';

  v_caught := false;
  begin
    perform private.cs05_close_shift(v_shift_a, v_actor_a, 25000.00);
  exception when others then
    v_caught := true;
  end;
  assert v_caught, 'AC-05 re-close should be rejected';

  v_caught := false;
  begin
    update public.shifts set closing_balance = 1 where id = v_shift_a;
  exception when others then
    v_caught := true;
  end;
  assert v_caught, 'AC-05 closed shift should be immutable';

  v_shift_b := private.cs05_open_shift(v_business, v_location, v_actor_b, 25000.00);

  v_caught := false;
  begin
    update public.shifts set cashier_profile_id = v_actor_a where id = v_shift_b;
  exception when others then
    v_caught := true;
  end;
  assert v_caught, 'R-02 actor should be immutable';

  insert into public.handovers(business_id, location_id, from_shift_id, to_shift_id, from_cashier_profile_id, to_cashier_profile_id, expected_balance, actual_balance, status)
  values (v_business, v_location, v_shift_a, v_shift_b, v_actor_a, v_actor_b, 25000.00, 25000.00, 'ACCEPTED');

  select count(*) into v_sum from public.handovers where from_shift_id = v_shift_a and to_shift_id = v_shift_b and discrepancy = 0;
  assert v_sum = 1, 'R-05 handover should link both shifts';

  raise notice 'All CS-05-P2 shift logic tests passed';
end $$;

ROLLBACK;
