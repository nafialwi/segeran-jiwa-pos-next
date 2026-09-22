# -*- coding: utf-8 -*-
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
MIG=ROOT/"supabase"/"migrations"/"20260920213000_uat_blocker_core_ui_recovery.sql"
APP=ROOT/"src"/"App.tsx"
HOME=ROOT/"src"/"screens"/"HomeScreen.tsx"
MENU=ROOT/"src"/"screens"/"MenuScreen.tsx"
SALES=ROOT/"src"/"screens"/"SalesScreen.tsx"
INV=ROOT/"src"/"screens"/"InventoryScreen.tsx"
PUR=ROOT/"src"/"screens"/"PurchaseScreen.tsx"
IMP=ROOT/"src"/"screens"/"LegacyImportScreen.tsx"
API=ROOT/"src"/"sales"/"sales-api.ts"

class UatBlockerCoreRecoveryTests(unittest.TestCase):
    def test_migration_exists(self):
        self.assertTrue(MIG.exists(), MIG.name)

    def test_server_authoritative_sales_contract(self):
        s=" ".join(MIG.read_text(encoding="utf-8").lower().split())
        for token in [
            "sale_price","sale_enabled","inventory_tracked","legacy_product_id",
            "create table if not exists public.legacy_master_imports",
            "create table if not exists public.business_checkout_settings",
            "import_legacy_master","sales_catalog",
            "inventory_operational_overview","purchase_operational_overview",
            "sj_sale_price_invalid",
        ]:
            self.assertIn(token,s)
        self.assertIn("and si.inventory_tracked", s)

    def test_real_sales_ui_replaces_placeholder(self):
        app=APP.read_text(encoding="utf-8")
        sales=SALES.read_text(encoding="utf-8")
        api=API.read_text(encoding="utf-8")
        self.assertNotIn("SalesFoundationScreen",app)
        self.assertIn("<SalesScreen />",app)
        self.assertIn("checkout_sale",api)
        for token in ["Keranjang","Tunai","QRIS","Transfer","Kasbon"]:
            self.assertIn(token,sales)

    def test_inventory_purchase_and_import_routes_exist(self):
        app=APP.read_text(encoding="utf-8")
        menu=MENU.read_text(encoding="utf-8")
        self.assertIn("<InventoryScreen />",app)
        self.assertIn("<PurchaseScreen />",app)
        self.assertIn("<LegacyImportScreen />",app)
        for route in ["/stok","/pembelian","/legacy-import"]:
            self.assertIn(route,app)
        for token in ["Persediaan","Pembelian","Migrasi Master Legacy"]:
            self.assertIn(token,menu)
        self.assertTrue(INV.exists())
        self.assertTrue(PUR.exists())
        self.assertTrue(IMP.exists())

    def test_back_link_uses_ascii_safe_label(self):
        approval=(ROOT/"src"/"screens"/"ExpenseApprovalScreen.tsx").read_text(encoding="utf-8")
        self.assertIn("Kembali ke Beranda",approval)

if __name__=="__main__":
    unittest.main()
