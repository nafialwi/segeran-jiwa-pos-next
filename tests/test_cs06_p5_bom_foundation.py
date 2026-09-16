from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase" / "migrations" / "20260915223000_cs06_p5_bom_foundation.sql"
SQL_TEST = ROOT / "supabase" / "tests" / "cs06_p5_bom_foundation_test.sql"


class Cs06P5BomFoundationTests(unittest.TestCase):
    def _migration(self) -> str:
        self.assertTrue(MIGRATION.is_file(), "P5 BOM migration must exist")
        return MIGRATION.read_text(encoding="utf-8").lower()

    def _sql_test(self) -> str:
        self.assertTrue(SQL_TEST.is_file(), "P5 BOM SQL integration test must exist")
        return SQL_TEST.read_text(encoding="utf-8").lower()

    def test_bom_schema_and_single_active_constraint_exist(self) -> None:
        source = self._migration()
        for token in (
            "create table public.boms",
            "create table public.bom_lines",
            "status in ('draft', 'active', 'retired')",
            "unique (business_id, finished_good_id, version)",
            "constraint bom_lines_component_unique",
            "deferrable initially deferred",
            "where status = 'active'",
        ):
            self.assertIn(token, source)

    def test_write_boundary_requires_production_permission(self) -> None:
        source = self._migration()
        self.assertGreaterEqual(
            source.count("private.has_permission(v_business, 'production_manage')"),
            2,
        )
        self.assertIn("sj_production_permission_denied", source)

    def test_security_definer_functions_use_hardened_search_path(self) -> None:
        source = self._migration()
        self.assertGreaterEqual(source.count("security definer"), 2)
        self.assertGreaterEqual(source.count("set search_path = ''"), 2)

    def test_stock_items_are_canonical_and_products_are_not_used(self) -> None:
        source = self._migration()
        self.assertIn("public.stock_items", source)
        self.assertNotIn("public.products", source)

    def test_p5_does_not_write_inventory(self) -> None:
        source = self._migration()
        self.assertNotIn("private.record_inventory_movement(", source)
        self.assertNotIn("insert into public.inventory_movements", source)
        self.assertNotIn("insert into public.inventory_movement_lines", source)

    def test_rpc_contracts_and_idempotency_are_present(self) -> None:
        source = self._migration()
        for token in (
            "public.save_bom_draft(",
            "public.activate_bom(",
            "private.lock_operation(",
            "private.record_operation_success(",
            "bom_duplicate_component",
            "bom_self_reference",
            "bom_ledger_precision_unsupported",
            "bom_not_draft",
        ):
            self.assertIn(token, source)

    def test_migration_avoids_xp_destructive_classification_tokens(self) -> None:
        source = self._migration()
        self.assertNotRegex(
            source,
            r"\b(delete\s+from|drop\s+(table|schema|database|column)|truncate\b)\b",
        )
        self.assertIn("merge into public.bom_lines", source)

    def test_direct_client_dml_is_not_granted(self) -> None:
        source = self._migration()
        self.assertIn("revoke all on table public.boms", source)
        self.assertIn("revoke all on table public.bom_lines", source)
        self.assertNotIn("grant insert", source)
        self.assertNotIn("grant update", source)
        self.assertNotIn("grant delete", source)

    def test_sql_integration_test_covers_real_bom_flow(self) -> None:
        source = self._sql_test()
        self.assertTrue(source.lstrip().startswith("begin;"))
        self.assertTrue(source.rstrip().endswith("rollback;"))
        for token in (
            "public.save_bom_draft(",
            "public.activate_bom(",
            "production_manage",
            "bom_self_reference",
            "bom_duplicate_component",
            "sj_production_permission_denied",
            "inventory_movements",
            "inventory_balances",
            "status = 'retired'",
            "cs06_p5_draft_replace_failed",
        ):
            self.assertIn(token, source)


if __name__ == "__main__":
    unittest.main()
