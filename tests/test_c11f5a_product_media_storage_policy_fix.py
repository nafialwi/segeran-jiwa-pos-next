from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIX = ROOT / "supabase/migrations/20260924124500_c11f5a_product_media_storage_policy_fix.sql"
SOURCE = ROOT / "supabase/migrations/20260924083000_c11f5_product_media.sql"


class C11F5AProductMediaStoragePolicyFixTests(unittest.TestCase):
    def test_repair_migration_exists_and_targets_only_product_media_policies(self):
        sql = FIX.read_text(encoding="utf-8")
        self.assertIn("product_media_manager_insert", sql)
        self.assertIn("product_media_manager_update", sql)
        self.assertIn("product_media_manager_delete", sql)
        self.assertNotIn("alter table public.sale_products", sql.lower())
        self.assertNotIn("update public.sale_products", sql.lower())

    def test_storage_policy_no_longer_calls_private_permission_helper_directly(self):
        sql = FIX.read_text(encoding="utf-8")
        self.assertNotIn("private.has_permission", sql)
        self.assertIn("public.get_my_authority()", sql)
        self.assertIn("'permissions'", sql)
        self.assertIn("? 'PRODUCT_MANAGE'", sql)

    def test_tenant_and_product_path_bounds_are_preserved(self):
        sql = FIX.read_text(encoding="utf-8")
        self.assertIn("(storage.foldername(name))[1]", sql)
        self.assertIn("(storage.foldername(name))[2]", sql)
        self.assertIn("p.business_id", sql)
        self.assertIn("p.id::text", sql)
        self.assertIn("bucket_id = 'product-media'", sql)

    def test_original_media_authority_contract_remains_present(self):
        sql = SOURCE.read_text(encoding="utf-8")
        self.assertIn("public.product_media_capability()", sql)
        self.assertIn("public.product_media_read_v1()", sql)
        self.assertIn("public.set_sale_product_image(", sql)
        self.assertIn("grant execute on function public.set_sale_product_image", sql)

    def test_repair_does_not_widen_storage_policy_role(self):
        sql = FIX.read_text(encoding="utf-8")
        self.assertEqual(sql.count("to authenticated"), 3)
        self.assertNotIn("to anon", sql.lower())
        self.assertNotIn("to public", sql.lower())


if __name__ == "__main__":
    unittest.main()
