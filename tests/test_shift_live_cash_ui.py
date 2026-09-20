from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
SCREEN=ROOT/"src"/"screens"/"ShiftManagementScreen.tsx"

class ShiftLiveCashUiTests(unittest.TestCase):
    def test_open_shift_fetches_live_reconciliation(self):
        s=SCREEN.read_text(encoding="utf-8")
        self.assertIn("fetchShiftReconciliation",s)
        self.assertIn("runningReconciliation",s)
        self.assertIn("Kas Berjalan",s)
        self.assertIn("Penjualan Tunai",s)
        self.assertIn("Uang Keluar",s)
        self.assertIn("runningReconciliation.expected_cash",s)

    def test_expense_refreshes_live_cash(self):
        s=SCREEN.read_text(encoding="utf-8")
        self.assertGreaterEqual(s.count("fetchShiftReconciliation(shift.id)"),2)
        self.assertNotIn("Mencatat&",s)

if __name__=="__main__":
    unittest.main()
