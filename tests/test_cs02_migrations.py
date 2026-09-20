from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"
SQL_TESTS = ROOT / "supabase" / "tests"

EXPECTED_MIGRATIONS = [
    "20260906171822_cs02_system_metadata.sql",
    "20260906171939_cs02_identity_and_reference.sql",
    "20260906172647_cs02_idempotency_and_audit.sql",
    "20260906172811_cs02_inventory_authority.sql",
    "20260906172916_cs02_money_authority.sql",
    "20260906173018_cs02_rls_and_grants.sql",
    "20260906173113_cs02_explicit_read_grants.sql",
    "20260906173248_cs02_restrict_auto_rls_helper.sql",
    "20260906173339_cs02_performance_hardening.sql",
    "20260907013121_cs02_correct_schema_source_anchor.sql",
    "20260907193000_cs02_revoke_non_dml_table_privileges.sql",
    "20260908013000_cs03_identity_session_permission.sql",
    "20260908102825_cs03_revoke_private_helper_execute.sql",
    "20260908190000_cs03_bootstrap_uuid_correction.sql",
    "20260910170000_cs04_sales_foundation.sql",
    "20260910190000_cs04_sales_rpc_foundation.sql",
    "20260910200000_cs04_sale_posting_engine.sql",
    "20260912100000_cs05_shift_foundation.sql",
    "20260912110000_cs05_shift_logic.sql",
    "20260913100000_cs05_shift_api.sql",
    "20260913110000_cs05_handover_target.sql",
    "20260914100000_cs05_cash_integration.sql",
    "20260915100000_cs06_p1_products_suppliers_units.sql",
    "20260915110000_cs06_p2a_rls_fix.sql",
    "20260915120000_cs06_p2b_inventory_balances.sql",
    "20260915130000_cs06_p2c_migrate_to_stock_items.sql",
    "20260915140000_cs06_p3_purchase_orders.sql",
    "20260915150000_cs06_p4_goods_receipts.sql",
    "20260915210000_cs06_p4r1_grn_hardening.sql",
    "20260915223000_cs06_p5_bom_foundation.sql",
    "20260916083000_cs06_p6_production_execution.sql",
    "20260916143000_cs06_p7_restock_transfer.sql",
    "20260919170000_cs06_p8_inventory_controls.sql",
    "20260920130000_cs05_cs06_closure_security_hardening.sql",
    "20260920140000_fin_p1_finance_foundation.sql",
    "20260920150000_fin_p2a_shift_funding_bridge.sql",
    "20260920160000_fin_p2b_shift_expense.sql",
    "20260920163000_fin_p2b1_expense_index_hardening.sql",
    "20260920170000_fin_p3_customer_debt_foundation.sql",
    "20260920171500_fin_p3a_rls_authority_bridge.sql",
    "20260920180000_fin_p4_qris_settlement_reconciliation.sql",
    "20260920190000_fin_p5_supplier_payable_foundation.sql",
    "20260920191500_fin_p5a_supplier_payment_method_api.sql",
    "20260920193000_fin_p5b_supplier_read_authority.sql",
    "20260920200000_fin_p6_expense_approval.sql",
    "20260920213000_uat_blocker_core_ui_recovery.sql",
    "20260920214500_uat_r1_sale_replay_stock_gate.sql",
    "20260920215500_uat_r2_recovery_index_hardening.sql",
    "20260920221000_uat_r3_purchase_front_door.sql",
    "20260920230000_fin_p7_employee_kasbon_foundation.sql",
    "20260920233000_fin_closure_owner_equity_personal_accounts.sql",
]
EXPECTED_SQL_TESTS = [
    "001_foundation_assertions.sql",
    "002_rls.sql",
    "003_idempotency.sql",
    "004_inventory.sql",
    "005_money.sql",
    "006_immutability.sql",
    "007_cs03_identity_permission.sql",
    "008_cs03_session_authority.sql",
    "009_cs04_sale_posting.sql",
    "010_cs05_shift.sql",
    "011_cs05_shift_logic.sql",
    "012_cs05_shift_api.sql",
    "013_cs05_handover_target.sql",
    "014_cs05_cash_integration.sql",
    "cs06_p1_products_suppliers_units_test.sql",
    "cs06_p2a_rls_fix_test.sql",
    "cs06_p2b_inventory_balances_test.sql",
    "cs06_p2c_migrate_to_stock_items_test.sql",
    "cs06_p3_purchase_orders_test.sql",
    "cs06_p4_goods_receipts_test.sql",
    "cs06_p4r1_grn_hardening_test.sql",
    "cs06_p5_bom_foundation_test.sql",
    "cs06_p6_production_execution_test.sql",
    "cs06_p7_restock_transfer_test.sql",
    "cs06_p8_inventory_controls_test.sql",
    "fin_closure_owner_equity_personal_accounts_test.sql",
    "fin_p1_finance_foundation_test.sql",
    "fin_p2a_shift_funding_bridge_test.sql",
    "fin_p2b1_expense_index_hardening_test.sql",
    "fin_p2b_shift_expense_test.sql",
    "fin_p3_customer_debt_foundation_test.sql",
    "fin_p3a_rls_authority_bridge_test.sql",
    "fin_p4_qris_settlement_reconciliation_test.sql",
    "fin_p5_supplier_payable_foundation_test.sql",
    "fin_p5a_supplier_payment_method_api_test.sql",
    "fin_p5b_supplier_read_authority_test.sql",
    "fin_p6_expense_approval_test.sql",
    "fin_p7_employee_kasbon_foundation_test.sql",
    "uat_blocker_core_ui_recovery_test.sql",
    "uat_r1_sale_replay_stock_gate_test.sql",
    "uat_r2_recovery_index_hardening_test.sql",
    "uat_r3_purchase_front_door_test.sql",
]


