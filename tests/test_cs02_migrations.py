from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"
SQL_TESTS = ROOT / "supabase" / "tests"

EXPECTED_MIGRATIONS = [
    "20260906171822_cs02_system_metadata.sql",
    "20260906171939_cs02_identity_and_reference.sql",
    "20260906172647_cs02_idempotency_and_audit.sql",
    "20260906172811_cs02_inventory_authority.sql",
    "20260906172916_cs02_money_authority.sql",
    "20260906173018_cs02_rls_and_grants.sql",
    "20260906173113_cs02_explicit_read_grants.sql",
    "20260906173248_cs02_restrict_auto_rls_helper.sql",
    "20260906173339_cs02_performance_hardening.sql",
    "20260907013121_cs02_correct_schema_source_anchor.sql",
    "20260907193000_cs02_revoke_non_dml_table_privileges.sql",
    "20260908013000_cs03_identity_session_permission.sql",
    "20260908102825_cs03_revoke_private_helper_execute.sql",
    "20260908190000_cs03_bootstrap_uuid_correction.sql",
    "20260910170000_cs04_sales_foundation.sql",
    "20260910190000_cs04_sales_rpc_foundation.sql",
    "20260910200000_cs04_sale_posting_engine.sql",
    "20260912100000_cs05_shift_foundation.sql",
]
EXPECTED_SQL_TESTS = [
    "001_foundation_assertions.sql",
    "002_rls.sql",
    "003_idempotency.sql",
    "004_inventory.sql",
    "005_money.sql",
    "006_immutability.sql",
    "007_cs03_identity_permission.sql",
    "008_cs03_session_authority.sql",
    "009_cs04_sale_posting.sql",
    "010_cs05_shift.sql",
]


class CS02MigrationSourceTests(unittest.TestCase):
    def test_exact_migration_history_is_source_controlled(self) -> None:
        self.assertEqual(
            sorted(path.name for path in MIGRATIONS.glob("*.sql")),
            EXPECTED_MIGRATIONS,
        )

    def test_exact_sql_integration_suite_is_present(self) -> None:
        self.assertEqual(
            sorted(path.name for path in SQL_TESTS.glob("*.sql")),
            EXPECTED_SQL_TESTS,
        )
        for name in EXPECTED_SQL_TESTS:
            source = (SQL_TESTS / name).read_text(encoding="utf-8").lower()
            self.assertTrue(source.lstrip().startswith("begin;"), name)
            self.assertTrue(source.rstrip().endswith("rollback;"), name)

    def test_authority_primitives_are_present(self) -> None:
        source = "\n".join(
            (MIGRATIONS / name).read_text(encoding="utf-8")
            for name in EXPECTED_MIGRATIONS
        )
        required = [
            "private.schema_versions",
            "public.businesses",
            "public.locations",
            "public.stock_items",
            "public.money_accounts",
            "public.operation_receipts",
            "public.audit_events",
            "public.inventory_movements",
            "public.inventory_movement_lines",
            "public.money_movements",
            "public.inventory_balances",
            "public.money_balances",
            "private.lock_operation",
            "private.record_inventory_movement",
            "private.record_money_movement",
            "enable row level security",
            "SJ_IMMUTABLE_FACT",
        ]
        for token in required:
            self.assertIn(token, source)

    def test_deterministic_reference_seeds_are_present(self) -> None:
        source = (MIGRATIONS / EXPECTED_MIGRATIONS[1]).read_text(encoding="utf-8")
        for token in [
            "'SJ'",
            "'GUDANG'",
            "'GERAI'",
            "'KAS_UTAMA'",
            "'BANK'",
            "'QRIS_BELUM_CAIR'",
            "'QRIS_SUDAH_CAIR'",
        ]:
            self.assertIn(token, source)

    def test_fix_forward_source_anchor_correction_is_explicit(self) -> None:
        legacy = "c7bce7498b27ea6bd5f8c1981597f068ca4f6f53"
        canonical = "c7bce7498b27eab6d5f8c1981597f068ca4f6f53"
        first = (MIGRATIONS / EXPECTED_MIGRATIONS[0]).read_text(encoding="utf-8")
        correction = (MIGRATIONS / "20260907013121_cs02_correct_schema_source_anchor.sql").read_text(encoding="utf-8")
        self.assertIn(legacy, first)
        self.assertIn(legacy, correction)
        self.assertIn(canonical, correction)

    def test_no_embedded_secret_assignments(self) -> None:
        secret_assignment = re.compile(
            r"(?im)(service_role|supabase_service_role_key|database_url|password|access_token)\s*=\s*[^\s]"
        )
        for path in [*MIGRATIONS.glob("*.sql"), *SQL_TESTS.glob("*.sql")]:
            source = path.read_text(encoding="utf-8")
            self.assertIsNone(secret_assignment.search(source), path.name)


if __name__ == "__main__":
    unittest.main()
