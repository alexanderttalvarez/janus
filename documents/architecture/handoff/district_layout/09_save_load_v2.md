# Handoff 09: Save/Load V2 and District Persistence

## Status

**Approved — 2026-09-03.** Implementation requires implemented H1-H8 authority snapshots, the recorded Fixture C H1 golden addendum, and MVP immediate realization. It is not blocked by future durable pending-cohort policy because MVP has no durable pending window.

## Purpose

**Revision:** 2026-09-08 delegated consistency pass. ADR 33 and Session H2 require coherent whole-session capture/candidate restore; `authorities.synergy` is exactly `{"schema_version":1,"mode":"derived_only"}` validated by Session, not a new stateful manager. MVP H3's due-payroll input is Staff-owned durable data. Root V2 keys stay unchanged; unsupported local payloads reject before staging, with no implied compatibility adapter. Current design scope is [Current MVP](../../../game_design/current_mvp.md).

**ADR 36 amendment, 2026-09-10:** The root remains Save V2 and the authority registry is unchanged. The current District local schema is `DistrictState.state_schema_version=3`; there is no converter, and local v2, older, and unknown District payloads reject before staging. This amendment does not assert implementation or evidence.

**ADR 37 correction, 2026-09-10:** The exact District v3 candidate includes the required construction annex defined by [ADR 37](../../decisions/37_district_construction_annex_schema.md), with corridors represented only by `explicit_circulation_cells`. This corrects ADR 36's root omission without changing Save V2, the registry, strict rejection policy, or evidence status.

Define Save V2 and detached, validated, atomic session replacement while preserving JSON monolithic slots, five slots, and `SaveManager` orchestration.

## Dependencies

- [H1](01_definition_schema_and_validation.md) semantic inclusion, [H2](02_resolved_district_model.md) canonical encoding/hash, H3-H8 state contracts.

## Source-of-truth documents

- [Decision 15](../../decisions/15_save_load_architecture.md)
- [Handoff index](./_index.md)

## Current-state findings

Current parsing emits `game_loaded`, schema follows application version, and managers deserialize sequentially into live state.

## Target state

Integer `save_schema_version`; layout/version/fingerprint identity; sparse authority snapshots; detached validation; staging projections; one atomic session commit; `game_loaded` only after commit. V2 is the first supported district-layout save schema.

## Scope

V2 envelope, V2 compatibility validation, staging, atomic commit, safe writes/backups, events, tests.

## Explicit non-goals

No generated data, V1 classification/conversion, runtime old-schema adapter, pending MVP records, gameplay policy, partial load, or guessed migration.

## System ownership

| Owner | Responsibility |
| --- | --- |
| `SaveManager` | I/O, schema validation, V2 compatibility policy, structured results, sole post-commit event. |
| H1 | Exact fingerprint semantic inclusion. |
| H2 | Exact canonical byte encoding and SHA-256. |
| Session owner | Candidate build and atomic swap. |

## Data contracts

### Exact V2 envelope

The V2 root has exactly `save_schema_version`, `meta`, `layout_ref`, and `authorities`; unknown or missing keys reject.

- `save_schema_version` is integer `2`.
- `meta` has exactly integer `slot`, integer UTC `timestamp`, and string `application_version`.
- `layout_ref` has exactly string `layout_id`, integer `layout_definition_version`, and lowercase 64-character hexadecimal SHA-256 `definition_fingerprint`.
- `authorities` has exactly the keys `district`, `zone_parcel`, `tenant`, `visitor`, `economy`, `progression`, `prestige`, `staff`, `synergy`, and `time`; no unknown or missing key is allowed.

Each authority value is a detached snapshot owned, versioned, and validated by that named authority. `authorities.district` is exactly H2/ADR 37's complete current `DistrictState` v3 schema, including the construction annex, explicit circulation, and manual-door edges, and its identity values must equal `layout_ref`. `authorities.economy` persists committed balance, loans, revision, and required recurring-settlement markers only; quotes, reservations, and capture tokens are excluded. `authorities.progression` persists committed Tech/point facts, milestone grants, selected/unlocked stable Plot IDs, and revision only; eligibility snapshots are derived after load and District must not duplicate selected Plot IDs. `authorities.visitor` persists realized visitor lifecycle state only; MVP persists no pending-arrival/cohort or source-capacity state. Derived geometry, transient ADR 35/ADR 36 snapshots, corridor identities, graphs, transforms, Nodes, indexes, presentation, reservations, pending cohorts, and caches are excluded.

Per [ADR 35](../../decisions/35_public_band_access_snapshot_and_zone_injection.md), Zone persists only each `PUBLIC_BAND` selected-door record's stable access-edge ID with its parcel cell and direction under the unchanged Zone local schema. Root `layout_ref` supplies durable layout provenance. No public-band snapshot, per-door fingerprint, Pedestrian Band ID, graph revision, or graph is persisted.

### Schema absence and incompatibility result

Any payload lacking `save_schema_version`, including every current V1 save, is unsupported. Reject it before staging, projection work, or live-session mutation. Do not classify its shape, convert it, map legacy source or floor IDs, derive baselines, or route fields through compatibility code.

Rejection returns a structured incompatibility diagnostic/result suitable for presentation, including a stable reason code and whether the slot was preserved. User-facing incompatibility messaging is required, but its exact text and UI location remain presentation-owned. Rejection never silently deletes, overwrites, or otherwise changes the existing save slot.

### Future V2 compatibility

