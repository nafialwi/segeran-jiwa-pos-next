from __future__ import annotations

import hashlib
import json
import re
import stat
import zipfile
from pathlib import Path, PurePosixPath

BLUEPRINT_BASELINE = "1.0"
ALLOWED_PACKAGE_TYPES = {"patch", "schema_patch"}
TARGET_BRANCH_RE = re.compile(r"^work/[a-z0-9][a-z0-9._/-]*$")
SHA40_RE = re.compile(r"^[0-9a-f]{40}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")

PROTECTED_PREFIXES = (
    ".github/workflows/",
    "docs/blueprint/",
    "supabase/migrations/",
    "inbox/",
    "processed/",
)

FORBIDDEN_EXACT = {
    ".env",
    ".env.local",
    ".env.production",
}


def normalize_rel_path(raw: str) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or raw.startswith("/"):
        raise ValueError(f"unsafe path: {raw!r}")
    path = PurePosixPath(raw)
    if path.is_absolute() or ".." in path.parts or "." in path.parts:
        raise ValueError(f"unsafe path: {raw!r}")
    normalized = path.as_posix()
    if normalized.startswith("../") or normalized == "..":
        raise ValueError(f"unsafe path: {raw!r}")
    return normalized


def is_forbidden_path(path: str) -> bool:
    lower = path.lower()
    name = PurePosixPath(lower).name
    return (
        lower in FORBIDDEN_EXACT
        or name == ".env"
        or name.startswith(".env.")
        or "secret" in name
        or name.endswith((".pem", ".key", ".p12", ".pfx"))
    )


def is_protected_path(
    path: str,
    package_type: str = "patch",
    *,
    for_delete: bool = False,
) -> bool:
    if path.startswith("supabase/migrations/"):
        return for_delete or package_type != "schema_patch"
    return any(path.startswith(prefix) for prefix in PROTECTED_PREFIXES)


def validate_manifest(manifest: dict, current_schema_version: int) -> dict:
    if not isinstance(manifest, dict):
        raise ValueError("manifest must be a JSON object")

    required = {
        "package_id",
        "milestone",
        "title",
        "revision",
        "package_type",
        "blueprint_baseline",
        "target_branch",
        "base_commit",
        "schema_version_expected",
        "retry_safe",
        "files_manifest",
        "delete_paths",
    }
    if set(manifest) != required:
        raise ValueError("manifest keys are invalid")

    for key in ("package_id", "milestone", "title"):
        if not isinstance(manifest[key], str) or not manifest[key]:
            raise ValueError(f"{key} must be a non-empty string")

    if not isinstance(manifest["revision"], str) or not re.fullmatch(
        r"R[1-9][0-9]*", manifest["revision"]
    ):
        raise ValueError("revision is invalid")

    if manifest["package_type"] not in ALLOWED_PACKAGE_TYPES:
        raise ValueError("unsupported package_type")
    if manifest["blueprint_baseline"] != BLUEPRINT_BASELINE:
        raise ValueError("blueprint baseline mismatch")
    if not isinstance(manifest["target_branch"], str) or not TARGET_BRANCH_RE.fullmatch(
        manifest["target_branch"]
    ):
        raise ValueError("unsafe target branch")
    if not isinstance(manifest["base_commit"], str) or not SHA40_RE.fullmatch(
        manifest["base_commit"]
    ):
        raise ValueError("invalid base_commit")
    if not isinstance(manifest["schema_version_expected"], int):
        raise ValueError("schema_version_expected must be integer")
    if manifest["schema_version_expected"] != current_schema_version:
        raise ValueError("schema version mismatch")
    if not isinstance(manifest["retry_safe"], bool):
        raise ValueError("retry_safe must be boolean")
    if not isinstance(manifest["files_manifest"], list) or not manifest["files_manifest"]:
        raise ValueError("files_manifest must be a non-empty list")
    if not isinstance(manifest["delete_paths"], list):
        raise ValueError("delete_paths must be a list")

    seen_files: set[str] = set()
    normalized_files: list[dict[str, str]] = []
    for entry in manifest["files_manifest"]:
        if not isinstance(entry, dict) or set(entry) != {"path", "sha256"}:
            raise ValueError("invalid files_manifest entry")
        path = normalize_rel_path(entry["path"])
        if path in seen_files:
            raise ValueError("duplicate files_manifest path")
        if is_forbidden_path(path):
            raise ValueError("forbidden path")
        if is_protected_path(path, manifest["package_type"]):
            raise ValueError("protected path")
        sha256 = entry["sha256"]
        if not isinstance(sha256, str) or not SHA256_RE.fullmatch(sha256):
            raise ValueError("invalid sha256")
        seen_files.add(path)
        normalized_files.append({"path": path, "sha256": sha256})

    seen_deletes: set[str] = set()
    normalized_deletes: list[str] = []
    for raw in manifest["delete_paths"]:
        path = normalize_rel_path(raw)
        if path in seen_deletes:
            raise ValueError("duplicate delete_paths path")
        if is_forbidden_path(path):
            raise ValueError("forbidden delete path")
        if is_protected_path(
            path,
            manifest["package_type"],
            for_delete=True,
        ):
            raise ValueError("protected delete path")
        seen_deletes.add(path)
        normalized_deletes.append(path)

    normalized = dict(manifest)
    normalized["files_manifest"] = normalized_files
    normalized["delete_paths"] = normalized_deletes
    return normalized


