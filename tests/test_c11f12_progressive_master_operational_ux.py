from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
USERS = (ROOT / "src/screens/OwnerUsersScreen.tsx").read_text(encoding="utf-8")
PURCHASE = (ROOT / "src/screens/PurchaseScreen.tsx").read_text(encoding="utf-8")
INVENTORY = (ROOT / "src/screens/InventoryControlScreen.tsx").read_text(encoding="utf-8")
PRODUCTS = (ROOT / "src/screens/ProductOperationsScreen.tsx").read_text(encoding="utf-8")
CSS = (ROOT / "src/app.css").read_text(encoding="utf-8")


class C11F12ProgressiveMasterOperationalUX(unittest.TestCase):
    def test_users_staff_creation_is_optional_and_safe(self):
        self.assertIn("useState(false)", USERS)
        self.assertIn("aria-expanded={showCreateStaff}", USERS)
        self.assertIn("showCreateStaff &&", USERS)
        self.assertIn("onSubmit={createStaff}", USERS)
        self.assertIn("setShowCreateStaff(false)", USERS)
        self.assertIn("selectedProfileId === user.profile_id", USERS)

    def test_user_permissions_are_exhaustive_and_grouped(self):
        permissions = re.findall(
            r"\{ code: '([A-Z_]+)', label:", USERS.split("const OPERATIONAL_PERMISSIONS:", 1)[1].split("function parseUsers", 1)[0].split("const PERMISSION_GROUPS", 1)[0]
        )
        grouped = re.findall(
            r"'([A-Z_]+)'",
            USERS.split("const PERMISSION_GROUPS:", 1)[1].split("function parseUsers", 1)[0],
        )
        self.assertEqual(sorted(permissions), sorted(grouped))
        self.assertEqual(len(permissions), len(set(grouped)))
        self.assertIn("OPERATIONAL_PERMISSIONS.filter", USERS)
        self.assertRegex(USERS, r"setPermission\(\s*selected,\s*code,")
        self.assertIn("userDetailTab === 'permissions'", USERS)
        self.assertIn("userDetailTab === 'devices'", USERS)

    def test_owner_device_safety_is_unchanged(self):
        for token in ("revokeDevice(", "revokeAndRemoveDevice(", "renameDevice(",
                      "owner_list_devices", "owner_list_users", "confirmAction",
                      "requireOnlineAction"):
            self.assertIn(token, USERS)
        self.assertIn("selected.role_code !== 'OWNER'", USERS)

    def test_purchase_tabs_and_financial_semantics_remain(self):
        for token in ("purchaseTab === 'DIRECT'", "purchaseTab === 'ORDER'",
                      "purchaseTab === 'RECEIPT'", "purchaseTab === 'MASTER'",
                      "onSubmit={saveSupplier}", "onSubmit={saveItem}",
                      "postReceipt(", "saveSupplier", "saveItem"):
            self.assertIn(token, PURCHASE)
        self.assertIn("aria-pressed={masterKind === 'SUPPLIER'}", PURCHASE)
        self.assertIn("aria-pressed={masterKind === 'ITEM'}", PURCHASE)
        self.assertIn("showPayables &&", PURCHASE)
        self.assertIn("aria-expanded={showPayables}", PURCHASE)

    def test_inventory_guarded_workflows_and_history_reachable(self):
        for token in ("canRestock", "canTransfer", "canCount", "canAdjust",
                      "submitRestock", "createTransfer", "postAdjustment",
                      "savePhysicalCount", "postCount", "shipTransfer"):
            self.assertIn(token, INVENTORY)
        self.assertIn("aria-expanded={showAdjustHistory}", INVENTORY)
        self.assertIn("showAdjustHistory &&", INVENTORY)

    def test_product_mobile_list_detail_with_original_editor(self):
        self.assertIn("data-mobile-view={mobileView}", PRODUCTS)
        self.assertIn("setMobileView('detail')", PRODUCTS)
        self.assertIn("setMobileView('list')", PRODUCTS)
        self.assertIn("product-ops-back-list", PRODUCTS)
        self.assertIn("selectProduct(product.id)", PRODUCTS)
        self.assertIn("openProductMaster(selected.id)", PRODUCTS)
        self.assertIn("productMediaPublicUrl", PRODUCTS)

    def test_mobile_styles_are_scoped(self):
        self.assertIn("/* C11-F12 — progressive owner, purchase, inventory, product on mobile */", CSS)
        self.assertIn("@media (max-width: 720px)", CSS)
        self.assertIn(".product-ops-layout[data-mobile-view='detail'] .product-ops-list", CSS)
        self.assertIn(".owner-users-detail-tabs", CSS)
        self.assertIn(".owner-permission-group", CSS)
        self.assertIn(".purchase-master-switch", CSS)


if __name__ == "__main__":
    unittest.main()
