BEGIN;

DO $$
DECLARE

  v_business uuid;
  v_profile uuid := '00000000-0000-0000-0000-000000000901';
  v_auth uuid := '00000000-0000-0000-0000-000000000902';

  v_location uuid;
  v_item uuid;
  v_sale uuid;

  v_result jsonb;
  v_audit jsonb;

BEGIN

  SELECT id
  INTO v_business
  FROM public.businesses
  WHERE code='SJ';


  SELECT id
  INTO v_location
  FROM public.locations
  WHERE business_id=v_business
  AND code='GERAI';


  INSERT INTO public.profiles(
      id,
      auth_user_id,
      display_name
  )
  VALUES(
      v_profile,
      v_auth,
      'CS04 Sale Posting Test'
  );


  INSERT INTO public.business_memberships(
      business_id,
      profile_id,
      role_code
  )
  VALUES(
      v_business,
      v_profile,
      'OWNER'
  );


  INSERT INTO public.stock_items(
      id,
      business_id,
      code,
      display_name,
      item_kind,
      base_unit
  )
  VALUES(
      '00000000-0000-0000-0000-000000000903',
      v_business,
      'CS04_TEST_ITEM',
      'CS04 Test Item',
      'FINISHED_GOOD',
      'PCS'
  )
  RETURNING id INTO v_item;


  PERFORM private.record_inventory_movement(
      v_business,
      v_profile,
      'cs04-sale-opening',
      'OPENING',
      'TEST',
      'OPEN-1',
      'TEST',
      jsonb_build_array(
          jsonb_build_object(
              'line_no',1,
              'stock_item_id',v_item,
              'location_id',v_location,
              'quantity_delta',10
          )
      ),
      null
  );


  INSERT INTO public.sales(
      business_id,
      location_id,
      invoice_number,
      cashier_profile_id,
      status,
      subtotal,
      discount_amount,
      total_amount
  )
  VALUES(
      v_business,
      v_location,
      'INV-CS04-001',
      v_profile,
      'COMPLETED',
      10000,
      0,
      10000
  )
  RETURNING id INTO v_sale;


  INSERT INTO public.sale_items(
      sale_id,
      line_no,
      stock_item_id,
      quantity,
      unit_price,
      subtotal
  )
  VALUES(
      v_sale,
      1,
      v_item,
      1,
      10000,
      10000
  );


  INSERT INTO public.payments(
      sale_id,
      method,
      amount,
      status
  )
  VALUES(
      v_sale,
      'CASH',
      10000,
      'PAID'
  );


  v_result :=
      private.post_sale_transaction(
          v_business,
          v_profile,
          v_sale
      );


  IF NOT EXISTS(
      SELECT 1
      FROM public.inventory_movements
      WHERE source_ref='INV-CS04-001'
  )
  THEN
      RAISE EXCEPTION 'CS04_INVENTORY_TRACE_FAILED';
  END IF;


  IF NOT EXISTS(
      SELECT 1
      FROM public.money_movements
      WHERE source_ref='INV-CS04-001'
  )
  THEN
      RAISE EXCEPTION 'CS04_MONEY_TRACE_FAILED';
  END IF;


  SELECT metadata
  INTO v_audit
  FROM public.audit_events
  WHERE entity_id=v_sale
  AND event_type='SALE_POSTED';


  IF v_audit IS NULL THEN
      RAISE EXCEPTION 'CS04_AUDIT_TRACE_FAILED';
  END IF;

  IF v_audit->>'inventory_movement_id' IS NULL THEN
      RAISE EXCEPTION 'CS04_AUDIT_INVENTORY_METADATA_FAILED';
  END IF;

  IF v_audit->>'money_movement_id' IS NULL THEN
      RAISE EXCEPTION 'CS04_AUDIT_MONEY_METADATA_FAILED';
  END IF;

  IF v_audit->>'receipt_id' IS NULL THEN
      RAISE EXCEPTION 'CS04_AUDIT_RECEIPT_METADATA_FAILED';
  END IF;

  IF NOT EXISTS(
      SELECT 1
      FROM public.inventory_balances
      WHERE business_id=v_business
      AND stock_item_id=v_item
      AND location_id=v_location
      AND quantity=9
  ) THEN
      RAISE EXCEPTION 'CS04_INVENTORY_BALANCE_FAILED';
  END IF;

  v_result :=
      private.post_sale_transaction(
          v_business,
          v_profile,
          v_sale
      );

  IF COALESCE(v_result->>'already_posted','false') <> 'true' THEN
      RAISE EXCEPTION 'CS04_IDEMPOTENCY_REPLAY_FAILED';
  END IF;


END $$;

ROLLBACK;
