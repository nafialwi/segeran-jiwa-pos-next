from __future__ import annotations

import hashlib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"
SQL_TESTS = ROOT / "supabase" / "tests"
REGISTRY = ROOT / "supabase" / "MIGRATION_REGISTRY.sha256"

CS03_MIGRATION = "20260908013000_cs03_identity_session_permission.sql"

TASK2_SQL_TESTS = {
    "007_cs03_identity_permission.sql",
}
TASK3_SQL_TESTS = {
    "008_cs03_session_authority.sql",
}

TASK2_REQUIRED_SQL = {
    "create table public.user_login_identities",
    "create table public.permission_definitions",
    "create table public.role_permissions",
    "create table public.user_permission_overrides",
    "create table public.trusted_devices",
    "create table public.user_device_access",
    "create table public.session_registry",
}
TASK3_REQUIRED_SQL = {
    "auth.sessions",
    "create or replace function private.is_active_member",
    "private.bootstrap_first_owner",
    "private.current_session_allowed",
    "private.has_permission",
    "public.bootstrap_current_session",
    "public.cs03_admin_bind_staff",
    "public.cs03_admin_get_target_auth_user",
    "public.cs03_admin_record_password_reset",
    "public.cs03_admin_remove_device",
    "public.cs03_admin_rename_device",
    "public.cs03_admin_revoke_device",
    "public.cs03_admin_set_permission_override",
    "public.cs03_admin_set_status",
    "public.get_my_authority",
    "public.owner_list_devices",
    "public.owner_list_users",
    "public.revoke_my_session",
    "revoke execute on function public.cs03_admin_bind_staff",
}
def task3_contract_active() -> bool:
    return (SQL_TESTS / "008_cs03_session_authority.sql").is_file()


def required_sql_tests() -> set[str]:
    names = set(TASK2_SQL_TESTS)
    if task3_contract_active():
        names.update(TASK3_SQL_TESTS)
    return names


def required_sql_tokens() -> set[str]:
    tokens = set(TASK2_REQUIRED_SQL)
    if task3_contract_active():
        tokens.update(TASK3_REQUIRED_SQL)
    return tokens


class Cs03MigrationTests(unittest.TestCase):
    def test_cs03_files_exist(self) -> None:
        self.assertTrue((MIGRATIONS / CS03_MIGRATION).is_file())
        for name in required_sql_tests():
            self.assertTrue((SQL_TESTS / name).is_file(), name)

    def test_cs03_is_forward_only_and_schema_version_two(self) -> None:
        text = (MIGRATIONS / CS03_MIGRATION).read_text("utf-8").lower()
        self.assertIn("insert into private.schema_versions", text)
        self.assertRegex(text, r"\b2\b")
        self.assertIn("'cs-03'", text)

    def test_required_authority_objects_exist(self) -> None:
        text = (MIGRATIONS / CS03_MIGRATION).read_text("utf-8").lower()
        for token in required_sql_tokens():
            self.assertIn(token.lower(), text, token)

    def test_no_client_secret_material(self) -> None:
        text = (MIGRATIONS / CS03_MIGRATION).read_text("utf-8").lower()
        for forbidden in (
            "supabase_secret_key=",
            "supabase_service_role_key=",
            "database_password=",
            "postgres_password=",
            "sb_secret_",
        ):
            self.assertNotIn(forbidden, text)

    def test_sql_tests_are_transactional(self) -> None:
        for name in required_sql_tests():
            text = (SQL_TESTS / name).read_text("utf-8").strip().lower()
            self.assertTrue(text.startswith("begin;"), name)
            self.assertTrue(text.endswith("rollback;"), name)

    def test_migration_registry_contains_exact_cs03_hash(self) -> None:
        migration = MIGRATIONS / CS03_MIGRATION
        digest = hashlib.sha256(migration.read_bytes()).hexdigest()
        registry = REGISTRY.read_text("utf-8")
        self.assertIn(CS03_MIGRATION, registry)
        self.assertIn(digest, registry)

    def test_task3_contract_is_not_silently_weakened(self) -> None:
        self.assertEqual(
            TASK3_SQL_TESTS,
            {"008_cs03_session_authority.sql"},
        )
        self.assertIn("private.current_session_allowed", TASK3_REQUIRED_SQL)
        self.assertIn("public.cs03_admin_remove_device", TASK3_REQUIRED_SQL)

    def test_existing_membership_helper_becomes_session_aware(self) -> None:
        text = (MIGRATIONS / CS03_MIGRATION).read_text("utf-8").lower()
        self.assertIn("auth.sessions", text)
        self.assertIn("private.current_session_allowed", text)
        self.assertIn("create or replace function private.is_active_member", text)

    def test_service_mutation_rpcs_are_not_client_executable(self) -> None:
        text = (MIGRATIONS / CS03_MIGRATION).read_text("utf-8").lower()
        self.assertIn(
            "revoke execute on function public.cs03_admin_bind_staff",
            text,
        )
        self.assertIn("from public, anon, authenticated", text)
        self.assertIn(
            "grant execute on function public.cs03_admin_bind_staff",
            text,
        )
        self.assertIn("to service_role", text)

    def test_task3_edge_dependencies_exist_before_edge_tasks(self) -> None:
        text = (MIGRATIONS / CS03_MIGRATION).read_text("utf-8").lower()
        for token in (
            "public.cs03_admin_rename_device",
            "public.cs03_admin_get_target_auth_user",
            "public.cs03_admin_record_password_reset",
            "public.owner_list_users",
            "public.owner_list_devices",
        ):
            self.assertIn(token, text)

    def test_owner_hard_boundary_is_not_denied_by_user_override(self) -> None:
        text = (MIGRATIONS / CS03_MIGRATION).read_text("utf-8").lower()
        self.assertIn(
            "coalesce((select owner_level from actor limit 1), false)",
            text,
        )


