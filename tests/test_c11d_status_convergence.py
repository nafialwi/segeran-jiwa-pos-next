from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
STATUS = ROOT / "src/ui/status-display.ts"
CSS = ROOT / "src/app.css"
SCREENS = [
    ROOT / "src/screens/ProductionScreen.tsx",
    ROOT / "src/screens/PurchaseScreen.tsx",
    ROOT / "src/screens/InventoryControlScreen.tsx",
    ROOT / "src/screens/FinanceScreen.tsx",
]


class C11DStatusConvergenceTests(unittest.TestCase):
    def test_shared_status_presenter_keeps_backend_enum_separate(self):
        source = STATUS.read_text(encoding="utf-8")
        self.assertIn("export function statusLabel", source)
        self.assertIn("export function statusToneClass", source)
        self.assertIn("DRAFT: 'Draf'", source)
        self.assertIn("POSTED: 'Diposting'", source)
        self.assertIn("REJECTED: 'Ditolak'", source)

    def test_daily_operational_screens_use_shared_presenter(self):
        for path in SCREENS:
            source = path.read_text(encoding="utf-8")
            self.assertIn("statusLabel", source, path.name)
            self.assertIn("operationalStatusClass", source, path.name)

    def test_status_tones_are_responsive_and_distinct(self):
        css = CSS.read_text(encoding="utf-8")
        self.assertIn(
            "/* C11-D3 — status language and tone convergence */",
            css,
        )
        self.assertIn(".operations-status.danger", css)
        self.assertIn(".operations-status.warning", css)
        self.assertIn(".operations-status.neutral", css)
        self.assertIn("white-space: normal;", css)


if __name__ == "__main__":
    unittest.main()
