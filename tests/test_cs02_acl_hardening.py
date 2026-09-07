from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = (
    ROOT
    / "supabase"
    / "migrations"
    / "20260907193000_cs02_revoke_non_dml_table_privileges.sql"
)


def normalized_sql() -> str:
    text = MIGRATION.read_text(encoding="utf-8").lower()
    return re.sub(r"\s+", " ", text).strip()


class Cs02AclHardeningTests(unittest.TestCase):
    def test_forward_acl_hardening_migration_exists(self) -> None:
        self.assertTrue(
            MIGRATION.exists(),
            "ACL hardening migration is missing",
        )

    def test_existing_client_non_dml_privileges_are_revoked(self) -> None:
        sql = normalized_sql()
        self.assertIn(
            "revoke truncate, references, trigger, maintain "
            "on all tables in schema public from anon, authenticated;",
            sql,
        )

    def test_future_postgres_created_tables_are_fail_closed(self) -> None:
        sql = normalized_sql()
        self.assertIn(
            "alter default privileges for role postgres in schema public "
            "revoke truncate, references, trigger, maintain "
            "on tables from anon, authenticated;",
            sql,
        )

    def test_trigger_helper_is_not_client_callable(self) -> None:
        sql = normalized_sql()
        self.assertIn(
            "revoke execute on function private.prevent_fact_mutation() "
            "from public, anon, authenticated;",
            sql,
        )

    def test_correction_does_not_grant_client_write_or_maintenance_privileges(self) -> None:
        sql = normalized_sql()
        forbidden = [
            "grant insert",
            "grant update",
            "grant delete",
            "grant truncate",
            "grant references",
            "grant trigger",
            "grant maintain",
        ]
        for token in forbidden:
            self.assertNotIn(token, sql)

    def test_source_anchor_regression_targets_named_migration(self) -> None:
        source = (ROOT / "tests" / "test_cs02_migrations.py").read_text(encoding="utf-8")
        match = re.search(
            r"(?ms)^\s*def test_fix_forward_source_anchor_correction_is_explicit"
            r"\s*\(self\).*?(?=^\s*def |\Z)",
            source,
        )
        self.assertIsNotNone(match)
        block = match.group(0)
        self.assertIn(
            "20260907013121_cs02_correct_schema_source_anchor.sql",
            block,
        )
        self.assertNotIn("EXPECTED_MIGRATIONS[-1]", block)


if __name__ == "__main__":
    unittest.main()
