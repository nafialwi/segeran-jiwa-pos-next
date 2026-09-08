-- CS-03 forward source synchronization.
-- Mirrors the already approved/applied hosted correction. Schema version remains 2.

revoke execute on function private.current_session_id()
from public, anon, authenticated, service_role;

revoke execute on function private.normalize_username(text)
from public, anon, authenticated, service_role;
