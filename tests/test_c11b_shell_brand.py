from pathlib import Path
import hashlib
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]
APP_SHELL = ROOT / "src/components/AppShell.tsx"
LOGIN = ROOT / "src/screens/LoginScreen.tsx"
HOME = ROOT / "src/screens/HomeScreen.tsx"
MENU = ROOT / "src/screens/MenuScreen.tsx"
CSS = ROOT / "src/app.css"
ASSET = ROOT / "public/brand/segeran-jiwa-logo.png"
MANIFEST = ROOT / "public/brand/manifest.json"


class C11BShellBrandTests(unittest.TestCase):
    def test_user_supplied_brand_asset_is_locked(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["dimensions"], [1254, 1254])
        digest = hashlib.sha256(ASSET.read_bytes()).hexdigest()
        self.assertEqual(digest, manifest["repo_sha256"])

    def test_app_shell_uses_real_brand_asset_not_placeholder_initials(self):
        src = APP_SHELL.read_text(encoding="utf-8")
        self.assertIn('/brand/segeran-jiwa-logo.png', src)
        self.assertIn('app-brand-logo', src)
        self.assertNotIn('>\n        SJ\n      </span>', src)

    def test_login_uses_the_same_canonical_brand_asset(self):
        src = LOGIN.read_text(encoding="utf-8")
        self.assertIn('/brand/segeran-jiwa-logo.png', src)
        self.assertIn('auth-brand-logo', src)

    def test_dashboard_uses_semantic_locked_icons_without_data_changes(self):
        src = HOME.read_text(encoding="utf-8")
        for token in ('icon="sales"', 'icon="receipt"', 'icon="cash"', 'icon="qris"'):
            self.assertIn(token, src)
        self.assertIn('dashboard-hero-brand', src)
        self.assertNotIn('fetchOwnerDashboard(', src.split('function OwnerDashboard', 1)[0])

    def test_menu_keeps_authority_checks_and_uses_semantic_icons(self):
        src = MENU.read_text(encoding="utf-8")
        for permission in ('SALE_EXECUTE', 'SHIFT_OPEN_CLOSE', 'INVENTORY_READ', 'PURCHASE_MANAGE'):
            self.assertIn(permission, src)
        for icon in ("'inventory'", "'restock'", "'reports'", "'cash'", "'check'"):
            self.assertIn(icon, src)

    def test_c11b_css_is_mobile_first_and_brand_integrated(self):
        css = CSS.read_text(encoding="utf-8")
        self.assertIn("/* C11-B — Shell, brand, dashboard & menu convergence */", css)
        self.assertIn(".app-brand-logo-frame", css)
        self.assertIn(".dashboard-hero-brand", css)
        self.assertIn("@media (max-width: 520px)", css)


if __name__ == "__main__":
    unittest.main()
