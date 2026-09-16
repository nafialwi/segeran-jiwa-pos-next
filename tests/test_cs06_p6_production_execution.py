from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase" / "migrations" / "20260916083000_cs06_p6_production_execution.sql"
SQL_TEST = ROOT / "supabase" / "tests" / "cs06_p6_production_execution_test.sql"

_DESTRUCTIVE = re.compile(r"\b(DROP\s+(TABLE|SCHEMA|DATABASE|COLUMN)|TRUNCATE\b|DELETE\s+FROM\b)", re.I)
_DATA_CHANGE = re.compile(r"\b(INSERT\s+INTO|UPDATE\b|DELETE\s+FROM|MERGE\b)\b", re.I)
_SAFE_DDL = re.compile(r"\b(CREATE\s+(TABLE|VIEW|FUNCTION|SCHEMA|TYPE|SEQUENCE)|ALTER\s+TABLE\s+.*\bADD\b|CREATE\s+INDEX\b)\b", re.I | re.S)
_NON_TRANSACTIONAL = re.compile(r"\b(CREATE\s+INDEX\s+CONCURRENTLY|DROP\s+INDEX\s+CONCURRENTLY|VACUUM\b|REINDEX\s+CONCURRENTLY)\b", re.I)
_READ_ONLY = re.compile(r"^\s*(SELECT\b|WITH\b|EXPLAIN\b|SHOW\b)", re.I)


def classify_sql(sql: str) -> str:
    if _NON_TRANSACTIONAL.search(sql):
        return "NON_TRANSACTIONAL"
    if _DESTRUCTIVE.search(sql):
        return "DESTRUCTIVE"
    if _DATA_CHANGE.search(sql):
        return "DATA_CHANGE"
    if _SAFE_DDL.search(sql):
        return "SAFE_DDL"
    if _READ_ONLY.search(sql):
        return "READ_ONLY"
    return "UNKNOWN"


class Cs06P6ProductionExecutionTests(unittest.TestCase):
    def _migration(self) -> str:
        self.assertTrue(MIGRATION.is_file(), "P6 production migration must exist")
        return MIGRATION.read_text(encoding="utf-8").lower()

    def _sql_test(self) -> str:
        self.assertTrue(SQL_TEST.is_file(), "P6 production SQL regression must exist")
        return SQL_TEST.read_text(encoding="utf-8").lower()

    def test_schema_and_rpc_contracts_exist(self) -> None:
        source = self._migration()
        for token in (
            "create table public.production_batches",
            "status in ('draft', 'posted')",
            "public.create_production_batch(",
            "public.post_production_batch(",
            "inventory_movement_id",
        ):
            self.assertIn(token, source)

    def test_permission_and_hardened_rpc_boundary(self) -> None:
        source = self._migration()
        self.assertGreaterEqual(
            source.count("private.has_permission(v_business, 'production_manage')"),
            2,
        )
        self.assertIn("sj_production_permission_denied", source)
        self.assertGreaterEqual(source.count("security definer"), 3)
        self.assertGreaterEqual(source.count("set search_path = ''"), 3)

    def test_posting_uses_canonical_inventory_writer_once_in_rpc_contract(self) -> None:
        source = self._migration()
        self.assertEqual(source.count("v_movement_id := private.record_inventory_movement("), 1)
        for token in (
            "'production_post:' || p_batch_id::text",
            "'production'",
            "'production_batch'",
            "'production_posted'",
        ):
            self.assertIn(token, source)

    def test_same_location_stock_guard_and_deterministic_locking_exist(self) -> None:
        source = self._migration()
        for token in (
            "for update",
            "order by bl.component_stock_item_id",
            "production_stock_insufficient",
            "m.business_id = v_business",
            "iml.location_id = v_batch.location_id",
            "'location_id', v_batch.location_id",
        ):
            self.assertIn(token, source)

    def test_bound_bom_and_post_idempotency_contracts_exist(self) -> None:
        source = self._migration()
        for token in (
            "and b.status = 'active'",
            "for share",
            "production_active_bom_required",
            "production_already_posted_mismatch",
            "v_batch.bom_id",
        ):
            self.assertIn(token, source)

    def test_posted_batch_immutability_and_client_dml_boundary_exist(self) -> None:
        source = self._migration()
        self.assertIn("production_immutable", source)
        self.assertIn("create trigger production_batches_guard_mutation", source)
        self.assertIn("revoke all on table public.production_batches", source)
        self.assertNotIn("grant insert", source)
        self.assertNotIn("grant update", source)
        self.assertNotIn("grant delete", source)

    def test_xp_classifier_is_data_change_and_forbidden_tokens_absent(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8") if MIGRATION.is_file() else ""
        self.assertTrue(source, "P6 production migration must exist")
        self.assertEqual(classify_sql(source), "DATA_CHANGE")
        self.assertIsNone(_DESTRUCTIVE.search(source))
        self.assertIsNone(_NON_TRANSACTIONAL.search(source))

    def test_sql_regression_covers_transactional_production_flow(self) -> None:
        source = self._sql_test()
        self.assertTrue(source.lstrip().startswith("begin;"))
        self.assertTrue(source.rstrip().endswith("rollback;"))
        for token in (
            "public.create_production_batch(",
            "public.post_production_batch(",
            "public.save_bom_draft(",
            "public.activate_bom(",
            "private.record_inventory_movement(",
            "production_already_posted_mismatch",
            "production_stock_insufficient",
            "sj_production_permission_denied",
            "production_immutable",
            "cs06_p6_bound_bom_changed",
            "cs06_p6_duplicate_movement",
            "cs06_p6_shortage_changed_stock",
        ):
            self.assertIn(token, source)


if __name__ == "__main__":
    unittest.main()
