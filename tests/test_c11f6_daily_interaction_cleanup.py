from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
APP = SRC / "App.tsx"
DIALOG = SRC / "components/ActionDialogProvider.tsx"
CSS = SRC / "app.css"


class C11F6DailyInteractionCleanupTests(unittest.TestCase):
    def test_native_prompt_confirm_alert_are_removed_from_app_source(self):
        pattern = re.compile(r"window\.(?:prompt|confirm|alert)\s*\(")
        offenders = []
        for path in SRC.rglob("*"):
            if path.suffix not in {".ts", ".tsx"}:
                continue
            if pattern.search(path.read_text(encoding="utf-8")):
                offenders.append(str(path.relative_to(ROOT)))
        self.assertEqual(offenders, [])

    def test_shared_action_dialog_is_global_accessible_and_escape_safe(self):
        app = APP.read_text(encoding="utf-8")
        source = DIALOG.read_text(encoding="utf-8")
        self.assertIn("<ActionDialogProvider>", app)
        self.assertIn('role="dialog"', source)
        self.assertIn('aria-modal="true"', source)
        self.assertIn("event.key !== 'Escape'", source)
        self.assertIn("document.body.style.overflow = 'hidden'", source)
        self.assertIn("window.requestAnimationFrame", source)
        self.assertIn("confirmAction", source)
        self.assertIn("promptAction", source)

    def test_number_inputs_declare_mobile_keyboard_intent(self):
        missing = []
        for path in SRC.rglob("*.tsx"):
            source = path.read_text(encoding="utf-8")
            for match in re.finditer(r"<input\b.*?/>", source, flags=re.S):
                tag = match.group(0)
                if 'type="number"' in tag and "inputMode=" not in tag:
                    missing.append(str(path.relative_to(ROOT)))
        self.assertEqual(missing, [])

    def test_destructive_flows_use_in_app_confirmation(self):
        expected = {
            "screens/LegacyImportScreen.tsx": "confirmAction",
            "screens/TransactionHistoryScreen.tsx": "confirmAction",
            "screens/OperationalMessageScreen.tsx": "confirmAction",
            "screens/FinanceScreen.tsx": "confirmAction",
            "screens/OwnerUsersScreen.tsx": "confirmAction",
        }
        for relative, token in expected.items():
            source = (SRC / relative).read_text(encoding="utf-8")
            self.assertIn("useActionDialog", source, relative)
            self.assertIn(token, source, relative)

    def test_prompt_workflows_are_cancelable_in_app_forms(self):
        owner = (SRC / "screens/OwnerUsersScreen.tsx").read_text(encoding="utf-8")
        approval = (SRC / "screens/ExpenseApprovalScreen.tsx").read_text(
            encoding="utf-8"
        )
        self.assertIn("promptAction", owner)
        self.assertIn("inputType: 'password'", owner)
        self.assertIn("minLength: 8", owner)
        self.assertIn("maxLength: 72", owner)
        self.assertIn("promptAction", approval)
        self.assertIn("if (reason === null) return;", approval)

    def test_action_dialog_has_mobile_sheet_and_desktop_modal_geometry(self):
        css = CSS.read_text(encoding="utf-8")
        marker = "/* C11-F6 — daily interaction cleanup */"
        self.assertIn(marker, css)
        final = css[css.index(marker) :]
        self.assertIn(".action-dialog-backdrop", final)
        self.assertIn(".action-dialog-sheet", final)
        self.assertIn("align-items: flex-end;", final)
        self.assertIn("@media (min-width: 760px)", final)
        self.assertIn("align-items: center;", final)
        self.assertIn(".action-dialog-danger", final)

    def test_f6_does_not_add_database_migration(self):
        names = [path.name.lower() for path in (ROOT / "supabase/migrations").glob("*.sql")]
        self.assertFalse(any("c11f6" in name for name in names))


if __name__ == "__main__":
    unittest.main()
