from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "src/App.tsx"
MENU = ROOT / "src/screens/MenuScreen.tsx"
HANDOVER = ROOT / "src/screens/HandoverScreen.tsx"
RECON = ROOT / "src/screens/ReconciliationScreen.tsx"
APPROVAL = ROOT / "src/screens/ExpenseApprovalScreen.tsx"
CSS = ROOT / "src/app.css"


class C11COperationalWorkflowTests(unittest.TestCase):
    def test_route_and_menu_permissions_remain_consistent(self):
        app = APP.read_text(encoding="utf-8")
        menu = MENU.read_text(encoding="utf-8")
        self.assertIn('path="/handover"', app)
        self.assertIn('permission="SHIFT_OPEN_CLOSE"', app)
        self.assertIn("hasPermission(authority, 'SHIFT_OPEN_CLOSE')", menu)
        self.assertIn('path="/rekonsiliasi"', app)
        self.assertIn('permission="SHIFT_READ_OWN"', app)
        self.assertIn("hasPermission(authority, 'SHIFT_READ_OWN')", menu)
        self.assertIn('path="/expense-approval"', app)
        self.assertIn("<RequireAccess ownerOnly>", app)
        self.assertIn("canAccessOwnerArea(authority)", menu)

    def test_handover_requires_explicit_confirmation_and_surfaces_variance(self):
        source = HANDOVER.read_text(encoding="utf-8")
        self.assertIn("confirmAction", source)
        self.assertIn("Terima serah terima shift?", source)
        self.assertIn("Tolak serah terima shift?", source)
        self.assertIn("formatVariance(handover.discrepancy)", source)
        self.assertIn("Ada selisih", source)

    def test_reconciliation_clears_stale_shift_detail_and_explains_actual_cash(self):
        source = RECON.read_text(encoding="utf-8")
        self.assertIn("setReconciliation(null)", source)
        self.assertIn("Kas Diharapkan (Expected)", source)
        self.assertIn("Kas Fisik (Actual)", source)
        self.assertIn("Belum dicatat", source)
        self.assertIn("Varians belum dapat dihitung", source)

    def test_approval_prioritizes_pending_and_requires_rejection_reason(self):
        source = APPROVAL.read_text(encoding="utf-8")
        self.assertIn("pendingRequests", source)
        self.assertIn("orderedRequests", source)
        self.assertIn("required: !approve", source)
        self.assertIn("minLength: approve ? undefined : 3", source)
        self.assertIn("success-banner", source)
        self.assertIn("error-banner", source)

    def test_operational_workflow_styles_are_mobile_aware(self):
        css = CSS.read_text(encoding="utf-8")
        self.assertIn(
            "/* C11-C2 — handover, reconciliation, and approval clarity */",
            css,
        )
        self.assertIn(".handover-card.warning", css)
        self.assertIn(".approval-request-card.pending", css)


if __name__ == "__main__":
    unittest.main()
