# Handoff 06 — Paint-First Zone Mutation and Preservation

**Status:** Approved
**Approved:** 2026-08-26
**Implementation order:** 6 — after Handoffs 01–05

## Purpose

**Revision:** 2026-09-08 delegated consistency pass. [Current MVP](../../../game_design/current_mvp.md), element 20, ADR 33 and the staged `tenant_interiors/H2` amendment apply. Explicit retirement atomically removes the retired parcel's automatic doors and any authorized Tenant binding, but never relaxes surviving-parcel or unrelated manual-door protection. Live occupied-interior edits requiring Service/Visitor swaps remain gated; detached prospective tests do not activate draft H4/H5. Ordinary paint must not infer eviction merely from changed area.

**Follow-on review, 2026-09-08:** The preceding revision records the earlier consistency pass. [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md) separately architecture-approves interior H4/H5. Foundation -> detached interior H1-H3 -> H4 implementation passes -> H5 candidate cutover passes -> Product acceptance; external Gate R is separate. Live occupied-edit Service/Visitor integration requires those implementation/cutover passes; detached tests and document approval activate nothing. Implementation/cutover remain NOT VERIFIED; Product acceptance/Gate R remain PENDING.

**ADR 36 revision, 2026-09-10:** [ADR 36](../../decisions/36_district_zone_spatial_snapshot_and_zone_mutation.md) replaces the production legacy-grid input and direct mutation statements below with injected immutable District/Zone snapshots and one coordinated District/Zone transaction. This is architecture approval only; implementation and evidence are not asserted.

**ADR 37 correction, 2026-09-10:** A successful Zone commit changing explicit circulation increments District-owned `construction_revision` exactly once but never creates or removes a corridor record. Zone conversion preserves acquired/constructed membership and is not Construction-tool demolition/removal or a refund path.

Replace the separate Edit Zone workflow with one paint-first Build Zone workflow.

The player paints a zone type to create, extend, or merge zones. The player paints **None** to remove selected zone tiles and return them to built external circulation. The implementation must preserve unaffected established parcels instead of globally reshuffling them when zones expand or merge.

This handoff supersedes the Handoff 01 / Decision 11 full-zone re-split rule for additive paint and same-type zone merges. Full-zone re-splitting remains inappropriate for those operations because it would move unaffected businesses.

## Player-facing rules

### Zone-type paint

- Painting a zone type onto unzoned explicit CIRCULATION tiles creates a new zone when no same-type zone is orthogonally connected through the pending paint.
- Painting adjacent to one same-type zone extends it.
- Painting that connects two or more same-type zones merges them.
- Painting over a tile already belonging to a zone of the selected type is a no-op.
- Painting over a different zone type is rejected. The player must paint None first.
- A merge may include all same-type zones connected through the pending painted tile set, not only the first touched zone.

### None paint

- None removes the selected tiles from their existing zone or zones and restores those tiles to owned, built, explicit `TileElement.CIRCULATION`.
- None on an already unzoned tile is a no-op.
- A paint stroke may affect multiple zones, but the full stroke is one atomic transaction: if any affected zone would become invalid, no tile from the stroke commits.
- Removing every tile from a zone deletes its `ZoneData` and parcels but does **not** sell or demolish the floor. All removed tiles become circulation.
- Removing a bridge that would leave a zone disconnected is rejected. The preview must draw the existing red invalid perimeter and disable Finish Zone.

### Tool modes

- Build Zone adds a **None** toggle alongside zone types.
- None, Transit tiles, and Remove are mutually exclusive modes. Activating one deactivates the others.
- Remove keeps its current pending-paint erase behavior; None changes committed-zone membership in the prospective transaction.
- The toolbar must show a specific invalid state for disconnected removal and preserve the existing blocked-door feedback.

## Mutation resolution

`ZoneTool` owns stroke capture and visual preview only. It does not decide zone identity, merge membership, parcel preservation, or persistence.

`ZoneManager` owns pure plan resolution and its Zone candidate for a `ZonePaintIntent`; District coordinates any commit that changes District facts:

```text
ZonePaintIntent
├── plot_id / floor
├── paint_mode: zone_type | none
├── selected tile set
└── pending per-tile typology overrides
```

