from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
SCREENS = SRC / "screens"
CSS = SRC / "app.css"

MATRIX_WIDTHS = (320, 360, 390, 412, 768, 1024, 1440)


class C11F7ResponsiveMatrixTests(unittest.TestCase):
    def test_matrix_covers_phone_tablet_and_desktop_widths(self):
        self.assertEqual(MATRIX_WIDTHS[:4], (320, 360, 390, 412))
        self.assertIn(768, MATRIX_WIDTHS)
        self.assertIn(1024, MATRIX_WIDTHS)
        self.assertIn(1440, MATRIX_WIDTHS)

    def test_every_screen_main_uses_bounded_layout_root(self):
        offenders = []
        for path in sorted(SCREENS.glob("*.tsx")):
            source = path.read_text(encoding="utf-8")
            for match in re.finditer(r'<main\s+className="([^"]+)"', source):
                classes = set(match.group(1).split())
                if not classes.intersection({"shell", "auth-page", "center-card"}):
                    offenders.append(path.name)
        self.assertEqual(offenders, [])

    def test_css_declares_matrix_breakpoints(self):
        css = CSS.read_text(encoding="utf-8")
        for token in [
            "@media (max-width: 360px)",
            "@media (max-width: 420px)",
            "@media (max-width: 520px)",
            "@media (max-width: 620px)",
            "@media (max-width: 759px)",
            "@media (min-width: 760px)",
            "@media (min-width: 960px)",
        ]:
            self.assertIn(token, css)

    def test_root_and_form_controls_are_overflow_bounded(self):
        css = CSS.read_text(encoding="utf-8")
        marker = "/* C11-F7 — full responsive & visual matrix hardening */"
        self.assertIn(marker, css)
        final = css[css.index(marker) :]
        self.assertIn("body {\n  overflow-x: clip;", final)
        self.assertIn("input:not([type='checkbox']):not([type='radio'])", final)
        self.assertIn("select,", final)
        self.assertIn("textarea {", final)
        self.assertIn("min-width: 0;", final)
        self.assertIn("max-width: 100%;", final)

    def test_narrow_action_rows_stack_instead_of_crushing_labels(self):
        css = CSS.read_text(encoding="utf-8")
        marker = "@media (max-width: 420px)"
        blocks = [part for part in css.split(marker)[1:] if "button-row" in part[:1400]]
        self.assertTrue(blocks)
        final_block = blocks[-1][:1600]
        self.assertIn(".button-row > .primary-button", final_block)
        self.assertIn("flex-basis: 100%;", final_block)
        self.assertIn("width: 100%;", final_block)

    def test_mobile_navigation_and_filter_strips_remain_scrollable(self):
        css = CSS.read_text(encoding="utf-8")
        marker = "/* C11-F7 — full responsive & visual matrix hardening */"
        final = css[css.index(marker) :]
        for selector in [
            ".operations-nav",
            ".control-center-nav",
            ".secondary-workflow-nav",
            ".purchase-workflow-tabs",
            ".inventory-control-tabs",
            ".product-ops-tabs",
            ".report-period-presets",
        ]:
            self.assertIn(selector, final)
        self.assertIn("overscroll-behavior-inline: contain;", final)
        self.assertIn("-webkit-overflow-scrolling: touch;", final)

    def test_report_mobile_and_desktop_presentations_remain_separate(self):
        css = CSS.read_text(encoding="utf-8")
        self.assertIn(".report-mobile-list", css)
        self.assertIn(".report-desktop-table", css)
        self.assertIn(".report-desktop-table-wrap", css)
        self.assertRegex(
            css,
            re.compile(
                r"@media \(max-width: 759px\).*?\.report-mobile-list\s*\{\s*display: grid;.*?\.report-desktop-table-wrap\s*\{\s*display: none;",
                re.S,
            ),
        )

    def test_dialog_families_keep_mobile_sheet_and_desktop_modal_modes(self):
        css = CSS.read_text(encoding="utf-8")
        for selector in [
            ".action-dialog-sheet",
            ".searchable-item-dialog",
            ".product-master-dialog",
            ".sales-v2-sheet",
        ]:
            self.assertIn(selector, css)
        self.assertIn("border-radius: var(--sj-radius-sheet) var(--sj-radius-sheet) 0 0;", css)
        self.assertIn("@media (min-width: 760px)", css)

    def test_screen_source_has_no_inline_min_width_trap(self):
        offenders = []
        for path in SRC.rglob("*.tsx"):
            if "minWidth:" in path.read_text(encoding="utf-8"):
                offenders.append(str(path.relative_to(ROOT)))
        self.assertEqual(offenders, [])

    def test_bottom_navigation_reserves_safe_area(self):
        css = CSS.read_text(encoding="utf-8")
        self.assertIn(".app-main {", css)
        self.assertIn("padding-bottom: calc(var(--sj-bottom-nav-height) + 18px);", css)
        self.assertIn("env(safe-area-inset-bottom)", css)
        self.assertIn(".app-bottom-nav", css)

    def test_f7_does_not_add_database_migration(self):
        names = [path.name.lower() for path in (ROOT / "supabase/migrations").glob("*.sql")]
        self.assertFalse(any("c11f7" in name for name in names))


if __name__ == "__main__":
    unittest.main()
