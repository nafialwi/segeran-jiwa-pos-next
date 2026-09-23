from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "src/screens/ReportsScreen.tsx"
CSS = ROOT / "src/app.css"
REPORT_API = ROOT / "src/reports/report-api.ts"


class C11F41CompactReportDrilldownTests(unittest.TestCase):
    def test_all_report_sections_use_one_compact_drilldown_pattern(self):
        source = REPORTS.read_text(encoding="utf-8")
        self.assertIn("function ReportSectionView(", source)
        self.assertIn('className="report-compact-row"', source)
        self.assertIn('aria-haspopup="dialog"', source)
        self.assertIn("function ReportDetailDialog(", source)
        self.assertIn("section.columns.map((column)", source)
        self.assertIn("reportCode={report.report_code}", source)

    def test_report_rows_are_paginated_twenty_at_a_time(self):
        source = REPORTS.read_text(encoding="utf-8")
        self.assertIn("const REPORT_PAGE_SIZE = 20;", source)
        self.assertIn("section.rows.slice(pageStart, pageStart + REPORT_PAGE_SIZE)", source)
        self.assertIn("section.rows.length > REPORT_PAGE_SIZE", source)
        self.assertIn("Sebelumnya", source)
        self.assertIn("Berikutnya", source)

    def test_filter_sort_changes_reset_page_and_detail(self):
        source = REPORTS.read_text(encoding="utf-8")
        self.assertIn("setPage(0);", source)
        self.assertIn("setSelectedRow(null);", source)
        self.assertIn("[resetKey]", source)
        self.assertIn("reportQuery}|${reportFilter}|${reportSort}", source)
    def test_detail_is_display_only_and_report_authority_is_unchanged(self):
        source = REPORTS.read_text(encoding="utf-8")
        api = REPORT_API.read_text(encoding="utf-8")
        self.assertIn("await runReport(code, dateFrom, dateTo)", source)
        self.assertIn("await exportReportExcel(report)", source)
        self.assertIn("supabase.rpc('report_run'", api)
        self.assertNotIn("supabase.from(", source)

    def test_compact_geometry_and_detail_sheet_are_declared(self):
        css = CSS.read_text(encoding="utf-8")
        marker = "/* C11-F4.1 — compact report list, drill-down, and pagination */"
        self.assertIn(marker, css)
        final = css[css.index(marker):]
        self.assertIn("min-height: 58px;", final)
        self.assertIn(".report-detail-backdrop", final)
        self.assertIn(".report-detail-dialog", final)
        self.assertIn(".report-pagination", final)
        self.assertIn("padding: 9px 10px;", final)
        self.assertIn("@media (min-width: 760px)", final)

    def test_desktop_and_mobile_share_the_same_paginated_rows(self):
        source = REPORTS.read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count("pageRows.map((row, index)"), 2)
        self.assertIn('className="report-desktop-row"', source)
        self.assertIn("onClick={() => setSelectedRow(row)}", source)


if __name__ == "__main__":
    unittest.main()