if __name__ == "__main__":
    unittest.main()

# CS-03 Task 10: one-time Owner bootstrap static contract.
import re as _cs03_task10_re
import unittest as _cs03_task10_unittest
from pathlib import Path as _cs03_task10_Path

_CS03_TASK10_ROOT = _cs03_task10_Path(__file__).resolve().parents[1]
_CS03_TASK10_MIGRATION = (
    _CS03_TASK10_ROOT
    / "supabase"
    / "migrations"
    / "20260908013000_cs03_identity_session_permission.sql"
)


class Cs03OwnerBootstrapStaticTests(_cs03_task10_unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sql = _CS03_TASK10_MIGRATION.read_text("utf-8")
        start = cls.sql.index(
            "create or replace function private.bootstrap_first_owner("
        )
        end = cls.sql.index(
            "create or replace function private.assert_cs03_owner_actor(",
            start,
        )
        cls.bootstrap = cls.sql[start:end]

    def test_private_bootstrap_first_owner_exists(self):
        self.assertIn(
            "create or replace function private.bootstrap_first_owner(",
            self.bootstrap,
        )
        self.assertIn("security definer", self.bootstrap)
        self.assertIn("set search_path = ''", self.bootstrap)

    def test_owner_bootstrap_is_one_time(self):
        self.assertIn(
            "SJ_OWNER_ALREADY_BOOTSTRAPPED",
            self.bootstrap,
        )
        self.assertIn(
            "where m.active and r.owner_level",
            self.bootstrap,
        )

    def test_owner_bootstrap_validates_username_and_internal_auth_email(self):
        self.assertIn(
            "private.normalize_username(p_username)",
            self.bootstrap,
        )
        self.assertRegex(
            self.bootstrap,
            _cs03_task10_re.compile(
                r"v_normalized\s*!~\s*'\^\[a-z0-9\]"
                r"\[a-z0-9_-\]\{2,31\}\$'"
            ),
        )
        self.assertIn(
            "v_expected_email := v_normalized || '@auth.segeranjiwa.invalid';",
            self.bootstrap,
        )
        self.assertIn(
            "from auth.users",
            self.bootstrap,
        )
        self.assertIn(
            "v_actual_email is distinct from v_expected_email",
            self.bootstrap,
        )
        self.assertIn(
            "SJ_AUTH_IDENTITY_MISMATCH",
            self.bootstrap,
        )

    def test_owner_bootstrap_execute_is_revoked_from_all_client_roles(self):
        normalized = " ".join(self.sql.split())
        expected = (
            "revoke execute on function "
            "private.bootstrap_first_owner(uuid, text, text) "
            "from public, anon, authenticated, service_role;"
        )
        self.assertIn(expected, normalized)
