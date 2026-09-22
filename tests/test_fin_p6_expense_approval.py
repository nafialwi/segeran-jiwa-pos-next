from __future__ import annotations
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MIGRATION=ROOT/"supabase"/"migrations"/"20260920200000_fin_p6_expense_approval.sql"
SHIFT_API=ROOT/"src"/"shift"/"shift-api.ts"
SHIFT_UI=ROOT/"src"/"screens"/"ShiftManagementScreen.tsx"
OWNER_UI=ROOT/"src"/"screens"/"ExpenseApprovalScreen.tsx"
APP=ROOT/"src"/"App.tsx"
HOME=ROOT/"src"/"screens"/"HomeScreen.tsx"
MENU=ROOT/"src"/"screens"/"MenuScreen.tsx"

class FinP6ExpenseApprovalTests(unittest.TestCase):
    def test_migration_exists(self):
        self.assertTrue(MIGRATION.exists(), MIGRATION.name)

    def test_approval_contract_is_present(self):
        source=" ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        for token in [
            "create table public.expense_approval_rules",
            "create table public.expense_approval_requests",
            "create table public.expense_approval_decisions",
            "create view public.expense_approval_queue",
            "finance_set_expense_approval_rule",
            "finance_submit_shift_expense",
            "finance_decide_expense_request",
            "finance_expense_approval_required",
            "finance_post_shift_expense_fact",
            "approval_state",
            "'pending'",
            "'approved'",
            "'rejected'",
        ]:
            self.assertIn(token,source)

    def test_client_uses_approval_aware_flow(self):
        api=SHIFT_API.read_text(encoding="utf-8")
        ui=SHIFT_UI.read_text(encoding="utf-8")
        owner=OWNER_UI.read_text(encoding="utf-8")
        app=APP.read_text(encoding="utf-8")
        menu=MENU.read_text(encoding="utf-8")
        self.assertIn("finance_submit_shift_expense",api)
        self.assertIn("expense_approval_queue",api)
        self.assertIn("Menunggu persetujuan Owner",ui)
        self.assertIn("finance_set_expense_approval_rule",owner)
        self.assertIn("finance_decide_expense_request",owner)
        self.assertIn('path="/expense-approval"',app)
        self.assertIn("Approval Pengeluaran",menu)
        self.assertIn("to: '/expense-approval'",menu)

if __name__=="__main__":
    unittest.main()
