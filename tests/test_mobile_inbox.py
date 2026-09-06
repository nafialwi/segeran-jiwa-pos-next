from __future__ import annotations

import hashlib
import json
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path

from tools.mobile_inbox.contract import validate_archive

BASE_COMMIT = "0123456789abcdef0123456789abcdef01234567"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def valid_manifest(payload: bytes) -> dict:
    return {
        "package_id": "SJPOSNEXT-CS-01-R1",
        "milestone": "CS-01",
        "title": "Core System: Repository, Mobile Inbox & Automation Foundation",
        "revision": "R1",
        "package_type": "patch",
        "blueprint_baseline": "1.0",
        "target_branch": "work/cs-01-r1",
        "base_commit": BASE_COMMIT,
        "schema_version_expected": 0,
        "retry_safe": False,
        "files_manifest": [
            {
                "path": "src/example.ts",
                "sha256": sha256_bytes(payload),
            }
        ],
        "delete_paths": [],
    }


class MobileInboxArchiveTests(unittest.TestCase):
    def make_zip(self, manifest: dict | None, entries: dict[str, bytes]) -> Path:
        temp_dir = Path(tempfile.mkdtemp())
        zip_path = temp_dir / "package.zip"
        with zipfile.ZipFile(zip_path, "w") as archive:
            if manifest is not None:
                archive.writestr(
                    "package-manifest.json",
                    json.dumps(manifest, sort_keys=True),
                )
            for name, data in entries.items():
                archive.writestr(name, data)
        self.addCleanup(lambda: shutil.rmtree(temp_dir, ignore_errors=True))
        return zip_path

    def validate(self, zip_path: Path) -> dict:
        extract_dir = Path(tempfile.mkdtemp())
        shutil.rmtree(extract_dir)
        self.addCleanup(lambda: shutil.rmtree(extract_dir, ignore_errors=True))
        return validate_archive(zip_path, extract_dir, current_schema_version=0)

    def test_accepts_valid_patch(self):
        payload = b"export const value = 1;\n"
        manifest = valid_manifest(payload)
        result = self.validate(
            self.make_zip(manifest, {"payload/src/example.ts": payload})
        )
        self.assertEqual(result["package_type"], "patch")

    def test_accepts_normal_payload_directory_entries(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        zip_path = Path(tempfile.mkdtemp()) / "package.zip"
        self.addCleanup(lambda: shutil.rmtree(zip_path.parent, ignore_errors=True))
        with zipfile.ZipFile(zip_path, "w") as archive:
            archive.writestr("package-manifest.json", json.dumps(manifest))
            archive.writestr("payload/", b"")
            archive.writestr("payload/src/", b"")
            archive.writestr("payload/src/example.ts", payload)
        result = self.validate(zip_path)
        self.assertEqual(result["package_id"], manifest["package_id"])

    def test_rejects_missing_manifest(self):
        with self.assertRaisesRegex(ValueError, "manifest"):
            self.validate(self.make_zip(None, {"payload/src/example.ts": b"x"}))

    def test_rejects_duplicate_root_manifest(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        zip_path = Path(tempfile.mkdtemp()) / "package.zip"
        self.addCleanup(lambda: shutil.rmtree(zip_path.parent, ignore_errors=True))
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(zip_path, "w") as archive:
                archive.writestr("package-manifest.json", json.dumps(manifest))
                archive.writestr("package-manifest.json", json.dumps(manifest))
                archive.writestr("payload/src/example.ts", payload)
        with self.assertRaisesRegex(ValueError, "manifest"):
            self.validate(zip_path)

    def test_rejects_invalid_manifest_json(self):
        payload = b"x"
        zip_path = Path(tempfile.mkdtemp()) / "package.zip"
        self.addCleanup(lambda: shutil.rmtree(zip_path.parent, ignore_errors=True))
        with zipfile.ZipFile(zip_path, "w") as archive:
            archive.writestr("package-manifest.json", "{not-json")
            archive.writestr("payload/src/example.ts", payload)
        with self.assertRaises(ValueError):
            self.validate(zip_path)

    def test_rejects_zip_slip_path(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        with self.assertRaisesRegex(ValueError, "unsafe"):
            self.validate(
                self.make_zip(
                    manifest,
                    {"payload/../../.github/workflows/pwn.yml": payload},
                )
            )

    def test_rejects_absolute_path(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        with self.assertRaisesRegex(ValueError, "unsafe"):
            self.validate(self.make_zip(manifest, {"/payload/src/example.ts": payload}))

    def test_rejects_backslash_path(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        with self.assertRaisesRegex(ValueError, "unsafe"):
            self.validate(self.make_zip(manifest, {"payload\\..\\evil.txt": payload}))

    def test_rejects_directory_traversal_entry(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        zip_path = Path(tempfile.mkdtemp()) / "package.zip"
        self.addCleanup(lambda: shutil.rmtree(zip_path.parent, ignore_errors=True))
        with zipfile.ZipFile(zip_path, "w") as archive:
            archive.writestr("package-manifest.json", json.dumps(manifest))
            archive.writestr("payload/../evil/", b"")
            archive.writestr("payload/src/example.ts", payload)
        with self.assertRaisesRegex(ValueError, "unsafe"):
            self.validate(zip_path)

    def test_rejects_wrong_blueprint_baseline(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        manifest["blueprint_baseline"] = "0.9"
        with self.assertRaisesRegex(ValueError, "blueprint"):
            self.validate(
                self.make_zip(manifest, {"payload/src/example.ts": payload})
            )

    def test_rejects_wrong_schema_version(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        manifest["schema_version_expected"] = 1
        with self.assertRaisesRegex(ValueError, "schema"):
            self.validate(
                self.make_zip(manifest, {"payload/src/example.ts": payload})
            )

    def test_rejects_bad_file_checksum(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        manifest["files_manifest"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "checksum"):
            self.validate(
                self.make_zip(manifest, {"payload/src/example.ts": payload})
            )

    def test_rejects_undeclared_payload_file(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        with self.assertRaisesRegex(ValueError, "undeclared"):
            self.validate(
                self.make_zip(
                    manifest,
                    {
                        "payload/src/example.ts": payload,
                        "payload/src/extra.ts": b"extra",
                    },
                )
            )

    def test_rejects_non_payload_extra_file(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        with self.assertRaisesRegex(ValueError, "undeclared"):
            self.validate(
                self.make_zip(
                    manifest,
                    {
                        "payload/src/example.ts": payload,
                        "README.txt": b"not allowed",
                    },
                )
            )

    def test_rejects_missing_declared_payload_file(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        with self.assertRaisesRegex(ValueError, "missing"):
            self.validate(self.make_zip(manifest, {}))

    def test_rejects_protected_workflow_write(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        manifest["files_manifest"] = [
            {
                "path": ".github/workflows/pwn.yml",
                "sha256": sha256_bytes(payload),
            }
        ]
        with self.assertRaisesRegex(ValueError, "protected"):
            self.validate(
                self.make_zip(
                    manifest,
                    {"payload/.github/workflows/pwn.yml": payload},
                )
            )

    def test_rejects_transport_state_write(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        manifest["files_manifest"] = [
            {
                "path": "processed/receipt.json",
                "sha256": sha256_bytes(payload),
            }
        ]
        with self.assertRaisesRegex(ValueError, "protected"):
            self.validate(
                self.make_zip(manifest, {"payload/processed/receipt.json": payload})
            )

    def test_rejects_secret_like_path(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        manifest["files_manifest"] = [
            {
                "path": "config/.env.local",
                "sha256": sha256_bytes(payload),
            }
        ]
        with self.assertRaisesRegex(ValueError, "forbidden"):
            self.validate(
                self.make_zip(manifest, {"payload/config/.env.local": payload})
            )

    def test_rejects_duplicate_files_manifest_path(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        manifest["files_manifest"].append(dict(manifest["files_manifest"][0]))
        with self.assertRaisesRegex(ValueError, "duplicate files_manifest"):
            self.validate(
                self.make_zip(manifest, {"payload/src/example.ts": payload})
            )

    def test_rejects_duplicate_delete_path(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        manifest["delete_paths"] = ["src/old.ts", "src/old.ts"]
        with self.assertRaisesRegex(ValueError, "duplicate delete_paths"):
            self.validate(
                self.make_zip(manifest, {"payload/src/example.ts": payload})
            )

    def test_rejects_unsafe_target_branch(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        manifest["target_branch"] = "main"
        with self.assertRaisesRegex(ValueError, "target branch"):
            self.validate(
                self.make_zip(manifest, {"payload/src/example.ts": payload})
            )

    def test_rejects_malformed_base_commit(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        manifest["base_commit"] = "abc"
        with self.assertRaisesRegex(ValueError, "base_commit"):
            self.validate(
                self.make_zip(manifest, {"payload/src/example.ts": payload})
            )

    def test_rejects_unsupported_package_type(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        manifest["package_type"] = "automation_patch"
        with self.assertRaisesRegex(ValueError, "package_type"):
            self.validate(
                self.make_zip(manifest, {"payload/src/example.ts": payload})
            )

    def test_rejects_duplicate_normalized_zip_entry(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        zip_path = Path(tempfile.mkdtemp()) / "package.zip"
        self.addCleanup(lambda: shutil.rmtree(zip_path.parent, ignore_errors=True))
        with zipfile.ZipFile(zip_path, "w") as archive:
            archive.writestr("package-manifest.json", json.dumps(manifest))
            archive.writestr("payload/src/example.ts", payload)
            archive.writestr("payload//src/example.ts", payload)
        with self.assertRaisesRegex(ValueError, "duplicate normalized"):
            self.validate(zip_path)

    def test_rejects_symlink_like_entry(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        zip_path = Path(tempfile.mkdtemp()) / "package.zip"
        self.addCleanup(lambda: shutil.rmtree(zip_path.parent, ignore_errors=True))
        with zipfile.ZipFile(zip_path, "w") as archive:
            archive.writestr("package-manifest.json", json.dumps(manifest))
            info = zipfile.ZipInfo("payload/src/example.ts")
            info.create_system = 3
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(info, payload)
        with self.assertRaisesRegex(ValueError, "symlink"):
            self.validate(zip_path)

    def test_cli_validate_works_when_invoked_by_file_path(self):
        payload = b"x"
        manifest = valid_manifest(payload)
        zip_path = self.make_zip(manifest, {"payload/src/example.ts": payload})
        extract_dir = Path(tempfile.mkdtemp())
        shutil.rmtree(extract_dir)
        self.addCleanup(lambda: shutil.rmtree(extract_dir, ignore_errors=True))
        result = subprocess.run(
            [
                sys.executable,
                "tools/mobile_inbox/intake.py",
                "validate",
                str(zip_path),
                "--extract-dir",
                str(extract_dir),
                "--schema-version-current",
                "0",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        normalized = json.loads(result.stdout)
        self.assertEqual(normalized["package_type"], "patch")


if __name__ == "__main__":
    unittest.main()
