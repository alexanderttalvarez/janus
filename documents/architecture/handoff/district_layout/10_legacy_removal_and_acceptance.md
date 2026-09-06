# Handoff 10: Legacy Removal and Final Acceptance Gate

## Status

**Implementation complete; acceptance blocked until the defined evidence package passes.** H10 begins after H1-H9 implementation. Acceptance—not implementation—requires zero adapters and complete release evidence.

## Purpose

Remove runtime compatibility scaffolding and prove the target authority chain, Save V2, generated projections, and all three fixtures without fixed-layout fallbacks.

## Dependencies

- Implemented H1-H9 and their required acceptance evidence.
- Implemented H5 zero-corner-frontage and topology-backed public-band physical-access contracts.
- Evidence contract: [H10 Release Evidence Contract](../../evidence/district_layout_acceptance/signoff/h10_release_evidence_contract.md).

## Source-of-truth documents

- [Handoff index](./_index.md)
- [Decisions 27](../../decisions/27_district_layout_templates.md), [28](../../decisions/28_visitor_arrival_architecture.md), and [15](../../decisions/15_save_load_architecture.md)
- [District architecture blueprint](../../design_handoff.md)

## Target state

Production has zero executable compatibility adapters/fallbacks. Explicit stable IDs and signed elevations cross boundaries; authority survives complete projection destruction/rebuild; V1 and schema-absent saves reject before staging without slot mutation.

## Scope and ownership

H10 deletes adapters/callers/registrations; classifies static hits; runs dependency, signal, scene, resource, export, fixture, save, lifecycle, parity, console, and performance audits; and owns the acceptance matrix and release decision. H1-H9 owners provide replacement evidence. H10 does not redesign gameplay, rewrite archive history, or restore a runtime fallback for rollback.

## Data contracts

### Executable adapter ledger

These ten adapters must have no executable implementation, registration, scene/resource reference, or runtime test helper after H10:

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

The stale aliases `Legacy25LayoutAdapter`, `LegacyPlotIdAdapter`, `LegacyPedestrianRingAdapter`, `LegacyRoadSceneAdapter`, `LegacyTrafficMarkerAdapter`, `LegacyCornerArrivalAdapter`, `LegacyZoneCoordinateAdapter`, and `LegacyDistrictSaveAdapter` must never be implementable. No H9 V1 converter, registry, or migration artifact exists.

### GridManager classification

`GridManager` is **retired legacy grid authority**, not a target District Runtime service or an eleventh adapter. Its default `plot_0` identity, `G` floor identity, pedestrian margin, world metrics, direct tile mutation, exterior inference, global rebuild, and legacy serialization cannot be reachable in production. It may remain only in the Archive-Policy-B test pack while named legacy zone/parcel regression suites require it. Details and evidence requirements are binding in the release evidence contract §4.

## Communication and persistence

`explicit layout/session -> resolve -> create/load authority -> validate/build projections -> atomic commit -> one committed/load event -> consumers`. UI and projections submit intent/render results but never supply identity, geometry, floor, source, access, route, or mutable authority.

H10 does not change V2. V1 and every schema-absent payload reject before staging/live mutation, preserve the old slot, and return H9's structured incompatibility result. Generated geometry, graphs, transforms, Nodes, indexes, caches, and projection artifacts are never saved.

## Coverage matrix

Every matrix row requires classified static/dependency evidence and named behavioral evidence; numeric hits are reviewed semantically, never bulk-replaced.

