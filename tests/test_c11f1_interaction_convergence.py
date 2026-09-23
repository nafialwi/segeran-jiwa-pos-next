from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
CSS = ROOT / "src/app.css"
SHELL = ROOT / "src/components/AppShell.tsx"
REPORTS = ROOT / "src/screens/ReportsScreen.tsx"
HISTORY = ROOT / "src/screens/TransactionHistoryScreen.tsx"
PRODUCT = ROOT / "src/screens/ProductOperationsScreen.tsx"
INVENTORY = ROOT / "src/screens/InventoryControlScreen.tsx"
USERS = ROOT / "src/screens/OwnerUsersScreen.tsx"


class C11F1InteractionConvergenceTests(unittest.TestCase):
    def test_global_press_feedback_is_immediate_and_touch_safe(self):
        css = CSS.read_text(encoding="utf-8")
        self.assertIn("touch-action: manipulation", css)
        self.assertIn("button:not(:disabled):active", css)
        self.assertIn("translateY(1px) scale(0.985)", css)
        self.assertIn("@media (prefers-reduced-motion: reduce)", css)
    def test_primary_route_change_returns_to_visible_start(self):
        source = SHELL.read_text(encoding="utf-8")
        self.assertIn("window.requestAnimationFrame", source)
        self.assertIn("window.scrollTo({ top: 0, left: 0, behavior: 'auto' });", source)
        self.assertIn("[location.pathname]", source)

    def test_reports_reveal_generated_result(self):
        source = REPORTS.read_text(encoding="utf-8")
        self.assertIn("const resultRef = useRef<HTMLElement | null>(null);", source)
        self.assertIn("resultRef.current?.scrollIntoView", source)
        self.assertIn("ref={resultRef}", source)
        self.assertIn('aria-live="polite"', source)

    def test_history_refund_and_correction_reveal_their_work_surface(self):
        source = HISTORY.read_text(encoding="utf-8")
        self.assertIn("refundPanelRef.current", source)
        self.assertIn("correctionPanelRef.current", source)
        self.assertGreaterEqual(source.count("scrollIntoView({ block: 'start', behavior: 'smooth' })"), 2)
        self.assertGreaterEqual(source.count("focus({ preventScroll: true })"), 2)
    def test_mobile_master_detail_selections_reveal_the_detail(self):
        product = PRODUCT.read_text(encoding="utf-8")
        inventory = INVENTORY.read_text(encoding="utf-8")
        users = USERS.read_text(encoding="utf-8")
        self.assertIn("function selectProduct(productId: string)", product)
        self.assertIn("detailRef.current?.scrollIntoView", product)
        self.assertIn("countWorkspaceRef.current?.scrollIntoView", inventory)
        self.assertIn("userDetailAnchorRef.current?.scrollIntoView", users)
        self.assertIn("window.matchMedia('(max-width: 720px)').matches", product)
        self.assertIn("window.matchMedia('(max-width: 759px)').matches", inventory)
        self.assertIn("window.matchMedia('(max-width: 759px)').matches", users)

    def test_contextual_feedback_has_machine_readable_status(self):
        for path in (REPORTS, HISTORY, PRODUCT, INVENTORY):
            source = path.read_text(encoding="utf-8")
            self.assertIn('role="alert"', source)
        for path in (HISTORY, PRODUCT, INVENTORY):
            source = path.read_text(encoding="utf-8")
            self.assertIn('role="status"', source)


if __name__ == "__main__":
    unittest.main()
