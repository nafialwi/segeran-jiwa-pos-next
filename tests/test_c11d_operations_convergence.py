from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SALES = ROOT / "src/screens/SalesScreen.tsx"
INVENTORY_API = ROOT / "src/inventory/inventory-api.ts"
INVENTORY = ROOT / "src/screens/InventoryScreen.tsx"
PRODUCT = ROOT / "src/screens/ProductOperationsScreen.tsx"
PURCHASE = ROOT / "src/screens/PurchaseScreen.tsx"
PRODUCTION = ROOT / "src/screens/ProductionScreen.tsx"
SHIFT = ROOT / "src/screens/ShiftManagementScreen.tsx"
CSS = ROOT / "src/app.css"


class C11DOperationsConvergenceTests(unittest.TestCase):
    def test_sales_first_paint_does_not_wait_for_checkout_support_data(self):
        src = SALES.read_text(encoding="utf-8")
        load = src.split("async function load()", 1)[1].split("useEffect(() =>", 1)[0]
        self.assertIn("await fetchSalesCatalog(currentShift.location_id)", load)
        self.assertIn("void warmCustomers()", load)
        self.assertIn("void warmQris()", load)
        self.assertNotIn("Promise.all([", load)
        self.assertIn("if (value === 'CREDIT') void warmCustomers()", src)
        self.assertIn("if (value === 'QRIS') void warmQris()", src)

    def test_inventory_detail_prefetch_reuses_inflight_request_without_stale_cache(self):
        api = INVENTORY_API.read_text(encoding="utf-8")
        screen = INVENTORY.read_text(encoding="utf-8")
        self.assertIn("inventoryDetailInflight", api)
        self.assertIn("inventoryDetailInflight[stockItemId] = undefined", api)
        self.assertIn("prefetchInventoryItemDetail", api)
        self.assertIn("onPointerDown={() =>", screen)
        self.assertIn("prefetchInventoryItemDetail(item.stockItemId)", screen)

    def test_product_list_is_not_blocked_by_bom_picker_options(self):
        src = PRODUCT.read_text(encoding="utf-8")
        load = src.split("const load = useCallback", 1)[1].split("const ensureBomOptions", 1)[0]
        self.assertIn("await fetchProductOperations()", load)
        self.assertNotIn("fetchBomStockOptions()", load)
        self.assertIn("tab === 'RECIPE' && canManageProduction", src)
        self.assertIn("await fetchBomStockOptions()", src)
        self.assertIn("loadingProducts", src)

    def test_purchase_finance_and_front_door_are_progressive(self):
        src = PURCHASE.read_text(encoding="utf-8")
        self.assertIn("const frontDoorPromise = fetchPurchaseFrontDoorOptions()", src)
        self.assertIn("const financePromise = (async () =>", src)
        self.assertIn("await Promise.all([frontDoorPromise, financePromise])", src)
        self.assertIn("loadingOptions", src)
        self.assertIn("loadingFinance", src)

    def test_production_and_shift_have_honest_progressive_loading(self):
        prod = PRODUCTION.read_text(encoding="utf-8")
        shift = SHIFT.read_text(encoding="utf-8")
        self.assertIn("const [loading, setLoading] = useState(true)", prod)
        self.assertIn("production-loading", prod)
        self.assertIn("const locationPromise = fetchLocations()", shift)
        self.assertIn("const currentShift = await fetchMyOpenShift()", shift)
        self.assertIn("locationsLoading", shift)
        self.assertIn("shift-loading", shift)

    def test_board03_visual_language_is_mobile_first_and_icon_led(self):
        css = CSS.read_text(encoding="utf-8")
        for token in (
            "/* C11-D — Inventory, recipe, purchase, production & shift convergence */",
            ".inventory-kind-chip",
            ".product-ops-hero-icon",
            ".purchase-summary-icon",
            ".production-selected-good",
            ".shift-action-icon",
            "@media (max-width: 520px)",
            "@media (max-width: 360px)",
        ):
            self.assertIn(token, css)

    def test_c11d_does_not_introduce_database_migration(self):
        migrations = ROOT / "supabase/migrations"
        names = [p.name.lower() for p in migrations.glob("*.sql")]
        self.assertFalse(any("c11d" in name for name in names))


if __name__ == "__main__":
    unittest.main()