Zone resolves the intent from its immutable Zone base, the exact floor-scoped `DistrictZoneSpatialSnapshot`, and the separate `PublicBandAccessSnapshot` into a `ZoneMutationPlan` before any authority, counter, or event mutation:

```text
intent
  -> discover source zones and target type
  -> validate paint eligibility and connectivity
  -> choose survivor / retired zones
  -> lock unaffected parcels
  -> plan new or mutable-space parcels
  -> validate automatic/manual doors and walls
  -> preview result OR District effect request + Zone prepare
```

The plan's only requested District effects are exact sorted cell sets to remove from/add to explicit circulation and canonical obsolete same-zone merge manual-door edges to remove. This request is not authority state. District validates it, prepares a prospective District candidate without changing acquired/constructed cells or creating/removing corridor records, increments `construction_revision` once if circulation changes, derives prospective ADR 36 and ADR 35 snapshots, and returns those inputs for Zone preparation of the same plan. Preview and commit use the same pure policies. Preview may allocate temporary plan data but may not consume persistent IDs/counters or mutate committed state.

## Zone identity and merge ownership

- All merging source zones must have the same zone type, plot, and floor.
- The deterministic survivor is the source zone with the lexicographically lowest persistent zone ID.
- The survivor retains its ID, name, layout seed, and zone-level metadata.
- All other source zone IDs are retired on commit.
- The merged zone owns the union of source-zone tiles plus new painted tiles and the combined typology map.
- Existing parcel IDs from all source zones remain globally unique and are retained when their parcel geometry is locked and still valid.
- Newly created parcels receive normal globally unique IDs and display numbers.

## Preservation-first parcel policy

### Locked parcels

A parcel is locked when its complete Tenant geometry is unchanged by the mutation and it remains legally fronted. A locked parcel retains:

- parcel ID and display number;
- geometry and core geometry;
- assigned debug subtype;
- future tenant reference/lifecycle state;
- selected automatic doors, subject to the existing door-preservation invariant.

Locked parcels are immutable occupied geometry for the mutation planner. New parcel generation must not consume, reshape, or reassign their tiles.

### Additions and merges

- Only newly painted Tenant components are eligible for new parcel generation.
- Existing locked parcels from every merged source zone are preserved unchanged.
- New painted Transit/Decoration tiles may form connectors and may merge zones without requiring a new parcel.
- New painted Tenant tiles must produce at least one valid new parcel or become documented residual Decoration through the successful plan; they must never force an existing parcel to resize.
- The new-space solver must treat locked parcels as boundaries and use only legitimate external CIRCULATION or same-zone Transit frontage.

### None removals

- Removing a Transit/Decoration tile leaves unrelated parcels locked.
- Removing any tile from a parcel makes that parcel mutable; it is retired if the remaining geometry cannot form a valid parcel under the applicable minimum/frontage policy.
- Unaffected parcels remain locked. Mutable remaining space is recalculated without modifying locked parcels.
- Current MVP debug mode retires parcel metadata only. Future tenant lifecycle implementation owns eviction, exclusivity locks, notifications, and tenant events.

### Debug subtype assignment

Handoff 02 is amended for this handoff:

- Locked parcels keep their existing debug subtype assignment.
- Only new or recalculated mutable parcels receive a new deterministic assignment.
- The assignment step must consider locked neighboring assignments as fixed graph-color constraints, so a new parcel cannot duplicate an edge-adjacent locked subtype.

## Door and wall rules

- All Handoff 05 automatic-door preservation rules continue to apply to locked parcels. A mutation that blocks an existing automatic door rejects atomically.
- All changed-endpoint manual-door preservation rules continue to apply, except for one approved merge exception.
- A manual Transit↔Transit door exactly on a boundary between source zones being merged is obsolete after merge: the Zone plan requests removal of its canonical DistrictState v3 edge, and District validates and includes that mutation in the atomic commit. It does not reject the merge.
- Every other manual door must remain legal under the prospective manual-door rules or reject atomically.
- The former boundary between merged zones is no longer structural after commit; wall rebuilding removes it except where parcel-boundary rules require walls.

## Validity and failure policy

A plan rejects without partial mutation when it has any of the following:

