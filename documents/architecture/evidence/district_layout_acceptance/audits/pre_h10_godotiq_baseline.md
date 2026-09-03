# Pre-H10 GodotIQ Audit Baseline

## Static validation

- `godotiq_validate(target="project")`: **0 issues**, 138 files checked.
- `godotiq_signal_map(scope="all", find="orphans")`: **0 orphan signals**;
  119 signals and 79 connections.
- `godotiq_signal_map(scope="all", find="missing")`: no missing-signal result.
- `godotiq_asset_registry(category="all", check_usage=true)`: 49 assets,
  0 unused assets.
- `godotiq_animation_audit(scope="all")`: 0 animations, 0 issues.
- `godotiq_spatial_audit(main_game.tscn)`: 0 reported spatial issues.

## Runtime validation

- Main scene launches through GodotIQ with a connected runtime.
- World root and active Camera3D are present and visible.
- Save and Load HUD buttons are present and interactive.
- Runtime debug console: 0 runtime errors and 0 script errors.
- Live SaveManager save/load/delete checks have passed.

## Known tooling limitation

`godotiq_check_errors(scope="project")` reports 15 low-confidence
`Script reload failed (error 22)` entries, primarily in projection and
resource scripts, with no line information. They do not reproduce in the
ordered headless H1-H9 tests or the main-scene runtime check, but they must be
resolved or explicitly classified before final H10 acceptance.
