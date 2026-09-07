begin;
do $$
declare
  v_business uuid;
  v_profile uuid := '00000000-0000-0000-0000-000000000301';
  v_auth uuid := '00000000-0000-0000-0000-000000000302';
  v_hash text;
  v_replay record;
  v_receipt uuid;
begin
  select id into v_business from public.businesses where code='SJ';
  insert into public.profiles(id,auth_user_id,display_name) values(v_profile,v_auth,'CS02 Test');
  insert into public.business_memberships(business_id,profile_id,role_code) values(v_business,v_profile,'OWNER');
  v_hash := private.payload_sha256('{"test":"idempotency"}'::jsonb);

  select * into v_replay from private.lock_operation(v_business,'cs02-test-key','CS02_TEST',v_hash);
  if v_replay.replay then raise exception 'CS02_IDEMPOTENCY_FIRST_CALL_REPLAYED'; end if;

  v_receipt := private.record_operation_success(v_business,'cs02-test-key','CS02_TEST',v_hash,'CS02_TEST_RESULT','00000000-0000-0000-0000-000000000303',v_profile);
  if v_receipt is null then raise exception 'CS02_RECEIPT_NOT_CREATED'; end if;

  select * into v_replay from private.lock_operation(v_business,'cs02-test-key','CS02_TEST',v_hash);
  if not v_replay.replay or v_replay.receipt_id <> v_receipt then raise exception 'CS02_IDEMPOTENCY_REPLAY_FAILED'; end if;

  begin
    perform * from private.lock_operation(v_business,'cs02-test-key','CS02_TEST',repeat('a',64));
    raise exception 'CS02_IDEMPOTENCY_CONFLICT_NOT_RAISED';
  exception when unique_violation then
    if position('SJ_IDEMPOTENCY_CONFLICT' in sqlerrm)=0 then raise; end if;
  end;
end $$;
rollback;
