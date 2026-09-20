from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
M=ROOT/"supabase"/"migrations"/"20260920221000_uat_r3_purchase_front_door.sql"
UI=ROOT/"src"/"screens"/"PurchaseScreen.tsx"
API=ROOT/"src"/"purchase"/"purchase-api.ts"

class UatR3PurchaseFrontDoorTests(unittest.TestCase):
    def test_migration_exists(self):
        self.assertTrue(M.exists(), M.name)

    def test_purchase_commands_exist(self):
        s=" ".join(M.read_text(encoding="utf-8").lower().split())
        for token in [
            "purchase_create_supplier",
            "purchase_create_item",
            "purchase_create_order",
            "purchase_create_goods_receipt",
            "purchase_front_door_options",
            "purchase_direct_buy",
            "purchase_manage",
            "partially_received",
            "post_goods_receipt",
            "assign_stock_item_base_unit_id",
            "base_unit_id",
        ]:
            self.assertIn(token,s)

    def test_po_writer_does_not_write_inventory(self):
        s=M.read_text(encoding="utf-8").lower()
        start=s.index("create or replace function public.purchase_create_order")
        end=s.index("create or replace function public.purchase_create_goods_receipt",start)
        body=s[start:end]
        self.assertNotIn("record_inventory_movement",body)
        self.assertIn("'approved'",body)

    def test_grn_creation_does_not_post_stock(self):
        s=M.read_text(encoding="utf-8").lower()
        start=s.index("create or replace function public.purchase_create_goods_receipt")
        end=s.index("create or replace function public.purchase_direct_buy",start)
        body=s[start:end]
        self.assertNotIn("record_inventory_movement",body)
        self.assertIn("'received'",body)

    def test_purchase_ui_has_operational_actions(self):
        self.assertTrue(API.exists())
        ui=UI.read_text(encoding="utf-8")
        api=API.read_text(encoding="utf-8")
        for token in [
            "Tambah Pemasok",
            "Tambah Barang",
            "Pesanan ke Pemasok",
            "Penerimaan Barang",
            "Belanja Langsung",
            "Barang Diterima",
        ]:
            self.assertIn(token,ui)
        for rpc in [
            "purchase_create_supplier",
            "purchase_create_item",
            "purchase_create_order",
            "purchase_create_goods_receipt",
            "purchase_direct_buy",
            "post_goods_receipt",
        ]:
            self.assertIn(rpc,api)

if __name__=="__main__":
    unittest.main()
