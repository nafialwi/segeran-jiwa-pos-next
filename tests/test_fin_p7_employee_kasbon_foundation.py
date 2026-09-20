from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
M=ROOT/"supabase"/"migrations"/"20260920230000_fin_p7_employee_kasbon_foundation.sql"

class FinP7EmployeeKasbonFoundationTests(unittest.TestCase):
    def test_migration_exists(self):
        self.assertTrue(M.exists())

    def test_employee_kasbon_contract_is_present(self):
        s=" ".join(M.read_text(encoding="utf-8").lower().split())
        for token in [
            "'kasbon_karyawan'",
            "create table public.employee_kasbons",
            "create view public.employee_kasbon_balances",
            "finance_create_employee_kasbon",
            "'employee_kasbon'",
            "'transfer'",
            "'kas_utama'",
            "'bank'",
            "finance_owner_required",
            "employee_kasbon_employee_invalid",
            "finance_insufficient_balance",
            "private.record_money_movement",
            "private.lock_operation",
            "private.record_operation_success",
        ]:
            self.assertIn(token,s)

    def test_no_unlocked_repayment_semantics_are_invented(self):
        s=M.read_text(encoding="utf-8").lower()
        for forbidden in [
            "employee_kasbon_payments",
            "pay_employee_kasbon",
            "salary",
            "payroll",
            "installment",
            "due_date",
            "interest_rate",
            "automatic_deduction",
        ]:
            self.assertNotIn(forbidden,s)

    def test_finance_read_is_owner_only(self):
        s=" ".join(M.read_text(encoding="utf-8").lower().split())
        self.assertIn("employee_kasbons_owner_read",s)
        self.assertIn("coalesce((public.get_my_authority() ->> 'owner')::boolean, false)",s)

if __name__=="__main__":
    unittest.main()
