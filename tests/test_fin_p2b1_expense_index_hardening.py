from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase" / "migrations" / "20260920163000_fin_p2b1_expense_index_hardening.sql"

class FinP2B1ExpenseIndexHardeningTests(unittest.TestCase):
    def test_migration_exists(self) -> None:
        self.assertTrue(MIGRATION.exists(), MIGRATION.name)

    def test_covering_indexes_are_declared(self) -> None:
        source = " ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        self.assertIn("business_expenses_location_idx", source)
        self.assertIn("on public.business_expenses(location_id)", source)
        self.assertIn("business_expenses_funding_account_idx", source)
        self.assertIn("on public.business_expenses(funding_account_id)", source)

if __name__ == "__main__":
    unittest.main()
