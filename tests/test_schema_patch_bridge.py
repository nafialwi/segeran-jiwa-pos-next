from __future__ import annotations

import hashlib
import json
import shutil
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.mobile_inbox.contract import PROTECTED_PREFIXES, validate_archive

BASE_COMMIT = "0123456789abcdef0123456789abcdef01234567"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def manifest_for(path: str, payload: bytes, package_type: str) -> dict:
    return {
        "package_id": "SJPOSNEXT-CS02-BRIDGE-TEST",
        "milestone": "CS-02",
        "title": "Schema Patch Bridge Test",
        "revision": "R1",
        "package_type": package_type,
        "blueprint_baseline": "1.0",
        "target_branch": "work/cs-02-bridge-test",
        "base_commit": BASE_COMMIT,
        "schema_version_expected": 0,
        "retry_safe": False,
        "files_manifest": [{"path": path, "sha256": sha256_bytes(payload)}],
        "delete_paths": [],
    }


class SchemaPatchBridgeTests(unittest.TestCase):
    def make_zip(self, manifest: dict, path: str, payload: bytes) -> Path:
        temp_dir = Path(tempfile.mkdtemp())
        self.addCleanup(lambda: shutil.rmtree(temp_dir))
        zip_path = temp_dir / "package.zip"
        with zipfile.ZipFile(zip_path, "w") as archive:
            archive.writestr(
                "package-manifest.json",
                json.dumps(manifest, sort_keys=True),
            )
            archive.writestr(f"payload/{path}", payload)
        return zip_path

    def validate(self, manifest: dict, path: str, payload: bytes) -> dict:
        temp_dir = Path(tempfile.mkdtemp())
        self.addCleanup(lambda: shutil.rmtree(temp_dir))
        extract_dir = temp_dir / "extract"
        return validate_archive(
            self.make_zip(manifest, path, payload),
            extract_dir,
            current_schema_version=0,
        )

    def test_schema_patch_accepts_migration_write(self):
        payload = b"select 1;\n"
        path = "supabase/migrations/202609070001_bridge_test.sql"
        manifest = manifest_for(path, payload, "schema_patch")
        result = self.validate(manifest, path, payload)
        self.assertEqual(result["package_type"], "schema_patch")

    def test_patch_still_rejects_migration_write(self):
        payload = b"select 1;\n"
        path = "supabase/migrations/202609070001_bridge_test.sql"
        manifest = manifest_for(path, payload, "patch")
        with self.assertRaisesRegex(ValueError, "protected"):
            self.validate(manifest, path, payload)

    def test_schema_patch_still_rejects_workflow_write(self):
        payload = b"name: nope\n"
        path = ".github/workflows/nope.yml"
        manifest = manifest_for(path, payload, "schema_patch")
        with self.assertRaisesRegex(ValueError, "protected"):
            self.validate(manifest, path, payload)

    def test_schema_patch_still_rejects_blueprint_write(self):
        payload = b"nope\n"
        path = "docs/blueprint/nope.md"
        manifest = manifest_for(path, payload, "schema_patch")
        with self.assertRaisesRegex(ValueError, "protected"):
            self.validate(manifest, path, payload)

    def test_schema_patch_rejects_migration_delete(self):
        payload = b"documentation only\n"
        path = "docs/checkpoints/schema-patch-test.md"
        manifest = manifest_for(path, payload, "schema_patch")
        manifest["delete_paths"] = [
            "supabase/migrations/202609060001_cs02_system_metadata.sql"
        ]
        with self.assertRaisesRegex(ValueError, "protected delete"):
            self.validate(manifest, path, payload)

    def test_schema_patch_preserves_all_other_protected_prefixes(self):
        payload = b"must stay protected\n"
        checked = 0
        for prefix in PROTECTED_PREFIXES:
            if prefix == "supabase/migrations/":
                continue
            checked += 1
            path = f"{prefix}bridge-probe.txt"
            manifest = manifest_for(path, payload, "schema_patch")
            with self.subTest(prefix=prefix):
                with self.assertRaisesRegex(ValueError, "protected"):
                    self.validate(manifest, path, payload)
        self.assertGreater(checked, 0)


if __name__ == "__main__":
    unittest.main()
