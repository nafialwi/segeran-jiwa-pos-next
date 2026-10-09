from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
APP = (ROOT / 'src/App.tsx').read_text(encoding='utf-8')
SHELL = (ROOT / 'src/components/AppShell.tsx').read_text(encoding='utf-8')


class C11F14LazyRouteLoading(unittest.TestCase):
    def test_login_remains_eager_while_major_modules_load_on_navigation(self):
        self.assertIn("import { LoginScreen } from './screens/LoginScreen'", APP)
        self.assertIn('<Route path="/login" element={<LoginScreen />} />', APP)
        for module in (
            'HomeScreen', 'SalesScreen', 'ReportsScreen',
            'TransactionHistoryScreen', 'FinanceScreen', 'ShiftManagementScreen',
            'InventoryScreen', 'InventoryControlScreen',
            'ProductOperationsScreen', 'PurchaseScreen', 'ProductionScreen',
            'ControlCenterScreen',
        ):
            with self.subTest(module=module):
                self.assertRegex(
                    APP,
                    rf"const {module} = lazy\(\(\) =>\s*import\('./screens/{module}'\)",
                )
                self.assertIn(f'<{module} />', APP)

    def test_all_lazy_imports_have_a_correct_named_export(self):
        lazy_definitions = re.findall(
            r"const (\w+Screen) = lazy\(\(\) =>\s*import\('./screens/(\w+Screen)'\)"
            r"\.then\(\(module\) => \(\{\s*default: module\.(\w+Screen)",
            APP,
        )
        self.assertEqual(len(lazy_definitions), 26)
        self.assertTrue(all(a == b == c for a, b, c in lazy_definitions))

    def test_authentication_and_sensitive_route_permissions_remain(self):
        self.assertIn("if (state.kind === 'anonymous')", APP)
        self.assertIn('<Navigate to="/login" replace />', APP)
        self.assertIn('<RequireAccess ownerOnly>', APP)
        for permission in (
            'SALE_EXECUTE', 'SHIFT_OPEN_CLOSE', 'HISTORY_ALL',
            'PURCHASE_MANAGE', 'INVENTORY_ADJUST', 'PRODUCTION_MANAGE',
        ):
            self.assertIn(f"'{permission}'" if permission in ('HISTORY_ALL', 'INVENTORY_ADJUST') else f'"{permission}"', APP)
        self.assertIn('path="/pengguna"', APP)
        self.assertIn('path="/keuangan"', APP)

    def test_late_page_load_retains_app_shell_and_accessible_feedback(self):
        self.assertIn('import { Suspense, useEffect }', SHELL)
        self.assertIn('className="app-route-content"', SHELL)
        self.assertRegex(SHELL, r'<Suspense\s+fallback=')
        self.assertIn('role="status"', SHELL)
        self.assertIn('<Outlet />', SHELL)
        self.assertIn('aria-label="Navigasi utama"', SHELL)
        self.assertRegex(APP, r'<Suspense\s+fallback=')


if __name__ == '__main__':
    unittest.main()
