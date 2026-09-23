from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260923133000_c11f0b_operational_message.sql"
API = ROOT / "src/operations/operational-message-api.ts"
SCREEN = ROOT / "src/screens/OperationalMessageScreen.tsx"
HOME = ROOT / "src/screens/HomeScreen.tsx"
APP = ROOT / "src/App.tsx"
MENU = ROOT / "src/screens/MenuScreen.tsx"
USERS = ROOT / "src/screens/OwnerUsersScreen.tsx"
AUTH = ROOT / "src/auth/types.ts"
CSS = ROOT / "src/app.css"


class C11F0BOperationalMessageTests(unittest.TestCase):
    def test_permission_and_route_are_real_but_permission_bounded(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn(
            "('OPERATIONAL_MESSAGE_MANAGE', 'Kelola Pesan Operasional', 'OPERASIONAL', true)",
            sql,
        )
        self.assertIn("'OPERATIONAL_MESSAGE_MANAGE'", AUTH.read_text(encoding="utf-8"))
        self.assertIn('path="/pesan-operasional"', APP.read_text(encoding="utf-8"))
        self.assertIn('permission="OPERATIONAL_MESSAGE_MANAGE"', APP.read_text(encoding="utf-8"))
        self.assertIn("Pesan Operasional", MENU.read_text(encoding="utf-8"))
        self.assertIn("Kelola Pesan Operasional", USERS.read_text(encoding="utf-8"))

    def test_tables_are_rls_enabled_and_have_no_direct_client_grants(self):
        sql = MIGRATION.read_text(encoding="utf-8").lower()
        self.assertIn("create table public.operational_messages", sql)
        self.assertIn("create table public.operational_message_reads", sql)
        self.assertIn("alter table public.operational_messages enable row level security", sql)
        self.assertIn("alter table public.operational_message_reads enable row level security", sql)
        self.assertIn("revoke all on table public.operational_messages", sql)
        self.assertIn("revoke all on table public.operational_message_reads", sql)
        self.assertNotIn("grant select on table public.operational_messages", sql)
        self.assertNotIn("grant insert on table public.operational_messages", sql)

    def test_management_mutations_are_permission_idempotency_and_audit_bounded(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertGreaterEqual(
            sql.count("private.has_permission(v_business, 'OPERATIONAL_MESSAGE_MANAGE')"),
            4,
        )
        self.assertIn("private.lock_operation(", sql)
        self.assertIn("'OPERATIONAL_MESSAGE_CREATE'", sql)
        self.assertIn("'OPERATIONAL_MESSAGE_CANCEL'", sql)
        self.assertIn("private.record_operation_success(", sql)
        self.assertIn("'OPERATIONAL_MESSAGE_CREATED'", sql)
        self.assertIn("'OPERATIONAL_MESSAGE_CANCELLED'", sql)
        self.assertIn("set search_path = ''", sql)
        self.assertIn("to authenticated;", sql)

    def test_message_shape_is_narrow_not_general_chat(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("target_kind in ('ALL_CASHIERS','PROFILE')", sql)
        self.assertIn("priority in ('NORMAL','HIGH')", sql)
        self.assertIn("valid_until > valid_from", sql)
        self.assertIn("interval '30 days'", sql)
        self.assertNotIn("conversation_id", sql)
        self.assertNotIn("thread_id", sql)
        self.assertNotIn("reply_to", sql)

    def test_cashier_inbox_is_target_and_time_bounded(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        start = sql.index("create or replace function public.my_operational_messages")
        end = sql.index("create or replace function public.mark_operational_message_read", start)
        body = sql[start:end]
        self.assertIn("m.cancelled_at is null", body)
        self.assertIn("now() >= m.valid_from", body)
        self.assertIn("now() < m.valid_until", body)
        self.assertIn("m.target_kind='ALL_CASHIERS' and v_role='KASIR'", body)
        self.assertIn("m.target_kind='PROFILE' and m.target_profile_id=v_actor", body)

    def test_read_ack_is_server_validated_and_audited(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("create or replace function public.mark_operational_message_read", sql)
        self.assertIn("on conflict (message_id, profile_id) do nothing", sql)
        self.assertIn("'OPERATIONAL_MESSAGE_READ'", sql)

    def test_frontend_uses_rpc_only_and_fails_closed_on_old_backend(self):
        api = API.read_text(encoding="utf-8")
        self.assertIn("fetchOperationalMessageCapability", api)
        self.assertIn("PGRST202", api)
        self.assertIn("could not find the function", api)
        self.assertIn("return false", api)
        self.assertNotIn("text.includes('operational_message_')", api)
        self.assertIn("supabase.rpc('create_operational_message'", api)
        self.assertIn("supabase.rpc('mark_operational_message_read'", api)
        self.assertIn("requireOnlineAction('Kirim Pesan Operasional')", api)
        self.assertNotIn(".from('operational_messages')", api)

    def test_cashier_dashboard_replaces_placeholder_with_real_inbox(self):
        home = HOME.read_text(encoding="utf-8")
        self.assertIn("CashierOperationalMessages", home)
        self.assertIn("fetchMyOperationalMessages(3)", home)
        self.assertIn("markOperationalMessageRead", home)
        self.assertIn("Sudah Dibaca", home)
        self.assertNotIn("Belum ada kanal pesan operasional yang aktif.", home)

    def test_management_ui_has_target_priority_validity_and_read_progress(self):
        screen = SCREEN.read_text(encoding="utf-8")
        for token in (
            "Prioritas",
            "Semua kasir",
            "Kasir tertentu",
            "Mulai berlaku",
            "Berlaku sampai",
            "Dibaca",
            "Batalkan",
            "SearchablePicker",
        ):
            self.assertIn(token, screen)

    def test_mobile_visuals_are_present(self):
        css = CSS.read_text(encoding="utf-8")
        self.assertIn("/* C11-F0B — Operational Message */", css)
        self.assertIn(".operational-message-card", css)
        self.assertIn(".dashboard-cashier-messages", css)
        self.assertIn("@media (max-width: 520px)", css)


if __name__ == "__main__":
    unittest.main()
