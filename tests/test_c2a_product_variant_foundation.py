from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260922080000_c2a_product_variant_foundation.sql"
SQL_TEST = ROOT / "supabase/tests/c2a_product_variant_foundation_test.sql"


class C2AProductVariantFoundationTests(unittest.TestCase):
    def migration(self) -> str:
        self.assertTrue(MIGRATION.exists(), "C2A migration must exist")
        return MIGRATION.read_text(encoding="utf-8").lower()

    def test_separates_sale_product_variant_and_sale_components(self):
        sql = self.migration()
        self.assertIn("create table public.sale_products", sql)
        self.assertIn("create table public.product_variants", sql)
        self.assertIn("create table public.variant_sale_components", sql)
        self.assertIn("direct_stock", sql)
        self.assertIn("make_to_order", sql)
        self.assertIn("preproduced", sql)

    def test_production_recipe_authority_is_not_duplicated(self):
        sql = self.migration()
        self.assertIn("production-stage recipe authority remains public.boms", sql)
        self.assertNotIn("consumption_stage text", sql)
        self.assertNotIn("create table public.variant_production_components", sql)

    def test_current_sale_enabled_stock_is_backfilled_as_direct_stock(self):
        sql = self.migration()
        self.assertRegex(
            sql,
            re.compile(
                r"insert\s+into\s+public\.sale_products.*?from\s+public\.stock_items.*?sale_enabled",
                re.S,
            ),
        )
        self.assertRegex(
            sql,
            re.compile(
                r"insert\s+into\s+public\.product_variants.*?direct_stock.*?sale_stock_item_id",
                re.S,
            ),
        )
        self.assertIn("'finished_good'", sql)
        self.assertIn("sale-stage", sql)

    def test_c2a_does_not_replace_existing_sale_or_inventory_writers(self):
        sql = self.migration()
        self.assertNotIn("create or replace function private.record_sale", sql)
        self.assertNotIn("create or replace function private.post_sale_transaction", sql)
        self.assertNotIn("record_inventory_movement(", sql)

    def test_v2_catalog_is_additive_and_permission_bounded(self):
        sql = self.migration()
        self.assertIn("create or replace function public.sales_catalog_v2", sql)
        self.assertIn("sale_execute", sql)
        self.assertIn("sj_shift_not_open", sql)
        self.assertIn("grant execute on function public.sales_catalog_v2(uuid) to authenticated", sql)
        self.assertNotIn("drop function public.sales_catalog", sql)

    def test_direct_client_dml_is_fail_closed(self):
        sql = self.migration()
        for table in ("sale_products", "product_variants", "variant_sale_components"):
            self.assertIn(f"revoke all on table public.{table}", sql)
            self.assertIn(f"grant select on table public.{table} to authenticated", sql)

    def test_sql_regression_is_transactional(self):
        self.assertTrue(SQL_TEST.exists(), "C2A SQL regression must exist")
        sql = SQL_TEST.read_text(encoding="utf-8").lower()
        self.assertTrue(sql.lstrip().startswith("begin;"))
        self.assertTrue(sql.rstrip().endswith("rollback;"))
        self.assertIn("sales_catalog_v2", sql)
        self.assertIn("c2a_direct_stock_backfill_failed", sql)


if __name__ == "__main__":
    unittest.main()
