from __future__ import annotations

import hashlib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"
REGISTRY = ROOT / "supabase" / "MIGRATION_REGISTRY.sha256"
HELPER_FIX = "20260908102825_cs03_revoke_private_helper_execute.sql"
BOOTSTRAP_FIX = "20260908190000_cs03_bootstrap_uuid_correction.sql"

class Cs03BootstrapUuidFixTests(unittest.TestCase):
    def test_forward_corrections_exist(self) -> None:
        self.assertTrue((MIGRATIONS / HELPER_FIX).is_file(), HELPER_FIX)
        self.assertTrue((MIGRATIONS / BOOTSTRAP_FIX).is_file(), BOOTSTRAP_FIX)

    def test_private_helper_source_sync_is_forward_only(self) -> None:
        text = (MIGRATIONS / HELPER_FIX).read_text("utf-8").lower()
        self.assertIn("revoke execute on function private.current_session_id()", text)
        self.assertIn("revoke execute on function private.normalize_username(text)", text)
        self.assertIn("from public, anon, authenticated, service_role", text)
        self.assertNotIn("insert into private.schema_versions", text)

    def test_bootstrap_no_longer_aggregates_uuid_with_min(self) -> None:
        text = (MIGRATIONS / BOOTSTRAP_FIX).read_text("utf-8").lower()
        self.assertIn("create or replace function public.bootstrap_current_session", text)
        self.assertNotIn("min(business_id)", text)
        self.assertIn("select count(*)", text)
        self.assertIn("into v_membership_count", text)
        self.assertIn("select business_id", text)
        self.assertIn("into v_business_id", text)
        self.assertIn("limit 1", text)
        self.assertIn("sj_membership_invalid", text)
        self.assertNotIn("insert into private.schema_versions", text)

    def test_registry_contains_exact_forward_correction_hashes(self) -> None:
        registry = REGISTRY.read_text("utf-8")
        for name in (HELPER_FIX, BOOTSTRAP_FIX):
            path = MIGRATIONS / name
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            self.assertIn(name, registry)
            self.assertIn(digest, registry)

if __name__ == "__main__":
    unittest.main()
