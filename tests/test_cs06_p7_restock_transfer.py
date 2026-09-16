from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase" / "migrations" / "20260916143000_cs06_p7_restock_transfer.sql"
SQL_TEST = ROOT / "supabase" / "tests" / "cs06_p7_restock_transfer_test.sql"

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


class Cs06P7RestockTransferTests(unittest.TestCase):
    def _migration(self) -> str:
        self.assertTrue(MIGRATION.is_file(), "P7 restock/transfer migration must exist")
        return MIGRATION.read_text(encoding="utf-8").lower()

    def _sql_test(self) -> str:
        self.assertTrue(SQL_TEST.is_file(), "P7 restock/transfer SQL regression must exist")
        return SQL_TEST.read_text(encoding="utf-8").lower()

    def test_five_authority_tables_and_state_machines_exist(self) -> None:
        source = self._migration()
        for token in (
            "create table public.restock_requests",
            "create table public.restock_request_lines",
            "create table public.stock_transfers",
            "create table public.stock_transfer_lines",
            "create table public.inventory_location_scopes",
            "status in ('draft', 'submitted', 'approved', 'rejected')",
            "status in ('draft', 'shipped', 'received')",
        ):
            self.assertIn(token, source)

    def test_permission_reuse_and_location_scope_management_exist(self) -> None:
        source = self._migration()
        self.assertIn("'inventory_request'", source)
        self.assertIn("'inventory_transfer'", source)
        self.assertIn("public.set_inventory_location_scope(", source)
        self.assertIn("active boolean not null default true", source)
        self.assertIn("private.is_owner(v_business)", source)
        self.assertIn("on conflict (business_id, profile_id, location_id) do update", source)
        self.assertNotIn("inventory_transfer_approve", source)
        self.assertNotIn("inventory_receive", source)

    def test_request_rpcs_never_write_inventory(self) -> None:
        source = self._migration()
        request_section = function_body(source, "create or replace function public.save_restock_request(", "create or replace function public.create_stock_transfer(")
        self.assertNotIn("record_inventory_movement", request_section)
        for token in (
            "public.save_restock_request(",
            "public.submit_restock_request(",
            "public.approve_restock_request(",
            "public.reject_restock_request(",
        ):
            self.assertIn(token, request_section)

    def test_transfer_posting_uses_exactly_two_canonical_writer_calls(self) -> None:
        source = self._migration()
        self.assertEqual(source.count("private.record_inventory_movement("), 2)
        ship = function_body(source, "create or replace function public.ship_stock_transfer(", "create or replace function public.receive_stock_transfer(")
        receive = function_body(source, "create or replace function public.receive_stock_transfer(", "revoke all on function")
        self.assertEqual(ship.count("private.record_inventory_movement("), 1)
        self.assertEqual(receive.count("private.record_inventory_movement("), 1)
        for token in ("'transfer_ship:' || p_transfer_id::text", "'transfer_out'", "'transfer_shipped'"):
            self.assertIn(token, ship)
        for token in ("'transfer_receive:' || p_transfer_id::text", "'transfer_in'", "'transfer_received'"):
            self.assertIn(token, receive)

    def test_stock_guard_scope_and_deterministic_locking_exist(self) -> None:
        source = self._migration()
        for token in (
            "transfer_stock_insufficient",
            "order by stl.stock_item_id",
            "for update of si",
            "iml.location_id = v_transfer.source_location_id",
            "private.has_inventory_location_scope(",
            "transfer_scope_denied",
            "restock_scope_denied",
        ):
            self.assertIn(token, source)

    def test_immutability_and_no_partial_contracts_exist(self) -> None:
        source = self._migration()
        for token in (
            "restock_immutable",
            "transfer_immutable",
            "create trigger restock_requests_guard_mutation",
            "create trigger restock_request_lines_guard_mutation",
            "create trigger stock_transfers_guard_mutation",
            "create trigger stock_transfer_lines_guard_mutation",
        ):
            self.assertIn(token, source)
        for forbidden in ("shipped_quantity", "received_quantity", "partial_shipment", "partial_receipt"):
            self.assertNotIn(forbidden, source)

    def test_security_definer_rls_and_client_dml_boundary_exist(self) -> None:
        source = self._migration()
        self.assertGreaterEqual(source.count("security definer"), 13)
        self.assertGreaterEqual(source.count("set search_path = ''"), 13)
        for table in (
            "public.restock_requests",
            "public.restock_request_lines",
            "public.stock_transfers",
            "public.stock_transfer_lines",
            "public.inventory_location_scopes",
        ):
            self.assertIn(f"revoke all on table {table}", source)
        self.assertNotIn("grant insert on table", source)
        self.assertNotIn("grant update on table", source)
        self.assertNotIn("grant delete on table", source)

    def test_xp_classifier_is_data_change_and_forbidden_tokens_absent(self) -> None:
        source = MIGRATION.read_text(encoding="utf-8") if MIGRATION.is_file() else ""
        self.assertTrue(source, "P7 restock/transfer migration must exist")
        self.assertEqual(classify_sql(source), "DATA_CHANGE")
        self.assertIsNone(_DESTRUCTIVE.search(source))
        self.assertIsNone(_NON_TRANSACTIONAL.search(source))

    def test_sql_regression_covers_scope_request_transfer_and_atomicity(self) -> None:
        source = self._sql_test()
        self.assertTrue(source.lstrip().startswith("begin;"))
        self.assertTrue(source.rstrip().endswith("rollback;"))
        for token in (
            "public.set_inventory_location_scope(",
            "public.save_restock_request(",
            "public.submit_restock_request(",
            "public.approve_restock_request(",
            "public.reject_restock_request(",
            "public.create_stock_transfer(",
            "public.ship_stock_transfer(",
            "public.receive_stock_transfer(",
            "restock_permission_denied",
            "transfer_permission_denied",
            "transfer_scope_denied",
            "transfer_same_location",
            "transfer_stock_insufficient",
            "cs06_p7_duplicate_transfer",
            "cs06_p7_ship_changed_destination",
            "cs06_p7_duplicate_outbound",
            "cs06_p7_duplicate_inbound",
            "cs06_p7_shortage_changed_stock",
            "cs06_p7_scope_revoke_not_enforced",
            "restock_immutable",
            "transfer_immutable",
        ):
            self.assertIn(token, source)


if __name__ == "__main__":
    unittest.main()
