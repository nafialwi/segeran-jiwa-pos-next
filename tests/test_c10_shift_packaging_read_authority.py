from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260922223000_c10_shift_packaging_read_authority.sql"
API = ROOT / "src/shift/shift-api.ts"


class C10ShiftPackagingReadAuthorityTests(unittest.TestCase):
    def test_migration_exists_and_creates_authenticated_rpc(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("create or replace function public.shift_packaging_usage", sql)
        self.assertIn("security definer", sql)
        self.assertIn("set search_path = ''", sql)
        self.assertIn("grant execute on function public.shift_packaging_usage(uuid)", sql)
        self.assertIn("to authenticated", sql)

    def test_rpc_is_shift_and_business_scoped(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("s.business_id = v_business", sql)
        self.assertIn("v_owner or s.cashier_profile_id = v_profile", sql)
        self.assertIn("sale.shift_id = p_shift", sql)
        self.assertIn("snap.component_role = 'PACKAGING'", sql)
    def test_frontend_uses_rpc_instead_of_protected_direct_sales_read(self):
        api = API.read_text(encoding="utf-8")
        start = api.index("export async function fetchShiftPackagingUsage")
        fn = api[start:]
        self.assertIn("supabase.rpc('shift_packaging_usage'", fn)
        self.assertNotIn(".from('sales')", fn)
        self.assertNotIn(".from('sale_item_component_snapshots')", fn)

    def test_missing_rpc_is_fail_closed_not_fake_healthy(self):
        api = API.read_text(encoding="utf-8")
        start = api.index("export async function fetchShiftPackagingUsage")
        fn = api[start:]
        self.assertIn("return { ready: false, items: [] }", fn)
        self.assertIn("PGRST202", fn)


if __name__ == "__main__":
    unittest.main()
