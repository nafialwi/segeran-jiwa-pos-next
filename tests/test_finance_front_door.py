from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
APP=ROOT/"src"/"App.tsx"
HOME=ROOT/"src"/"screens"/"HomeScreen.tsx"
SCREEN=ROOT/"src"/"screens"/"FinanceScreen.tsx"
API=ROOT/"src"/"finance"/"finance-api.ts"

class FinanceFrontDoorTests(unittest.TestCase):
    def test_files_and_owner_route_exist(self):
        self.assertTrue(SCREEN.exists())
        self.assertTrue(API.exists())
        app=APP.read_text()
        home=HOME.read_text()
        self.assertIn('path="/keuangan"',app)
        self.assertIn("<FinanceScreen />",app)
        self.assertIn("<RequireAccess ownerOnly>",app)
        self.assertIn('to="/keuangan"',home)
        self.assertIn("Keuangan",home)

    def test_front_door_exposes_locked_finance_capabilities(self):
        s=SCREEN.read_text()
        for token in [
            "Saldo Keuangan",
            "Pindah Uang",
            "Modal Owner",
            "Pengeluaran Pribadi Owner",
            "Settlement QRIS",
            "Rekonsiliasi Harian",
            "Hutang Pelanggan",
            "Utang Pemasok",
            "Kasbon Karyawan",
            "Approval Pengeluaran",
        ]:
            self.assertIn(token,s)

    def test_personal_withdrawal_has_explicit_profit_warning_and_confirmation(self):
        s=SCREEN.read_text()
        self.assertIn("tidak diperlakukan sebagai biaya usaha",s)
        self.assertIn("tidak mengurangi laba usaha",s)
        self.assertIn("confirmAction",s)

    def test_api_uses_canonical_finance_authority(self):
        s=API.read_text()
        for rpc in [
            "finance_owner_overview",
            "finance_post_transfer",
            "finance_post_owner_capital",
            "finance_post_owner_personal_withdrawal",
            "finance_settle_qris",
            "finance_reconcile_day",
            "finance_pay_customer_debt",
            "finance_pay_supplier_payable",
            "finance_create_employee_kasbon",
        ]:
            self.assertIn(rpc,s)

        migration=(
            ROOT
            / "supabase"
            / "migrations"
            / "20260922230000_c10_finance_overview_authority.sql"
        ).read_text()
        for authority in [
            "owner_list_users",
            "money_balances",
            "customer_debt_balances",
            "supplier_payable_balances",
            "employee_kasbon_balances",
        ]:
            self.assertIn(authority,migration)

    def test_unlocked_month_close_is_not_invented(self):
        combined=(SCREEN.read_text()+API.read_text()).lower()
        self.assertNotIn("tutup bulan",combined)
        self.assertNotIn("month_close",combined)
        self.assertNotIn("reopen_month",combined)

if __name__=="__main__":
    unittest.main()
