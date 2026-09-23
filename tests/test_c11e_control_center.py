from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
CONTROL = ROOT / "src/screens/ControlCenterScreen.tsx"
FINANCE = ROOT / "src/screens/FinanceScreen.tsx"
USERS = ROOT / "src/screens/OwnerUsersScreen.tsx"
ATTENTION = ROOT / "src/screens/AttentionScreen.tsx"
BACKUP = ROOT / "src/screens/BackupRestoreScreen.tsx"
HEALTH = ROOT / "src/screens/SystemHealthScreen.tsx"
OFFLINE = ROOT / "src/screens/OfflineSyncScreen.tsx"
DIAGNOSTICS = ROOT / "src/screens/DiagnosticsScreen.tsx"
PICKER = ROOT / "src/components/SearchablePicker.tsx"
SALES = ROOT / "src/screens/SalesScreen.tsx"
PURCHASE = ROOT / "src/screens/PurchaseScreen.tsx"
PRODUCT = ROOT / "src/screens/ProductOperationsScreen.tsx"
CSS = ROOT / "src/app.css"


class C11EControlCenterTests(unittest.TestCase):
    def test_control_center_is_grouped_without_route_changes(self):
        src = CONTROL.read_text(encoding="utf-8")
        for group in ("'Bisnis'", "'Orang'", "'Sistem'"):
            self.assertIn(group, src)
        for route in (
            "'/keuangan'",
            "'/pengguna#permissions'",
            "'/pengguna#devices'",
            "'/pengaturan/backup'",
            "'/pengaturan/kesehatan'",
        ):
            self.assertIn(route, src)
    def test_finance_summary_uses_authoritative_overview_codes(self):
        src = FINANCE.read_text(encoding="utf-8")
        self.assertIn("fetchFinanceOverview()", src)
        for code in ("KAS_UTAMA", "KAS_SHIFT", "BANK", "QRIS_BELUM_CAIR"):
            self.assertIn(code, src)
        self.assertIn("customerDebtTotal", src)
        self.assertIn("supplierPayableTotal", src)
        self.assertIn("finance-summary-grid", src)
        self.assertIn("SearchablePicker", src)

    def test_user_device_surface_has_search_and_honest_loading(self):
        src = USERS.read_text(encoding="utf-8")
        self.assertIn("owner_list_users", src)
        self.assertIn("owner_list_devices", src)
        self.assertIn("userSearch", src)
        self.assertIn("usersLoading", src)
        self.assertIn("devicesLoading", src)
        self.assertIn("owner-user-card", src)
        self.assertIn("owner-device-card", src)

    def test_evidence_screens_preserve_truth_boundaries(self):
        attention = ATTENTION.read_text(encoding="utf-8")
        backup = BACKUP.read_text(encoding="utf-8")
        health = HEALTH.read_text(encoding="utf-8")
        offline = OFFLINE.read_text(encoding="utf-8")
        diagnostics = DIAGNOSTICS.read_text(encoding="utf-8")
        self.assertIn("Tidak berarti seluruh sistem sehat", attention)
        self.assertIn("bukan status backup realtime", backup)
        self.assertIn("bukan bukti kesehatan backend", health)
        self.assertIn("Tidak ada antrean mutasi offline", offline)
        self.assertIn("Tidak menampilkan token", diagnostics)
    def test_unbounded_entity_lists_use_searchable_picker(self):
        picker = PICKER.read_text(encoding="utf-8")
        self.assertIn('role="dialog"', picker)
        self.assertIn('role="listbox"', picker)
        self.assertIn('type="search"', picker)
        for screen in (SALES, PURCHASE, PRODUCT, FINANCE):
            self.assertIn("SearchablePicker", screen.read_text(encoding="utf-8"))

    def test_c11e_css_is_mobile_first_and_readable(self):
        css = CSS.read_text(encoding="utf-8")
        for token in (
            "/* C11-E — Settings, finance, people, attention & system convergence */",
            ".control-center-groups",
            ".finance-summary-grid",
            ".owner-user-card",
            ".control-health-grid",
            "@media (max-width: 620px)",
            "@media (max-width: 360px)",
        ):
            self.assertIn(token, css)

    def test_c11e_does_not_add_database_migration(self):
        names = [p.name.lower() for p in (ROOT / "supabase/migrations").glob("*.sql")]
        self.assertFalse(any("c11e" in name for name in names))


if __name__ == "__main__":
    unittest.main()
