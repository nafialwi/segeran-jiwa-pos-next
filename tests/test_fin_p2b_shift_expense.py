from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase" / "migrations" / "20260920160000_fin_p2b_shift_expense.sql"
SHIFT_API = ROOT / "src" / "shift" / "shift-api.ts"
SHIFT_UI = ROOT / "src" / "screens" / "ShiftManagementScreen.tsx"

class FinP2BShiftExpenseTests(unittest.TestCase):
    def test_migration_exists(self) -> None:
        self.assertTrue(MIGRATION.exists(), MIGRATION.name)

    def test_expense_authority_and_cash_sale_alignment_are_present(self) -> None:
        source = " ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        for token in [
            "create table public.business_expenses",
            "create policy business_expenses_scope_read",
            "finance_post_shift_expense",
            "expense_shift_create",
            "'shift_expense'",
            "'business_expense'",
            "'expense'",
            "'cash_out'",
            "finance_cash_movement_source_required",
            "then 'kas_shift'",
        ]:
            self.assertIn(token, source)
        self.assertNotIn("when v_method = 'cash' then 'kas_utama'", source)

    def test_ui_replaces_generic_cash_movement_with_permission_gated_expense(self) -> None:
        api = SHIFT_API.read_text(encoding="utf-8")
        ui = SHIFT_UI.read_text(encoding="utf-8")
        self.assertIn("finance_submit_shift_expense", api)
        self.assertIn("business_expenses", api)
        self.assertIn("Catat Pengeluaran Shift", ui)
        self.assertIn("EXPENSE_SHIFT_CREATE", ui)
        self.assertNotIn("Gerakan Kas", ui)
        self.assertNotIn("addCashMovement", ui)

if __name__ == "__main__":
    unittest.main()
