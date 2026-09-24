from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
M = ROOT / "supabase" / "migrations" / "20260921003000_hrr_p4_sale_correction.sql"
SCREEN = ROOT / "src" / "screens" / "TransactionHistoryScreen.tsx"
API = ROOT / "src" / "history" / "history-api.ts"
REPORT = ROOT / "supabase" / "migrations" / "20260920250000_hrr_p3_reports_excel.sql"


class HrrP4SaleCorrectionTests(unittest.TestCase):
    def source(self) -> str:
        return M.read_text(encoding="utf-8").lower()

    def test_migration_exists(self):
        self.assertTrue(M.exists())

    def test_distinct_immutable_correction_fact_exists(self):
        s = self.source()
        for token in [
            "create table public.sale_corrections",
            "sale_corrections_immutable",
            "private.prevent_fact_mutation()",
            "create or replace function public.correct_sale",
            "'sale_correction'",
            "'correction_limited'",
            "sale_already_corrected",
            "sale_already_refunded",
        ]:
            self.assertIn(token, s)
        self.assertNotIn("perform public.refund_sale", s)
        self.assertNotIn("select public.refund_sale", s)

    def test_original_business_facts_are_never_mutated(self):
        s = self.source()
        forbidden = [
            "update public.sales",
            "delete from public.sales",
            "update public.sale_items",
            "delete from public.sale_items",
            "update public.payments",
            "delete from public.payments",
            "update public.customer_debts",
            "delete from public.customer_debts",
        ]
        for token in forbidden:
            self.assertNotIn(token, s)

    def test_correction_uses_single_inventory_and_money_engines(self):
        s = self.source()
        self.assertIn("private.record_inventory_movement(", s)
        self.assertIn("private.record_money_movement(", s)
        self.assertIn("p_reverses_movement_id => v_original_inventory", s)
        self.assertIn("p_reverses_movement_id => v_original_money", s)
        self.assertIn("'sale_correction_reversal'", s)
        self.assertIn("'reversal'", s)

    def test_cash_is_signed_adjustment_not_refund(self):
        s = self.source()
        self.assertIn("cash_transactions_amount_check", s)
        self.assertIn("transaction_type = 'adjustment'", s)
        self.assertIn("'adjustment'", s)
        self.assertIn("v_sale.total_amount * -1", s)
        self.assertIn("'sale_correction'", s)

    def test_credit_with_downstream_payment_fails_closed(self):
        s = self.source()
        self.assertIn("customer_debt_payments", s)
        self.assertIn("sale_correction_paid_debt_unsupported", s)

    def test_closed_shift_and_insufficient_balance_fail_closed(self):
        s = self.source()
        self.assertIn("sale_correction_shift_closed_unsupported", s)
        self.assertIn("private.finance_account_balance", s)
        self.assertIn("sale_correction_account_balance_insufficient", s)

    def test_history_and_debt_projection_distinguish_corrected(self):
        s = self.source()
        self.assertIn("'corrected'", s)
        self.assertIn("'correction'", s)
        self.assertIn("customer_debt_balances", s)
        api = API.read_text(encoding="utf-8")
        self.assertIn("HistoryCorrection", api)
        self.assertIn("correctSale", api)

    def test_refund_rejects_corrected_sale(self):
        s = self.source()
        self.assertIn("create or replace function public.refund_sale", s)
        self.assertIn("sale_already_corrected", s)

    def test_reports_include_distinct_correction_events(self):
        s = self.source()
        for token in [
            "create or replace function public.report_run",
            "sale_corrections",
            "'koreksi'",
            "correction_total",
        ]:
            self.assertIn(token, s)

    def test_ui_has_distinct_correction_preview_and_confirmation(self):
        screen = SCREEN.read_text(encoding="utf-8")
        for token in [
            "Koreksi Transaksi",
            "KOREKSI / PEMBALIKAN",
            "Dampak Stok",
            "Dampak Kas / QRIS / Transfer",
            "Dampak Hutang",
            "Dampak HPP / Laba",
            "Dampak Keuangan",
            "bukan refund pelanggan",
            "confirmAction",
        ]:
            self.assertIn(token, screen)

    def test_correction_is_online_only_not_queued_offline(self):
        screen = SCREEN.read_text(encoding="utf-8")
        self.assertIn("navigator.onLine", screen)
        self.assertIn("Koreksi memerlukan koneksi", screen)


if __name__ == "__main__":
    unittest.main()
