# Handoff 01 — Deterministic Parcel Splitting

**Status:** Approved
**Approved:** 2026-08-22
**Implementation order:** 1 of 1

## Purpose

When a player finalizes or edits a zone, derive valid business-parcel geometry from its Tenant tiles. This handoff covers geometry, validation, stable parcel identity, and the two door concepts needed to validate access.

It does **not** assign tenant subtypes, create tenants, run applications or lifecycle states, spawn interiors, create door visuals, alter walls, create labels, or implement notifications.

## Authoritative design constraints

- Zones are contiguous painted areas on a single floor.
- Only tiles typed **Tenant** are rentable parcel area.
- **Transit** and **Decoration** tiles are never parcel area. Internal Transit may provide access/frontage; Decoration does not.
- Every valid parcel is a non-overlapping, 4-connected, axis-aligned rectangle made only of Tenant tiles.
- Every valid parcel has at least one usable access edge to circulation.
- Zone splitting is geometry only; business subtype assignment and tenant lifecycle remain downstream systems.
- Recalculate the full geometry after every tile or typology edit. Wall-mode changes do not trigger a split.

## Data ownership and contract

| Owner | Responsibility |
|---|---|
| `ZoneManager` | Owns `ZoneData`, validates/commits zone edits atomically, retains prior parcels for overlap matching, synchronizes GridManager only after success. |
| `ZoneSplitter` | Pure, stateless geometry pass. It receives immutable zone/grid/policy input and returns a `SplitResult`; it does not mutate, emit signals, assign businesses, or depend on scene nodes. |
| `GridManager` | Owns tile validity, typology, footprint bounds, and circulation classifications used to evaluate access. |
| `ZoneBusinessAssigner` | Downstream-only owner of business-subtype choice. It receives valid, unoccupied parcels after a successful split. |
| Future tenant lifecycle | Owns tenant identity and occupancy state; out of scope for this handoff. |

### Required split input

- Zone ID, **plot ID**, floor ID, zone type, painted tile coordinates, and typology data.
- Immutable floor-grid context: valid footprint, tile occupancy/typology, external corridor/plaza/entrance access classification, and internal Transit tiles.
- Generic MVP zone-size policy.
- Previous parcels are **not** a `ZoneSplitter` input; they are retained by `ZoneManager` for post-split preservation matching.

`plot_id` is required on `ZoneData` and must be explicit throughout the split contract. No default plot inference is permitted.

### Required split result

A result must distinguish a legal empty result from a rejected split:

- status: `SUCCESS`, `INVALID_ZONE_GEOMETRY`, `NO_VALID_FRONTAGE`, or `INSUFFICIENT_RENTABLE_SPACE`;
- valid parcels;
- residual Tenant tiles that cannot legally join a parcel, proposed for Decoration conversion only on success;
- deterministic diagnostics sufficient for future UI/notification copy.

A parcel carries a stable parcel ID, its rectangle/canonical tile set, area, and one or more directed tenant-door candidate edges. Subtype, tenant ID, and lifecycle status are not owned by the splitter.

## MVP area policy

The generic MVP minimum parcel area equals the documented average store size for its zone type.

| Zone type | Minimum parcel area |
|---|---:|
| Retail | 6 tiles |
| Food & Beverage | 8 tiles |
| Entertainment | 12 tiles |
| Services | 5 tiles |
| Anchor | 30 tiles |

This generic policy will be superseded or augmented by subtype-specific requirements during the later business-assignment handoff. No subtype is selected during splitting.

## Door and frontage model

Two concepts are explicitly distinct:

```
External Corridor <-> Transit Door <-> Internal Transit
External Corridor/Internal Transit <-> Tenant-Door Candidate <-> Tenant Parcel
```

| Concept | Meaning | Scope here |
|---|---|---|
| Transit door | Structural connection between external corridor and a zone-internal Transit tile. | Existing circulation behavior remains authoritative; no changes in this handoff. |
| Tenant-door candidate | Directed shared edge between a parcel Tenant tile and valid circulation (external corridor, plaza, entrance, or internal Transit). | Created as parcel metadata to prove frontage; no visual, collision, wall gap, or pathfinding node is created now. |

A direct Tenant-to-external-corridor edge is a valid tenant-door candidate. A Tenant-to-Tenant edge is never an entrance. A Transit or Decoration tile is never included in a parcel.

### MVP access classification

For Handoff 01, `GridManager` classifies a directed Tenant edge as valid frontage only when its adjacent coordinate is one of the following:

1. A valid footprint tile that is owned, has a built floor, has `TileElement.CIRCULATION`, and is not part of the candidate zone. This is the MVP representation of an external corridor, plaza, or entrance.
2. A tile in the same painted zone whose immutable zone typology is `Transit`. This is internal Transit frontage.
3. A coordinate outside the plot boundary and inside `PlotData.pedestrian_boundary`. This is virtual exterior-pedestrian frontage and is metadata-only for this handoff.

A valid-footprint unowned tile is never frontage and must not be treated as a proxy for public circulation. A coordinate outside the floor footprint but inside the plot boundary is also not frontage. Coordinates outside the pedestrian boundary are not frontage.

