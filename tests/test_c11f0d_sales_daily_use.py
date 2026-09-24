from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCREEN = ROOT / "src/screens/SalesScreen.tsx"
CSS = ROOT / "src/app.css"
API = ROOT / "src/sales/sales-api.ts"


class C11F0DSalesDailyUseTests(unittest.TestCase):
    def test_success_resets_payment_draft_to_cash(self):
        source = SCREEN.read_text(encoding="utf-8")
        checkout = source.index("const result = await checkoutSale")
        reset = source.index("setMethod('CASH');", checkout)
        success = source.index("setSuccess({ result, items: successItems });", checkout)
        self.assertGreater(reset, success)
        for token in ("setCashReceived(0);", "setCustomerId('');", "setQrisConfirmed(false);", "setTransferConfirmed(false);", "setDiscountType('NONE');"):
            self.assertIn(token, source[success:])

    def test_success_refreshes_catalog_without_reopening_full_page_loader(self):
        source = SCREEN.read_text(encoding="utf-8")
        self.assertIn("async function refreshCatalogAfterSale(locationId: string)", source)
        self.assertIn("void refreshCatalogAfterSale(shift.location_id);", source)
        checkout = source.index("const result = await checkoutSale")
        success_tail = source[checkout:source.index("return (", checkout)]
        self.assertNotIn("await load();", success_tail)
        self.assertIn("fetchSalesCatalog(locationId)", source)

    def test_product_grid_density_supports_two_three_four_and_persists_per_device(self):
        source = SCREEN.read_text(encoding="utf-8")
        css = CSS.read_text(encoding="utf-8")
        self.assertIn("type GridDensity = 2 | 3 | 4;", source)
        self.assertIn("GRID_DENSITY_STORAGE_KEY", source)
        self.assertIn("window.localStorage.setItem", source)
        self.assertIn("([2, 3, 4] as const)", source)
        for value in (2, 3, 4):
            self.assertIn(f".sales-v2-product-grid.sales-grid-{value}", css)

    def test_loading_is_visual_progress_not_blank_identity_card(self):
        source = SCREEN.read_text(encoding="utf-8")
        css = CSS.read_text(encoding="utf-8")
        self.assertIn('className="sales-v2-loading"', source)
        self.assertIn('aria-busy="true"', source)
        self.assertIn(".sales-v2-loading-grid", css)
        self.assertIn("@keyframes sales-v2-loading-shimmer", css)

    def test_touch_controls_release_focus_and_disable_sticky_mobile_hover(self):
        source = SCREEN.read_text(encoding="utf-8")
        css = CSS.read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count("event.currentTarget.blur()"), 4)
        self.assertIn("-webkit-tap-highlight-color: transparent", css)
        self.assertIn("@media (hover: none), (pointer: coarse)", css)

    def test_shift_header_and_error_state_do_not_claim_stale_context(self):
        source = SCREEN.read_text(encoding="utf-8")
        self.assertIn("'Memeriksa shift…'", source)
        self.assertIn("'Shift belum aktif'", source)
        self.assertIn("sales-v2-shift-dot-inactive", source)
        self.assertGreaterEqual(source.count("setError('');"), 3)

    def test_checkout_truth_and_fail_closed_authority_are_unchanged(self):
        source = SCREEN.read_text(encoding="utf-8")
        api = API.read_text(encoding="utf-8")
        self.assertIn("checkoutSale(request)", source)
        self.assertIn("pendingCheckout", source)
        self.assertIn("operationId: crypto.randomUUID()", source)
        self.assertIn("requireOnlineAction('Penjualan')", api)
        self.assertIn("supabase.rpc('checkout_sale_v2'", api)
        self.assertNotIn(".from('sales').insert", source + api)


if __name__ == "__main__":
    unittest.main()
