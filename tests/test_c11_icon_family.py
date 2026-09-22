from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]
ICON_ROOT = ROOT / "public/icons/segeran-jiwa/locked"
MANIFEST = ICON_ROOT / "LOCKED_ASSET_MANIFEST.json"
REGISTRY = ROOT / "src/ui/iconRegistry.ts"


class C11IconFamilyTests(unittest.TestCase):
    def test_locked_legacy_svg_family_is_complete(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["production_svg_count"], 61)
        self.assertEqual(len(list(ICON_ROOT.rglob("*.svg"))), 61)

    def test_every_locked_svg_matches_legacy_manifest_checksum_key(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        keys = set(manifest["sha256"])
        actual = {
            str(path.relative_to(ICON_ROOT)).replace("\\", "/")
            for path in ICON_ROOT.rglob("*.svg")
        }
        self.assertEqual(actual, keys)

    def test_registry_uses_locked_svg_paths_not_png_subset(self):
        source = REGISTRY.read_text(encoding="utf-8")
        self.assertIn("'/icons/segeran-jiwa/locked'", source)
        self.assertIn(".svg", source)
        self.assertNotIn(".png", source)


if __name__ == "__main__":
    unittest.main()