| Assumption/search target | Replacement owner | Required evidence |
| --- | ---: | --- |
| Ten canonical adapters and eight stale aliases | H1/H3/H5/H6/H7/H8/H10 | Exact negative searches and successful target flows. |
| `25x25_full`, district-semantic `25`, `24`, `12`, `12.5`, `625` | H1-H6 | Archive-only/classified hits; unequal/even/odd fixtures and sparse scaling pass. |
| `DEFAULT_PLOT`, `plot_0`, `GROUND_FLOOR`, `G`/`F`/`B`, `floor_levels`, `floor_plot_0_G` | H3/H4/H6/H9 | Explicit stable IDs/signed elevations; display-only labels; no production convenience fallback. |
| `PlotData.pedestrian_boundary`, `spawn_points`, `virtual_exterior`, fixed exterior doors, corner frontage | H5/H6/H8 | Generated topology/stable sources; public-band access and threshold tests. |
| Authored roads, lanes, markers, corner/source authority | H4/H5/H7/H8 | Generated manifests/graph goldens and stable control-anchor IDs. |
| Direct mutable `GridTile` writes, ownership/construction conflation, full-volume allocation, global rebuilds, bare `Vector2i` boundaries | H3/H4/H5 | Transactions, truth-table, sparse/delta, and explicit-address audits. |
| Schema-absent/V1 mutation | H9 | Reject before staging/live mutation, preserve slot, structured result. |

The final matrix records file/line or tool artifact, test/fixture name, and pass/fail for every row.

## Acceptance criteria

- Exactly ten adapters, stale aliases, and unnamed production equivalents are absent.
- Every coverage row has objective evidence; `fixture.legacy_25_single`, `fixture.variable_30x40_single`, and `fixture.mixed_3x3` pass end to end.
- Approved H5 frontage/public-band access contracts, V2 round trip/rejection behavior, projection rebuild, editor/runtime parity, and clean console pass.
- Hybrid R1 performance evidence passes the absolute and same-hardware-relative budgets, with no repeated-cycle leak.
- Archive Policy B production/test-pack CI proof passes with zero production reachability to archive-only content.
- `GridManager` has zero production reachability and, if retained, appears only in the separately packaged test pack.
- Architecture, Design, QA, and Release provide independent, candidate-commit-bound approvals.

## Required tests and audit evidence

- Exact static searches across scripts, scenes, resources, settings, tests, exports, and tracked backups; dependency/signal/orphan/scene/resource/registry audits.
- Three-fixture resolution, transactions, projections, graphs, arrivals, V2 save/load, cleanup, zone/parcel regression, and fault injection at every transaction/load/projection boundary.
- Release-build RVR-1 sampling, repeated topology/projection and save/load cycles, raw console logs, and leak gate under the evidence contract §§1-2.
- Separate production-export and test-pack manifests, checksums, forbidden-content/reachability scans, CI URLs, and test-pack invocation under §3.

## Release-policy contracts

Evidence is rooted at `documents/architecture/evidence/district_layout_acceptance/` with `proof/`, `migration/`, `performance/`, `audits/`, and `signoff/`. The binding selected-policy record is `signoff/selected_policies.md`; operational requirements are in `signoff/h10_release_evidence_contract.md`.

**Selected:** V1 has no production support; H9 rejects schema-absent payloads before staging/live mutation and preserves slots. Performance is Hybrid R1. Archive is B—separate test pack. These selections are policy, not proof or release approval.

## Failure and rollback behavior

Any failed audit, test, warning/leak gate, budget, archive proof, or signoff blocks release. Fix target behavior rather than restoring runtime compatibility. Source-control rollback is allowed; dead adapters are never retained for rollback.

## Technical risks

Unrelated numeric hits, hidden resource references, defaults without adapter names, test-only archive leakage, projection-as-authority, editor lifecycle leaks, and process-exit ObjectDB/resource warnings.

## FACTS

- H10 removes ten adapters, not nine.
- V1 production support is excluded.
- Design requires 60 FPS with up to 200 simultaneous MVP visitors.

## ASSUMPTIONS

- H1-H9 establish explicit fixture registries and H10 evidence is captured against a single candidate commit.

## OPEN QUESTIONS

- Actual signer assignments.
- Production export-preset and CI job identifiers; these must be recorded in evidence before acceptance and do not alter the selected policy.

## GodotPrompter skills required by implementation agents

- `godot-code-review`, `scene-organization`, `save-load`, `dependency-injection`, `ai-navigation`, `camera-system`, `godot-testing`, `godot-debugging`, `godot-optimization`.
