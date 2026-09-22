from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

FINANCE = ROOT / "src/screens/FinanceScreen.tsx"
REPORTS = ROOT / "src/screens/ReportsScreen.tsx"
HISTORY = ROOT / "src/screens/TransactionHistoryScreen.tsx"
HANDOVER = ROOT / "src/screens/HandoverScreen.tsx"
SHIFT_HISTORY = ROOT / "src/screens/ShiftHistoryScreen.tsx"
RECON = ROOT / "src/screens/ReconciliationScreen.tsx"
USERS = ROOT / "src/screens/OwnerUsersScreen.tsx"
APPROVAL = ROOT / "src/screens/ExpenseApprovalScreen.tsx"
LEGACY = ROOT / "src/screens/LegacyImportScreen.tsx"
CONTROL_NAV = ROOT / "src/components/ControlCenterNav.tsx"
CSS = ROOT / "src/app.css"


class C7SecondaryScreenConvergenceTests(unittest.TestCase):
    def test_finance_has_control_nav_and_workflow_index(self):
        src = FINANCE.read_text(encoding="utf-8")
        self.assertIn("ControlCenterNav", src)
        self.assertIn('className="shell secondary-screen finance-workspace"', src)
        for token in (
            "Ringkasan",
            "Pindah Uang",
            "QRIS",
            "Rekonsiliasi",
            "Piutang & Utang",
            "Kasbon",
            "Owner",
            'id="finance-balances"',
            'id="finance-transfer"',
            'id="finance-qris"',
            'id="finance-reconciliation"',
            'id="finance-receivables"',
            'id="finance-kasbon"',
            'id="finance-owner"',
        ):
            self.assertIn(token, src)

    def test_finance_has_no_legacy_control_glyphs(self):
        src = FINANCE.read_text(encoding="utf-8")
        self.assertNotIn("", src)
        self.assertNotIn("�", src)
        self.assertIn("Kembali ke Pusat Kontrol", src)

    def test_reports_are_converged_without_changing_read_model(self):
        src = REPORTS.read_text(encoding="utf-8")
        self.assertIn('className="shell secondary-screen reports-workspace"', src)
        self.assertIn("secondary-filter-panel", src)
        self.assertIn("report-result-shell", src)
        self.assertIn("runReport", src)
        self.assertIn("exportReportExcel", src)

    def test_history_refund_correction_have_distinct_visual_authority(self):
        src = HISTORY.read_text(encoding="utf-8")
        self.assertIn('className="shell secondary-screen history-workspace"', src)
        self.assertIn("history-filter-panel", src)
        self.assertIn("history-transaction-card", src)
        self.assertIn("history-impact-panel refund", src)
        self.assertIn("history-impact-panel correction", src)
        for token in (
            "Refund Transaksi",
            "Koreksi Transaksi",
            "Dampak Stok",
            "Dampak Dana",
            "Dampak Hutang",
            "Dampak HPP / Laba",
            "Dampak Keuangan",
        ):
            self.assertIn(token, src)

    def test_shift_secondary_screens_share_operations_workspace(self):
        for path in (HANDOVER, SHIFT_HISTORY, RECON):
            src = path.read_text(encoding="utf-8")
            self.assertIn("OperationsNav", src)
            self.assertIn("operations-shell", src)
        recon = RECON.read_text(encoding="utf-8")
        duplicate = (
            '<p className="eyebrow">OPERASIONAL · SHIFT</p>\n'
            '            <p className="eyebrow">OPERASIONAL · SHIFT</p>'
        )
        self.assertNotIn(duplicate, recon)

    def test_owner_secondary_screens_share_control_center_navigation(self):
        for path in (USERS, APPROVAL, LEGACY):
            src = path.read_text(encoding="utf-8")
            self.assertIn("ControlCenterNav", src)
            self.assertIn("secondary-screen", src)

    def test_control_center_nav_has_single_owner_workspace(self):
        src = CONTROL_NAV.read_text(encoding="utf-8")
        for token in (
            "Pusat Kontrol",
            "Keuangan",
            "Pengguna",
            "Approval",
            "Migrasi",
            "/pengaturan",
            "/keuangan",
            "/pengguna",
            "/expense-approval",
            "/legacy-import",
        ):
            self.assertIn(token, src)

    def test_c7_css_uses_shared_design_tokens(self):
        src = CSS.read_text(encoding="utf-8")
        for token in (
            ".secondary-screen",
            ".secondary-workflow-nav",
            ".secondary-filter-panel",
            ".finance-workspace",
            ".history-transaction-card",
            ".history-impact-panel",
            "var(--sj-border)",
            "var(--sj-surface)",
            "var(--sj-brand-soft)",
        ):
            self.assertIn(token, src)

    def test_no_c7_database_migration(self):
        matches = list((ROOT / "supabase/migrations").glob("*c7*"))
        self.assertEqual([], matches)


if __name__ == "__main__":
    unittest.main()
