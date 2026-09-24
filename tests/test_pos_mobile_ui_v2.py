from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
SCREEN=ROOT/"src"/"screens"/"SalesScreen.tsx"
API=ROOT/"src"/"sales"/"sales-api.ts"
CSS=ROOT/"src"/"app.css"

class PosMobileUiV2Tests(unittest.TestCase):
    def test_sales_uses_synchronous_submit_guard_and_stable_operation_id(self):
        s=SCREEN.read_text(encoding="utf-8")
        api=API.read_text(encoding="utf-8")
        self.assertIn("useRef",s)
        self.assertIn("submitGuardRef",s)
        self.assertIn("pendingCheckout",s)
        self.assertIn("operationId: crypto.randomUUID()",s)
        self.assertIn("saveSalesDraft(window.localStorage",s)
        self.assertIn("checkoutSale(request)",s)
        self.assertIn("operationId: string",api)
        self.assertIn("p_operation_id: args.operationId",api)

    def test_mobile_pos_has_sticky_toolbar_compact_grid_and_fixed_cart(self):
        s=SCREEN.read_text(encoding="utf-8")
        css=CSS.read_text(encoding="utf-8")
        for token in [
            "sales-v2-toolbar",
            "sales-v2-category-strip",
            "sales-v2-product-grid",
            "sales-v2-product-card",
            "sales-v2-cart-bar",
            "sales-v2-sheet-backdrop",
            "sales-v2-sheet",
            "Keranjang",
            "Lihat & Bayar",
            "Uang Pas",
        ]:
            self.assertIn(token,s+css)
        self.assertIn("position: sticky",css)
        self.assertIn("position: fixed",css)
        self.assertIn("grid-template-columns: repeat(3, minmax(0, 1fr))",css)

    def test_checkout_is_in_dialog_sheet_not_below_catalog(self):
        s=SCREEN.read_text(encoding="utf-8")
        self.assertIn('role="dialog"',s)
        self.assertIn('aria-modal="true"',s)
        self.assertIn("cartOpen",s)
        self.assertIn("setCartOpen(true)",s)

if __name__=="__main__":
    unittest.main()