V2 payloads must match the exact envelope above and resolve a known layout whose definition version and fingerprint match `layout_ref`. Unknown, retired, or incompatible layouts and fingerprints reject safely before staging. Future V2 schema migrations are permitted only when explicitly approved and released; no converter, registry, compatibility adapter, baseline/derivation policy, or migration artifact is created in advance.

## Communication and event flow

`parse -> require V2 root -> require current exact District local v3 including ADR 37 annex -> validate exact envelope -> resolve definition -> verify fingerprint -> validate District floor sets/annex/revisions -> validate Zone conflicts and remaining authority cross-refs detached -> derive candidate-only ADR 35/ADR 36 snapshots -> build and validate candidate topology/Staff and remaining projections -> atomic session commit publishes ready candidate values/projections -> game_loaded once`.

Detached restore must validate the root/layout and exact current District v3 candidate, including construction records, FloorState sets, revision invariants, fixed occupancy, and cross-owner Zone conflicts, before deriving transient snapshots inside the isolated candidate. Zone candidate acceptance uses those immutable values and requires every persisted public-band door's exact stable ID, endpoint, and direction to match the public-band snapshot. Missing, malformed, stale, absent, or mismatched input rejects without replacement or synthesis. Local District v2, older, and unknown payloads reject before staging. Candidate topology and Staff room-reference projections, the unsaved pedestrian graph, and all remaining staging projections must build and validate before atomic session replacement; no graph or projection failure may occur first after replacement. Post-commit runtime transaction graph and wall reactions are unaffected. Failure preserves the old session and slot.

Metadata reads, parsing, migration, staging, and failures emit no `game_loaded`.

## Persistence impact

V1 and other schema-absent payloads are rejected with no slot mutation. Save writes stage and validate the complete V2 envelope, flush a temporary file, then atomically replace the slot; failure preserves the prior slot. MVP retains no automatic rolling backup copies: the five player-controlled slots are the retention model. MVP persists no pending arrival records. Future durable cohorts must define persistence before shipping.

## Editor/runtime behavior

Editor can validate detached data without events or live mutation. Runtime exposes no staging Nodes/services before commit.

## V1 Save Support Decision (2026-08-31)

**Approved policy:** V2 is the first supported district-layout save schema. Current V1 saves and every payload without `save_schema_version` are incompatible and rejected before staging or live mutation. The old slot remains intact, and the returned structured diagnostic enables required presentation-owned incompatibility messaging. There is no V1 conversion, support window, compatibility adapter, fixture conversion, source/floor mapping, baseline/derivation policy, or migration registry.

## Expected affected files/systems

SaveManager, V2 DTOs, session staging, all authority snapshot boundaries, projection rebuild orchestration, presentation-owned incompatibility messaging.

## Acceptance criteria

Exact-key V2 sparse round trip, including exact DistrictState v3 explicit circulation/manual doors, Economy committed-only state, Progression-selected Plot ownership without District duplication, and stable-ID-only public-door provenance; local District v2/older/unknown and schema-absent/V1 rejection before staging with a structured incompatibility result and preserved slot; V2 malformed, unknown-layout, fingerprint, snapshot revision/layout/scope, and door-provenance rejection; candidate-only District-first derivation and Zone validation without replacement; post-commit snapshot/graph/projection rebuild; staged atomic save/load; all failures retain the old session and slot; one post-commit `game_loaded`; generated data absent; no pending-MVP blocker.

## Required tests

V2 exact root/meta/layout/authority key and type tests; exact DistrictState v3 schema, explicit-circulation/manual-door round trip, and local v2/older/unknown pre-staging rejection; H2 district-schema invariants; Economy reservation/token exclusion and recurring-settlement marker round trip; Progression selected-Plot/milestone round trip with derived eligibility reconstruction and no District duplication; realized-visitor-only MVP persistence; schema-absent payload (including current V1) rejection before staging/live mutation with structured incompatibility diagnostic and unchanged slot; V2 missing/unknown keys, unknown layout IDs, definition-version mismatch, fingerprint mismatch, malformed candidate snapshots, and cross-authority scope/revision mismatch rejection; detached authority validation; post-commit snapshot/graph/projection rebuild; fault injection at every staged load/save step; event order; safe temporary-file atomic replacement; round trip. Verify that no local District converter, V1 shape classifier, source/floor mapper, fixture conversion, baseline/derivation policy, compatibility adapter, or migration registry is reachable or required.

## Performance/scalability checks

Report parse/validate/rebuild/commit separately; size follows mutable state; repeated cycles leak nothing.

## Failure and rollback behavior

Any precommit failure destroys staging and preserves live session/slot. V2 never silently downgrades.

## Technical risks

JSON number coercion, accidental live singleton mutation, staging registration, unsupported definition retirement, and unclear presentation of incompatibility.

## FACTS

- `game_loaded` means successful atomic commit only.
- H1 owns inclusion; H2 owns bytes/hash.
- H9 is implementation-ready when H1-H8 authority snapshots and MVP immediate realization are implemented.

## ASSUMPTIONS

- Authorities expose detached snapshot validation/import.

## OPEN QUESTIONS

- Concrete performance budgets.
- Future V2 schema migration rules remain open and require explicit approval and release before implementation.
- Future durable cohort policy before those cohorts ship.

## GodotPrompter skills required by implementation agents

- `save-load`, `resource-pattern`, `dependency-injection`, `scene-organization`, `godot-testing`.
