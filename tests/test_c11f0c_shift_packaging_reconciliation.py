from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = (
    ROOT
    / "supabase/migrations/20260923150000_c11f0c_shift_packaging_reconciliation.sql"
)
SHIFT_API = ROOT / "src/shift/shift-api.ts"
SHIFT_SCREEN = ROOT / "src/screens/ShiftManagementScreen.tsx"
INVENTORY_API = ROOT / "src/inventory/inventory-control-api.ts"
SHIFT_CORE = ROOT / "src/shift/shift-core.ts"
CSS = ROOT / "src/app.css"


class C11F0CShiftPackagingReconciliationTests(unittest.TestCase):
    def test_shift_checkpoints_extend_canonical_inventory_count_not_second_engine(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("alter table public.inventory_counts", sql)
        self.assertIn("add column shift_id uuid references public.shifts", sql)
        self.assertIn("add column shift_checkpoint text", sql)
        self.assertIn("inventory_counts_shift_checkpoint_shape", sql)
        self.assertIn("inventory_counts_shift_checkpoint_idx", sql)
        self.assertNotIn("create table public.shift_packaging_stock", sql)
        self.assertNotIn("create table public.cup", sql.lower())

    def test_shift_link_is_immutable_and_count_attempts_remain_auditable(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("guard_inventory_count_shift_link", sql)
        self.assertIn("INVENTORY_COUNT_SHIFT_LINK_IMMUTABLE", sql)
        self.assertIn("order by c.snapshot_at desc, c.created_at desc", sql)
        self.assertNotIn("inventory_counts_shift_checkpoint_unique", sql)
        self.assertIn("SHIFT_PACKAGING_COUNT_CREATED", sql)

    def test_checkpoint_create_is_permission_shift_scope_and_location_bounded(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        create = sql[
            sql.index("create or replace function public.create_shift_packaging_count"):
            sql.index("create or replace function public.shift_packaging_reconciliation")
        ]
        self.assertIn("private.has_permission(v_business, 'INVENTORY_COUNT')", create)
        self.assertIn("v_shift.cashier_profile_id <> v_actor", create)
        self.assertIn("private.has_inventory_location_scope", create)
        self.assertIn("v_shift.status <> 'OPEN'", create)
        self.assertIn("si.item_kind = 'PACKAGING'", create)
        self.assertIn("si.inventory_tracked", create)
        self.assertIn("private.lock_operation(", create)
        self.assertIn("private.record_operation_success(", create)
        self.assertIn("insert into public.inventory_counts", create)
        self.assertIn("insert into public.inventory_count_lines", create)

    def test_opening_is_never_reconstructed_after_first_sale(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("sale.shift_id = p_shift", sql)
        self.assertIn("SJ_SHIFT_PACKAGING_OPENING_TOO_LATE", sql)
        self.assertIn("v_checkpoint = 'OPENING' and v_has_sales", sql)
        self.assertIn("v_count.status = 'POSTED'", sql)

    def test_stale_checkpoint_can_be_superseded_without_mutating_old_fact(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        self.assertIn("v_existing_stale", sql)
        self.assertIn("im_after.created_at > v_count.snapshot_at", sql)
        self.assertIn("im_after.id <> v_count.movement_id", sql)
        self.assertNotIn("delete from public.inventory_counts", sql.lower())
        self.assertNotIn("update public.inventory_count_lines", sql.lower())

    def test_projection_combines_physical_theoretical_expected_and_variance(self):
        sql = MIGRATION.read_text(encoding="utf-8")
        projection = sql[sql.index("create or replace function public.shift_packaging_reconciliation"):]
        for token in (
            "public.inventory_count_lines opening_line",
            "public.inventory_count_lines closing_line",
            "public.sale_item_component_snapshots snap",
            "snap.component_role = 'PACKAGING'",
            "current_expected_quantity",
            "opening_physical_quantity",
            "theoretical_usage",
            "closing_expected_quantity",
            "closing_physical_quantity",
            "closing_line.physical_quantity",
            "- closing_line.expected_quantity",
            "closing_stale",
        ):
            self.assertIn(token, projection)

    def test_frontend_uses_projection_rpc_with_c10_fail_closed_fallback(self):
        api = SHIFT_API.read_text(encoding="utf-8")
        self.assertIn("supabase.rpc('shift_packaging_reconciliation'", api)
        self.assertIn("isMissingShiftPackagingReconciliationRpc", api)
        self.assertIn("PGRST202", api)
        self.assertIn("fetchShiftPackagingUsage(shiftId)", api)
        self.assertIn("ready: false", api)
        self.assertIn("supabase.rpc('create_shift_packaging_count'", api)
        self.assertIn("requireOnlineAction(", api)
        self.assertNotIn(".from('inventory_counts').insert", api)

    def test_screen_records_physical_through_existing_inventory_count_authority(self):
        screen = SHIFT_SCREEN.read_text(encoding="utf-8")
        inventory_api = INVENTORY_API.read_text(encoding="utf-8")
        for token in (
            "recordInventoryCount",
            "postInventoryCount",
            "Mulai Hitung Opening",
            "Simpan Hitungan Opening",
            "Posting Opening",
            "Mulai Hitung Closing",
            "Hitung Ulang Closing",
            "Posting Closing",
            "Awal Fisik",
            "Pemakaian Teoritis",
            "Expected Closing",
            "Fisik Closing",
            "Selisih",
        ):
            self.assertIn(token, screen)
        self.assertIn("supabase.rpc('record_inventory_count'", inventory_api)
        self.assertIn("supabase.rpc('post_inventory_count'", inventory_api)

    def test_shift_close_is_not_silently_hard_blocked_by_new_packaging_feature(self):
        screen = SHIFT_SCREEN.read_text(encoding="utf-8")
        self.assertIn("closing || !runningReconciliation || !actualCashValid", screen)
        self.assertNotIn("!packagingClosingComplete", screen[screen.index("Tutup Shift"):])
        self.assertIn("Shift tidak mengarang angka fisik", screen)

    def test_human_error_mapping_handles_stale_count_and_late_opening(self):
        core = SHIFT_CORE.read_text(encoding="utf-8")
        self.assertIn("error.message.startsWith('INVENTORY_')", core)
        self.assertIn("SJ_SHIFT_PACKAGING_OPENING_TOO_LATE", core)
        self.assertIn("INVENTORY_COUNT_BALANCE_CHANGED", core)

    def test_mobile_reconciliation_cards_and_count_fields_are_declared(self):
        css = CSS.read_text(encoding="utf-8")
        for token in (
            "/* C11-F0C — Shift Packaging Reconciliation */",
            ".shift-packaging-checkpoints",
            ".shift-packaging-count-form",
            ".shift-packaging-reconciliation-grid",
            ".shift-packaging-reconciliation-card",
            "@media (max-width: 390px)",
        ):
            self.assertIn(token, css)


if __name__ == "__main__":
    unittest.main()
