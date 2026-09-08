# District Layout Handoff Index

This is the implementation order, authority ledger, and cutover gate for the district-layout program. It refines the [architecture blueprint](../../design_handoff.md), [Decision 27](../../decisions/27_district_layout_templates.md), and [Decision 28](../../decisions/28_visitor_arrival_architecture.md).

**Current revision:** 2026-09-08, delegated documentation approval. [ADR 33](../../decisions/33_documentation_consistency_and_minimum_contracts.md) and [Current MVP](../../../game_design/current_mvp.md) govern amendments and scope. Migration observations/adapters below are historical, not work to recreate. Implementation claims come from [existing evidence](../../evidence/district_layout_acceptance/_index.md), not a new audit. New contract clarifications require new verification; historical PASS records do not prove them.

## Handoff IDs and implementation gates

| Order | Handoff | Architecture status | Implementation gate |
| ---: | --- | --- | --- |
| 01 | [Definition Schema and Validation](01_definition_schema_and_validation.md) | Approved and frozen — 2026-08-31 | H1 KEEP and A-C proof contract are frozen for H3; Fixture C fingerprint refresh requires the separately recorded explicit H1 addendum. |
| 02 | [Resolved District Model](02_resolved_district_model.md) | Approved and frozen — 2026-08-31 | Resolver contract is frozen with H1 KEEP; Fixture C fingerprint refresh requires the separately recorded explicit H1 addendum. |
| 03 | [Variable Floor Grid Migration](03_variable_floor_grid_migration.md) | Approved — 2026-09-03 | H1 KEEP, frozen H1/H2 goldens, and Economy/Progression dependencies are satisfied. |
| 04 | [World Projection and Editor Preview](04_world_projection_and_editor_preview.md) | Approved contract; runtime and preview tests reported passing | Formal full-preview acceptance is not recorded. Runtime remains available to successors; reconcile every preview criterion with the recorded tests, without inferring approval from PASS. |
| 05 | [Street and Pedestrian Generation](05_street_and_pedestrian_generation.md) | Approved — 2026-09-03 | Public-realm, Economy, Progression, selected-Plot, and god-mode contracts are reconciled; implementation requires H3 transactions and H4 runtime projection lifecycle. |
| 06 | [Camera Envelope and Pedestrian Gateways](06_camera_and_pedestrian_gateways.md) | Approved — 2026-09-03 | Camera policy is selected/validated; implementation requires H3 selected/Active Plot views and H5 public topology. |
| 07 | [Traffic Topology Migration](07_traffic_topology_migration.md) | Approved — 2026-09-03 | Active/owned versus selected/unowned Plot topology is reconciled; implementation requires H3 committed state and H5 public-realm/conversion inputs. |
| 08 | [Visitor Arrival MVP Migration](08_visitor_arrival_mvp_migration.md) | Approved — 2026-09-03 | Requires H3 source state, H5 pedestrian graph, H6 structural eligibility, and VisitorManager lifecycle; it is independent of H7 traffic topology and requires no durable pending policy. |
| 09 | [Save/Load V2 and District Persistence](09_save_load_v2.md) | Approved — 2026-09-03 | Requires implemented H1-H8 authority snapshots, recorded Fixture C golden addendum, and MVP immediate realization. V2 is the first supported district-layout save schema with no automatic rolling backups. |
| 10 | [Legacy Removal and Final Acceptance Gate](10_legacy_removal_and_acceptance.md) | Approved engineering/release contract under ADR 32 | Engineering complete; H10 release acceptance pending external Gate R. Candidate binding and external evidence remain outstanding; this is not Product MVP completion. |

Architecture approval confirms contracts. Implementation gates confirm only the explicitly stated predecessor evidence; numeric Handoff IDs do not create unstated dependencies. H7 traffic topology and H8 pedestrian MVP arrival are parallel branches after H5, with H8 additionally requiring H6. H1 and H2 may be approved and implemented together for proof only. After all three proofs, H1 records **KEEP**, **REVISE**, or **REJECT**; KEEP freezes the production H1/H2 format and goldens, while REVISE/REJECT blocks H3 production work.

