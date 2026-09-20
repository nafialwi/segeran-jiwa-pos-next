from __future__ import annotations
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MIGRATION=ROOT/"supabase"/"migrations"/"20260920193000_fin_p5b_supplier_read_authority.sql"

class FinP5BSupplierReadAuthorityTests(unittest.TestCase):
    def test_migration_exists(self):
        self.assertTrue(MIGRATION.exists(), MIGRATION.name)

    def test_supplier_select_is_permission_bounded(self):
        source=" ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        self.assertIn('drop policy if exists "tenant isolation for suppliers"',source)
        self.assertIn("grant select on table public.suppliers to authenticated",source)
        self.assertIn("create policy suppliers_purchase_read",source)
        self.assertIn("purchase_manage",source)
        self.assertIn("get_my_authority",source)

if __name__=="__main__":
    unittest.main()
