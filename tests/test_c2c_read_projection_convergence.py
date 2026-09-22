from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260922100000_c2c_read_projection_convergence.sql"
SQL_TEST = ROOT / "supabase/tests/c2c_read_projection_convergence_test.sql"
HISTORY_API = ROOT / "src/history/history-api.ts"


class C2CReadProjectionConvergenceTests(unittest.TestCase):
    def migration(self) -> str:
        self.assertTrue(MIGRATION.exists(), "C2C migration must exist")
        return MIGRATION.read_text(encoding="utf-8").lower()

    def test_single_legacy_v2_sale_line_projection_exists(self):
        sql = self.migration()
        self.assertIn("create or replace view private.sale_line_read_projection", sql)
        self.assertIn("product_code_snapshot", sql)
        self.assertIn("product_name_snapshot", sql)
        self.assertIn("variant_name_snapshot", sql)
        self.assertIn("coalesce(", sql)
        self.assertIn("product_key", sql)

    def test_history_reads_projection_and_searches_variant_snapshot(self):
        sql = self.migration()
        self.assertIn("create or replace function public.transaction_history_search", sql)
        self.assertIn("from private.sale_line_read_projection line", sql)
        self.assertIn("'variant_id'", sql)
        self.assertIn("'variant_name'", sql)
        self.assertIn("lower(coalesce(line.variant_name,''))", sql)
        self.assertNotIn(
            "join public.stock_items item on item.id=line.stock_item_id",
            sql,
        )

    def test_reports_group_by_product_identity_not_inventory_component(self):
        sql = self.migration()
        self.assertIn("create or replace function public.report_run", sql)
        self.assertIn("from private.sale_line_read_projection li", sql)
        self.assertIn("group by li.product_key", sql)
        self.assertIn("'varian'", sql)
        self.assertNotIn("group by li.stock_item_id", sql)

    def test_correction_preview_uses_original_inventory_movement(self):
        sql = self.migration()
        self.assertIn("create or replace function public.sale_correction_preview", sql)
        self.assertIn("inventory_movement_lines", sql)
        self.assertIn("sale_consumption", sql)
        self.assertNotIn(
            "join public.stock_items item on item.id=line.stock_item_id",
            sql,
        )

    def test_frontend_history_type_accepts_v2_identity(self):
        src = HISTORY_API.read_text(encoding="utf-8")
        self.assertIn("stock_item_id: string | null", src)
        self.assertIn("sale_product_id: string | null", src)
        self.assertIn("variant_id: string | null", src)
        self.assertIn("variant_name: string | null", src)
        self.assertIn("fulfillment_mode: string | null", src)

    def test_sql_regression_is_transactional_and_covers_legacy_and_v2(self):
        self.assertTrue(SQL_TEST.exists(), "C2C SQL regression must exist")
        sql = SQL_TEST.read_text(encoding="utf-8").lower()
        self.assertTrue(sql.lstrip().startswith("begin;"))
        self.assertTrue(sql.rstrip().endswith("rollback;"))
        for token in (
            "checkout_sale_v2",
            "checkout_sale(",
            "transaction_history_search",
            "report_run",
            "sale_correction_preview",
            "c2c_v2_history_failed",
            "c2c_legacy_history_failed",
            "c2c_product_report_failed",
            "c2c_correction_preview_failed",
        ):
            self.assertIn(token, sql)


if __name__ == "__main__":
    unittest.main()
