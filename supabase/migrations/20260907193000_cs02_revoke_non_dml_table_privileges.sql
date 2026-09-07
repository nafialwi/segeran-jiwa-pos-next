-- CS-02 hosted ACL hardening.
-- Browser client roles keep only the explicitly intended data privileges.
-- PostgreSQL 17 also exposes MAINTAIN as a table privilege; it is not a client API need.

revoke truncate, references, trigger, maintain
on all tables in schema public
from anon, authenticated;

alter default privileges for role postgres in schema public
revoke truncate, references, trigger, maintain
on tables
from anon, authenticated;

-- Trigger helper: not a client-callable API.
revoke execute on function private.prevent_fact_mutation()
from public, anon, authenticated;
