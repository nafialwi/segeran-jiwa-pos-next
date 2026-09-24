from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
COMPONENT = ROOT / "src/components/OperationalState.tsx"
CSS = ROOT / "src/app.css"
SHIFT_HISTORY = ROOT / "src/screens/ShiftHistoryScreen.tsx"
RECON = ROOT / "src/screens/ReconciliationScreen.tsx"
INVENTORY = ROOT / "src/screens/InventoryScreen.tsx"
INVENTORY_ITEM = ROOT / "src/screens/InventoryItemScreen.tsx"
PRODUCTION = ROOT / "src/screens/ProductionScreen.tsx"
PURCHASE = ROOT / "src/screens/PurchaseScreen.tsx"


class C11DOperationalStateTests(unittest.TestCase):
    def test_shared_state_component_has_accessible_semantics(self):
        source = COMPONENT.read_text(encoding="utf-8")
        self.assertIn("kind: 'loading' | 'empty' | 'error'", source)
        self.assertIn('role="status"', source)
        self.assertIn('aria-live="polite"', source)
        self.assertIn('role="alert"', source)
        self.assertIn("operations-card-skeleton", source)
        self.assertIn("empty-state", source)

    def test_daily_operational_screens_use_shared_state_component(self):
        for path in (SHIFT_HISTORY, RECON, INVENTORY, INVENTORY_ITEM):
            source = path.read_text(encoding="utf-8")
            self.assertIn("OperationalState", source, path.name)
        self.assertNotIn("<p>Memuat…</p>", SHIFT_HISTORY.read_text(encoding="utf-8"))
        self.assertNotIn(
            "<p>Memuat riwayat shift…</p>",
            RECON.read_text(encoding="utf-8"),
        )

    def test_feedback_banners_expose_status_and_alert_roles(self):
        production = PRODUCTION.read_text(encoding="utf-8")
        purchase = PURCHASE.read_text(encoding="utf-8")
        for source in (production, purchase):
            self.assertIn('className="error-banner" role="alert"', source)
            self.assertIn(
                'className="success-banner" role="status" aria-live="polite"',
                source,
            )

    def test_state_geometry_is_mobile_aware(self):
        css = CSS.read_text(encoding="utf-8")
        self.assertIn(
            "/* C11-D1 — shared operational state convergence */",
            css,
        )
        self.assertIn(".operational-state-loading", css)
        self.assertIn(".operational-state-empty", css)
        self.assertIn("@media (max-width: 420px)", css)


if __name__ == "__main__":
    unittest.main()
