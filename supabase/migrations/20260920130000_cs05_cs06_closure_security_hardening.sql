-- CS-05 / CS-06 closure security hardening.
-- Make the reporting view obey caller RLS and pin helper search paths.

alter view public.cs05_sales_by_shift set (security_invoker = true);

alter function private.cs05_open_shift(uuid, uuid, uuid, numeric, jsonb)
    set search_path = '';

alter function private.cs05_close_shift(uuid, uuid, numeric)
    set search_path = '';

alter function private.cs05_shift_immutable()
    set search_path = '';
