# P02 District-Zone Snapshot and Atomic Zone Mutation Evidence

**Observed:** 2026-09-11  
**Base candidate:** `65614da981244ad62da8f6430d725e1c6e9a07bb` with an uncommitted implementation worktree  
**Engine:** Godot `4.7.stable.official.5b4e0cb0f` on Linux  
**Disposition:** Implementation PASS; manual approval PENDING

## Implemented contract

- `DistrictState` local schema v3 retains the Save V2 root, stores explicit circulation on each floor, stores canonical `manual_door_edges`, and rejects obsolete local schemas.
- `DistrictZoneSpatialSnapshot` is an immutable, transient, explicitly floor-scoped ADR 36 value derived by District authority.
- Zone preview receives only bounded layout/revision metadata plus ADR 35/36 snapshots; production Zone code receives no full `DistrictState`.
- Zone plans request exact District effects. District validates and applies those effects to a detached candidate, derives prospective snapshots, and passes the exact accepted plan into Zone prepare.
- Zone paint consumes explicit circulation. None paint restores explicit circulation while preserving acquired and constructed cells. Obsolete same-zone manual-door edges are removed from the same District candidate.
- Production Zone code no longer depends on `GridManager`, `FloorGrid`, `GridTile`, `PlotData`, legacy adapters, or archive-group queries. Zone commits do not write legacy grid state.

## Focused observed results

| Command | Result |
|---|---|
| `godot --headless --path . -s res://tests/test_district_zone_spatial_snapshot.gd` | 13 passed, 0 failed |
| `godot --headless --path . -s res://tests/test_zone_splitter.gd` | 145 passed, 0 failed |
| `godot --headless --path . res://tests/test_zone_manager_split_commit.tscn` | 206 passed, 0 failed |
| `godot --headless --path . -s res://tests/test_district_runtime_h3.gd` | 55 passed, 0 failed |
| `godot --headless --path . -s res://tests/test_public_band_access_adr35.gd` | 16 passed, 0 failed |
| `godot --headless --path . -s res://tests/test_resolved_district_model.gd` | 77 passed, 0 failed |
| `godot --headless --path . -s res://tests/test_construction_mvp.gd` | 31 passed, 0 failed |
| `godot --headless --path . -s res://tests/test_save_load_h9.gd` | 19 passed, 0 failed |
| `godot --headless --path . -s res://tests/test_public_realm_h5.gd` | 22 passed, 0 failed |
| `godot --headless --path . res://tests/test_wall_manager.tscn` | 23 passed, 0 failed |
| `godot --headless --path . --quit-after 5` | Main scene reached `Ready and paused` without parser or runtime failures |
| `git diff --check` | clean |
| GodotIQ project convention validation | 197 files checked, 0 issues |
| GodotIQ Zone signal audit | 149 signals, 119 connections, 0 orphans |

## Covered ADR 35/36/37 obligations

- Explicit signed-elevation and masked-floor scope.
- Distinct valid, acquired, constructed, eligible, and circulation sets.
- Strict unknown-field, subset, scope, stale-revision, and mixed-revision rejection.
- Preview non-mutation, exact preview-plan handoff, prospective prepare snapshots, and transaction rollback behavior.
- Circulation consumption/restoration and preservation of acquired/constructed rights.
- Atomic obsolete manual-door removal.
- Automatic-door stability and retained public-band door provenance.
- Exact District local v3 validation, obsolete-schema rejection, and Save V2 round trip.
- Committed public graph and wall projection regressions.

## Known validation limitation

GodotIQ project preflight continues to report nine line-less, low-confidence `Script reload failed (error 22)` entries already documented in P00/P01. Focused parser checks return zero errors, all listed headless suites execute, and the main scene starts successfully. A second headless editor also reports the expected GodotIQ WebSocket port conflict because the connected editor already owns port 6007; this is not a game runtime failure.

## Approval status

P02 implementation evidence is complete, but the human approval gate remains open. Do not begin P03 until manual testing is confirmed.
