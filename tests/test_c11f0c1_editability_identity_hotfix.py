from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
HTTP = ROOT / "supabase/functions/_shared/http.ts"
IDENTITY = ROOT / "supabase/functions/identity-admin/index.ts"
DEVICE = ROOT / "supabase/functions/device-admin/index.ts"
CONFIG = ROOT / "supabase/config.toml"
USERS = ROOT / "src/screens/OwnerUsersScreen.tsx"
PRODUCT_MIGRATION = ROOT / "supabase/migrations/20260923120000_c11f0a_product_master_editor.sql"


class C11F0C1EditabilityIdentityHotfixTests(unittest.TestCase):
    def test_edge_functions_are_browser_preflight_safe(self):
        http = HTTP.read_text(encoding="utf-8")
        self.assertIn("export const CORS_HEADERS", http)
        self.assertIn("'access-control-allow-origin': '*'", http)
        self.assertIn("authorization, x-client-info, apikey, content-type", http)
        for path in (IDENTITY, DEVICE):
            source = path.read_text(encoding="utf-8")
            self.assertIn("req.method === 'OPTIONS'", source)
            self.assertIn("CORS_HEADERS", source)

    def test_gateway_verification_is_disabled_only_because_internal_auth_is_explicit(self):
        config = CONFIG.read_text(encoding="utf-8")
        self.assertIn("[functions.identity-admin]", config)
        self.assertIn("[functions.device-admin]", config)
        self.assertGreaterEqual(config.count("verify_jwt = false"), 2)
        for path in (IDENTITY, DEVICE):
            source = path.read_text(encoding="utf-8")
            self.assertIn("requireOwnerContext(req)", source)
        auth_context = (ROOT / "supabase/functions/_shared/auth-context.ts").read_text(encoding="utf-8")
        self.assertIn("userClient.auth.getUser(token)", auth_context)
        self.assertIn("authority.owner !== true", auth_context)

    def test_owner_users_shows_safe_human_error_not_raw_transport_code(self):
        source = USERS.read_text(encoding="utf-8")
        self.assertIn("edgeFunctionErrorMessage", source)
        self.assertIn("Administrasi pengguna tidak dapat diproses. Periksa koneksi lalu coba lagi.", source)
        self.assertIn("Administrasi perangkat tidak dapat diproses. Periksa koneksi lalu coba lagi.", source)
        self.assertNotIn("throw new Error('SJ_IDENTITY_ADMIN_FAILED')", source)
        self.assertNotIn("throw new Error('SJ_DEVICE_ADMIN_FAILED')", source)

    def test_product_variant_editor_rebuilds_system_finished_good_component(self):
        sql = PRODUCT_MIGRATION.read_text(encoding="utf-8")
        self.assertIn("if v_mode in ('DIRECT_STOCK','PREPRODUCED') then", sql)
        self.assertIn("'FINISHED_GOOD'", sql)
        self.assertIn("p_sale_stock_item_id", sql)
        self.assertIn("1.000", sql)
        self.assertIn("delete from public.variant_sale_components", sql)


if __name__ == "__main__":
    unittest.main()
