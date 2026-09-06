from __future__ import annotations

import argparse
from pathlib import PurePosixPath


def select_single_zip(changes: list[tuple[str, str]]) -> str:
    if len(changes) != 1:
        raise ValueError("transport commit must change exactly one file")
    status, path = changes[0]
    if status not in {"A", "M"}:
        raise ValueError("transport ZIP must be added or modified")
    pure = PurePosixPath(path)
    if pure.parent.as_posix() != "inbox" or pure.suffix.lower() != ".zip":
        raise ValueError("transport commit must change exactly one inbox ZIP")
    return path


def parse_name_status(text: str) -> list[tuple[str, str]]:
    rows = []
    for line in text.splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) != 2:
            raise ValueError("unsupported git name-status row")
        rows.append((parts[0], parts[1]))
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("name_status_file")
    args = parser.parse_args()

    text = open(args.name_status_file, encoding="utf-8").read()
    print(select_single_zip(parse_name_status(text)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
