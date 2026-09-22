from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "src/App.tsx"
MENU = ROOT / "src/screens/MenuScreen.tsx"
OPS_NAV = ROOT / "src/components/OperationsNav.tsx"
PURCHASE = ROOT / "src/screens/PurchaseScreen.tsx"
SHIFT = ROOT / "src/screens/ShiftManagementScreen.tsx"
PRODUCT = ROOT / "src/screens/ProductOperationsScreen.tsx"
PRODUCT_API = ROOT / "src/operations/product-api.ts"
CONTROL = ROOT / "src/screens/InventoryControlScreen.tsx"
CONTROL_API = ROOT / "src/inventory/inventory-control-api.ts"
AUTH_TYPES = ROOT / "src/auth/types.ts"
PERMISSION = ROOT / "src/auth/permission.ts"
CSS = ROOT / "src/app.css"


class C5BOperationsConvergenceTests(unittest.TestCase):
    def test_purchase_is_grouped_into_operational_workflows(self):
        src = PURCHASE.read_text(encoding="utf-8")
        for token in (
            "Belanja Langsung",
            "Pesanan Pemasok",
            "Penerimaan Barang",
            "Master Data",
            "purchase-workflow-tabs",
            "purchase-summary-grid",
        ):
            self.assertIn(token, src)
        for fn in (
            "directBuy",
            "createPurchaseOrder",
            "createGoodsReceipt",
            "postGoodsReceipt",
        ):
            self.assertIn(fn, src)

    def test_shift_has_open_active_close_reconciliation_and_packaging_control(self):
        src = SHIFT.read_text(encoding="utf-8")
        for token in (
            "Buka Shift",
            "Shift Aktif",
            "Tutup Shift",
            "Rekonsiliasi",
            "Kontrol Kemasan",
            "/stok/kontrol?tab=COUNT&kind=PACKAGING",
            "shift-kpi-grid",
            "shift-closing-card",
        ):
            self.assertIn(token, src)
        self.assertIn("fetchShiftReconciliation", src)
        self.assertIn("closeShift", src)

    def test_bom_configuration_reuses_versioned_authority(self):
        api = PRODUCT_API.read_text(encoding="utf-8")
        screen = PRODUCT.read_text(encoding="utf-8")
        for token in ("save_bom_draft", "activate_bom", "requireOnlineAction"):
            self.assertIn(token, api)
        for token in (
            "Konfigurasi BOM",
            "Simpan Draft BOM",
            "Aktifkan BOM",
            "PRODUCTION_MANAGE",
        ):
            self.assertIn(token, screen)
        self.assertNotIn(".insert(", api)
        self.assertNotIn(".update(", api)
        self.assertNotIn(".delete(", api)

    def test_inventory_control_permissions_are_typed_and_routed(self):
        types = AUTH_TYPES.read_text(encoding="utf-8")
        for token in (
            "'INVENTORY_REQUEST'",
            "'INVENTORY_TRANSFER'",
            "'INVENTORY_COUNT'",
            "'INVENTORY_ADJUST'",
        ):
            self.assertIn(token, types)

        app = APP.read_text(encoding="utf-8")
        self.assertIn('path="/stok/kontrol"', app)
        self.assertIn("InventoryControlScreen", app)
        self.assertIn("'INVENTORY_COUNT'", app)
        self.assertIn("'INVENTORY_ADJUST'", app)

        permission = PERMISSION.read_text(encoding="utf-8")
        self.assertIn("route === '/stok/kontrol'", permission)

    def test_inventory_control_uses_existing_canonical_rpcs(self):
        api = CONTROL_API.read_text(encoding="utf-8")
        for token in (
            "save_restock_request",
            "submit_restock_request",
            "create_stock_transfer",
            "ship_stock_transfer",
            "receive_stock_transfer",
            "create_inventory_count",
            "record_inventory_count",
            "post_inventory_count",
            "post_inventory_adjustment",
            "requireOnlineAction",
        ):
            self.assertIn(token, api)
        self.assertNotIn("record_inventory_movement", api)
        self.assertNotIn(".insert(", api)
        self.assertNotIn(".update(", api)
        self.assertNotIn(".delete(", api)

    def test_stock_control_front_door_covers_board03_controls(self):
        src = CONTROL.read_text(encoding="utf-8")
        for token in (
            "Minta Restock",
            "Transfer",
            "Stok Opname",
            "Penyesuaian",
            "PACKAGING",
            "Expected",
            "Fisik",
            "inventory-control-tabs",
        ):
            self.assertIn(token, src)

    def test_menu_and_operations_nav_surface_stock_control(self):
        menu = MENU.read_text(encoding="utf-8")
        nav = OPS_NAV.read_text(encoding="utf-8")
        self.assertIn("Kontrol Stok", menu)
        self.assertIn("to: '/stok/kontrol'", menu)
        self.assertIn("Kontrol Stok", nav)
        self.assertIn("/stok/kontrol", nav)

    def test_packaging_is_treated_as_inventory_not_second_cup_engine(self):
        control = CONTROL.read_text(encoding="utf-8")
        api = CONTROL_API.read_text(encoding="utf-8")
        self.assertIn("Kemasan adalah Stock Item", control)
        self.assertIn("inventory_counts", api)
        self.assertNotIn("cupInventory", control + api)
        self.assertNotIn("cupShift", control + api)

    def test_shift_packaging_usage_reads_sale_snapshots_and_is_fail_closed(self):
        api = (ROOT / "src/shift/shift-api.ts").read_text(encoding="utf-8")
        screen = SHIFT.read_text(encoding="utf-8")
        self.assertIn("sale_item_component_snapshots", api)
        self.assertIn("component_role", api)
        self.assertIn("PACKAGING", api)
        self.assertIn("ready: false", api)
        self.assertIn("Theoretical usage", screen)
        self.assertNotIn("record_inventory_movement", api)

    def test_reconciliation_is_part_of_shared_operations_workspace(self):
        src = (ROOT / "src/screens/ReconciliationScreen.tsx").read_text(
            encoding="utf-8"
        )
        self.assertIn("OperationsNav", src)
        self.assertIn("operations-shell", src)
        self.assertIn("Rekonsiliasi Shift", src)

    def test_c5b_uses_shared_design_system(self):
        css = CSS.read_text(encoding="utf-8")
        for token in (
            ".purchase-workflow-tabs",
            ".purchase-summary-grid",
            ".shift-kpi-grid",
            ".shift-closing-card",
            ".inventory-control-tabs",
            ".inventory-control-grid",
            ".bom-config-panel",
            "var(--sj-brand-900)",
            "var(--sj-surface)",
            "var(--sj-border)",
        ):
            self.assertIn(token, css)

    def test_no_new_c5b_database_migration(self):
        migrations = list((ROOT / "supabase/migrations").glob("*c5b*"))
        self.assertEqual([], migrations)


if __name__ == "__main__":
    unittest.main()
