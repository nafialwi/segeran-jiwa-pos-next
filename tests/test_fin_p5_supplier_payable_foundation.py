from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase" / "migrations" / "20260920190000_fin_p5_supplier_payable_foundation.sql"

class FinP5SupplierPayableFoundationTests(unittest.TestCase):
    def test_migration_exists(self) -> None:
        self.assertTrue(MIGRATION.exists(), MIGRATION.name)

    def test_supplier_payable_contract_is_present(self) -> None:
        source = " ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        for token in [
            "'utang_pemasok'",
            "create table public.supplier_payables",
            "create table public.supplier_payable_payments",
            "create view public.supplier_payable_balances",
            "finance_create_supplier_payable",
            "finance_pay_supplier_payable",
            "'supplier_payable'",
            "'supplier_payable_payment'",
            "'transfer'",
            "purchase_manage",
            "payment_transfer",
            "supplier_payable_overpayment",
        ]:
            self.assertIn(token, source)

    def test_supplier_payment_is_not_new_income_or_expense(self) -> None:
        source = " ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        pay_start = source.index("create or replace function public.finance_pay_supplier_payable")
        pay_source = source[pay_start:]
        self.assertIn("'transfer'", pay_source)
        self.assertNotIn("'income'", pay_source)
        self.assertNotIn("'expense'", pay_source)

if __name__ == "__main__":
    unittest.main()
