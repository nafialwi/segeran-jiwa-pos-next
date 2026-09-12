BEGIN;

DO $$
DECLARE
  v_business uuid;
  v_location uuid;
  v_cashier uuid := '00000000-0000-0000-0000-000000000901';
  v_auth uuid := '00000000-0000-0000-0000-000000000902';

  v_shift uuid;
  v_shift2 uuid;
  v_transaction uuid;
  v_handover uuid;

  v_count integer;
BEGIN

  SELECT id INTO v_business FROM public.businesses WHERE code='SJ';
  SELECT id INTO v_location FROM public.locations WHERE business_id=v_business AND code='GERAI';

  INSERT INTO public.profiles(id, auth_user_id, display_name)
  VALUES(v_cashier, v_auth, 'CS05 Shift Test Cashier');

  INSERT INTO public.shifts(business_id, location_id, cashier_profile_id, opening_balance)
  VALUES(v_business, v_location, v_cashier, 100000.00)
  RETURNING id INTO v_shift;

  SELECT COUNT(*) INTO v_count FROM public.shifts WHERE id = v_shift;
  ASSERT v_count = 1, 'Shift should be created';

  INSERT INTO public.cash_transactions(business_id, location_id, shift_id, cashier_profile_id, transaction_type, amount, reference_type, notes)
  VALUES(v_business, v_location, v_shift, v_cashier, 'CASH_IN', 50000.00, 'manual_adjustment', 'Test cash in')
  RETURNING id INTO v_transaction;

  SELECT COUNT(*) INTO v_count FROM public.cash_transactions WHERE id = v_transaction;
  ASSERT v_count = 1, 'Cash transaction should be created';

  UPDATE public.shifts
  SET closed_at = now(), closing_balance = 150000.00, status = 'CLOSED'
  WHERE id = v_shift;

  SELECT COUNT(*) INTO v_count FROM public.shifts WHERE id = v_shift AND status = 'CLOSED';
  ASSERT v_count = 1, 'Shift should be closed';

  INSERT INTO public.handovers(business_id, location_id, from_shift_id, from_cashier_profile_id, expected_balance, actual_balance)
  VALUES(v_business, v_location, v_shift, v_cashier, 150000.00, 150000.00)
  RETURNING id INTO v_handover;

  SELECT COUNT(*) INTO v_count FROM public.handovers WHERE id = v_handover AND discrepancy = 0;
  ASSERT v_count = 1, 'Handover should have zero discrepancy';

  INSERT INTO public.shifts(business_id, location_id, cashier_profile_id, opening_balance)
  VALUES(v_business, v_location, v_cashier, 150000.00)
  RETURNING id INTO v_shift2;

  UPDATE public.handovers
  SET to_shift_id = v_shift2, to_cashier_profile_id = v_cashier, status = 'ACCEPTED'
  WHERE id = v_handover;

  SELECT COUNT(*) INTO v_count FROM public.handovers WHERE id = v_handover AND status = 'ACCEPTED';
  ASSERT v_count = 1, 'Handover should be accepted';

  RAISE NOTICE 'All CS-05 shift tests passed';

END $$;

ROLLBACK;
