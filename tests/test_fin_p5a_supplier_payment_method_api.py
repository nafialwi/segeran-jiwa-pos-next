from __future__ import annotations
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MIGRATION=ROOT/"supabase"/"migrations"/"20260920191500_fin_p5a_supplier_payment_method_api.sql"

class FinP5ASupplierPaymentMethodApiTests(unittest.TestCase):
    def test_migration_exists(self):
        self.assertTrue(MIGRATION.exists(), MIGRATION.name)

    def test_method_api_replaces_account_uuid_api(self):
        source=" ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        self.assertIn(
            "drop function if exists public.finance_pay_supplier_payable(uuid, uuid, numeric, text)",
            source,
        )
        self.assertIn("finance_pay_supplier_payable( p_payable_id uuid, p_method text",source)
        self.assertIn("v_method not in ('cash', 'transfer')",source)
        self.assertIn("when v_method = 'cash' then 'kas_utama'",source)
        self.assertIn("when v_method = 'transfer' then 'bank'",source)
        self.assertIn("payment_transfer",source)

if __name__=="__main__":
    unittest.main()
