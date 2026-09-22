from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "src/App.tsx"
MENU = ROOT / "src/screens/MenuScreen.tsx"
INV = ROOT / "src/screens/InventoryScreen.tsx"
INV_DETAIL = ROOT / "src/screens/InventoryItemScreen.tsx"
PRODUCT = ROOT / "src/screens/ProductOperationsScreen.tsx"
PRODUCTION = ROOT / "src/screens/ProductionScreen.tsx"
INV_API = ROOT / "src/inventory/inventory-api.ts"
PRODUCT_API = ROOT / "src/operations/product-api.ts"
PROD_API = ROOT / "src/production/production-api.ts"
NAV = ROOT / "src/components/OperationsNav.tsx"
CSS = ROOT / "src/app.css"


class C5AOperationsFrontDoorTests(unittest.TestCase):
    def test_routes_add_item_product_and_production_front_doors(self):
        src = APP.read_text(encoding="utf-8")
        self.assertIn('path="/stok/:stockItemId"', src)
        self.assertIn('path="/produk"', src)
        self.assertIn('path="/produksi"', src)
        self.assertIn("InventoryItemScreen", src)
        self.assertIn("ProductOperationsScreen", src)
        self.assertIn("ProductionScreen", src)
        self.assertIn("'PRODUCTION_MANAGE'", src)

    def test_permission_helper_matches_new_operations_routes(self):
        src = (ROOT / "src/auth/permission.ts").read_text(encoding="utf-8")
        self.assertIn("route === '/produk'", src)
        self.assertIn("route === '/produksi'", src)
        self.assertIn("route.startsWith('/stok/')", src)
        self.assertIn("'INVENTORY_READ'", src)
        self.assertIn("'PRODUCTION_MANAGE'", src)

    def test_menu_surfaces_product_recipe_and_production_by_permission(self):
        src = MENU.read_text(encoding="utf-8")
        self.assertIn("Produk & Resep", src)
        self.assertIn("Produksi", src)
        self.assertIn("to: '/produk'", src)
        self.assertIn("to: '/produksi'", src)
        self.assertIn("'PRODUCTION_MANAGE'", src)

    def test_operations_nav_unifies_board03_modules(self):
        src = NAV.read_text(encoding="utf-8")
        for token in (
            "Persediaan",
            "Produk & Resep",
            "Pembelian",
            "Produksi",
            "Shift",
            "/stok",
            "/produk",
            "/pembelian",
            "/produksi",
            "/shift",
        ):
            self.assertIn(token, src)
        for screen in (INV, INV_DETAIL, PRODUCT, PRODUCTION):
            self.assertIn("OperationsNav", screen.read_text(encoding="utf-8"))

    def test_inventory_front_door_is_card_detail_oriented(self):
        src = INV.read_text(encoding="utf-8")
        self.assertIn("inventory-summary-grid", src)
        self.assertIn("inventory-item-grid", src)
        self.assertIn("item_kind", src)
        self.assertIn("Semua kategori", src)
        self.assertIn("stockItemId", src)
        self.assertIn("/stok/", src)
        self.assertNotIn('className="data-table-wrap"', src)

    def test_inventory_detail_reads_existing_movement_authority_only(self):
        src = INV_API.read_text(encoding="utf-8")
        self.assertIn("inventory_operational_overview", src)
        self.assertIn("inventory_movement_lines", src)
        self.assertIn("inventory_movements", src)
        self.assertNotIn(".insert(", src)
        self.assertNotIn(".update(", src)
        self.assertNotIn(".delete(", src)
        screen = INV_DETAIL.read_text(encoding="utf-8")
        self.assertIn("Saldo per Lokasi", screen)
        self.assertIn("Pergerakan Stok", screen)
        self.assertIn("Alasan", screen)

    def test_product_screen_distinguishes_variant_sale_components_and_bom(self):
        api = PRODUCT_API.read_text(encoding="utf-8")
        screen = PRODUCT.read_text(encoding="utf-8")
        for token in (
            "sale_products",
            "product_variants",
            "variant_sale_components",
            "boms",
            "bom_lines",
            "REFINEMENT_DATABASE_NOT_READY",
        ):
            self.assertIn(token, api)
        for token in (
            "Informasi",
            "Varian",
            "Resep",
            "Kemasan",
            "MAKE_TO_ORDER",
            "PREPRODUCED",
            "BOM Produksi",
        ):
            self.assertIn(token, screen)
        self.assertNotIn(".insert(", api)
        self.assertNotIn(".update(", api)
        self.assertNotIn(".delete(", api)

    def test_production_front_door_reuses_existing_production_writers(self):
        api = PROD_API.read_text(encoding="utf-8")
        screen = PRODUCTION.read_text(encoding="utf-8")
        self.assertIn("create_production_batch", api)
        self.assertIn("post_production_batch", api)
        self.assertIn("requireOnlineAction", api)
        self.assertIn("production_batches", api)
        self.assertIn("boms", api)
        self.assertIn("Rencana Produksi", screen)
        self.assertIn("Batch Produksi", screen)
        self.assertIn("BOM Aktif", screen)
        self.assertNotIn("record_inventory_movement", api)

    def test_c5a_uses_shared_design_system_and_no_new_db_migration(self):
        css = CSS.read_text(encoding="utf-8")
        for token in (
            ".operations-nav",
            ".inventory-summary-grid",
            ".inventory-item-grid",
            ".product-ops-layout",
            ".production-batch-grid",
            "var(--sj-brand-900)",
            "var(--sj-surface)",
            "var(--sj-border)",
        ):
            self.assertIn(token, css)

        migrations = list((ROOT / "supabase/migrations").glob("*c5a*"))
        self.assertEqual([], migrations)


if __name__ == "__main__":
    unittest.main()
