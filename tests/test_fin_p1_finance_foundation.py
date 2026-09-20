from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase" / "migrations" / "20260920140000_fin_p1_finance_foundation.sql"


class FinP1FinanceFoundationTests(unittest.TestCase):
    def test_migration_exists(self) -> None:
        self.assertTrue(MIGRATION.exists(), MIGRATION.name)

    def test_locked_finance_contract_is_present(self) -> None:
        source = " ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        required = [
            "'kas_shift'",
            "drop policy if exists money_accounts_member_read on public.money_accounts",
            "create policy money_accounts_owner_read",
            "drop policy if exists money_movements_member_read on public.money_movements",
            "create policy money_movements_owner_read",
            "create or replace function public.finance_post_transfer",
            "create or replace function public.finance_post_owner_capital",
            "create or replace function public.finance_post_owner_personal_withdrawal",
            "'owner_capital'",
            "'owner_personal_expense'",
            "'adjustment'",
        ]
        for token in required:
            self.assertIn(token, source)


if __name__ == "__main__":
    unittest.main()
