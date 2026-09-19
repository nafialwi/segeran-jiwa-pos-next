from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase" / "migrations" / "20260919170000_cs06_p8_inventory_controls.sql"
SQL_TEST = ROOT / "supabase" / "tests" / "cs06_p8_inventory_controls_test.sql"

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


def function_body(source: str, signature: str, next_signature: str | None = None) -> str:
    start = source.index(signature)
    end = source.index(next_signature, start + len(signature)) if next_signature else len(source)
    return source[start:end]


class Cs06P8InventoryControlsTests(unittest.TestCase):
    def _migration(self) -> str:
        self.assertTrue(MIGRATION.is_file(), "P8 inventory-controls migration must exist")
        return MIGRATION.read_text(encoding="utf-8").lower()

    def _sql_test(self) -> str:
        self.assertTrue(SQL_TEST.is_file(), "P8 inventory-controls SQL regression must exist")
        return SQL_TEST.read_text(encoding="utf-8").lower()

    def test_stock_count_and_adjustment_authorities_exist(self) -> None:
        source = self._migration()
        for token in (
            "create table if not exists public.inventory_counts",
            "create table if not exists public.inventory_count_lines",
            "create table if not exists public.inventory_adjustments",
            "status in ('draft', 'counted', 'posted')",
            "'inventory_count'",
            "'inventory_adjust'",
        ):
            self.assertIn(token, source)

    def test_migration_is_reentrant_for_db_regression_remediation(self) -> None:
        source = self._migration()
        for token in (
            "create table if not exists public.inventory_counts",
            "create table if not exists public.inventory_count_lines",
            "create table if not exists public.inventory_adjustments",
            "create index if not exists inventory_counts_business_location_status_idx",
            "drop policy if exists \"tenant read isolation for inventory_counts\" on public.inventory_counts",
            "drop trigger if exists inventory_counts_guard_mutation on public.inventory_counts",
        ):
            self.assertIn(token, source)

    def test_count_expected_snapshot_is_server_derived_and_stale_safe(self) -> None:
        source = self._migration()
        create_count = function_body(
            source,
            "create or replace function public.create_inventory_count(",
            "create or replace function public.record_inventory_count(",
        )
        post_count = function_body(
            source,
            "create or replace function public.post_inventory_count(",
            "create or replace function public.post_inventory_adjustment(",
        )
        self.assertIn("expected_quantity", create_count)
        self.assertIn("inventory_movements", create_count)
        self.assertIn("inventory_movement_lines", create_count)
        self.assertIn("order by si.id", create_count)
        self.assertIn("for update of si", create_count)
        self.assertIn("inventory_count_balance_changed", post_count)
        self.assertIn("current_balance.quantity is distinct from l.expected_quantity", post_count)
        self.assertNotIn("expected_quantity", source[source.index("create or replace function public.record_inventory_count("):source.index("create or replace function public.post_inventory_count(")].split("p_lines jsonb", 1)[0])

    def test_all_stock_changes_use_canonical_writer(self) -> None:
        source = self._migration()
        self.assertEqual(source.count("private.record_inventory_movement("), 3)
        count_post = function_body(
            source,
            "create or replace function public.post_inventory_count(",
            "create or replace function public.post_inventory_adjustment(",
        )
        adjust = function_body(
            source,
            "create or replace function public.post_inventory_adjustment(",
            "create or replace function public.reverse_inventory_control(",
        )
        reversal = function_body(
            source,
            "create or replace function public.reverse_inventory_control(",
            "revoke all on function private.guard_inventory_count_mutation",
        )
        self.assertEqual(count_post.count("private.record_inventory_movement("), 1)
        self.assertEqual(adjust.count("private.record_inventory_movement("), 1)
        self.assertEqual(reversal.count("private.record_inventory_movement("), 1)
        self.assertIn("'stock_opname'", count_post)
        self.assertIn("'inventory_adjustment'", adjust)
        self.assertIn("'inventory_write_off'", adjust)
        self.assertIn("'inventory_reversal'", reversal)
        self.assertIn("v_original.id", reversal)
        self.assertIn("reverses_movement_id", source)

    def test_negative_stock_and_writeoff_guards_exist(self) -> None:
        source = self._migration()
        adjust = function_body(
            source,
            "create or replace function public.post_inventory_adjustment(",
            "create or replace function public.reverse_inventory_control(",
        )
        reversal = function_body(
            source,
            "create or replace function public.reverse_inventory_control(",
            "revoke all on function private.guard_inventory_count_mutation",
        )
        for token in (
            "inventory_adjustment_negative_stock",
            "inventory_writeoff_must_be_negative",
            "v_current + p_quantity_delta < 0",
        ):
            self.assertIn(token, adjust)
        self.assertIn("inventory_reversal_negative_stock", reversal)
        self.assertIn("b.current_quantity - b.quantity_delta < 0", reversal)

    def test_permission_location_scope_and_security_boundary_exist(self) -> None:
        source = self._migration()
        for token in (
            "private.has_permission(v_business, 'inventory_count')",
            "private.has_permission(v_business, 'inventory_adjust')",
            "private.has_inventory_location_scope(",
            "private.is_owner(v_business)",
            "inventory_count_scope_denied",
            "inventory_adjust_scope_denied",
        ):
            self.assertIn(token, source)
        self.assertGreaterEqual(source.count("security definer"), 7)
        self.assertGreaterEqual(source.count("set search_path = ''"), 7)
        for table in (
            "public.inventory_counts",
            "public.inventory_count_lines",
            "public.inventory_adjustments",
        ):
            self.assertIn(f"revoke all on table {table}", source)
        self.assertNotIn("grant insert on table", source)
        self.assertNotIn("grant update on table", source)
        self.assertNotIn("grant delete on table", source)

    def test_immutability_and_idempotency_contracts_exist(self) -> None:
        source = self._migration()
        for token in (
            "inventory_count_immutable",
            "create trigger inventory_counts_guard_mutation",
            "create trigger inventory_count_lines_guard_mutation",
            "create trigger inventory_adjustments_immutable",
            "inventory_count_create",
            "inventory_adjustment_create",
            "inventory_control_reverse",
            "inventory_control_already_reversed",
        ):
            self.assertIn(token, source)

    def test_xp_classifier_is_data_change_and_forbidden_tokens_absent(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8") if MIGRATION.is_file() else ""
        self.assertTrue(source, "P8 inventory-controls migration must exist")
        self.assertEqual(classify_sql(source), "DATA_CHANGE")
        self.assertIsNone(_DESTRUCTIVE.search(source))
        self.assertIsNone(_NON_TRANSACTIONAL.search(source))

    def test_sql_regression_covers_operational_controls(self) -> None:
        source = self._sql_test()
        self.assertTrue(source.lstrip().startswith("begin;"))
        self.assertTrue(source.rstrip().endswith("rollback;"))
        for token in (
            "public.create_inventory_count(",
            "public.record_inventory_count(",
            "public.post_inventory_count(",
            "public.post_inventory_adjustment(",
            "public.reverse_inventory_control(",
            "inventory_count_scope_denied",
            "cs06_p8_count_balance_failed",
            "cs06_p8_duplicate_count_movement",
            "inventory_adjustment_negative_stock",
            "cs06_p8_adjust_replay_changed_fact",
            "cs06_p8_reversal_link_missing",
            "inventory_control_already_reversed",
            "inventory_count_balance_changed",
            "inventory_adjust_scope_denied",
        ):
            self.assertIn(token, source)
        self.assertNotIn("update public.inventory_count_lines", source)


if __name__ == "__main__":
    unittest.main()