`CIRCULATION` does not distinguish corridor, plaza, and entrance in MVP. Tenant-door candidate detection must not call `can_place_door_between()`; that method remains the structural/manual-door rule. A tenant-door candidate does not set door flags, open walls, create visuals or collisions, or add pathfinding edges.

## Deterministic split procedure

1. **Normalize and validate source geometry**
   - Deduplicate and canonically sort painted coordinates.
   - Reject a zone whose painted body is not 4-connected or whose coordinates are invalid for its plot/floor footprint.
   - Partition Tenant tiles from Transit/Decoration tiles.

2. **Partition rentable components**
   - Compute 4-connected components of Tenant tiles.
   - Components separated by Transit or Decoration are evaluated independently; parcels never bridge those tiles.

3. **Detect directed frontage**
   - Enumerate every Tenant-to-valid-circulation edge in a canonical coordinate/direction order.
   - A component with no valid tenant-door candidate cannot produce a parcel.

4. **Set the target count**
   - Per component, calculate `floor(eligible Tenant tiles / zone-type minimum area)`.
   - This is a target, never a reason to create an invalid parcel. A constrained shape may produce fewer parcels only when at least one valid parcel remains.

5. **Reserve frontage and grow candidates**
   - Use contiguous, unclaimed frontage runs as parcel seeds.
   - Grow candidates inward from their tenant-door candidate edge using only currently unclaimed Tenant tiles.
   - Candidates must remain rectangles and meet the minimum area.
   - Choose candidates deterministically: prioritize legal candidates closest to the zone-type target area, then greater usable coverage, then canonical coordinate/direction ordering. Input tile order must never affect the result.

6. **Validate and repair**
   - Reject candidates below the minimum or without a tenant-door candidate.
   - Merge only if the merged result remains a fronted rectangle and meets all invariants.
   - Unused legal Tenant cells are residuals proposed for Decoration conversion; they are never silently discarded.

7. **Commit or reject atomically**
   - If no valid frontage exists, or no component can produce one minimum-sized fronted parcel, return failure and block finalization.
   - On success, `ZoneManager` atomically commits parcels and residual Decoration conversions, then synchronizes GridManager.
   - On failure, leave the edited zone and grid unchanged.

## Edit, identity, and persistence policy

- A successful zone tile/typology edit triggers a full split recalculation.
- `ZoneManager` snapshots existing parcels before the split and matches old/new parcels one-to-one by spatial overlap, using deterministic tie-breaks.
- A valid matched parcel retains its persistent parcel ID; a new unmatched parcel receives a new ID; a removed/invalid parcel ID is retired.
- Future tenant preservation may retain a tenant reference only when its matched parcel remains viable under the applicable policy. This handoff creates no tenant records.
- Parcel IDs and parcel-to-tenant mappings must be persisted. Save restoration must recreate/match parcel geometry before restoring tenant occupancy.

## Failure behavior and TODO

| Failure | Finalization behavior |
|---|---|
| Invalid painted zone geometry | Block finalization; make no grid/zone change. |
| No valid frontage | Block finalization; make no grid/zone change. |
| No minimum-sized fronted parcel | Block finalization; make no grid/zone change. |

**TODO — Notifications:** When the alert/notification system exists, publish a player-facing failure using the result status and zone/floor context. This handoff only requires diagnostics; it does not implement notification wiring.

## Acceptance requirements

- A fronted rectangular zone produces only non-overlapping, fronted rectangles that fully use parcel tiles.
- Reordering input tiles or typology-map insertion order produces identical parcels, IDs/order, frontage metadata, residuals, and diagnostics.
- An L-shaped zone produces rectangles only; unusable Tenant tiles become residual Decoration on successful finalization.
- Internal Transit provides valid frontage but is never parcel area.
- Decoration blocks growth and is never consumed or overwritten.
- A zone with no valid frontage, or no valid minimum-sized parcel, cannot finalize and leaves the prior state untouched.
- Every accepted parcel meets the table minimum, is wholly Tenant, is rectangular, and contains at least one directed tenant-door candidate.
- Tenant components separated by Transit/Decoration are never bridged.
- After a successful edit, overlapping valid parcels retain persistent IDs deterministically; new parcels get new IDs.

## Implementation guidance

Implementation must use a pure, unit-testable splitter and a structured split result. Do not incrementally modify the current splitter if doing so preserves invalid non-rectangular or unfronted outcomes; replace its geometry behavior within the accepted pure-system boundary.

Required implementation skills: `godot-prompter:resource-pattern` (data contract) and `godot-prompter:godot-testing` (deterministic geometry tests). Use `godot-prompter:event-bus` only when the notification TODO is implemented in a later handoff.

## Explicit non-goals

- Business subtype selection and adjacency graph coloring.
- Immediate debug tenant assignment.
- Tenant application, construction, occupancy, closure, or eviction effects.
- Per-tile tenant numbers/labels.
- Door visuals, wall openings, pathfinding changes, or interior placement.
- Player notifications/alerts.
