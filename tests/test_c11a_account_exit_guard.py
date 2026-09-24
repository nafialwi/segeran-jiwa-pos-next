from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MENU = ROOT / "src/screens/MenuScreen.tsx"
DRAFT = ROOT / "src/sales/sales-draft.ts"


class C11AAccountExitGuardTests(unittest.TestCase):
    def test_switch_and_logout_check_shift_and_draft_before_action(self):
        menu = MENU.read_text(encoding="utf-8")
        draft = DRAFT.read_text(encoding="utf-8")
        self.assertIn("fetchMyOpenShift()", menu)
        self.assertIn("hasSalesDraftForProfile", menu)
        self.assertIn("confirmAction", menu)
        self.assertIn("runAccountAction('switch')", menu)
        self.assertIn("runAccountAction('logout')", menu)
        self.assertIn("Status shift tidak dapat diverifikasi", menu)
        self.assertIn("export function hasSalesDraftForProfile", draft)


if __name__ == "__main__":
    unittest.main()
