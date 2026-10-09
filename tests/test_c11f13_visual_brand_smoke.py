from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "public/brand"
LOGO = BRAND / "segeran-jiwa-logo-384.webp"
FALLBACK = BRAND / "segeran-jiwa-logo.png"


class C11F13VisualBrandSmokeTests(unittest.TestCase):
    def test_small_webp_brand_variant_is_valid_and_original_is_preserved(self):
        self.assertTrue(LOGO.is_file())
        self.assertLess(LOGO.stat().st_size, 40_000)
        raw = LOGO.read_bytes()
        self.assertEqual(raw[:4], b"RIFF")
        self.assertEqual(raw[8:12], b"WEBP")
        self.assertTrue(FALLBACK.is_file())

    def test_login_and_navigation_prefer_webp_but_keep_png_fallback(self):
        for relative in (
            "src/screens/LoginScreen.tsx",
            "src/components/AppShell.tsx",
            "src/screens/HomeScreen.tsx",
        ):
            content = (ROOT / relative).read_text(encoding="utf-8")
            with self.subTest(file=relative):
                self.assertIn('src="/brand/segeran-jiwa-logo.png"', content)
                self.assertIn('srcSet="/brand/segeran-jiwa-logo-384.webp"', content)

    def test_control_center_decorative_logo_uses_optimized_asset(self):
        css = (ROOT / "src/app.css").read_text(encoding="utf-8")
        self.assertIn("image-set(", css)
        self.assertIn("url('/brand/segeran-jiwa-logo-384.webp') type('image/webp')", css)
        self.assertIn("url('/brand/segeran-jiwa-logo.png') type('image/png')", css)


if __name__ == "__main__":
    unittest.main()
