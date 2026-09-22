from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
HOME = ROOT / "src/screens/HomeScreen.tsx"
API = ROOT / "src/dashboard/dashboard-api.ts"
CSS = ROOT / "src/app.css"


class C4DashboardConvergenceTests(unittest.TestCase):
    def test_home_is_role_aware_dashboard_not_engineering_link_grid(self):
        src = HOME.read_text(encoding="utf-8")
        self.assertIn("OwnerDashboard", src)
        self.assertIn("CashierDashboard", src)
        self.assertIn("canAccessOwnerArea(authority)", src)
        self.assertNotIn('className="action-grid"', src)
        self.assertNotIn('className="identity-card"', src)

    def test_owner_dashboard_reads_existing_report_and_finance_authorities(self):
        src = API.read_text(encoding="utf-8")
        self.assertIn("runReport('SALES'", src)
        self.assertIn("money_accounts", src)
        self.assertIn("money_balances", src)
        self.assertIn("'KAS_UTAMA'", src)
        self.assertIn("'KAS_SHIFT'", src)
        self.assertIn("'QRIS_BELUM_CAIR'", src)
        self.assertNotIn("insert(", src)
        self.assertNotIn("update(", src)
        self.assertNotIn("delete(", src)

    def test_cashier_dashboard_uses_shift_authority_without_global_finance(self):
        src = API.read_text(encoding="utf-8")
        self.assertIn("fetchMyOpenShift", src)
        self.assertIn("fetchShiftReconciliation", src)
        self.assertIn("fetchCashierDashboard", src)
        cashier = src.split("export async function fetchCashierDashboard", 1)[1]
        self.assertNotIn("money_accounts", cashier)
        self.assertNotIn("money_balances", cashier)
        self.assertNotIn("runReport(", cashier)

    def test_owner_kpis_trend_best_sellers_and_attention_are_present(self):
        src = HOME.read_text(encoding="utf-8")
        for token in (
            "Penjualan Hari Ini",
            "Transaksi",
            "Kas Tersedia",
            "QRIS Belum Cair",
            "Tren 7 Hari",
            "Produk Terlaris",
            "Perlu Perhatian",
        ):
            self.assertIn(token, src)

    def test_cashier_dashboard_has_shift_sale_cta_and_truthful_owner_message(self):
        src = HOME.read_text(encoding="utf-8")
        for token in (
            "Shift Aktif",
            "Jual Sekarang",
            "Kas Diharapkan",
            "Penjualan Shift",
            "Aksi Cepat",
            "Pesan Owner",
            "Belum ada kanal pesan operasional",
        ):
            self.assertIn(token, src)

    def test_dashboard_is_responsive_and_uses_c1_design_tokens(self):
        css = CSS.read_text(encoding="utf-8")
        for token in (
            ".dashboard-shell",
            ".dashboard-kpi-grid",
            ".dashboard-owner-grid",
            ".dashboard-trend-bars",
            ".dashboard-quick-grid",
            "@media (min-width: 960px)",
            "var(--sj-brand-900)",
            "var(--sj-surface)",
            "var(--sj-border)",
        ):
            self.assertIn(token, css)

    def test_loading_is_card_level_not_full_screen(self):
        src = HOME.read_text(encoding="utf-8")
        self.assertIn("dashboard-skeleton", src)
        self.assertNotIn("Memuat dashboard...", src)
        self.assertNotIn("center-card", src)


if __name__ == "__main__":
    unittest.main()
