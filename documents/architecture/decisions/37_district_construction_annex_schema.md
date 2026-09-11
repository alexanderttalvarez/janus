# ADR 37: District Construction Annex Schema

**Status:** Accepted, 2026-09-10. This is a binding architecture and state-schema decision. It corrects ADR 36's accidental exact-root omission before ADR 36 implementation acceptance. It asserts no implementation, migration/converter, tests, evidence, Product acceptance, or release acceptance; prior evidence does not prove this decision.

## Context

[ADR 36](36_district_zone_spatial_snapshot_and_zone_mutation.md) approved `DistrictState` v3 but described its exact root as the prior v2 shape plus only `manual_door_edges`. Approved [Construction H1](../handoff/construction/01_mvp_circulation_vertical_links_and_operations_room.md) requires durable identities and geometry for stairs, elevators, and Operations Rooms. Persisting corridors both as construction records and as `FloorState.explicit_circulation_cells`, or treating construction revision as a second concurrency authority, would duplicate authoritative state.

## Decision

Retain a closed construction annex inside `DistrictState` v3, without a second concurrency authority or duplicate active-corridor state. The save root remains V2, the authority registry is unchanged, and the District local schema remains v3. No migration or converter is approved. Local v2, older, and unknown District schemas continue to reject under the current strict policy.

### Exact DistrictState v3 root

Unknown or missing keys reject. `state_schema_version` is literal integer `3`. The root has exactly:

- `state_schema_version`
- `district_revision`
- `layout_id`
- `layout_definition_version`
- `definition_fingerprint`
- `plot_states`
- `street_segment_states`
- `arrival_source_states`
- `demolished_fixed_occupant_ids`
- `construction_schema_version`
- `construction_revision`
- `construction_records`
- `manual_door_edges`

`manual_door_records` is obsolete and forbidden. `manual_door_edges` remains the exact ADR 36/ADR 31 representation.

### Revisions

`construction_schema_version` is literal integer `1`. `construction_revision` is a nonnegative District-owned construction-content revision, not an independent concurrency revision or authority. `district_revision` remains the sole optimistic concurrency guard.

`construction_revision` increments exactly once in a successful District commit that changes either `construction_records` or any `FloorState.explicit_circulation_cells`; otherwise it is unchanged. It cannot exceed `district_revision`. Consumers bind it to the enclosing `district_revision`, layout identity, and commit ID and may not commit against it alone.

### Active corridors

- Active corridor cells are represented only by `FloorState.explicit_circulation_cells`, which remain a subset of constructed and acquired cells. A persisted corridor `construction_record` is invalid because it would duplicate authority and conflict with Zone paint consumption/restoration.
- A corridor's stable construction identity is derived deterministically from its exact ADR 36 `FloorCellAddress` and layout identity. It is unsaved and may be used by deltas and projections.
- Corridor construction adds the cell to `constructed_cells` when not already constructed and to `explicit_circulation_cells`.
- ADR 36 Zone-type paint removes only explicit-circulation membership; None restores it. Acquired and constructed membership remain. These transitions increment `construction_revision` because active construction topology changed.
- Zone conversion is not Construction-tool demolition/removal and creates no general removal, cancellation, salvage, or refund gameplay.

### Exact construction_records schema

`construction_records` is duplicate-free and sorted ascending by `construction_id`. It contains only `stairs`, `elevator`, and `operations_room`; a `corridor` record is invalid. Every record has exactly:

- `construction_id`: nonempty stable string.
- `kind`: `stairs` | `elevator` | `operations_room`.
- `plot_id`: stable runtime Plot ID.
- `cells`: canonical nonempty array of exact `ConstructionCellAddress` values.
- `shaft_cells`: canonical array of `ConstructionCellAddress` values.
- `lobby_cells`: canonical array of `ConstructionCellAddress` values.
- `connection`: exact `{orientation:string, stop_elevations:Array[int]}`.

`ConstructionCellAddress` has exactly `{plot_id:string, floor_id:string, elevation:int, x:int, y:int}` and resolves to H2's exact floor, plot, and cell identity. Address arrays are duplicate-free and sort ascending by `(elevation,floor_id,y,x)`. Every address's `plot_id` equals its record's `plot_id`. `cells` is the exact occupied union. No occupied cell may overlap another construction record or fixed occupancy.

Kind invariants are:

- `stairs`: `cells` is the approved matching 2x2 footprint on each of exactly two adjacent elevations; `shaft_cells` and `lobby_cells` are empty; `stop_elevations` is exactly those elevations ascending; `orientation` is the approved cardinal orientation.
- `elevator`: `shaft_cells` has one same-local-cell address per contiguous stop including G; `lobby_cells` has one distinct lobby address on every same-floor stop; `cells` is the exact duplicate-free union; `stop_elevations` is exactly the contiguous stops ascending; `orientation` is `NONE`.
- `operations_room`: `cells` is one 2x2 footprint on one floor; `shaft_cells` and `lobby_cells` are empty; `stop_elevations` is exactly that elevation; `orientation` is `NONE`. `operations_room_id` derives as `construction_id` and MVP `building_id` derives as `plot_id`; neither is duplicated in persistence.

At commit and detached restore, every record must satisfy the acquired, constructed, buildable, available, current-cap, current-policy, and Zone compatibility requirements already approved by Construction H1.

### Occupancy and Zone validation

`constructed_cells` means occupied construction cells, including active explicit circulation and the occupied union of retained `construction_records`. Zone paint leaves the generic constructed floor in place while changing only circulation classification. Prospective one-element-per-tile validation considers Zone state, fixed occupants, explicit circulation, and construction records; it never infers generic unzoned constructed space as corridor.

### Publication and projections

Topology and Staff facts derive only from committed `explicit_circulation_cells` plus `construction_records`. Every published construction revision is the enclosing state's `construction_revision`, bound with `district_revision` and commit ID. Nodes, `GridManager`, graphs, caches, and projection state are never authoritative inputs.

### Save and restore

Exact District v3 validation includes the annex. Before commit, the detached candidate validates construction records, FloorState sets, revision invariants, ownership/caps/policies, occupancy, and cross-owner Zone conflicts. Candidate topology and Staff projections rebuild and validate from that candidate before active-session replacement. Unknown, missing, old, or malformed local District schemas reject without conversion or repair.

## Alternatives rejected

- Remove the annex: loses durable identities, links, and rooms.
- Keep three loose fields while persisting corridor records beside explicit cells: duplicates active-corridor authority.
- Make `construction_revision` an independent concurrency authority: conflicts with District's sole-write and atomic-commit boundary.
- Add a construction save root or authority-registry key: unnecessarily changes Save V2 ownership.

## Acceptance obligations

- Exact-key acceptance/rejection, including `manual_door_records` rejection and `manual_door_edges` acceptance.
- Corridor no-record enforcement and deterministic unsaved identity.
- Zone consume/restore round trip with unchanged acquired/constructed membership and exactly specified revision behavior.
- Each retained kind round trip; malformed footprint, stop, shaft, lobby, orientation, and union rejection.
- Duplicate, overlap, fixed-occupancy, ownership, cap/policy, and cross-reference rejection.
- Detached candidate restore and candidate topology/Staff projection readiness before replacement.
- No converter, legacy dependency, projection authority, second concurrency guard, or prior-evidence substitution.
