from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
API = ROOT / "src/sales/sales-api.ts"
SCREEN = ROOT / "src/screens/SalesScreen.tsx"


class C3ASalesFrontendV2Tests(unittest.TestCase):
    def test_api_declares_product_variant_catalog_contract(self):
        src = API.read_text(encoding="utf-8")
        for token in (
            "sale_product_id: string",
            "variant_id: string",
            "product_code: string",
            "product_name: string",
            "variant_code: string",
            "variant_name: string",
            "fulfillment_mode:",
            "available_quantity: number | null",
            "inventory_managed: boolean",
        ):
            self.assertIn(token, src)

    def test_catalog_calls_v2_rpc_and_fails_closed_if_schema_is_missing(self):
        src = API.read_text(encoding="utf-8")
        self.assertIn("sales_catalog_v2", src)
        self.assertIn("REFINEMENT_DATABASE_NOT_READY", src)
        self.assertIn("tidak dialihkan ke katalog Legacy", src)
        self.assertNotIn(
            "fetchSalesCatalogV2(currentShift.location_id).catch",
            SCREEN.read_text(encoding="utf-8"),
        )

    def test_checkout_v2_submits_variant_identity(self):
        api = API.read_text(encoding="utf-8")
        screen = SCREEN.read_text(encoding="utf-8")
        self.assertIn("checkout_sale_v2", api)
        self.assertIn("variant_id: string; quantity: number", api)
        self.assertIn("line_note?: string", api)
        self.assertIn("variant_id: line.item.variant_id", screen)
        self.assertNotIn("stock_item_id: line.item.stock_item_id", screen)

    def test_cart_identity_is_variant_not_stock_item(self):
        src = SCREEN.read_text(encoding="utf-8")
        self.assertIn("line.item.variant_id === item.variant_id", src)
        self.assertIn("key={item.variant_id}", src)
        self.assertIn("key={line.item.variant_id}", src)
        self.assertIn("adjust(line.item.variant_id", src)
        self.assertNotIn("line.item.stock_item_id === item.stock_item_id", src)

    def test_product_and_variant_are_searchable_and_visible(self):
        src = SCREEN.read_text(encoding="utf-8")
        self.assertIn("item.product_name.toLowerCase().includes(query)", src)
        self.assertIn("item.variant_name.toLowerCase().includes(query)", src)
        self.assertIn("item.variant_code.toLowerCase().includes(query)", src)
        self.assertIn("sales-v2-variant-name", src)

    def test_availability_uses_v2_catalog_capacity(self):
        src = SCREEN.read_text(encoding="utf-8")
        self.assertIn("item.inventory_managed", src)
        self.assertIn("item.available_quantity", src)
        self.assertNotIn("item.inventory_tracked", src)

    def test_safety_guards_remain_present(self):
        api = API.read_text(encoding="utf-8")
        screen = SCREEN.read_text(encoding="utf-8")
        self.assertIn("requireOnlineAction('Penjualan')", api)
        self.assertIn("pendingOperationIdRef", screen)
        self.assertIn("submitGuardRef", screen)
        self.assertIn("p_operation_id: args.operationId", api)
        for method in ("CASH", "QRIS", "TRANSFER", "CREDIT"):
            self.assertIn(method, screen + api)


if __name__ == "__main__":
    unittest.main()
