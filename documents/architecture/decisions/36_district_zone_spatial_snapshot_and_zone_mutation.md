# ADR 36: District-Zone Spatial Snapshot and Zone Mutation Transaction

**Status:** Accepted, 2026-09-10. This is a binding architecture and state-schema decision. It does not assert implementation, migration, tests, evidence, Product acceptance, or release acceptance; prior evidence does not prove this decision.

## Context

Production Zone internals still depend on retired `GridManager`, `FloorGrid`, `GridTile`, and `PlotData` semantics, which H10 prohibits in production dependencies and adapters. [ADR 31](31_door_endpoint_semantics_views.md) owns District endpoint facts but exposes only narrow per-endpoint views. A broader snapshot without durable District source facts would hide rather than remove legacy authority.

The source gap is the frozen H2 `DistrictState` v2 shape: it cannot distinguish explicit constructed circulation and omits the District-owned manual-door records required by [ADR 30](30_manual_door_authority.md). This decision amends that state schema and defines the bounded value needed by Zone transactions.

## Decision

Approve option B, but not an implementation agent's exact name or a new service boundary. `DistrictZoneSpatialSnapshot` is a floor-scoped batch generalization of ADR 31's District endpoint view. It is not a manager, autoload, service, authority, or generalized world-spatial query boundary.

`PublicBandAccessSnapshot` from [ADR 35](35_public_band_access_snapshot_and_zone_injection.md) remains a separate injected value. Passing `DistrictState`, `PedestrianGraphSnapshot`, `GridManager`, or projection state directly is rejected.

`FloorAccessContext` may remain only as a pure transient internal composition helper built from matching immutable District and Zone snapshots. It is not an architecture boundary and may not expose, retain, or query `GridManager`, `FloorGrid`, `GridTile`, `PlotData`, Nodes, or live managers.

### DistrictState v3 amendment

The root remains Save V2 and the authority registry is unchanged. The current `DistrictState.state_schema_version` is integer `3`. There is no converter: local v2, older, and unknown District schemas reject before staging. This pre-release project retains the already approved strict-rejection policy.

**Correction before implementation acceptance:** [ADR 37](37_district_construction_annex_schema.md) corrects this decision's accidental exact-root omission. The exact `DistrictState` v3 root keys are `state_schema_version`, `district_revision`, `layout_id`, `layout_definition_version`, `definition_fingerprint`, `plot_states`, `street_segment_states`, `arrival_source_states`, `demolished_fixed_occupant_ids`, `construction_schema_version`, `construction_revision`, `construction_records`, and `manual_door_edges`; `FloorState` has exactly its prior fields plus `explicit_circulation_cells`. Unknown or missing keys reject, and `manual_door_records` is obsolete and forbidden. ADR 37 is authoritative for the exact annex and record schema.

- `acquired_cells`, `constructed_cells`, and `explicit_circulation_cells` are duplicate-free and ordered row-major by `(y,x)`.
- Every explicit-circulation cell is constructed and acquired. Generic constructed or unzoned space is never inferred as circulation.
- Active corridors exist only in `explicit_circulation_cells`; corridor construction records are invalid. Retained construction records contain only stairs, elevators, and Operations Rooms under ADR 37.
- Each `manual_door_edges` record has exactly `endpoint_a` and `endpoint_b`; each endpoint is ADR 31's exact `FloorCellAddress` `{runtime_plot_id:string, signed_elevation:int, local_cell:{x:int,y:int}}`.
- Door endpoints have the same `runtime_plot_id` and `signed_elevation`, are distinct, and are orthogonally adjacent. They are canonical ascending by `(runtime_plot_id,signed_elevation,local_cell.y,local_cell.x)`.
- The collection is sorted by endpoint pair and duplicate-free. Presence means a committed door. Zone identity and typology are not duplicated.

This amends only H2's frozen state schema. H1/H2 definition fingerprints and resolved-layout goldens do not change. New state, save, and transaction verification is required; old evidence does not prove ADR 36.

### Exact transient snapshot

Unknown or missing fields and any invariant failure invalidate the value. `DistrictZoneSpatialSnapshot` has exactly:

