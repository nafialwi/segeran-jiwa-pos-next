from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase" / "migrations" / "20260920170000_fin_p3_customer_debt_foundation.sql"

class FinP3CustomerDebtFoundationTests(unittest.TestCase):
    def test_migration_exists(self) -> None:
        self.assertTrue(MIGRATION.exists(), MIGRATION.name)

    def test_customer_debt_authority_is_declared(self) -> None:
        source = " ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        for token in [
            "create table public.customers",
            "create table public.customer_debts",
            "create table public.customer_debt_payments",
            "create view public.customer_debt_balances with (security_invoker = true)",
            "'hutang_pelanggan'",
            "customer_id uuid",
            "sales_shift_id_fkey",
            "create or replace function public.save_customer",
            "create or replace function public.checkout_sale",
            "create or replace function public.finance_pay_customer_debt",
            "'customer_debt_manage'",
            "'payment_transfer'",
            "'credit'",
            "'kas_shift'",
            "'bank'",
            "'customer_debt_payment'",
        ]:
            self.assertIn(token, source)

    def test_sale_integrity_fix_forward_is_present(self) -> None:
        source = " ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        self.assertIn("v_actor := private.current_profile_id()", source)
        self.assertIn("v_subtotal := v_subtotal +", source)
        self.assertIn("shift_id, customer_id", source)
        self.assertIn("cashier_profile_id", source)
        self.assertIn("verified_by", source)
        self.assertIn("revoke execute on function private.record_sale", source)
        self.assertIn("revoke execute on function private.post_sale_transaction", source)

if __name__ == "__main__":
    unittest.main()
