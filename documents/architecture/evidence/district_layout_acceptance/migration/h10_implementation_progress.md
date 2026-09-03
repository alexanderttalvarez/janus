# H10 Implementation Progress

This record captures the implementation phase only. It is not the H10
acceptance or release signoff.

## Completed boundary removals

- Deleted `scripts/district/district_legacy_adapters.gd`.
- Deleted the traffic, visitor-spawn, and camera-bounds adapter scripts.
- Replaced main-scene district bootstrap and grid projection wiring with the
  explicit H1 fixture factory and H2 resolver path.
- Removed fixed footprint-file loading from `MainGame`.
- Removed plot corner spawn-point generation and serialization.
- Removed VisitorManager's autonomous spawn path and spawn-point exit fallback.
- Removed `VisitorData.spawn_point_id`.

## Validation

- H1: 60 passed, 0 failed.
- H2: 73 passed, 0 failed.
- H3: 32 passed, 0 failed.
- H4: 22 passed, 0 failed.
- H4 editor preview: 15 passed, 0 failed.
- H5: 21 passed, 0 failed.
- H6: 23 passed, 0 failed.
- H7: 19 passed, 0 failed.
- H8: 31 passed, 0 failed.
- H9: 18 passed, 0 failed.
- Main scene started through GodotIQ with zero runtime/debug-console errors.
- GodotIQ project validation reported zero convention issues.

## Remaining acceptance work

- Complete detailed predecessor, migration, performance, archive, and signoff
  evidence required by H10.
- Resolve the known test-runner limitation for
  `test_zone_manager_split_commit.gd`.
- Investigate the low-confidence Godot editor error-22 reload reports and the
  H8 process-exit ObjectDB/resource leak warnings.
