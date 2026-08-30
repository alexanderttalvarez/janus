# Handoff 10: Legacy Removal and Final Acceptance Gate

## Status

**Draft - implementation blocked by predecessors and required approvals.** H10 implementation starts after H1-H9 implementation and required design/migration approvals. H10 removes all ten executable adapters and gathers audit evidence; H10 acceptance, not implementation start, requires zero adapters and evidence for every coverage row.

## Purpose

Remove runtime compatibility scaffolding and prove the complete target authority chain, Save V2, generated projections, and all three fixtures without fixed-layout fallbacks.

## Dependencies

- Implemented [H1](01_definition_schema_and_validation.md), [H2](02_resolved_district_model.md), [H3](03_variable_floor_grid_migration.md), [H4](04_world_projection_and_editor_preview.md), [H5](05_street_and_pedestrian_generation.md), [H6](06_camera_and_pedestrian_gateways.md), [H7](07_traffic_topology_migration.md), [H8](08_visitor_arrival_mvp_migration.md), and [H9](09_save_load_v2.md), with their required design and migration approvals recorded.
- Recorded approval and implementation of both H5 design decisions: one selected corner-frontage alternative and one selected public-band physical parcel-door alternative.

## Source-of-truth documents

- [Handoff index](./_index.md)
- [Decisions 27](../../decisions/27_district_layout_templates.md), [28](../../decisions/28_visitor_arrival_architecture.md), and [15](../../decisions/15_save_load_architecture.md)

## Current-state findings

Known legacy assumptions span fixed dimensions, default IDs/floors, dense mutable grids, authored roads/markers, corners, outside-grid access, direct writes, global rebuilds, and parse-time load events.

## Target state

Production has zero executable compatibility adapters/fallbacks. Explicit stable IDs and signed elevations cross boundaries; authority can survive complete projection destruction/rebuild; legacy V1 support is isolated offline only.

## Scope

Delete adapters/callers/registrations; negative-search stale aliases; classify every static hit; run dependency/signal/scene/resource/export audits; execute three-fixture, save, zone/parcel, lifecycle, parity, console, and performance gates.

## Explicit non-goals

No gameplay, visual redesign, unrelated refactor, archive-history rewrite, or silent loss of supported saves.

## System ownership

H1-H9 owners provide replacement evidence. H10 owns deletion, audit artifacts, acceptance matrix, release decision, and proof that no equivalent unnamed fallback survives.

## Data contracts

### Executable adapter ledger

Exactly these ten adapters must have no executable implementation, registration, scene/resource reference, or runtime test helper after H10:

1. `LegacyFootprintLayerAdapter`
2. `LegacyLayoutBootstrapAdapter`
3. `LegacyFloorIdAdapter`
4. `LegacyGridProjectionAdapter`
5. `LegacyDefaultPlotSelectionAdapter`
6. `LegacyExteriorAccessAdapter`
7. `LegacyCameraBoundsAdapter`
8. `LegacyCornerSpawnAdapter`
9. `LegacyAuthoredTrafficLayoutAdapter`
10. `LegacyVisitorSpawnAdapter`

Negative-search these stale aliases, which must never be implementable: `Legacy25LayoutAdapter`, `LegacyPlotIdAdapter`, `LegacyPedestrianRingAdapter`, `LegacyRoadSceneAdapter`, `LegacyTrafficMarkerAdapter`, `LegacyCornerArrivalAdapter`, `LegacyZoneCoordinateAdapter`, and `LegacyDistrictSaveAdapter`. H9's offline converter may remain under support policy and is not an adapter.

## Communication and event flow

`explicit layout/session -> resolve -> create/load authority -> validate/build projections -> atomic commit -> one committed/load event -> consumers`. No adapter supplies default identity, geometry, floor, source, access, or route.

## Persistence impact

H10 does not change V2. Supported V1 conversion remains detached/offline; new games never select the legacy fixture by fallback.

## Editor/runtime behavior

Editor/runtime resolver, fingerprint, topology, and source outputs match. Production `main_game` contains composition/presentation roots, not authored district authority. Clean runs have no errors or fallback warnings.

## Migration and compatibility requirements

All ten adapters and unnamed equivalents are removed. H9 converter retention/removal follows explicit support policy. Unknown IDs/fingerprints reject. Archived fixtures are selected only by explicit fixture/migration identity.

## Expected affected files/systems

All H1-H9 implementation surfaces, production composition, project settings, tests, resources, registries, exports, and archived fixtures identified by project-wide audits.

### Coverage matrix

Every row requires classified static/dependency evidence plus named behavioral evidence. Numeric hits must be reviewed semantically, not bulk-replaced.

