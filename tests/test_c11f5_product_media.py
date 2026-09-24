from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260924083000_c11f5_product_media.sql"
MEDIA = ROOT / "src/operations/product-media.ts"
MASTER = ROOT / "src/components/ProductMasterEditor.tsx"
PRODUCTS = ROOT / "src/screens/ProductOperationsScreen.tsx"
SALES = ROOT / "src/screens/SalesScreen.tsx"
CSS = ROOT / "src/app.css"


class C11F5ProductMediaTests(unittest.TestCase):
    def test_migration_adds_optional_product_media_and_bounded_bucket(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("add column if not exists image_path text", sql)
        self.assertIn("'product-media'", sql)
        self.assertIn("2097152", sql)
        self.assertIn("image/webp", sql)
        self.assertIn("image/jpeg", sql)
        self.assertIn("image/png", sql)
        self.assertIn("sale_products_image_path_shape", sql)

    def test_storage_writes_are_tenant_and_product_manage_bounded(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("product_media_manager_insert", sql)
        self.assertIn("product_media_manager_update", sql)
        self.assertIn("product_media_manager_delete", sql)
        self.assertIn("private.has_permission(", sql)
        self.assertIn("'PRODUCT_MANAGE'", sql)
        self.assertIn("(storage.foldername(name))[1]", sql)
        self.assertIn("p.id::text = (storage.foldername(name))[2]", sql)

    def test_pointer_writer_is_permission_idempotency_and_audit_bounded(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("public.set_sale_product_image(", sql)
        self.assertIn("private.lock_operation(", sql)
        self.assertIn("'PRODUCT_MEDIA_SET'", sql)
        self.assertIn("private.record_operation_success(", sql)
        self.assertIn("SALE_PRODUCT_IMAGE_ADDED", sql)
        self.assertIn("SALE_PRODUCT_IMAGE_REPLACED", sql)
        self.assertIn("SALE_PRODUCT_IMAGE_REMOVED", sql)
        self.assertNotIn("update public.sales", sql.lower())
        self.assertNotIn("update public.inventory_balances", sql.lower())

    def test_media_client_compresses_validates_and_cleans_failed_uploads(self):
        source = MEDIA.read_text(encoding="utf-8")
        self.assertIn("MAX_SOURCE_BYTES = 12 * 1024 * 1024", source)
        self.assertIn("MAX_OUTPUT_BYTES = 2 * 1024 * 1024", source)
        self.assertIn("MAX_IMAGE_EDGE = 1200", source)
        self.assertIn("prepareProductImage", source)
        self.assertIn("canvas.toBlob", source)
        self.assertIn("image/webp", source)
        self.assertIn("await removeStorageObject(path).catch", source)
        self.assertIn("product_media_capability", source)

    def test_product_master_supports_preview_replace_and_remove(self):
        source = MASTER.read_text(encoding="utf-8")
        self.assertIn("productMediaReady", source)
        self.assertIn("product-master-media-preview", source)
        self.assertIn('accept="image/jpeg,image/png,image/webp"', source)
        self.assertIn("uploadProductImage", source)
        self.assertIn("removeProductImage", source)
        self.assertIn("Ganti Foto", source)
        self.assertIn("Hapus Foto", source)
        self.assertIn("product && (", source)

    def test_sales_media_is_background_presentation_not_catalog_blocker(self):
        source = SALES.read_text(encoding="utf-8")
        self.assertIn("async function warmProductMedia()", source)
        self.assertIn("const items = await fetchSalesCatalog", source)
        self.assertIn("setCatalog(items);", source)
        self.assertIn("void warmProductMedia();", source)
        self.assertIn("Product images are optional presentation data", source)
        self.assertIn("productMediaPublicUrl(group.imagePath)", source)

    def test_product_operations_media_is_optional_and_does_not_disable_master(self):
        source = PRODUCTS.read_text(encoding="utf-8")
        self.assertIn("fetchProductMediaIndex()", source)
        self.assertIn("fetchProductMediaCapability().catch(() => false)", source)
        self.assertIn("canManageProductMedia", source)
        self.assertIn("product-ops-thumbnail", source)
        self.assertIn("product-ops-hero-media", source)
        self.assertIn("onMediaChanged={handleProductMediaChanged}", source)

    def test_media_css_preserves_placeholder_fallback_and_mobile_layout(self):
        css = CSS.read_text(encoding="utf-8")
        marker = "/* C11-F5 — product media & catalog completion */"
        self.assertIn(marker, css)
        final = css[css.index(marker):]
        self.assertIn(".sales-v2-product-visual > img", final)
        self.assertIn("object-fit: cover;", final)
        self.assertIn(".product-master-media-layout", final)
        self.assertIn(".product-media-file-button.disabled", final)
        self.assertIn("@media (max-width: 620px)", final)


if __name__ == "__main__":
    unittest.main()
