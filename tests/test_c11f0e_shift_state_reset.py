from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCREEN = ROOT / "src/screens/ShiftManagementScreen.tsx"
API = ROOT / "src/shift/shift-api.ts"
CSS = ROOT / "src/app.css"


class C11F0EShiftStateResetTests(unittest.TestCase):
    def test_native_blocking_alert_is_removed(self):
        source = SCREEN.read_text(encoding="utf-8")
        self.assertNotIn("alert(", source)
        self.assertIn("setShiftMessage(", source)
        self.assertIn("Shift berhasil ditutup. Varians kas:", source)

    def test_closing_cash_requires_fresh_physical_input(self):
        source = SCREEN.read_text(encoding="utf-8")
        self.assertIn("actualCashInput, setActualCashInput", source)
        self.assertIn("actualCashInput.trim() === ''", source)
        self.assertIn("Uang aktual wajib diisi dari hasil hitung fisik.", source)
        self.assertIn("!actualCashValid", source)
        self.assertIn("Belum diisi", source)
        self.assertIn("'—'", source)

    def test_open_and_close_clear_cross_shift_drafts(self):
        source = SCREEN.read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count("setOpeningBalance(0);"), 2)
        self.assertGreaterEqual(source.count("setActualCashInput('');"), 4)
        self.assertIn("setExpenseCategory('');", source)
        self.assertIn("setExpenseDescription('');", source)
        self.assertIn("setExpenseAmount(0);", source)
        self.assertIn("setExpenseMessage('');", source)
        self.assertIn("setPackagingMessage('');", source)

    def test_close_authority_is_unchanged(self):
        source = SCREEN.read_text(encoding="utf-8")
        api = API.read_text(encoding="utf-8")
        self.assertIn("closeShift(shift.id, actualCash)", source)
        self.assertIn("fetchShiftReconciliation(shift.id)", source)
        self.assertIn("fetchShiftPackagingReconciliation(shift.id)", source)
        self.assertIn("supabase.rpc(", api)
        self.assertNotIn(".from('shifts').update", source + api)

    def test_shift_touch_controls_remove_mobile_tap_residue(self):
        css = CSS.read_text(encoding="utf-8")
        self.assertIn("/* C11-F0E — Shift interaction state hardening */", css)
        self.assertIn("-webkit-tap-highlight-color: transparent", css)
        self.assertIn("touch-action: manipulation", css)
        self.assertIn("@media (hover: none), (pointer: coarse)", css)


if __name__ == "__main__":
    unittest.main()
