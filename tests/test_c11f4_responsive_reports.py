from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "src/screens/ReportsScreen.tsx"
CSS = ROOT / "src/app.css"
REPORT_API = ROOT / "src/reports/report-api.ts"


class C11F4ResponsiveReportsTests(unittest.TestCase):
    def test_mobile_cards_and_desktop_table_share_report_rows(self):
        source = REPORTS.read_text(encoding="utf-8")
        self.assertIn('className="report-mobile-list"', source)
        self.assertIn("<ReportCompactRow", source)
        self.assertIn('className="data-table report-desktop-table"', source)
        self.assertIn("displaySections.map((section)", source)

    def test_display_controls_are_client_side_only(self):
        source = REPORTS.read_text(encoding="utf-8")
        self.assertIn("rowSearchText(section, row).includes(query)", source)
        self.assertIn("reportFilter === 'ALL'", source)
        self.assertIn("setReportSort('VALUE_DESC')", source)
        self.assertIn("Filter dan urutan hanya mengubah tampilan", source)
        self.assertIn("await exportReportExcel(report)", source)

    def test_report_dates_are_human_readable_without_changing_rpc(self):
        source = REPORTS.read_text(encoding="utf-8")
        api = REPORT_API.read_text(encoding="utf-8")
        self.assertIn("if (format === 'date')", source)
        self.assertIn("formatValue(report.period.date_from, 'date')", source)
        self.assertIn("formatValue(report.period.date_to, 'date')", source)
        self.assertIn("supabase.rpc('report_run'", api)

    def test_seven_day_preset_remains_inclusive_seven_days(self):
        source = REPORTS.read_text(encoding="utf-8")
        self.assertIn("from.setDate(to.getDate() - 6);", source)

    def test_mobile_geometry_prevents_crushed_report_tables(self):
        css = CSS.read_text(encoding="utf-8")
        marker = "/* C11-F4 — responsive reports & mobile readability */"
        self.assertIn(marker, css)
        final = css[css.index(marker):]
        self.assertIn(".report-desktop-table", final)
        self.assertIn("min-width: 820px;", final)
        self.assertIn(".report-mobile-list", final)
        self.assertIn("@media (max-width: 759px)", final)
        self.assertIn("grid-template-columns: repeat(2, minmax(0, 1fr));", final)
        self.assertIn("grid-column: 1 / -1;", final)

    def test_mobile_report_view_keeps_bottom_navigation_clear(self):
        css = CSS.read_text(encoding="utf-8")
        marker = "/* C11-F4 — responsive reports & mobile readability */"
        final = css[css.index(marker):]
        self.assertIn("padding-bottom: calc(96px + env(safe-area-inset-bottom));", final)
        self.assertIn(".report-desktop-table-wrap", final)
        self.assertIn("display: none;", final)


if __name__ == "__main__":
    unittest.main()