def _is_symlink(info: zipfile.ZipInfo) -> bool:
    mode = (info.external_attr >> 16) & 0xFFFF
    return stat.S_ISLNK(mode)


def _validate_directory_entry(raw_name: str) -> None:
    if not raw_name.endswith("/"):
        raise ValueError(f"unsafe directory entry: {raw_name!r}")
    directory_name = raw_name.rstrip("/")
    if not directory_name:
        raise ValueError("unsafe empty directory entry")
    normalize_rel_path(directory_name)


def validate_archive(
    zip_path: Path,
    extract_dir: Path,
    current_schema_version: int,
) -> dict:
    with zipfile.ZipFile(zip_path) as archive:
        infos = archive.infolist()
        names = [info.filename for info in infos]
        if names.count("package-manifest.json") != 1:
            raise ValueError("manifest must exist exactly once at archive root")

        normalized_zip_names: set[str] = set()
        normalized_to_info: dict[str, zipfile.ZipInfo] = {}

        for info in infos:
            if _is_symlink(info):
                raise ValueError("unsafe symlink-like ZIP entry")
            raw_name = info.filename
            if info.is_dir():
                _validate_directory_entry(raw_name)
                continue

            name = normalize_rel_path(raw_name)
            if name in normalized_zip_names:
                raise ValueError("duplicate normalized ZIP path")
            normalized_zip_names.add(name)
            normalized_to_info[name] = info

        manifest_info = normalized_to_info.get("package-manifest.json")
        if manifest_info is None:
            raise ValueError("manifest must exist exactly once at archive root")

        try:
            manifest = json.loads(archive.read(manifest_info))
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            raise ValueError("manifest JSON is invalid") from exc

        manifest = validate_manifest(manifest, current_schema_version)

        declared = {
            f"payload/{item['path']}": item for item in manifest["files_manifest"]
        }
        actual_payload = {
            name for name in normalized_zip_names if name.startswith("payload/")
        }

        if actual_payload - set(declared):
            raise ValueError("undeclared payload file")
        if set(declared) - actual_payload:
            raise ValueError("declared payload file missing")

        allowed_files = {"package-manifest.json"} | set(declared)
        if normalized_zip_names - allowed_files:
            raise ValueError("undeclared archive file")

        for archive_name, item in declared.items():
            info = normalized_to_info[archive_name]
            data = archive.read(info)
            digest = hashlib.sha256(data).hexdigest()
            if digest != item["sha256"]:
                raise ValueError(f"checksum mismatch: {item['path']}")

        extract_dir.mkdir(parents=True, exist_ok=False)
        for archive_name, item in declared.items():
            info = normalized_to_info[archive_name]
            target = extract_dir / "payload" / item["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(info))

        (extract_dir / "package-manifest.json").write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        return manifest
