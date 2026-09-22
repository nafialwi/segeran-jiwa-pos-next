from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260922230000_c10_finance_overview_authority.sql"
API = ROOT / "src/finance/finance-api.ts"


class C10FinanceOverviewAuthorityTests(unittest.TestCase):
    def test_owner_overview_rpc_is_hardened_and_authenticated_only(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("create or replace function public.finance_owner_overview()", sql)
        self.assertIn("security definer", sql)
        self.assertIn("set search_path = ''", sql)
        self.assertIn("SJ_OWNER_FINANCE_AUTHORITY_REQUIRED", sql)
        self.assertIn("grant execute on function public.finance_owner_overview()", sql)
        self.assertIn("to authenticated", sql)

    def test_rpc_uses_existing_finance_read_authorities(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        for token in [
            "money_accounts",
            "money_balances",
            "customer_debt_balances",
            "supplier_payable_balances",
            "employee_kasbon_balances",
            "finance_daily_reconciliations",
            "qris_settlements",
            "owner_list_users",
        ]:
            self.assertIn(token, sql)

    def test_frontend_uses_single_owner_overview_rpc(self):
        api = API.read_text(encoding="utf-8")
        start = api.index("export async function fetchFinanceOverview")
        end = api.index("export async function postFinanceTransfer", start)
        fn = api[start:end]
        self.assertIn("supabase.rpc('finance_owner_overview')", fn)
        self.assertNotIn(".from(", fn)
        self.assertNotIn("owner_list_users", fn)


if __name__ == "__main__":
    unittest.main()
