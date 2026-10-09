from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
BOUNDARY = (ROOT / "src/components/RouteErrorBoundary.tsx").read_text(encoding="utf-8")
SHELL = (ROOT / "src/components/AppShell.tsx").read_text(encoding="utf-8")
CSS = (ROOT / "src/app.css").read_text(encoding="utf-8")
HARNESS = (ROOT / "tests/browser-harness/f15-route-error.tsx").read_text(encoding="utf-8")


class RouteFailureRecoveryTests(unittest.TestCase):
    def test_route_exception_renders_safe_recovery_actions(self):
        self.assertIn("class RouteErrorBoundary extends Component", BOUNDARY)
        self.assertIn("getDerivedStateFromError()", BOUNDARY)
        self.assertIn('role="alert"', BOUNDARY)
        self.assertIn("Halaman belum dapat dibuka", BOUNDARY)
        self.assertIn("window.location.reload()", BOUNDARY)
        self.assertIn('to="/"', BOUNDARY)
        self.assertIn("Kembali ke Beranda", BOUNDARY)

    def test_route_change_resets_boundary_and_keeps_navigation(self):
        self.assertIn("RouteErrorBoundary key={location.pathname}", SHELL)
        self.assertIn("<Suspense", SHELL)
        self.assertIn("<Outlet />", SHELL)
        self.assertIn('className="app-mobile-header"', SHELL)
        self.assertIn('className="app-bottom-nav"', SHELL)
        self.assertIn('aria-label="Navigasi utama"', SHELL)

    def test_test_harness_is_isolated_and_simulates_rejected_module(self):
        self.assertIn("SIMULATED_ROUTE_CHUNK_FAILED", HARNESS)
        self.assertIn("Promise.reject", HARNESS)
        self.assertIn("RouteErrorBoundary key={location.pathname}", HARNESS)
        self.assertNotIn("supabase", HARNESS.lower())
        self.assertNotIn("checkout", HARNESS.lower())

    def test_mobile_recovery_actions_remain_touch_accessible(self):
        self.assertIn("/* C11-F15 — clear recovery controls", CSS)
        self.assertIn(".route-load-error .button-row > *", CSS)
        self.assertIn("flex: 1 1 100%", CSS)


if __name__ == "__main__":
    unittest.main()