## Global invariants

- Authority flows from immutable definitions to pure resolution to immutable `ResolvedDistrictSnapshot` to sparse `DistrictState` in one session District Runtime, then to disposable projections.
- District Runtime is the sole district writer; `ZoneManager` is the sole zone/parcel writer.
- Stable authored identity crosses boundaries. Coordinates, transforms, Node names, traversal order, and scene paths never create identity.
- Every floor address carries runtime plot ID, signed elevation, and local coordinate as applicable.
- Ownership, availability, fixed occupancy, buildability, acquired space, and construction are independent.
- Economy and progression are queried authorities. No handoff invents prices, formulas, unlocks, or caps.
- Camera viewing never creates `FloorState`. Generated geometry, graphs, indexes, and transforms are not saved.

## Proof-fixture progression

| Gate | Evidence | Effect |
| --- | --- | --- |
| A `fixture.legacy_25_single` | Validation, deterministic resolution, immutability, parity, IDs/counts/fingerprint | Continue proof implementation. |
| B `fixture.variable_30x40_single` | A plus rectangular geometry, exact irregular masks, ownership and cap scope | Continue proof implementation. |
| C `fixture.mixed_3x3` | Prior checks plus templates, roles, exact partitions, topology and fixed occupancy | Record KEEP/REVISE/REJECT. |

Literal fingerprint SHA values are generated, reviewed, and frozen only after proof implementation. H3 production implementation starts only after KEEP.

## Single-owner matrix

| Concern | Authority | Handoff |
| --- | --- | ---: |
| Definition semantics, fixtures, semantic fingerprint inclusion | Definition pipeline | H1 |
| Canonical byte encoding, hash, resolved geometry/topology descriptors | Stateless resolver | H2 |
| District lifecycle, state, section/space/construction transactions | Session District Runtime | H3 |
| Generated floor/wall/door/overlay/debug Nodes and `main_game` composition | Projection Coordinator | H4 |
| Public-realm descriptors/geometry, conversion, final pedestrian graph | Public-realm projection | H5 |
| Camera envelope and structural gateway eligibility | Camera/gateway projections | H6 |
| `RoadGraphSnapshot`, topology, graph deltas, lane/control anchors | TrafficTopology | H7 |
| Transient traffic reservations and cars | TrafficManager | H7 contract |
| Arrival allocation/orchestration policy | Arrival Coordinator | H8 |
| `ArrivalSourceState` writes | District Runtime | H3/H8 contract |
| Save schema, migration, atomic load | `SaveManager` | H9 |
| Final removal and release evidence | Cutover owner | H10 |

## Fixed-25x25 coverage matrix

| Legacy surface | Replacement owner |
| --- | ---: |
| Footprint input and definition roles/masks | H1 |
| Fingerprint framing/resolution | H2 |
| `GridManager`, `PlotData`, `FloorGrid`, `GridTile`, floor IDs, transactions | H3 |
| `floor.tscn`, generated walls/doors/overlays/debug and `main_game` composition | H4 |
| Pedestrian bands, roads, intersections, frontage, conversion, pedestrian graph | H5 |
| Camera bounds and gateway structural eligibility/transforms | H6 |
| Authored lanes/markers and road graph | H7 |
| Corner visitor allocation/realization | H8 |
| V1 rejection and V2 persistence | H9 |
| Static/runtime acceptance audit | H10 |

## Temporary adapters

The historical migration plan named exactly ten adapters; evidence reports their removal by H10. This table preserves their identities for evidence interpretation, not an instruction to recreate them in new implementation.

