from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
CSS = ROOT / "src/app.css"


class C11DVisualDensityTests(unittest.TestCase):
    def setUp(self):
        css = CSS.read_text(encoding="utf-8")
        marker = "/* C11-D2 — operational density & alignment convergence */"
        self.assertIn(marker, css)
        self.final = css[css.index(marker):]

    def test_headers_share_compact_geometry_without_touch_target_regression(self):
        self.assertIn(
            ".operations-shell > .topbar.operations-header,",
            self.final,
        )
        self.assertIn(
            ".secondary-screen > .topbar.secondary-hero",
            self.final,
        )
        self.assertIn("padding: 13px 15px;", self.final)
        self.assertIn("font-size: clamp(1.35rem, 3vw, 1.8rem);", self.final)
        self.assertIn("min-height: var(--sj-touch-min);", self.final)

    def test_panels_forms_and_buttons_use_consistent_density(self):
        self.assertIn(".operations-shell .operations-panel,", self.final)
        self.assertIn("padding: 14px;", self.final)
        self.assertIn(".operations-shell .stack-form,", self.final)
        self.assertIn("gap: 10px;", self.final)
        self.assertIn(".operations-shell .button-row,", self.final)
        self.assertIn("gap: 8px;", self.final)

    def test_mobile_density_has_scoped_breakpoints(self):
        self.assertIn("@media (max-width: 759px)", self.final)
        self.assertIn("@media (max-width: 420px)", self.final)
        self.assertIn("padding: 11px 12px;", self.final)
        self.assertIn("font-size: 1.32rem;", self.final)

    def test_sales_specific_shell_is_not_overridden(self):
        self.assertNotIn(".sales-v2-shell", self.final)
        self.assertNotIn(".sales-v2-header", self.final)


if __name__ == "__main__":
    unittest.main()
