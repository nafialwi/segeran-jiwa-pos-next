from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
M=ROOT/"supabase"/"migrations"/"20260920243000_hrr_p2_sale_refund.sql"
SCREEN=ROOT/"src"/"screens"/"TransactionHistoryScreen.tsx"
API=ROOT/"src"/"history"/"history-api.ts"

class HrrP2SaleRefundTests(unittest.TestCase):
    def test_migration_exists(self):
        self.assertTrue(M.exists())

    def test_refund_fact_and_command_contract(self):
        s=" ".join(M.read_text(encoding="utf-8").lower().split())
        for token in [
            "create table public.sale_refunds",
            "refund_sale",
            "'return_to_stock'",
            "'damaged_unfit'",
            "'no_goods_returned'",
            "'sale_refund'",
            "'reversal'",
            "reverses_movement_id",
            "transaction_type, amount, reference_type",
            "'refund'",
            "correction_limited",
            "sale_already_refunded",
            "private.record_inventory_movement",
            "private.record_money_movement",
            "private.lock_operation",
        ]:
            self.assertIn(token,s)

    def test_original_sale_is_not_mutated(self):
        s=M.read_text(encoding="utf-8").lower()
        self.assertNotIn("update public.sales",s)
        self.assertNotIn("delete from public.sales",s)
        self.assertNotIn("update public.payments",s)
        self.assertNotIn("delete from public.payments",s)
        self.assertNotIn("update public.customer_debts",s)

    def test_credit_refund_projection_and_manual_qris_semantics(self):
        s=" ".join(M.read_text(encoding="utf-8").lower().split())
        self.assertIn("receivable_cancelled_amount",s)
        self.assertIn("payout_amount",s)
        self.assertIn("'refunded'",s)
        self.assertIn("'none'",s)
        self.assertNotIn("qris_provider_cancel",s)
        self.assertNotIn("automatic_qris_refund",s)

    def test_ui_requires_impact_preview_and_confirmation(self):
        screen=SCREEN.read_text(encoding="utf-8")
        api=API.read_text(encoding="utf-8")
        self.assertIn("refundSale",api)
        for token in [
            "Refund Transaksi",
            "Kembali ke stok",
            "Rusak / tidak layak",
            "Barang tidak kembali",
            "Dampak Stok",
            "Dampak Dana",
            "Dampak Hutang",
            "Dampak HPP / Laba",
            "Dampak Keuangan",
            "confirmAction",
        ]:
            self.assertIn(token,screen)

if __name__=="__main__":
    unittest.main()