| Adapter | Introduced | Purpose |
| --- | ---: | --- |
| `LegacyFootprintLayerAdapter` | H1 | Read the old mask as one explicit definition layer. |
| `LegacyLayoutBootstrapAdapter` | H3 | Build fixture-A session state through target contracts. |
| `LegacyFloorIdAdapter` | H3 | Translate old floor labels for old persistence/listeners. |
| `LegacyGridProjectionAdapter` | H3 | Present legacy grid-shaped read views. |
| `LegacyDefaultPlotSelectionAdapter` | H3 | Localize old implicit plot selection. |
| `LegacyExteriorAccessAdapter` | H3, continued H5 | Preserve old frontage until the approved zero-corner-frontage and topology-backed public-band access rules are implemented and migrated. |
| `LegacyCameraBoundsAdapter` | H6 | Bridge legacy camera bootstrap bounds. |
| `LegacyCornerSpawnAdapter` | H6 | Bridge legacy gateway/layout behavior only. |
| `LegacyAuthoredTrafficLayoutAdapter` | H7 | Adapt authored lanes/controls to graph values. |
| `LegacyVisitorSpawnAdapter` | H8 | Bridge selected source records to old visitor behavior. |

No V1-to-V2 converter exists. Payloads without `save_schema_version`, including current V1 saves, reject before staging or live mutation and leave their slots intact. Stale aliases are never implementable: `Legacy25LayoutAdapter`, `LegacyPlotIdAdapter`, `LegacyPedestrianRingAdapter`, `LegacyRoadSceneAdapter`, `LegacyTrafficMarkerAdapter`, `LegacyCornerArrivalAdapter`, `LegacyZoneCoordinateAdapter`, and `LegacyDistrictSaveAdapter`.

## Approval readiness for H1-H3

- H1 is approval-ready when semantic roles, identities, exact fixture predicates, diagnostics, and fingerprint inclusion are fixed.
- H2 is approval-ready when resolution, canonical ordering, byte framing, and hashing are deterministic.
- H3 is approval-ready when lifecycle, sole-writer, transaction, revision, economy/progression, and ZoneManager coordination contracts are atomic.
- Remaining implementation choices must not change authority, identity, persistence, determinism, or atomicity. Named later design blockers may remain.

## 2026-08-31 Road & Intersection Addendum

The H5 corner-frontage and public-band physical-door design blockers are resolved. H5 and H7 remain implementation-blocked solely by their predecessor implementation gates; H4 remains projection lifecycle only. The approved road profile, public-realm, conversion, traffic-light, controlled-area, and crossing contracts are recorded in H1, H2, H5, H7, the central design/architecture documents, and the civic-perimeter visual kit.

## 2026-08-31 Fixture C Initial Ownership Decision

Fixture C initial ownership is exactly `{market_entry,station_entry,garden_entry}`; `market_hall` and `garden_plot` are Plot IDs, not ownership values. The [frozen-golden addendum](frozen_h1_h2_goldens.md) explicitly refreshed C's fingerprint on 2026-09-04; the old "unchanged goldens" assertion was stale. ADR 33 corrects the connected-area rationale: these are valid proof-only disconnected active-slot components. This pass changes no fixture masks, IDs or frozen fingerprints and grants no extra production ownership.

## 2026-08-31 Editor Preview Addendum

Historical addition of the preview requirement. The proof record now reports runtime 22/22 and preview 15/15 tests passing; formal full-preview acceptance is not recorded. H4 remains approved and runtime remains usable by successors. Do not restate the plugin as unimplemented or infer acceptance from those counts.

## 2026-08-31 V1 Save Support Decision

**Approved:** V2 is the first supported district-layout save schema. Any payload lacking `save_schema_version`, including current V1 saves, is unsupported and must be rejected before staging or live-session mutation. Rejection preserves the existing slot and returns a structured incompatibility result for required presentation-owned user messaging. No V1 converter, registry, support window, compatibility adapter, fixture conversion, source/floor mapping, or migration artifact is in the plan. Future V2 migrations require explicit approval and release.

## Related authorities

- [District architecture blueprint](../../design_handoff.md)
- [Decision 27](../../decisions/27_district_layout_templates.md)
- [Decision 28](../../decisions/28_visitor_arrival_architecture.md)
- [District Layout and Land Expansion](../../../game_design/elements/19_district_layout_land_expansion.md)
