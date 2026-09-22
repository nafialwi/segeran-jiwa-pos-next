from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260922110000_c3b_sales_facts_checkout.sql"
SQL_TEST = ROOT / "supabase/tests/c3b_sales_facts_checkout_test.sql"
API = ROOT / "src/sales/sales-api.ts"
SCREEN = ROOT / "src/screens/SalesScreen.tsx"
HISTORY_API = ROOT / "src/history/history-api.ts"
HISTORY_SCREEN = ROOT / "src/screens/TransactionHistoryScreen.tsx"


class C3BSalesFactsCheckoutTests(unittest.TestCase):
    def migration(self) -> str:
        self.assertTrue(MIGRATION.exists(), "C3B migration must exist")
        return MIGRATION.read_text(encoding="utf-8").lower()

    def test_discount_authority_and_immutable_sale_facts_exist(self):
        sql = self.migration()
        self.assertIn("'sale_discount'", sql)
        for token in (
            "discount_type",
            "discount_value",
            "discount_reason",
            "discount_approved_by",
        ):
            self.assertIn(token, sql)
        self.assertIn("private.has_permission(p_business_id, 'sale_discount')", sql)
        self.assertIn("sj_discount_permission_required", sql)

    def test_tender_and_change_are_payment_facts_not_revenue(self):
        sql = self.migration()
        self.assertIn("tendered_amount", sql)
        self.assertIn("change_amount", sql)
        self.assertIn("tendered_amount - amount", sql)
        self.assertIn("v_payment_amount := v_total_amount", sql)
        self.assertIn("private.record_money_movement(", sql)

    def test_line_notes_are_immutable_sale_line_facts(self):
        sql = self.migration()
        self.assertIn("add column line_note text", sql)
        self.assertGreaterEqual(sql.count("'line_note'"), 2)
        self.assertIn("v_item ->> 'line_note'", sql)
        self.assertIn("private.sale_line_read_projection", sql)

    def test_full_discount_still_posts_inventory_without_money(self):
        sql = self.migration()
        self.assertIn("v_total_amount = 0", sql)
        self.assertIn("v_amount > 0", sql)
        self.assertIn("v_money_id := null", sql)
        self.assertIn("alter column money_reversal_movement_id drop not null", sql)
        self.assertIn("if new.amount = 0 then", sql)
        self.assertIn("v_sale.total_amount > 0", sql)

    def test_checkout_v2_accepts_discount_and_returns_authoritative_receipt_facts(self):
        sql = self.migration()
        self.assertIn("p_discount jsonb", sql)
        for token in (
            "'subtotal'",
            "'discount_amount'",
            "'total_amount'",
            "'payment_method'",
            "'tendered_amount'",
            "'change_amount'",
        ):
            self.assertIn(token, sql)

    def test_frontend_exposes_board02_checkout_facts_and_single_success_authority(self):
        api = API.read_text(encoding="utf-8")
        screen = SCREEN.read_text(encoding="utf-8")
        for token in (
            "discount:",
            "tenderedAmount",
            "line_note",
            "p_discount:",
        ):
            self.assertIn(token, api + screen)
        for token in (
            "SALE_DISCOUNT",
            "Diskon",
            "Alasan diskon",
            "Catatan item",
            "Pembayaran Berhasil",
            "Transaksi Baru",
            "Lihat Riwayat",
            "Pilih Varian",
        ):
            self.assertIn(token, screen)
        self.assertIn('to="/riwayat"', screen)
        self.assertNotIn("Penjualan berhasil. Invoice:", screen)

    def test_history_exposes_new_facts(self):
        api = HISTORY_API.read_text(encoding="utf-8")
        screen = HISTORY_SCREEN.read_text(encoding="utf-8")
        for token in (
            "tendered_amount",
            "change_amount",
            "discount_type",
            "discount_value",
            "discount_reason",
            "line_note",
        ):
            self.assertIn(token, api)
        self.assertIn("Kembalian", screen)
        self.assertIn("Diskon", screen)
        self.assertIn("Catatan item", screen)

    def test_sql_regression_is_transactional_and_covers_board02_facts(self):
        self.assertTrue(SQL_TEST.exists(), "C3B SQL regression must exist")
        sql = SQL_TEST.read_text(encoding="utf-8").lower()
        self.assertTrue(sql.lstrip().startswith("begin;"))
        self.assertTrue(sql.rstrip().endswith("rollback;"))
        for token in (
            "checkout_sale_v2",
            "tendered_amount",
            "change_amount",
            "discount_amount",
            "line_note",
            "100",
            "c3b_full_discount_inventory_failed",
            "c3b_full_discount_money_failed",
            "c3b_refund_zero_total_failed",
            "c3b_correction_zero_total_failed",
        ):
            self.assertIn(token, sql)


if __name__ == "__main__":
    unittest.main()
