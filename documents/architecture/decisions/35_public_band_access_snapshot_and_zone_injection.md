# ADR 35: Public Band Access Snapshot and Zone Injection

**Status:** Accepted, 2026-09-09. This resolves the existing H5 public-band access boundary and current Zone door representation. It does not assert implementation, migration, test, Product acceptance, or release evidence.

## Context

[District H5](../handoff/district_layout/05_street_and_pedestrian_generation.md) already owns public topology and permits active public Pedestrian Bands to provide physical parcel access, while [Zone H5](../handoff/zone_parcels/05_automatic_parcel_doors.md) keeps `ZoneManager` as the sole automatic-door and parcel writer. Passing the post-commit `PedestrianGraphSnapshot` into prospective Zone work would create circular timing, and the current Zone schema did not state the exact durable public-door provenance record.

## Decision

No manager, autoload, or save root is added. `PublicBandAccessSnapshot` is an immutable, transient, unsaved H5 value derived by the public-realm resolver from exactly one immutable resolved layout and one committed or prospective District candidate. The District transaction coordinator injects it explicitly into Zone preparation. `ZoneManager` remains the sole automatic-door and parcel writer; H5 remains the public-topology owner.

### Exact snapshot contract

Unknown or missing fields invalidate the value at the architecture boundary. `PublicBandAccessSnapshot` has exactly:

- `schema_id`: literal `public_band_access_snapshot`.
- `schema_version`: integer `1`.
- `layout_ref`: exactly `{layout_id:string, layout_definition_version:int, definition_fingerprint:lowercase 64-char sha256}`, matching [District H9](../handoff/district_layout/09_save_load_v2.md).
- `district_revision`: nonnegative integer revision of the committed or prospective District candidate represented.
- `access_edges`: duplicate-free array sorted ascending by `access_edge_id`.

Each access edge has exactly:

- `access_edge_id`: stable `jid1` identity.
- `parcel_endpoint`: exact `FloorCellAddress` `{runtime_plot_id:string, signed_elevation:int, local_cell:{x:int,y:int}}`.
- `outward_direction`: exactly `NORTH`, `EAST`, `SOUTH`, or `WEST`.
- `pedestrian_band_id`: stable H2 Pedestrian Band ID.

The access-edge identity tuple is `(public_band_access, pedestrian_band_id, runtime_plot_id, signed_elevation, local_cell.x, local_cell.y, outward_direction)`, framed by [District H2](../handoff/district_layout/02_resolved_district_model.md) `jid1` rules. Public bands are ground public realm, so every valid entry has `signed_elevation=0`. An entry represents positive-length orthogonal adjacency from an Active/owned Plot boundary to an active Pedestrian Band. Corner-only, selected/unowned, inactive, virtual, implicit, or transform-derived entries are absent; accepting any such entry is invalid.

The snapshot contains no Nodes, transforms, graph indexes or handles, Zone or parcel IDs, or mutable collections.

### Exact persisted selected-door contract

Each Parcel persists `selected_door_edges`, duplicate-free and canonically sorted by `parcel_cell.y`, `parcel_cell.x`, then `direction`. Every record has exactly:

- `parcel_cell`: exact `{x:int,y:int}` in the parent Parcel's Plot/elevation scope.
- `direction`: exactly `NORTH`, `EAST`, `SOUTH`, or `WEST`.
- `access_kind`: exactly `SAME_ZONE_TRANSIT`, `EXPLICIT_CIRCULATION`, or `PUBLIC_BAND`.
- `access_cell`: exact `{x:int,y:int}` for `SAME_ZONE_TRANSIT` and `EXPLICIT_CIRCULATION`; `null` for `PUBLIC_BAND`.
- `public_band_access_edge_id`: `null` for `SAME_ZONE_TRANSIT` and `EXPLICIT_CIRCULATION`; a nonempty stable snapshot edge ID for `PUBLIC_BAND`.

Unknown or missing fields, an invalid null pairing, a duplicate origin cell, or a duplicate record reject. The V2 root and Zone local discriminator/version remain unchanged: `zone_parcel_core_annex`, version `1`. H5 already approved doors and graph provenance; this decision clarifies their exact current-schema representation and is not a migration. Root `layout_ref` plus the stable edge ID is durable provenance. Do not duplicate the snapshot, fingerprint, Pedestrian Band ID, or graph revision per door, and persist no graph or snapshot.

### Allocation and validation

Candidate positions comprise same-zone Transit, explicit owned/built circulation, and injected snapshot entries whose endpoints match Parcel boundary cells. Public-band access is external physical access and participates in the existing preservation-first allocation.

An existing persisted `PUBLIC_BAND` selection is legal only when its exact ID exists and its endpoint and direction match in the injected prospective snapshot. A replacement edge never compensates for an absent or changed retained edge. Missing, malformed, or stale snapshot input fails closed.

Stable reason codes are:

- `PUBLIC_BAND_ACCESS_UNAVAILABLE`: required public access has missing or incompatible snapshot input during a transaction.
- `PUBLIC_BAND_ACCESS_STALE`: District revision or layout identity mismatch.
- `EXISTING_DOOR_INVALIDATED`: a retained edge ID is absent or its endpoint/direction differs.
- `INVALID_PUBLIC_BAND_DOOR_PROVENANCE`: malformed persisted public-band door record or load provenance.

### Transaction injection

Preview and commit capture the same District base/candidate, `layout_ref`, and Zone base/candidate. Pure H5 derivation creates the snapshot from the District candidate, and the District coordinator passes it as explicit Zone prepare input; Zone does not query global H5 state or a live graph. Zone preparation returns a detached candidate/token bound to `district_revision`, Zone base revision, and `layout_ref`.

Under the existing [H3 gate](../handoff/district_layout/03_variable_floor_grid_migration.md), District revision, Zone revision, and layout fingerprint are revalidated before authority swaps. Authorities swap and the complete envelope appends once under the existing protocol. The post-commit `PedestrianGraphSnapshot` rebuild uses committed facts and must contain the same stable connector IDs.

A Zone-only mutation uses current committed District state as its District candidate. A District mutation that may affect public access includes Zone as a participant even when it requests no new doors, so retained doors validate atomically. Missing or stale data rejects before any swap, event, save-visible change, wall mutation, or graph mutation.

### Save and load

Only Zone door-record stable IDs persist. Detached restore validates the V2 root, `layout_ref`, and District candidate first; derives a candidate `PublicBandAccessSnapshot`; then validates Zone selected doors against that snapshot before accepting the Zone candidate. It neither replaces nor synthesizes public-band access. The unsaved pedestrian graph rebuild follows accepted durable candidates. Any failure preserves the old session and slot.

## Alternatives rejected

- Use `PedestrianGraphSnapshot` directly: it is broader, post-commit derived state and creates circular prospective timing.
- Persist `PublicBandAccessSnapshot`: it duplicates resolved District/layout facts and can become stale.
- Add a generalized spatial service: it introduces a new owner and abstraction without a current requirement.

## Acceptance obligations

Verify deterministic snapshot derivation; ground-level public-edge allocation; preservation and save round trip; atomic rejection when a retained public edge is removed; Zone-only and District-changing preview/commit parity; layout, revision, and malformed-input rejection; candidate-only save/load validation; post-commit graph connector-ID parity; and absence of global queries, new owners, persisted snapshots, or persisted graphs.
