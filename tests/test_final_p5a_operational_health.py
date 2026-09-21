from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "src" / "App.tsx"
COMPONENT = ROOT / "src" / "components" / "OperationalHealthBanner.tsx"
HEALTH = ROOT / "src" / "health" / "operational-health.ts"


class FinalP5AOperationalHealthTests(unittest.TestCase):
    def test_banner_is_global_at_app_shell(self):
        source = APP.read_text(encoding="utf-8")
        self.assertIn("OperationalHealthBanner", source)
        self.assertIn("<OperationalHealthBanner />", source)

    def test_connectivity_reacts_without_polling_or_backend_probe(self):
        source = COMPONENT.read_text(encoding="utf-8")
        self.assertIn("addEventListener('online'", source)
        self.assertIn("addEventListener('offline'", source)
        self.assertNotIn("setInterval", source)
        self.assertNotIn("supabase", source.lower())
        self.assertNotIn("fetch(", source)

    def test_online_state_does_not_claim_backend_health(self):
        source = HEALTH.read_text(encoding="utf-8")
        self.assertIn("needsAttention: false", source)
        self.assertIn("bukan pernyataan", source)
        self.assertIn("backend", source)
        self.assertIn("database", source)


if __name__ == "__main__":
    unittest.main()
