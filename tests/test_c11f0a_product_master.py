from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260923120000_c11f0a_product_master_editor.sql"
API = ROOT / "src/operations/product-api.ts"
SCREEN = ROOT / "src/screens/ProductOperationsScreen.tsx"
EDITOR = ROOT / "src/components/ProductMasterEditor.tsx"
AUTH_TYPES = ROOT / "src/auth/types.ts"
AUTH_PERMISSION = ROOT / "src/auth/permission.ts"
APP = ROOT / "src/App.tsx"
MENU = ROOT / "src/screens/MenuScreen.tsx"
USERS = ROOT / "src/screens/OwnerUsersScreen.tsx"
CSS = ROOT / "src/app.css"


class C11F0AProductMasterTests(unittest.TestCase):
    def test_product_manage_is_a_real_permission_and_route_capability(self):
        migration = MIGRATION.read_text(encoding="utf-8")
        self.assertIn(
            "('PRODUCT_MANAGE', 'Kelola Produk Jual', 'PRODUK', true)",
            migration,
        )
        self.assertIn("'PRODUCT_MANAGE'", AUTH_TYPES.read_text(encoding="utf-8"))
        self.assertIn("'PRODUCT_MANAGE'", AUTH_PERMISSION.read_text(encoding="utf-8"))
        self.assertIn("'PRODUCT_MANAGE'", APP.read_text(encoding="utf-8"))
        self.assertIn("'PRODUCT_MANAGE'", MENU.read_text(encoding="utf-8"))
        self.assertIn(
            "{ code: 'PRODUCT_MANAGE', label: 'Kelola Produk Jual' }",
            USERS.read_text(encoding="utf-8"),
        )

    def test_mutations_are_rpc_bounded_not_direct_frontend_table_writes(self):
        api = API.read_text(encoding="utf-8")
        editor = EDITOR.read_text(encoding="utf-8")
        self.assertIn("supabase.rpc('save_sale_product_master'", api)
        self.assertIn("supabase.rpc('save_product_variant_master'", api)
        self.assertIn("requireOnlineAction('Simpan Produk')", api)
        self.assertIn("requireOnlineAction('Simpan Varian')", api)
        self.assertNotIn(".from('sale_products').update", api)
        self.assertNotIn(".from('product_variants').update", api)
        self.assertNotIn(".from('variant_sale_components').delete", api)
        self.assertIn("saveSaleProductMaster", editor)
        self.assertIn("saveProductVariantMaster", editor)

    def test_server_functions_are_permission_idempotency_and_audit_bounded(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertGreaterEqual(
            sql.count("private.has_permission(v_business, 'PRODUCT_MANAGE')"),
            3,
        )
        self.assertIn("private.lock_operation(", sql)
        self.assertIn("private.record_operation_success(", sql)
        self.assertIn("insert into public.audit_events", sql)
        self.assertIn("'SALE_PRODUCT_CREATED'", sql)
        self.assertIn("'PRODUCT_VARIANT_CREATED'", sql)
        self.assertIn("security definer", sql.lower())
        self.assertIn("set search_path = ''", sql)
        self.assertIn(
            "from public, anon, authenticated, service_role", sql
        )
        self.assertIn("to authenticated;", sql)

    def test_variant_component_shape_is_server_derived_and_validated(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("v_role not in ('INGREDIENT','PACKAGING')", sql)
        self.assertIn("v_item_kind <> 'PACKAGING'", sql)
        self.assertIn(
            "v_item_kind not in ('MATERIAL','OTHER')",
            sql,
        )
        self.assertIn("'FINISHED_GOOD'", sql)
        self.assertIn("delete from public.variant_sale_components", sql)
        self.assertIn("quantity_per_unit", sql)
        self.assertIn("SJ_MTO_COMPONENT_REQUIRED", sql)
        self.assertIn("SJ_STOCK_VARIANT_INGREDIENT_NOT_ALLOWED", sql)

    def test_historical_sale_truth_is_not_rewritten(self):
        sql = MIGRATION.read_text(encoding="utf-8").lower()
        for forbidden in (
            "update public.sales",
            "delete from public.sales",
            "update public.sale_items",
            "delete from public.sale_items",
            "update public.sale_item_component_snapshots",
            "delete from public.sale_item_component_snapshots",
        ):
            self.assertNotIn(forbidden, sql)

    def test_ui_supports_product_variant_price_mode_active_and_components(self):
        editor = EDITOR.read_text(encoding="utf-8")
        for token in (
            "Nama produk",
            "Kategori",
            "Aktif dijual",
            "Harga jual (Rp)",
            "Cara pemenuhan",
            "Stok langsung",
            "Dibuat saat dijual",
            "Dibuat sebelumnya",
            "Varian aktif",
            "Varian utama",
            "Komponen saat dijual",
            "Bahan",
            "Kemasan",
            "Tambah Produk",
        ):
            # Tambah Produk is rendered by the parent screen.
            source = editor + SCREEN.read_text(encoding="utf-8")
            self.assertIn(token, source)

    def test_editor_is_capability_gated_for_unmigrated_preview(self):
        api = API.read_text(encoding="utf-8")
        screen = SCREEN.read_text(encoding="utf-8")
        self.assertIn("fetchProductMasterCapability", api)
        self.assertIn("PGRST202", api)
        self.assertIn("return false", api)
        self.assertIn("productMasterReady", screen)
        self.assertIn("canManageProduct", screen)

    def test_editor_is_mobile_first_and_keeps_touch_actions_readable(self):
        css = CSS.read_text(encoding="utf-8")
        self.assertIn("/* C11-F0A — Product Master Editor */", css)
        self.assertIn(".product-master-dialog", css)
        self.assertIn("@media (max-width: 520px)", css)
        self.assertIn("min-height: 48px", css)

    def test_migration_does_not_grant_table_write_access(self):
        sql = MIGRATION.read_text(encoding="utf-8").lower()
        self.assertNotIn("grant insert on table public.sale_products", sql)
        self.assertNotIn("grant update on table public.sale_products", sql)
        self.assertNotIn("grant insert on table public.product_variants", sql)
        self.assertNotIn("grant update on table public.product_variants", sql)
        self.assertNotIn("grant delete on table public.variant_sale_components", sql)


    def test_product_and_variant_edit_paths_are_direct_and_visible(self):
        screen = SCREEN.read_text(encoding="utf-8")
        editor = EDITOR.read_text(encoding="utf-8")
        css = CSS.read_text(encoding="utf-8")
        self.assertIn("<span>Edit Produk</span>", screen)
        self.assertIn('className="secondary-button product-variant-edit"', screen)
        self.assertIn("openProductMaster(selected.id, variant.id)", screen)
        self.assertIn("initialVariantId={masterVariantId}", screen)
        self.assertIn("initialVariantId?: string | null;", editor)
        self.assertIn("variant.id === initialVariantId", editor)
        self.assertIn("Editor produk belum aktif pada backend ini.", screen)
        self.assertIn("/* C11-B2 — product edit discoverability */", css)


if __name__ == "__main__":
    unittest.main()
