from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.mobile_inbox.contract import validate_archive


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate")
    validate_parser.add_argument("zip_path", type=Path)
    validate_parser.add_argument("--extract-dir", required=True, type=Path)
    validate_parser.add_argument(
        "--schema-version-current",
        required=True,
        type=int,
    )

    args = parser.parse_args()
    manifest = validate_archive(
        args.zip_path,
        args.extract_dir,
        args.schema_version_current,
    )
    print(json.dumps(manifest, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