| Assumption/search target | Replacement owner | Required evidence |
| --- | ---: | --- |
| Ten canonical adapter names | H1/H3/H5/H6/H7/H8 | Exact negative search plus successful target flows. |
| Eight stale adapter aliases | H10 | Exact negative search; no executable implementation/registration. |
| `25x25_full` | H1 | Archive-only classification; never complete authority/bootstrap. |
| Numeric `25`, `24`, `12`, `12.5` where district-semantic | H1-H6 | Classified hits; unequal/even/odd fixture geometry passes. |
| `625`, per-tile mesh/allocation | H3/H4 | No fixed count; projection/state scales with actual sparse content. |
| `DEFAULT_PLOT`, `plot_0` | H3 | No production default/inference; explicit ID rejection tests. |
| `GROUND_FLOOR`; `G`/`F`/`B` strings as authority | H3/H9 | Signed integers in authority; labels only display/offline migration. |
| `floor_levels` | H3/H6 | View capabilities use signed elevations; viewing creates no state. |
| `floor_plot_0_G` | H3/H4 | No hard lookup; explicit projection handle tests. |
| `PlotData.pedestrian_boundary` and `PlotData.spawn_points` | H5/H6/H8 | Generated topology/stable sources; no serialization/authority. |
| `virtual_exterior` and synthetic exterior plot ID | H3/H5 | Approved topology access IDs; no outside-grid/synthetic identity. |
| `World/TrafficLayout/Lanes` and all eight `Lane_*` names | H7 | No authored graph lookup; generated graph goldens. |
| Marker families `Spawn`, `StopLine`, `Exit`, `SourceClear`, `IntersectionHold`, `IntersectionClear` | H7 | Stable control-anchor kinds; no Node-name contract. |
| `NW`, `NE`, `SW`, `SE` traffic/source authority | H6/H7/H9 | Stable topology IDs and detached source migration only. |
| Fixed exterior door coordinates/public-band physical-door access | H5 | Recorded approved H5 physical-door alternative (A, B, or C), selected-rule evidence, and rejection of unselected alternatives. |
| Corner-only frontage attribution | H5 | Recorded approved H5 corner-frontage alternative (A, B, or C), selected-rule below/exact/above-threshold evidence, and rejection of unselected alternatives. |
| `PedestrianArea` size 25 and margin/ring | H5 | Final generated pedestrian graph and bands. |
| Garbage coordinates `2..22`, if present | H3 | Explicit-address/shape-aware placement or classified unrelated. |
| Zero-origin and world-Y=0 pick math | H3/H4 | Snapshot transform round trips at translated plots/elevations. |
| Direct mutable `GridTile` writes | H3 | District transactions only; mutation-boundary audit. |
| `owned` + `floor_built` conflation | H3/H9 | Independent truth table and explicit V1-only conversion. |
| Full-volume allocation | H3 | Sparse counts follow mutations, including elevations. |
| Global wall/path rebuilds | H4/H5 | Scoped deltas/rebuild evidence and escalation diagnostics. |
| Bare `Vector2i` across boundaries | H3 | Typed explicit-address API/dependency audit. |
| Hand-authored roads/crosswalks/traffic markers | H4/H5/H7 | Scene/resource audit plus generated manifest/graph parity. |
| Save V1 direct manager mutation | H9 | Offline detached conversion and atomic candidate commit. |

The final matrix records file/line or tool artifact, test/fixture name, and pass/fail for every row.

## Acceptance criteria

- Exactly ten adapters are removed; all stale aliases and unnamed equivalents are absent.
- Every coverage row has objective evidence and all three fixtures pass end to end.
- Both H5 DESIGN BLOCKERS have recorded approvals and implemented tests: corner-frontage attribution and public-band physical doors; `LegacyExteriorAccessAdapter` is gone.
- Save V2 round-trip, recognized V1 conversion, malformed/unknown/fingerprint rejection, and post-commit-only event pass.
- Projection destruction/rebuild preserves authority; editor/runtime parity and clean console pass.
- Concrete H1-H9 performance budgets pass with no repeated-cycle leak.

## Required tests

- Exact static searches listed in the matrix across scripts/scenes/resources/settings/tests/exports.
- Dependency/signal/orphan/scene/resource/registry audits.
- `fixture.legacy_25_single`, `fixture.variable_30x40_single`, and `fixture.mixed_3x3` resolution, transactions, projections, conversion, graphs, arrivals, save/load, and cleanup.
- Existing zone/parcel regression suite on non-legacy fixtures.
- Fault injection at every transaction/load/projection boundary and clean debug console.

## Performance/scalability checks

Record resolver, session, graph, projection, wall, camera, arrival, save, staged load, commit, Nodes, draws, memory, path size, source count, and save size. The selected performance policy and thresholds block H4 performance acceptance and H10 acceptance, not H10 implementation.

### Release-policy contracts

Acceptance evidence is rooted exactly at `documents/architecture/evidence/district_layout_acceptance/` with subfolders `proof/`, `migration/`, `performance/`, `audits/`, and `signoff/`. Selected policy files are stored under `signoff/`. Required signoff roles are exactly Architecture, Design, QA, and Release; the release owner assigns actual people. Signer names and the open V1 support window are policy assignments, not implementation-agent choices.

No alternative below is selected by this handoff:

| Policy | Alternatives | Selection authority and criterion | Required before |
| --- | --- | --- | --- |
| Performance | A baseline-relative; B target-platform absolute; C hybrid | Release + Architecture select based on target hardware and CI stability. | H4 performance acceptance. |
| V1 support | A no production support; B one-release support; C multi-release support | Release + Product select based on shipped save population and support cost. | H9 cutover. |
| Archive | A export exclusion; B separate test pack; C non-`res://` fixture repository | Release + QA select based on proof reproducibility and zero runtime reachability. | H10 acceptance. |

## Failure and rollback behavior

Any failed audit/test/budget blocks release. Fix target behavior rather than restoring runtime fallback. Source-control rollback is allowed; dead adapters are not retained for rollback.

## Technical risks

Unrelated numeric hits, hidden resource references, defaults without adapter names, legacy test helpers, archive leakage, projection-as-authority, and repeated-cycle leaks.

## FACTS

- H10 removes ten adapters, not nine.
- H9 offline conversion is not an adapter.

## ASSUMPTIONS

- H1-H9 establish explicit fixture registries before H10; selected release policies are recorded at their named acceptance gates.

## OPEN QUESTIONS

- Selected performance, V1 support, and archive policies; signer assignments and the support window remain release-owner policy records under `signoff/`.

## GodotPrompter skills required by implementation agents

- `godot-code-review`, `scene-organization`, `save-load`, `dependency-injection`, `ai-navigation`, `camera-system`, `godot-testing`, `godot-debugging`, `godot-optimization`.