class CS02MigrationSourceTests(unittest.TestCase):
    def test_exact_migration_history_is_source_controlled(self) -> None:
        self.assertEqual(
            sorted(path.name for path in MIGRATIONS.glob("*.sql")),
            EXPECTED_MIGRATIONS,
        )

    def test_exact_sql_integration_suite_is_present(self) -> None:
        self.assertEqual(
            sorted(path.name for path in SQL_TESTS.glob("*.sql")),
            EXPECTED_SQL_TESTS,
        )
        for name in EXPECTED_SQL_TESTS:
            source = (SQL_TESTS / name).read_text(encoding="utf-8").lower()
            self.assertTrue(source.lstrip().startswith("begin;"), name)
            self.assertTrue(source.rstrip().endswith("rollback;"), name)

    def test_authority_primitives_are_present(self) -> None:
        source = "\n".join(
            (MIGRATIONS / name).read_text(encoding="utf-8")
            for name in EXPECTED_MIGRATIONS
        )
        required = [
            "private.schema_versions",
            "public.businesses",
            "public.locations",
            "public.stock_items",
            "public.money_accounts",
            "public.operation_receipts",
            "public.audit_events",
            "public.inventory_movements",
            "public.inventory_movement_lines",
            "public.money_movements",
            "public.inventory_balances",
            "public.money_balances",
            "private.lock_operation",
            "private.record_inventory_movement",
            "private.record_money_movement",
            "enable row level security",
            "SJ_IMMUTABLE_FACT",
        ]
        for token in required:
            self.assertIn(token, source)

    def test_deterministic_reference_seeds_are_present(self) -> None:
        source = (MIGRATIONS / EXPECTED_MIGRATIONS[1]).read_text(encoding="utf-8")
        for token in [
            "'SJ'",
            "'GUDANG'",
            "'GERAI'",
            "'KAS_UTAMA'",
            "'BANK'",
            "'QRIS_BELUM_CAIR'",
            "'QRIS_SUDAH_CAIR'",
        ]:
            self.assertIn(token, source)

    def test_fix_forward_source_anchor_correction_is_explicit(self) -> None:
        legacy = "c7bce7498b27ea6bd5f8c1981597f068ca4f6f53"
        canonical = "c7bce7498b27eab6d5f8c1981597f068ca4f6f53"
        first = (MIGRATIONS / EXPECTED_MIGRATIONS[0]).read_text(encoding="utf-8")
        correction = (MIGRATIONS / "20260907013121_cs02_correct_schema_source_anchor.sql").read_text(encoding="utf-8")
        self.assertIn(legacy, first)
        self.assertIn(legacy, correction)
        self.assertIn(canonical, correction)

    def test_no_embedded_secret_assignments(self) -> None:
        secret_assignment = re.compile(
            r"(?im)(service_role|supabase_service_role_key|database_url|password|access_token)\s*=\s*[^\s]"
        )
        for path in [*MIGRATIONS.glob("*.sql"), *SQL_TESTS.glob("*.sql")]:
            source = path.read_text(encoding="utf-8")
            self.assertIsNone(secret_assignment.search(source), path.name)


if __name__ == "__main__":
    unittest.main()
