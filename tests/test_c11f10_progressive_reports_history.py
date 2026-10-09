from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
REPORTS = (ROOT / "src/screens/ReportsScreen.tsx").read_text(encoding="utf-8")
HISTORY = (ROOT / "src/screens/TransactionHistoryScreen.tsx").read_text(encoding="utf-8")
CSS = (ROOT / "src/app.css").read_text(encoding="utf-8")


class C11F10ProgressiveReportsHistoryTests(unittest.TestCase):
    def test_report_basic_controls_show_before_advanced_dates(self):
        self.assertIn("periodPreset === 'CUSTOM'", REPORTS)
        self.assertIn("report-custom-date", REPORTS)
        self.assertIn("Tampilkan Laporan", REPORTS)
        self.assertIn("setPeriodPreset('CUSTOM')", REPORTS)
        self.assertIn("Pilih periode untuk melihat ringkasan bisnis.", REPORTS)

    def test_report_display_controls_are_progressive_and_section_scoped(self):
        self.assertIn("aria-expanded={showDisplayFilters}", REPORTS)
        self.assertIn("setShowDisplayFilters((open) => !open)", REPORTS)
        self.assertIn("showDisplayFilters &&", REPORTS)
        self.assertIn("report-section-switcher", REPORTS)
        self.assertIn("selectedSectionKey === 'ALL'", REPORTS)
        self.assertIn("displaySections.map((section, index)", REPORTS)
        self.assertIn("Semua bagian", REPORTS)

    def test_report_authority_and_export_scope_are_unchanged(self):
        self.assertIn("REPORTS.filter((report)", REPORTS)
        self.assertIn("hasPermission(authority, report.permission)", REPORTS)
        self.assertIn("await runReport(code, dateFrom, dateTo)", REPORTS)
        self.assertIn("await exportReportExcel(report)", REPORTS)
        self.assertIn("section.columns.map((column)", REPORTS)

    def test_history_quick_period_keeps_manual_and_advanced_filters(self):
        self.assertIn("type HistoryQuickPeriod", HISTORY)
        self.assertIn("applyQuickPeriod(period: HistoryQuickPeriod)", HISTORY)
        self.assertIn("historyLocalDate(from)", HISTORY)
        self.assertIn("quickPeriod === value", HISTORY)
        self.assertIn("aria-expanded={showAdvancedFilters}", HISTORY)
        self.assertIn("history-advanced-grid", HISTORY)
        for label in ("Nomor Transaksi", "Produk", "Pengguna", "Metode Pembayaran",
                      "Nominal minimum (Rp)", "Nominal maksimum (Rp)", "Status"):
            self.assertIn(label, HISTORY)

    def test_history_is_page_limited_without_changing_server_limit_or_safety(self):
        self.assertIn("const HISTORY_PAGE_SIZE = 10;", HISTORY)
        self.assertIn("historyResultsRef.current?.scrollIntoView", HISTORY)
        self.assertIn("visibleRows.map((row)", HISTORY)
        self.assertIn("setHistoryPage(0)", HISTORY)
        self.assertIn("Halaman riwayat transaksi", HISTORY)
        self.assertIn("limit: 100", HISTORY)
        self.assertIn("searchTransactionHistory(query)", HISTORY)
        self.assertIn("canRefund &&", HISTORY)
        self.assertIn("canCorrect &&", HISTORY)
        self.assertIn("confirmAction(", HISTORY)

    def test_mobile_css_is_scoped_to_report_and_history(self):
        self.assertIn("/* C11-F10 — progressive report/history discovery on phones.", CSS)
        self.assertIn(".history-period-presets", CSS)
        self.assertIn(".report-section-switcher", CSS)
        self.assertIn(".history-advanced-grid", CSS)
        self.assertIn("@media (max-width: 620px)", CSS)


if __name__ == "__main__":
    unittest.main()
