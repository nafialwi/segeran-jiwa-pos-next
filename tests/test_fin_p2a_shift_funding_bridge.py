from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase" / "migrations" / "20260920150000_fin_p2a_shift_funding_bridge.sql"
SHIFT_API = ROOT / "src" / "shift" / "shift-api.ts"
SHIFT_UI = ROOT / "src" / "screens" / "ShiftManagementScreen.tsx"
SHIFT_CORE = ROOT / "src" / "shift" / "shift-core.ts"

class FinP2AShiftFundingBridgeTests(unittest.TestCase):
    def test_migration_exists(self) -> None:
        self.assertTrue(MIGRATION.exists(), MIGRATION.name)

    def test_funding_contract_is_present(self) -> None:
        source = " ".join(MIGRATION.read_text(encoding="utf-8").lower().split())
        for token in [
            "opening_source_type",
            "opening_source_ref",
            "opening_money_movement_id",
            "finance_open_shift_from_main_cash",
            "finance_opening_source_required",
            "shift_open_main_cash",
            "'transfer'",
            "'kas_utama'",
            "'kas_shift'",
        ]:
            self.assertIn(token, source)

    def test_frontend_uses_funded_open_for_positive_balance(self) -> None:
        api = SHIFT_API.read_text(encoding="utf-8")
        ui = SHIFT_UI.read_text(encoding="utf-8")
        core = SHIFT_CORE.read_text(encoding="utf-8")
        self.assertIn("finance_open_shift_from_main_cash", api)
        self.assertIn("p_idempotency_key", api)
        self.assertIn("Kas Utama", ui)
        self.assertIn("FINANCE_OPENING_SOURCE_REQUIRED", core)
        self.assertIn("FINANCE_INSUFFICIENT_BALANCE", core)

if __name__ == "__main__":
    unittest.main()
