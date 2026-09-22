from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
CSS = ROOT / "src/app.css"


class C10MobileFirstHardeningTests(unittest.TestCase):
    def test_global_shell_cannot_expand_past_mobile_viewport(self):
        css = CSS.read_text(encoding="utf-8")
        self.assertIn("/* C10 — Mobile-first UAT hardening */", css)
        self.assertIn("overflow-x: hidden;", css)
        self.assertIn("grid-auto-columns: minmax(0, 1fr);", css)

    def test_mobile_route_shells_share_narrow_safe_width(self):
        css = CSS.read_text(encoding="utf-8")
        for token in [
            ".sales-v2-shell",
            ".dashboard-shell",
            ".operations-shell",
            ".control-page",
            ".control-center-screen",
            ".secondary-screen",
        ]:
            self.assertIn(token, css)
        self.assertIn("width: calc(100% - 16px);", css)

    def test_horizontal_workflow_navigation_remains_scrollable(self):
        css = CSS.read_text(encoding="utf-8")
        for token in [
            ".operations-nav",
            ".control-center-nav",
            ".secondary-workflow-nav",
            ".purchase-workflow-tabs",
            ".inventory-control-tabs",
            ".product-ops-tabs",
        ]:
            self.assertIn(token, css)
        self.assertIn("scroll-snap-type: x proximity;", css)
        self.assertIn("-webkit-overflow-scrolling: touch;", css)

    def test_narrow_phone_kpis_can_collapse_to_one_column(self):
        css = CSS.read_text(encoding="utf-8")
        self.assertIn("@media (max-width: 360px)", css)
        self.assertIn(".dashboard-kpi-grid", css)
        self.assertIn(".shift-kpi-grid", css)


if __name__ == "__main__":
    unittest.main()
