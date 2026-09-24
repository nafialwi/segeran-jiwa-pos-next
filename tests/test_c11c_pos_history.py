from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SALES = ROOT / "src/screens/SalesScreen.tsx"
HISTORY = ROOT / "src/screens/TransactionHistoryScreen.tsx"
CSS = ROOT / "src/app.css"


class C11CPosHistoryTests(unittest.TestCase):
    def test_sales_keeps_checkout_authority_and_adds_semantic_visuals(self):
        src = SALES.read_text(encoding="utf-8")
        for token in [
            "checkoutSale({",
            "fetchMyOpenShift()",
            "hasPermission(authority, 'SALE_DISCOUNT')",
            "PAYMENT_QRIS",
            "PAYMENT_TRANSFER",
            "CUSTOMER_DEBT_MANAGE",
        ]:
            self.assertIn(token, src)
        for icon in [
            'name="search"',
            'name="product"',
            'name="cart"',
            "'qris'",
            "'transfer'",
            "'credit-debt'",
            'name="checkout"',
        ]:
            self.assertIn(icon, src)

    def test_checkout_remains_fail_closed_before_visual_submit(self):
        src = SALES.read_text(encoding="utf-8")
        self.assertIn("disabled={!canPay}", src)
        self.assertIn("if (!shift || !canPay || submitGuardRef.current) return;", src)
        self.assertIn("pendingOperationIdRef.current ?? crypto.randomUUID()", src)

    def test_history_keeps_refund_correction_guards_and_adds_status_ui(self):
        src = HISTORY.read_text(encoding="utf-8")
        for token in [
            "refundSale({",
            "previewSaleCorrection(row.sale_id)",
            "correctSale({",
            "if (!navigator.onLine)",
            "confirmAction({",
        ]:
            self.assertIn(token, src)
        self.assertIn("history-payment-chip", src)
        self.assertIn("history-status-chip", src)
        self.assertIn('name="receipt"', src)

    def test_c11c_css_declares_mobile_and_desktop_convergence(self):
        css = CSS.read_text(encoding="utf-8")
        self.assertIn("/* C11-C — POS, checkout, success & history convergence */", css)
        self.assertIn(".sales-v2-product-visual", css)
        self.assertIn(".sales-v2-payment-methods button .sj-icon", css)
        self.assertIn(".history-status-chip", css)
        self.assertIn("@media (min-width: 960px)", css)


if __name__ == "__main__":
    unittest.main()
