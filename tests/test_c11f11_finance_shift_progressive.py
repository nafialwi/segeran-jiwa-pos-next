from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
FINANCE = (ROOT / "src/screens/FinanceScreen.tsx").read_text(encoding="utf-8")
SHIFT = (ROOT / "src/screens/ShiftManagementScreen.tsx").read_text(encoding="utf-8")
CSS = (ROOT / "src/app.css").read_text(encoding="utf-8")


class C11F11FinanceShiftProgressiveTests(unittest.TestCase):
    def test_finance_defaults_to_balances_and_exposes_all_original_workflows(self):
        self.assertIn("useState<FinanceFlow>('balances')", FINANCE)
        self.assertIn("FINANCE_FLOWS.map((item)", FINANCE)
        self.assertIn("aria-pressed={financeFlow === item.id}", FINANCE)
        for section, flow in {
            "balances": "balances",
            "transfer": "transfer",
            "owner": "owner",
            "qris": "qris",
            "reconciliation": "recon",
            "receivables": "receivables",
            "payables": "payables",
            "kasbon": "kasbon",
            "approval": "approval",
            "personal": "owner",
        }.items():
            self.assertIn(f'id="finance-{section}"', FINANCE)
            self.assertIn(f"financeFlow === '{flow}'", FINANCE)

    def test_finance_business_actions_and_reconciliation_are_preserved(self):
        for form in ("submitTransfer", "submitCapital", "submitPersonal", "submitQris",
                     "submitReconciliation", "submitDebtPayment", "submitSupplierPayment",
                     "submitKasbon"):
            self.assertIn(f"onSubmit={{{form}}}", FINANCE)
        for name in ("postFinanceTransfer", "postOwnerCapital", "settleQris",
                     "reconcileFinanceDay", "payCustomerDebt", "paySupplierPayable",
                     "createEmployeeKasbon", "postOwnerPersonalWithdrawal",
                     "confirmAction"):
            self.assertIn(name, FINANCE)
        self.assertIn("positiveAmount", FINANCE)
        self.assertIn("Piutang Pelanggan", FINANCE)

    def test_shift_summary_and_accessibility(self):
        self.assertIn("useState<ShiftFlow>('overview')", SHIFT)
        self.assertIn('className="shift-kpi-grid"', SHIFT)
        self.assertIn('aria-label="Pilih pekerjaan Shift"', SHIFT)
        self.assertIn("aria-pressed={shiftFlow === value}", SHIFT)
        self.assertIn("setShiftFlow(value)", SHIFT)
        self.assertIn("Link className=\"primary-link shift-sale-link\"", SHIFT)

    def test_shift_panels_and_permissions_remain(self):
        for flow in ("cash", "expense", "packaging", "closing", "more"):
            self.assertIn(f"shiftFlow === '{flow}'", SHIFT)
        self.assertIn("canCreateShiftExpense && shiftFlow === 'expense'", SHIFT)
        self.assertIn("postShiftExpense", SHIFT)
        self.assertIn("createShiftPackagingCount", SHIFT)
        self.assertIn("fetchShiftPackagingReconciliation", SHIFT)
        self.assertIn("canCloseShift(shift)", SHIFT)
        self.assertIn("await closeShift(shift.id, actualCash)", SHIFT)
        self.assertIn("actualCashInput.trim() === ''", SHIFT)
        self.assertIn("packagingClosingComplete", SHIFT)

    def test_shift_flow_is_reset_after_lifecycle_transitions(self):
        self.assertGreaterEqual(SHIFT.count("setShiftFlow('overview')"), 2)
        self.assertIn("await openShift(locationId, openingBalance)", SHIFT)
        self.assertIn("await closeShift(shift.id, actualCash)", SHIFT)

    def test_mobile_layout_preserves_touch_navigation(self):
        self.assertIn("/* C11-F11 — single-workflow finance and shift panels", CSS)
        self.assertIn(".finance-workspace .finance-flow-tabs", CSS)
        self.assertIn(".shift-operations-screen .shift-flow-tabs", CSS)
        self.assertIn("overscroll-behavior-inline: contain;", CSS)
        self.assertIn("min-height: var(--sj-touch-min);", CSS)
        self.assertIn(":focus-visible", CSS)


if __name__ == "__main__":
    unittest.main()
