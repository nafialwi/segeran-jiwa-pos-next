from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
NAV = ROOT / "src/navigation/appNavigation.ts"
MENU = ROOT / "src/screens/MenuScreen.tsx"
REPORTS = ROOT / "src/screens/ReportsScreen.tsx"
CSS = ROOT / "src/app.css"


class C11F3DailyNavigationReportsTests(unittest.TestCase):
    def test_primary_navigation_replaces_attention_with_reports(self):
        source = NAV.read_text(encoding="utf-8")
        self.assertIn("'home' | 'sale' | 'history' | 'reports' | 'menu'", source)
        self.assertIn("label: 'Laporan'", source)
        self.assertIn("to: '/laporan'", source)
        self.assertIn("icon: 'reports'", source)
        self.assertNotIn("id: 'attention'", source)

    def test_reports_primary_entry_remains_permission_bounded(self):
        source = NAV.read_text(encoding="utf-8")
        for permission in (
            "REPORT_SALES_LIMITED",
            "REPORT_INVENTORY",
            "REPORT_PURCHASE",
        ):
            self.assertIn(permission, source)
    def test_attention_is_preserved_under_menu(self):
        source = MENU.read_text(encoding="utf-8")
        self.assertIn("label: 'Perhatian'", source)
        self.assertIn("to: '/perhatian'", source)
        self.assertIn("icon: 'notification'", source)

    def test_reports_default_to_daily_use_and_have_quick_periods(self):
        source = REPORTS.read_text(encoding="utf-8")
        self.assertIn("useState<ReportPeriodPreset>('TODAY')", source)
        self.assertIn("{ id: 'TODAY', label: 'Hari ini' }", source)
        self.assertIn("{ id: 'LAST_7_DAYS', label: '7 hari' }", source)
        self.assertIn("{ id: 'MONTH', label: 'Bulan ini' }", source)
        self.assertIn("{ id: 'CUSTOM', label: 'Custom' }", source)
        self.assertIn('role="group"', source)
        self.assertIn("aria-pressed={periodPreset === preset.id}", source)

    def test_manual_date_changes_clear_stale_report_and_switch_to_custom(self):
        source = REPORTS.read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count("setPeriodPreset('CUSTOM')"), 2)
        self.assertGreaterEqual(source.count("setReport(null);"), 4)

    def test_report_period_controls_are_mobile_touch_safe(self):
        css = CSS.read_text(encoding="utf-8")
        marker = "/* C11-F3 — daily navigation & report-entry convergence */"
        self.assertIn(marker, css)
        final = css[css.index(marker):]
        self.assertIn(".report-period-presets", final)
        self.assertIn(".report-period-chip", final)
        self.assertIn("min-height: var(--sj-touch-min);", final)
        self.assertIn("overscroll-behavior-inline: contain;", final)


if __name__ == "__main__":
    unittest.main()
