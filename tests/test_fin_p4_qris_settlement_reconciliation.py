from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase" / "migrations" / "20260920180000_fin_p4_qris_settlement_reconciliation.sql"

class FinP4QrisSettlementReconciliationTests(unittest.TestCase):
    def test_migration_exists(self) -> None:
        self.assertTrue(MIGRATION.exists(), MIGRATION.name)

    def test_qris_settlement_authority_is_declared(self) -> None:
        source = " ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        for token in [
            "create table public.qris_settlements",
            "create table public.finance_daily_reconciliations",
            "create or replace function public.finance_settle_qris",
            "create or replace function public.finance_reconcile_day",
            "'qris_belum_cair'",
            "'qris_sudah_cair'",
            "'bank'",
            "'qris_provider_fee'",
            "'sesuai'",
            "'perlu_diperiksa'",
            "public.get_my_authority()",
        ]:
            self.assertIn(token, source)

    def test_settlement_uses_single_money_authority(self) -> None:
        source = " ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        self.assertIn("'settlement'", source)
        self.assertIn("'expense'", source)
        self.assertIn("'transfer'", source)
        self.assertIn("private.record_money_movement", source)
        self.assertIn("private.record_operation_success", source)
        self.assertIn("private.lock_operation", source)

    def test_reconciliation_is_snapshot_not_mutable_ledger(self) -> None:
        source = " ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        self.assertIn("finance_daily_reconciliations_immutable", source)
        self.assertIn("cash_variance", source)
        self.assertIn("qris_variance", source)
        self.assertIn("transfer_variance", source)
        self.assertIn("stock_status", source)

if __name__ == "__main__":
    unittest.main()
