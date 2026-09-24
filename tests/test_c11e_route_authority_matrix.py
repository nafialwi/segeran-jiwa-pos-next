from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "src/App.tsx"
MENU = ROOT / "src/screens/MenuScreen.tsx"
PERMISSION = ROOT / "src/auth/permission.ts"


class C11ERouteAuthorityMatrixTests(unittest.TestCase):
    def test_owner_only_routes_match_router_menu_and_projection_helper(self):
        app = APP.read_text(encoding="utf-8")
        menu = MENU.read_text(encoding="utf-8")
        permission = PERMISSION.read_text(encoding="utf-8")

        for route in (
            "/pengguna",
            "/keuangan",
            "/pengaturan/backup",
            "/expense-approval",
            "/legacy-import",
        ):
            self.assertIn(f'path="{route}"', app)
            self.assertIn(f"route === '{route}'", permission)

        self.assertGreaterEqual(app.count("<RequireAccess ownerOnly>"), 5)
        self.assertIn("canAccessOwnerArea(authority)", menu)
        self.assertIn("to: '/pengguna'", menu)
        self.assertIn("to: '/keuangan'", menu)
        self.assertIn("to: '/expense-approval'", menu)
        self.assertIn("to: '/legacy-import'", menu)

    def test_daily_permission_routes_match_router_and_menu(self):
        app = APP.read_text(encoding="utf-8")
        menu = MENU.read_text(encoding="utf-8")

        pairs = (
            ("/jual", "SALE_EXECUTE"),
            ("/shift", "SHIFT_OPEN_CLOSE"),
            ("/handover", "SHIFT_OPEN_CLOSE"),
            ("/shift-history", "SHIFT_READ_OWN"),
            ("/rekonsiliasi", "SHIFT_READ_OWN"),
            ("/pembelian", "PURCHASE_MANAGE"),
            ("/produksi", "PRODUCTION_MANAGE"),
            ("/pesan-operasional", "OPERATIONAL_MESSAGE_MANAGE"),
        )
        for route, permission in pairs:
            self.assertIn(f'path="{route}"', app)
            self.assertIn(f'permission="{permission}"', app)
            self.assertIn(f"hasPermission(authority, '{permission}')", menu)


if __name__ == "__main__":
    unittest.main()
