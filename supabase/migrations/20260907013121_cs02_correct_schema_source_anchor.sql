do $$
declare
  v_expected constant text := 'c7bce7498b27eab6d5f8c1981597f068ca4f6f53';
  v_legacy constant text := 'c7bce7498b27ea6bd5f8c1981597f068ca4f6f53';
  v_current text;
begin
  select source_anchor into v_current
  from private.schema_versions
  where version = 1 and milestone = 'CS-02';

  if v_current is null then
    raise exception 'CS02_SCHEMA_VERSION_AUTHORITY_MISSING';
  elsif v_current = v_expected then
    return;
  elsif v_current = v_legacy then
    update private.schema_versions
    set source_anchor = v_expected
    where version = 1 and milestone = 'CS-02';
  else
    raise exception 'CS02_SCHEMA_SOURCE_ANCHOR_UNEXPECTED: %', v_current;
  end if;
end $$;