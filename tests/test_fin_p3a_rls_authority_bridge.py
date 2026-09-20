from __future__ import annotations
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MIGRATION=ROOT/"supabase"/"migrations"/"20260920171500_fin_p3a_rls_authority_bridge.sql"

class FinP3ARlsAuthorityBridgeTests(unittest.TestCase):
    def test_migration_exists(self) -> None:
        self.assertTrue(MIGRATION.exists(), MIGRATION.name)

    def test_policies_use_public_authority_boundary(self) -> None:
        source=" ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        self.assertIn("public.get_my_authority()", source)
        self.assertIn("customers_authorized_read", source)
        self.assertIn("customer_debts_authorized_read", source)
        self.assertIn("customer_debt_payments_authorized_read", source)
        self.assertNotIn("private.has_permission", source)

if __name__=="__main__":
    unittest.main()
