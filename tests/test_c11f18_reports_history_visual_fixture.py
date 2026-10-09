from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests/browser-harness/f18"
CONFIG = (FIXTURE / "vite.config.mjs").read_text(encoding="utf-8")
ENTRY = (FIXTURE / "main.tsx").read_text(encoding="utf-8")
REPORTS = (FIXTURE / "stub-reports.ts").read_text(encoding="utf-8")
HISTORY = (FIXTURE / "stub-history.ts").read_text(encoding="utf-8")
EXPORT = (FIXTURE / "stub-export.ts").read_text(encoding="utf-8")
BROWSER = (FIXTURE / "verify-browser.py").read_text(encoding="utf-8")
CSS = (ROOT / "src/app.css").read_text(encoding="utf-8")


class F18VisualFixtureTests(unittest.TestCase):
    def test_fixture_is_not_in_production_bundle_entry(self):
        self.assertNotIn("browser-harness", (ROOT / "vite.config.ts").read_text())
        self.assertNotIn("browser-harness", (ROOT / "src/main.tsx").read_text())
        self.assertIn("f18-browser-fixture-only", CONFIG)
        self.assertIn("host: '127.0.0.1'", CONFIG)
        self.assertIn("strictPort: true", CONFIG)

    def test_real_screens_with_obvious_fixture_notice(self):
        self.assertIn("src/screens/ReportsScreen", ENTRY)
        self.assertIn("src/screens/TransactionHistoryScreen", ENTRY)
        self.assertIn("src/components/AppShell", ENTRY)
        self.assertIn("KHUSUS UJI UI", ENTRY)
        self.assertIn("TANPA DATABASE", ENTRY)

    def test_stubbed_reports_history_and_export_disable_writes(self):
        self.assertIn("async function runReport", REPORTS)
        self.assertIn("CONTOH-", REPORTS)
        self.assertIn("async function searchTransactionHistory", HISTORY)
        self.assertIn("CONTOH-", HISTORY)
        self.assertIn("async function refundSale", HISTORY)
        self.assertIn("async function correctSale", HISTORY)
        self.assertIn("async function previewSaleCorrection", HISTORY)
        self.assertGreaterEqual(HISTORY.count("throw new Error("), 3)
        self.assertIn("throw new Error", EXPORT)
        for src in (HISTORY, REPORTS, EXPORT):
            self.assertNotIn("supabase", src.lower())
            self.assertNotIn("fetch(", src)

    def test_browser_verifies_responsive_and_workflows(self):
        for value in ("320,740", "390,844", "412,915", "768,1024", "1280,800"):
            self.assertIn(value, BROWSER)
        for value in ("BROWSER_F18_PASS", "report-summary-card", "report-section-switcher",
                      "history-pagination", "Cari Riwayat", "history-advanced-grid"):
            self.assertIn(value, BROWSER)
        self.assertIn("getComputedStyle", BROWSER)

    def test_scrollbar_refinement_keeps_keyboard_focus(self):
        self.assertIn("/* C11-F18 — horizontal controls", CSS)
        for cls in (".history-period-presets", ".report-period-presets", ".report-section-switcher"):
            self.assertIn(cls, CSS)
        self.assertIn("scrollbar-width: none", CSS)
        self.assertIn(":focus-visible", CSS)
        for name in ("laporan-owner-320.png", "riwayat-owner-390.png", "laporan-owner-768.png"):
            self.assertTrue((ROOT / "docs/visual-evidence/c11f18" / name).is_file())


if __name__ == "__main__":
    unittest.main()
