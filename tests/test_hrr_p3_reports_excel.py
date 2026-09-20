from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260920250000_hrr_p3_reports_excel.sql"

class HrrP3ReportsExcelTests(unittest.TestCase):
    def test_migration_exists(self):
        self.assertTrue(MIGRATION.exists())

    def test_reports_are_read_only_projection_authority(self):
        s = MIGRATION.read_text().lower()
        self.assertIn("create or replace function public.report_run", s)
        self.assertIn("report_sales_limited", s)
        self.assertIn("report_inventory", s)
        self.assertIn("report_purchase", s)
        self.assertIn("report_owner_required", s)
        self.assertIn("has_inventory_location_scope", s)
        self.assertNotIn("insert into public.", s)
        self.assertNotIn("update public.", s)
        self.assertNotIn("delete from public.", s)

    def test_blueprint_minimum_reports_exist(self):
        s = MIGRATION.read_text()
        for code in ("SALES","PRODUCT","INVENTORY","SHIFT","PURCHASE","FINANCE"):
            self.assertIn("'" + code + "'", s)
        for label in (
            "Laporan Penjualan","Laporan Produk","Laporan Persediaan",
            "Laporan Shift","Laporan Pembelian","Laporan Keuangan"
        ):
            self.assertIn(label, s)

    def test_finance_does_not_fake_profit_when_hpp_missing(self):
        s = MIGRATION.read_text()
        self.assertIn("Coverage HPP belum tersedia", s)
        self.assertIn("'Estimasi Laba','value',null", s)

    def test_excel_is_structured_and_not_raw_dump(self):
        s = (ROOT / "src/reports/report-excel.ts").read_text()
        for token in (
            "write-excel-file/browser","stickyRowsCount","business_name",
            "report_title","generated_at","summary","sections","columns","toFile",
        ):
            self.assertIn(token, s)

    def test_single_reports_route_and_permission_surface(self):
        app = (ROOT / "src/App.tsx").read_text()
        home = (ROOT / "src/screens/HomeScreen.tsx").read_text()
        screen = (ROOT / "src/screens/ReportsScreen.tsx").read_text()
        self.assertIn('path="/laporan"', app)
        self.assertIn('to="/laporan"', home)
        self.assertIn("REPORT_SALES_LIMITED", app)
        self.assertIn("REPORT_INVENTORY", app)
        self.assertIn("REPORT_PURCHASE", app)
        self.assertIn("Ekspor Excel", screen)

if __name__ == "__main__":
    unittest.main()
