from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests/browser-harness/f19"
CONFIG = (FIXTURE / "vite.config.mjs").read_text(encoding="utf-8")
ENTRY = (FIXTURE / "main.tsx").read_text(encoding="utf-8")
FINANCE = (FIXTURE / "stub-finance.ts").read_text(encoding="utf-8")
SHIFT = (FIXTURE / "stub-shift.ts").read_text(encoding="utf-8")
INVENTORY = (FIXTURE / "stub-inventory.ts").read_text(encoding="utf-8")
BROWSER = (FIXTURE / "verify-browser.py").read_text(encoding="utf-8")
CSS = (ROOT / "src/app.css").read_text(encoding="utf-8")


class F19FinanceShiftFixtureTests(unittest.TestCase):
    def test_fixture_is_separate_from_production_entry(self):
        self.assertIn("f19-browser-fixture-only", CONFIG)
        self.assertIn("127.0.0.1", CONFIG)
        self.assertNotIn("browser-harness", (ROOT / "vite.config.ts").read_text())
        self.assertNotIn("browser-harness", (ROOT / "src/main.tsx").read_text())

    def test_actual_screens_with_synthetic_notice(self):
        self.assertIn("src/screens/FinanceScreen", ENTRY)
        self.assertIn("src/screens/ShiftManagementScreen", ENTRY)
        self.assertIn("src/components/AppShell", ENTRY)
        self.assertIn("KHUSUS UJI UI", ENTRY)
        self.assertIn("TANPA DATABASE", ENTRY)

    def test_business_mutations_disabled_in_fixture(self):
        for token in ("createEmployeeKasbon", "postFinanceTransfer", "postOwnerCapital",
                      "payCustomerDebt", "paySupplierPayable", "settleQris",
                      "reconcileFinanceDay"):
            self.assertIn(token, FINANCE)
        for token in ("openShift", "closeShift", "postShiftExpense", "createShiftPackagingCount"):
            self.assertIn(token, SHIFT)
        self.assertGreaterEqual((FINANCE + SHIFT + INVENTORY).count("throw new Error("), 3)
        for code in (FINANCE, SHIFT, INVENTORY):
            self.assertNotIn("supabase", code.lower())
            self.assertNotIn("fetch(", code)

    def test_browser_covers_navigation_layout_and_fixture_permissions(self):
        for size in ("320,740", "390,844", "412,915", "768,1024", "1280,800"):
            self.assertIn(size, BROWSER)
        for token in ("BROWSER_F19_PASS", "SHIFT_KASIR", "finance-flow-tabs",
                      "shift-flow-tabs", "finance-receivables", "shift-closing-card",
                      "finance-summary-grid"):
            self.assertIn(token, BROWSER)
        self.assertIn("Pengeluaran' not in kasir['tabs']", BROWSER)

    def test_compact_finance_320_and_visual_evidence(self):
        self.assertIn("/* C11-F19 — compact finance overview", CSS)
        self.assertIn("@media (max-width: 360px)", CSS)
        self.assertIn(".finance-workspace .finance-summary-grid", CSS)
        self.assertIn("grid-template-columns: repeat(2, minmax(0, 1fr))", CSS)
        for name in ("keuangan-owner-320.png", "keuangan-owner-390.png",
                     "shift-owner-390.png", "shift-kasir-390.png",
                     "shift-closing-owner-390.png"):
            self.assertTrue((ROOT / "docs/visual-evidence/c11f19" / name).is_file())


if __name__ == "__main__":
    unittest.main()
