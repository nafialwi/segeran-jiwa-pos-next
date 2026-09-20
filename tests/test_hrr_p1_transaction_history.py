from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
M=ROOT/"supabase"/"migrations"/"20260920240000_hrr_p1_transaction_history.sql"
SCREEN=ROOT/"src"/"screens"/"TransactionHistoryScreen.tsx"
API=ROOT/"src"/"history"/"history-api.ts"
APP=ROOT/"src"/"App.tsx"
HOME=ROOT/"src"/"screens"/"HomeScreen.tsx"
TYPES=ROOT/"src"/"auth"/"types.ts"
REQ=ROOT/"src"/"auth"/"RequireAccess.tsx"

class HrrP1TransactionHistoryTests(unittest.TestCase):
    def test_migration_and_permissions_exist(self):
        self.assertTrue(M.exists())
        s=" ".join(M.read_text(encoding="utf-8").lower().split())
        for token in [
            "'history_own'",
            "'history_all'",
            "transaction_history_search",
            "history_read_required",
            "cashier_profile_id = v_profile",
            "invoice_number",
            "payment_method",
            "business_date",
        ]:
            self.assertIn(token,s)

    def test_history_is_read_only_search_not_report(self):
        s=M.read_text(encoding="utf-8").lower()
        self.assertNotIn("update public.sales",s)
        self.assertNotIn("delete from public.sales",s)
        self.assertNotIn("insert into public.sales",s)
        self.assertNotIn("create or replace function public.refund",s)
        self.assertNotIn("create or replace function public.reverse",s)
        self.assertNotIn("record_money_movement",s)
        self.assertNotIn("record_inventory_movement",s)

    def test_client_route_and_blueprint_filters_exist(self):
        self.assertTrue(SCREEN.exists())
        self.assertTrue(API.exists())
        app=APP.read_text()
        home=HOME.read_text()
        screen=SCREEN.read_text()
        self.assertIn('path="/riwayat"',app)
        self.assertIn("anyPermissions",app)
        self.assertIn('to="/riwayat"',home)
        for label in [
            "Tanggal / Hari Usaha",
            "Nomor Transaksi",
            "Produk",
            "Pengguna",
            "Metode Pembayaran",
            "Nominal",
            "Status",
        ]:
            self.assertIn(label,screen)
        self.assertIn("Pencarian transaksi individual",screen)
        self.assertNotIn("Laporan Penjualan",screen)

    def test_permission_surface_supports_history_any_of(self):
        types=TYPES.read_text()
        req=REQ.read_text()
        self.assertIn("'HISTORY_OWN'",types)
        self.assertIn("'HISTORY_ALL'",types)
        self.assertIn("anyPermissions",req)

if __name__=="__main__":
    unittest.main()
