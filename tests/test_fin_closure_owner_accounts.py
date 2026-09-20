from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
M=ROOT/"supabase"/"migrations"/"20260920233000_fin_closure_owner_equity_personal_accounts.sql"

class FinanceClosureOwnerAccountsTests(unittest.TestCase):
    def test_migration_exists(self):
        self.assertTrue(M.exists())

    def test_blueprint_minimum_accounts_are_seeded(self):
        s=" ".join(M.read_text(encoding="utf-8").lower().split())
        self.assertIn("'modal'",s)
        self.assertIn("'pengeluaran_pribadi'",s)
        self.assertIn("'modal owner'",s)
        self.assertIn("'pengeluaran pribadi owner'",s)

    def test_owner_capital_is_two_sided_adjustment_not_income(self):
        s=" ".join(M.read_text(encoding="utf-8").lower().split())
        self.assertIn("finance_post_owner_capital",s)
        self.assertIn("v_modal_account",s)
        self.assertIn("'adjustment'",s)
        self.assertIn("'owner_capital'",s)
        self.assertNotIn("'income'",s)

    def test_owner_personal_withdrawal_is_two_sided_adjustment_not_expense(self):
        s=" ".join(M.read_text(encoding="utf-8").lower().split())
        self.assertIn("finance_post_owner_personal_withdrawal",s)
        self.assertIn("v_personal_account",s)
        self.assertIn("'owner_personal_expense'",s)
        self.assertNotIn("'expense'",s)

if __name__=="__main__":
    unittest.main()
