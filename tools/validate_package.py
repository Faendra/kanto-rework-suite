#!/usr/bin/env python3
"""Static checks for the P0 package that do not require a ROM or Gen1Recomp."""
from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "packages" / "kanto_rework_core"


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    manifest_path = PACKAGE / "manifest.json"
    if not manifest_path.is_file():
        fail("manifest.json is missing")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    required = {
        "id": "kanto_rework_core",
        "api": 2,
        "entry": "main.lua",
        "profile": "overhaul",
    }
    for key, expected in required.items():
        if manifest.get(key) != expected:
            fail(f"manifest {key!r} must be {expected!r}")
    for relative in (
        "main.lua",
        "core/layout.lua",
        "core/theme.lua",
        "core/profile.lua",
        "core/presenter.lua",
        "core/pointer.lua",
        "core/native_pointer.lua",
    ):
        if not (PACKAGE / relative).is_file():
            fail(f"missing package file: {relative}")
    forbidden = {".gb", ".gbc", ".sav", ".srm"}
    offenders = [path for path in PACKAGE.rglob("*") if path.suffix.lower() in forbidden]
    if offenders:
        fail("ROM/save files are forbidden: " + ", ".join(map(str, offenders)))
    print("P0 package static validation passed")


if __name__ == "__main__":
    main()
