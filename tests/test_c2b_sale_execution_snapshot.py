from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260922090000_c2b_sale_execution_snapshot.sql"
SQL_TEST = ROOT / "supabase/tests/c2b_sale_execution_snapshot_test.sql"


class C2BSaleExecutionSnapshotTests(unittest.TestCase):
    def migration(self) -> str:
        self.assertTrue(MIGRATION.exists(), "C2B migration must exist")
        return MIGRATION.read_text(encoding="utf-8").lower()

    def test_sale_items_can_hold_variant_snapshot_without_fake_stock_item(self):
        sql = self.migration()
        self.assertIn("alter column stock_item_id drop not null", sql)
        for column in (
            "sale_product_id",
            "variant_id",
            "product_code_snapshot",
            "product_name_snapshot",
            "variant_code_snapshot",
            "variant_name_snapshot",
            "fulfillment_mode_snapshot",
        ):
            self.assertIn(column, sql)

    def test_component_snapshot_is_immutable_historical_fact(self):
        sql = self.migration()
        self.assertIn("create table public.sale_item_component_snapshots", sql)
        self.assertIn("inventory_tracked_snapshot", sql)
        self.assertIn("stock_item_code_snapshot", sql)
        self.assertIn("stock_item_name_snapshot", sql)
        self.assertIn("quantity_per_unit", sql)
        self.assertIn("quantity_total", sql)
        self.assertIn("private.prevent_fact_mutation()", sql)

    def test_v2_record_sale_uses_variant_and_sale_time_snapshot(self):
        sql = self.migration()
        self.assertIn("create or replace function private.record_sale_v2", sql)
        self.assertIn("variant_id", sql)
        self.assertIn("variant_sale_components", sql)
        self.assertIn("sale_item_component_snapshots", sql)
        self.assertIn("sale_create_v2", sql)
        self.assertIn("sj_variant_components_missing", sql)
        self.assertIn("sj_variant_component_shape_invalid", sql)

    def test_posting_keeps_single_inventory_and_money_engine(self):
        sql = self.migration()
        self.assertIn("create or replace function private.post_sale_transaction", sql)
        self.assertEqual(sql.count("private.record_inventory_movement("), 1)
        self.assertEqual(sql.count("private.record_money_movement("), 2)
        self.assertIn("sale_item_component_snapshots", sql)
        self.assertIn("legacy_sale_item", sql)
        self.assertIn("snapshot_v2", sql)

    def test_posting_has_definitive_concurrency_safe_stock_gate(self):
        sql = self.migration()
        self.assertIn("pg_catalog.pg_advisory_xact_lock", sql)
        self.assertIn("c2b:sale-stock:", sql)
        self.assertIn("sj_stock_low", sql)
        self.assertLess(
            sql.index("pg_catalog.pg_advisory_xact_lock"),
            sql.index("private.record_inventory_movement("),
        )

    def test_public_v2_checkout_is_additive_and_old_checkout_remains(self):
        sql = self.migration()
        self.assertIn("create or replace function public.checkout_sale_v2", sql)
        self.assertIn("private.record_sale_v2", sql)
        self.assertIn("private.post_sale_transaction", sql)
        self.assertNotIn("drop function public.checkout_sale", sql)
        self.assertNotIn("create or replace function public.checkout_sale(", sql)

    def test_refund_and_correction_are_not_reimplemented(self):
        sql = self.migration()
        self.assertNotIn("create or replace function public.refund_sale", sql)
        self.assertNotIn("create or replace function public.correct_sale", sql)
        self.assertIn("refund/correction continue to reverse the original inventory movement", sql)

    def test_sql_regression_is_transactional_and_exercises_real_v2_flow(self):
        self.assertTrue(SQL_TEST.exists(), "C2B SQL regression must exist")
        sql = SQL_TEST.read_text(encoding="utf-8").lower()
        self.assertTrue(sql.lstrip().startswith("begin;"))
        self.assertTrue(sql.rstrip().endswith("rollback;"))
        for token in (
            "checkout_sale_v2",
            "make_to_order",
            "sale_item_component_snapshots",
            "inventory_movement_lines",
            "c2b_snapshot_quantity_failed",
            "c2b_inventory_aggregation_failed",
            "c2b_replay_failed",
        ):
            self.assertIn(token, sql)


if __name__ == "__main__":
    unittest.main()
