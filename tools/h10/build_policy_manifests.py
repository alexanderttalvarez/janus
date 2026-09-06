#!/usr/bin/env python3
"""Build deterministic H10 production and Archive Policy B manifests."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PRODUCTION_EXCLUDES = (
    ".git/",
    ".godot/",
    ".github/",
    "build/",
    ".godotiq/",
    "documents/",
    "tests/",
    "tools/",
    "addons/godotiq/",
    "addons/district_projection_preview/",
    "scripts/grid/grid_manager.gd",
    "scripts/grid/grid_manager.gd.uid",
    "scripts/grid/grid_tile.gd",
    "scripts/grid/grid_tile.gd.uid",
    "scripts/grid/floor_grid.gd",
    "scripts/grid/floor_grid.gd.uid",
    "scripts/grid/plot_data.gd",
    "scripts/grid/plot_data.gd.uid",
    "scripts/grid/footprint_loader.gd",
    "scripts/grid/footprint_loader.gd.uid",
    "scripts/resources/district_layout_fixture_factory.gd",
    "scripts/resources/district_layout_fixture_factory.gd.uid",
    "scripts/projection/projection_editor_source.gd",
    "scripts/projection/projection_editor_source.gd.uid",
    "scripts/projection/projection_preview.gd",
    "scripts/projection/projection_preview.gd.uid",
    "scripts/projection/projection_preview_controller.gd",
    "scripts/projection/projection_preview_controller.gd.uid",
)
FORBIDDEN_PRODUCTION_CONTENT = (
    "GridManager",
    "fixture.legacy_25_single",
    "fixture.variable_30x40_single",
    "fixture.mixed_3x3",
    "LegacyFootprintLayerAdapter",
    "LegacyLayoutBootstrapAdapter",
    "LegacyFloorIdAdapter",
    "LegacyGridProjectionAdapter",
    "LegacyDefaultPlotSelectionAdapter",
    "LegacyExteriorAccessAdapter",
    "LegacyCameraBoundsAdapter",
    "LegacyCornerSpawnAdapter",
    "LegacyAuthoredTrafficLayoutAdapter",
    "LegacyVisitorSpawnAdapter",
)


def _relative_files() -> list[Path]:
    files: list[Path] = []
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT)
        if any(str(relative).startswith(prefix) for prefix in PRODUCTION_EXCLUDES):
            continue
        files.append(relative)
    return files


def _digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _build_manifest(name: str, files: list[Path], enforce_production: bool) -> dict:
    entries: list[dict[str, str | int]] = []
    violations: list[dict[str, str]] = []
    for relative in files:
        absolute = ROOT / relative
        entries.append(
            {
                "path": relative.as_posix(),
                "bytes": absolute.stat().st_size,
                "sha256": _digest(absolute),
            }
        )
        if not enforce_production:
            continue
        try:
            text = absolute.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for forbidden in FORBIDDEN_PRODUCTION_CONTENT:
            if forbidden in text:
                violations.append({"path": relative.as_posix(), "match": forbidden})
    return {
        "schema_version": 1,
        "policy": "production" if enforce_production else "archive_policy_b_test_pack",
        "file_count": len(entries),
        "files": entries,
        "forbidden_content_violations": violations,
        "valid": not violations,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=ROOT / "build" / "h10")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    production_files = _relative_files()
    all_files = sorted(
        path.relative_to(ROOT)
        for path in ROOT.rglob("*")
        if path.is_file()
        and ".git" not in path.parts
        and ".godot" not in path.parts
        and "build" not in path.parts
    )
    manifests = {
        "production_manifest.json": _build_manifest("production", production_files, True),
        "test_pack_manifest.json": _build_manifest("test_pack", all_files, False),
    }
    for filename, manifest in manifests.items():
        destination = args.output_dir / filename
        destination.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"{filename}: {manifest['file_count']} files, valid={manifest['valid']}")
    return 0 if manifests["production_manifest.json"]["valid"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
