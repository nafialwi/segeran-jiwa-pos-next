from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests/browser-harness/f17"
CONFIG = (FIXTURE / "vite.config.mjs").read_text(encoding="utf-8")
MAIN = (FIXTURE / "main.tsx").read_text(encoding="utf-8")
MOCK_PRODUCTION = (FIXTURE / "stub-production.ts").read_text(encoding="utf-8")
MOCK_AUTH = (FIXTURE / "stub-auth.ts").read_text(encoding="utf-8")
BROWSER = (FIXTURE / "verify-browser.py").read_text(encoding="utf-8")


class C11F17BrowserFixtureTests(unittest.TestCase):
    def test_harness_is_separate_from_production_build(self):
        production = (ROOT / "vite.config.ts").read_text(encoding="utf-8")
        entry = (ROOT / "src/main.tsx").read_text(encoding="utf-8")
        self.assertNotIn("browser-harness", production)
        self.assertNotIn("browser-harness", entry)
        self.assertIn("f17-browser-fixture-only", CONFIG)
        self.assertIn("host: '127.0.0.1'", CONFIG)
        self.assertIn("strictPort: true", CONFIG)

    def test_real_ui_components_used_without_live_login(self):
        self.assertIn("src/components/AppShell", MAIN)
        self.assertIn("src/screens/MenuScreen", MAIN)
        self.assertIn("src/screens/ProductionScreen", MAIN)
        self.assertIn("fixture-notice", MAIN)
        self.assertIn("TANPA DATABASE", MAIN)
        self.assertIn("fixture-profile", MOCK_AUTH)
        self.assertIn("kasir-demo", MOCK_AUTH)

    def test_fixture_cannot_post_production_batches(self):
        self.assertIn("async function createProductionBatch", MOCK_PRODUCTION)
        self.assertIn("async function postProductionBatch", MOCK_PRODUCTION)
        self.assertGreaterEqual(MOCK_PRODUCTION.count("throw new Error("), 2)
        self.assertNotIn("supabase", MOCK_PRODUCTION.lower())
        self.assertNotIn("fetch(", MOCK_PRODUCTION)

    def test_browser_runner_verifies_interaction_and_responsiveness(self):
        for size in ("320,740", "390,844", "412,915", "768,1024", "1280,800"):
            self.assertIn(size, BROWSER)
        self.assertIn("production-batch-card", BROWSER)
        self.assertIn("menu-card strong", BROWSER)
        self.assertIn("BROWSER_F17_PASS", BROWSER)
        self.assertIn("doc", BROWSER)
        self.assertIn("screenshot", BROWSER)

    def test_visual_evidence_is_fixture_labelled(self):
        self.assertIn("KHUSUS UJI UI", MAIN)
        self.assertTrue((FIXTURE / "fixture.css").is_file())
        for relative in ("menu-owner-390.png", "menu-kasir-390.png",
                         "produksi-owner-390.png", "produksi-batch-owner-390.png"):
            self.assertTrue((ROOT / "docs/visual-evidence/c11f17" / relative).is_file())


if __name__ == "__main__":
    unittest.main()