- `schema_id`: literal `district_zone_spatial_snapshot`.
- `schema_version`: integer `1`.
- `layout_ref`: exact H9 `{layout_id:string, layout_definition_version:int, definition_fingerprint:lowercase 64-char sha256}`.
- `district_revision`: nonnegative integer revision of the represented committed or prospective candidate.
- `floor_scope`: exact `{floor_id:string, runtime_plot_id:string, signed_elevation:int}`, where `floor_id` resolves to the H2 `(runtime_plot_id,signed_elevation)` tuple.
- `valid_cells`: duplicate-free row-major array of exact `{x:int,y:int}`.
- `acquired_cells`: the same shape and order, and a subset of `valid_cells`.
- `constructed_cells`: the same shape and order, and a subset of `acquired_cells`.
- `zone_eligible_cells`: the same shape and order, and a subset of `constructed_cells`. It means only the District-owned conjunction of resolved validity, rights/acquisition, availability, buildability, construction, caps, and no incompatible fixed occupancy. It includes no Zone membership or typology policy.
- `explicit_circulation_cells`: the same shape and order, and a subset of both `constructed_cells` and `zone_eligible_cells`.
- `manual_door_edges`: canonical DistrictState v3 door records whose endpoints resolve to this floor scope.

The snapshot is immutable, transient, and unsaved, derived from exactly one resolved layout plus one committed or prospective District candidate. It contains no zone IDs, typology, parcels, public bands, graph/path data, transforms, Nodes, mutable collections, or implicit plot/floor defaults. The whole explicitly addressed floor scope is deliberate and bounded; this decision does not authorize a generalized world spatial service.

### Coordinated Zone mutation

Zone-type paint consumes explicit circulation and None paint restores it, so Zone paint is a coordinated District and Zone mutation:

1. The District coordinator captures the immutable resolved layout, District base, Zone base, revisions, ADR 36 base snapshot, and ADR 35 public-band snapshot.
2. Zone pure preview resolves one Zone plan from intent, Zone base, and the injected snapshots. It requests only exact sorted cell sets to remove from or add to explicit circulation and canonical obsolete same-zone merge manual-door edges to remove. The request is not authority state.
3. District validates those effects against the intent and base facts, prepares a prospective District candidate without changing acquired or constructed cells for paint, increments `construction_revision` exactly once when explicit circulation changes, and derives prospective ADR 36 and ADR 35 snapshots.
4. Zone prepare validates the same plan against the prospective inputs and returns a token bound to District revision, Zone base revision, `layout_ref`, and plan identity.
5. The existing H3 gate and barrier revalidate, swap District and Zone state atomically, append once, and flush once. H5 graph/path projections and H4 walls react only after commit. Zone never mutates grid, pathfinding, or projection state.
6. Failure before append changes neither authority and publishes nothing.

A Zone-only mutation that truly changes no District fact may use committed District state as the unchanged candidate, but still receives the snapshot. A District mutation affecting Zone legality injects a prospective snapshot and includes Zone as a participant. Preview and commit use the same pure policies. No direct production Zone commit may mutate legacy spatial state.

Zone paint consumption/restoration is not Construction-tool demolition or removal and creates no corridor record, removal path, or refund. `district_revision` remains the sole concurrency guard; ADR 37's `construction_revision` is content versioning bound to the enclosing District revision/layout/commit.

### Failure codes

The stable architecture-level codes are:

- `DISTRICT_ZONE_SPATIAL_UNAVAILABLE`
- `DISTRICT_ZONE_SPATIAL_STALE`
- `DISTRICT_ZONE_SPATIAL_SCOPE_MISMATCH`
- `INVALID_DISTRICT_ZONE_SPATIAL_SNAPSHOT`

Existing door and zone errors remain.

## Alternatives rejected

- Keep legacy Zone inputs or add an adapter: prohibited by H10 and preserves retired authority.
- Pass `DistrictState`: exposes persistence internals instead of a bounded purpose-specific value.
- Pass `PedestrianGraphSnapshot`: supplies broader post-commit projection state and creates prospective timing problems.
- Derive from projection state: makes generated state authoritative.
- Add a new spatial manager/service: duplicates authority and creates an unbounded query boundary.

## Acceptance obligations

- No production dependency, signature, or reachability to `GridManager`, `FloorGrid`, `GridTile`, `PlotData`, legacy adapters, or the archive group.
- Unequal/masked-plot and signed-elevation explicit-scope coverage.
- Distinct valid, acquired, constructed, eligible, and explicit-circulation coverage; generic unzoned space is never inferred as circulation.
- Zone-type paint removes explicit circulation and None restores it without changing acquired or constructed cells.
- Manual merge-door removal is a District-state mutation requested by the Zone plan and committed atomically.
- Preview/prepare parity; stale, mixed, scope, and malformed failures; no partial events.
- Automatic and public-band door preservation with ADR 35.
- Exact DistrictState v3 schema and Save V2 round trip, with old local District schema rejection.
- Path, graph, and walls update only from committed deltas.
