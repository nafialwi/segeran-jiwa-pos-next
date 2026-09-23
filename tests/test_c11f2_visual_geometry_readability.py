from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
CSS = ROOT / "src/app.css"


class C11F2VisualGeometryReadabilityTests(unittest.TestCase):
    def setUp(self):
        self.css = CSS.read_text(encoding="utf-8")
        marker = "/* C11-F2 — typography, geometry & readability convergence */"
        self.assertIn(marker, self.css)
        self.final = self.css[self.css.index(marker):]

    def test_typography_contract_has_readable_tokens(self):
        for token in (
            "--sj-font-micro: 0.68rem;",
            "--sj-font-caption: 0.72rem;",
            "--sj-font-small: 0.78rem;",
            "--sj-font-body: 0.875rem;",
            "--sj-line-body: 1.45;",
        ):
            self.assertIn(token, self.final)
    def test_form_controls_share_font_and_mobile_zoom_safe_size(self):
        self.assertIn("button,\ninput,\nselect,\ntextarea {\n  font: inherit;", self.final)
        self.assertIn("input,\n  select,\n  textarea {\n    font-size: 1rem;", self.final)

    def test_common_geometry_uses_design_tokens(self):
        for token in (
            "--sj-radius-control: 12px;",
            "--sj-radius-card: 16px;",
            "--sj-radius-sheet: 22px;",
            "--sj-touch-min: 44px;",
        ):
            self.assertIn(token, self.final)
        self.assertIn("border-radius: var(--sj-radius-card);", self.final)
        self.assertIn("min-height: var(--sj-touch-min);", self.final)

    def test_long_text_is_bounded_in_common_surfaces(self):
        self.assertIn("overflow-wrap: anywhere;", self.final)
        self.assertIn(".topbar > *", self.final)
        self.assertIn(".section-heading > *", self.final)
        self.assertIn(".product-ops-select strong", self.final)
    def test_daily_mobile_labels_are_not_micro_legacy_sizes(self):
        self.assertIn(".app-bottom-nav-link {\n  font-size: var(--sj-font-caption);", self.final)
        self.assertIn(".sales-v2-product-name {\n  font-size: 0.82rem;", self.final)
        self.assertIn(".sales-v2-variant-name {\n  font-size: var(--sj-font-caption);", self.final)
        self.assertIn(".sales-grid-4 .sales-v2-product-name {\n  font-size: var(--sj-font-caption);", self.final)

    def test_dialog_radius_matches_context(self):
        self.assertIn(".searchable-item-dialog,\n.product-master-dialog {\n  border-radius: var(--sj-radius-sheet);", self.final)
        self.assertIn("@media (max-width: 520px)", self.final)
        self.assertIn("@media (min-width: 760px)", self.final)

    def test_tables_and_status_messages_are_overflow_safe(self):
        self.assertIn("overscroll-behavior-inline: contain;", self.final)
        self.assertIn(".error-banner,\n.success-banner,\n.form-error", self.final)
        self.assertIn("overflow-wrap: anywhere;", self.final)


if __name__ == "__main__":
    unittest.main()