| Condition | Result |
|---|---|
| Different zone type touched by type paint | `INVALID_ZONE_GEOMETRY` with a stable type-conflict diagnostic. |
| Remaining zone is not 4-connected after None | `INVALID_ZONE_GEOMETRY` with `DISCONNECTED_ZONE`. |
| New/mutable Tenant space has no valid minimum-sized fronted parcel | Existing split failure status; no commit. |
| Existing automatic door is blocked | `EXISTING_DOOR_INVALIDATED`. |
| Existing non-obsolete manual door becomes illegal | `EXISTING_DOOR_INVALIDATED`. |
| Merge source zones differ in plot/floor/type | `INVALID_ZONE_GEOMETRY`. |

A rejected plan preserves District and Zone authority, parcels, typologies, explicit circulation, manual-door edges, counters, events, pathfinding, walls, and labels.

## Runtime flow

```text
Player selects zone type or None
  -> ZoneTool collects one pending stroke
  -> capture District/Zone bases, revisions, ADR 36 snapshot, and ADR 35 snapshot
  -> Zone pure preview resolves sources / merge / removal
  -> locked parcels + mutable/new-space plan derived
  -> door/connectivity checks + exact requested District effects
  -> valid: enable Finish; invalid: red perimeter + status
  -> District validates effects and prepares prospective candidate
  -> derive prospective ADR 36 and ADR 35 snapshots
  -> Zone prepares the same plan against prospective inputs
  -> H3 gate revalidates and atomically swaps District + Zone state
  -> append once and flush once
  -> graph/path and walls react to committed deltas only
  -> emit zone-created / zone-modified / zone-deleted events in deterministic order
```

## Data ownership

| Owner | Responsibility |
|---|---|
| `ZoneTool` | Paint mode, stroke selection, None/Transit/Remove exclusivity, and non-mutating visual feedback. |
| `ZoneManager` | Intent/plan resolution, zone merge/remove ownership, locked-parcel selection, Zone candidate validation/preparation, and Zone identity lifecycle. It never writes District, grid, graph/path, or projection state. |
| Pure mutation planner / new-space solver | Plan parcel geometry only for mutable or newly painted space while treating locked parcels as immutable obstacles. |
| `ZoneBusinessAssigner` | Assign only new/mutable parcels while respecting locked subtype assignments. |
| District coordinator/runtime | Derive ADR 36/ADR 35 snapshots, validate requested circulation/manual-door effects, prepare the District candidate, and coordinate the existing H3 atomic commit. |
| H5 graph/path projection | React only to committed District/Zone deltas; never participate in preview or authority mutation. |
| `WallManager` | React only to committed deltas and remove former merged-zone structural boundaries. |
| Future tenant lifecycle | Owns eviction consequences; not implemented here. |

## Acceptance requirements

- Extending a zone preserves all unaffected parcels and their IDs, display numbers, subtype assignments, and automatic doors.
- Connecting same-type zones merges them under the deterministic survivor ID without reshuffling locked parcels.
- A Transit/Decoration-only connector may merge zones without producing a new tenant parcel.
- A different-type zone cannot be painted over or silently converted.
- None returns removed tiles to built explicit circulation; removing all tiles deletes only the zone, not the floor.
- None that disconnects a zone remains preview-invalid, has a red perimeter, and cannot finalize.
- A merge clears only obsolete manual Transit↔Transit doors on its former source-zone boundaries; unrelated manual doors remain protected.
- New/mutable parcel subtype assignment respects fixed neighboring locked assignments.
- Preview and commit agree exactly for merge, remove, door, residual, identity, and failure outcomes.
- Rejected plans leave all committed state and counters unchanged.
- Stale, mixed, scope-mismatched, unavailable, or malformed ADR 36 input fails with the approved architecture-level code and no partial event.
- Zone-type paint removes explicit circulation and None restores it while acquired and constructed cell sets remain unchanged.
- A committed circulation membership change increments `construction_revision` exactly once, creates/removes no corridor record, and is not Construction-tool demolition/removal.
- Production Zone signatures and dependencies have no reachability to `GridManager`, `FloorGrid`, `GridTile`, `PlotData`, legacy adapters, or archive content.

## Explicit non-goals

- Tenant eviction implementation, tenant applications, exclusivity lock timers, notifications, revenue, prestige, or construction.
- Automatic merging of different zone types.
- Automatic splitting of disconnected remainders into multiple zones.
- Changes to door collision, navigation semantics beyond normal rebuilds, or wall visualization modes.
- Save-file schema migration beyond existing ZoneData/Parcel persistence contracts.
