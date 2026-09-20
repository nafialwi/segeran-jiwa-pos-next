from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase" / "migrations" / "20260920130000_cs05_cs06_closure_security_hardening.sql"


class CS05CS06ClosureSecurityHardeningTests(unittest.TestCase):
    def test_closure_security_hardening_migration_exists(self) -> None:
        self.assertTrue(MIGRATION.exists(), MIGRATION.name)

    def test_view_uses_security_invoker_and_helpers_pin_search_path(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8").lower()
        normalized = " ".join(source.split())
        self.assertIn(
            "alter view public.cs05_sales_by_shift set (security_invoker = true)",
            normalized,
        )
        self.assertIn(
            "alter function private.cs05_open_shift(uuid, uuid, uuid, numeric, jsonb) set search_path = ''",
            normalized,
        )
        self.assertIn(
            "alter function private.cs05_close_shift(uuid, uuid, numeric) set search_path = ''",
            normalized,
        )
        self.assertIn(
            "alter function private.cs05_shift_immutable() set search_path = ''",
            normalized,
        )


if __name__ == "__main__":
    unittest.main()
