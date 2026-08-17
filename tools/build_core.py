#!/usr/bin/env python3
"""Build a launcher-importable Kanto Rework Core ZIP."""
from __future__ import annotations

import json
import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "packages" / "kanto_rework_core"
DIST = ROOT / "dist"


def main() -> None:
    manifest = json.loads((PACKAGE / "manifest.json").read_text(encoding="utf-8"))
    version = manifest["version"]
    output = DIST / f"kanto_rework_core-{version}.zip"
    DIST.mkdir(parents=True, exist_ok=True)

    files = sorted(path for path in PACKAGE.rglob("*") if path.is_file())
    manifest_path = PACKAGE / "manifest.json"
    ordered = [manifest_path] + [path for path in files if path != manifest_path]

    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in ordered:
            archive.write(path, path.relative_to(PACKAGE).as_posix())

    print(output)


if __name__ == "__main__":
    main()
