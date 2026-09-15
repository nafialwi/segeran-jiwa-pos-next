from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase" / "migrations" / "20260915210000_cs06_p4r1_grn_hardening.sql"
SQL_TEST = ROOT / "supabase" / "tests" / "cs06_p4r1_grn_hardening_test.sql"


class Cs06P4R1GrnHardeningTests(unittest.TestCase):
    def _migration(self) -> str:
        self.assertTrue(MIGRATION.is_file(), "P4R1 forward hardening migration must exist")
        return MIGRATION.read_text(encoding="utf-8").lower()

    def _sql_test(self) -> str:
        self.assertTrue(SQL_TEST.is_file(), "P4R1 SQL integration test must exist")
        return SQL_TEST.read_text(encoding="utf-8").lower()

    def test_forward_hardening_migration_exists(self) -> None:
        self.assertTrue(MIGRATION.is_file())

    def test_posting_requires_purchase_permission_and_hardened_search_path(self) -> None:
        source = self._migration()
        self.assertIn("set search_path = ''", source)
        self.assertIn("private.has_permission(v_business, 'purchase_manage')", source)
        self.assertIn("sj_purchase_permission_denied", source)

    def test_posting_uses_canonical_inventory_writer(self) -> None:
        source = self._migration()
        self.assertIn("private.record_inventory_movement(", source)
        self.assertNotIn("insert into public.inventory_movements", source)
        self.assertNotIn("insert into public.inventory_movement_lines", source)
        self.assertNotIn("grl.location_id", source)

    def test_grn_lines_are_bound_to_po_lines_and_over_receipt_is_blocked(self) -> None:
        source = self._migration()
        for token in (
            "pol.purchase_order_id <> v_po.id",
            "pol.stock_item_id <> grl.stock_item_id",
            "pol.unit_id <> grl.unit_id",
            "grn_over_receipt",
            "grn_duplicate_po_line",
            "grn_line_arithmetic_invalid",
        ):
            self.assertIn(token, source)

    def test_po_completion_is_decided_per_po_line(self) -> None:
        source = self._migration()
        self.assertIn("v_all_received", source)
        self.assertIn("grl.purchase_order_line_id = pol.id", source)
        self.assertNotIn("v_received_total", source)
        self.assertNotIn("v_ordered_total", source)

    def test_posting_records_actor_and_has_retry_safe_replay(self) -> None:
        source = self._migration()
        self.assertIn("posted_by = v_actor", source)
        self.assertIn("'grn_post:' || p_goods_receipt_id::text", source)
        self.assertIn("'already_posted', true", source)

    def test_sql_integration_test_executes_real_posting_flow(self) -> None:
        source = self._sql_test()
        self.assertTrue(source.lstrip().startswith("begin;"))
        self.assertTrue(source.rstrip().endswith("rollback;"))
        for token in (
            "public.post_goods_receipt(",
            "partially_received",
            "received",
            "grn_over_receipt",
            "sj_purchase_permission_denied",
            "already_posted",
            "inventory_balances",
        ):
            self.assertIn(token, source)


if __name__ == "__main__":
    unittest.main()
