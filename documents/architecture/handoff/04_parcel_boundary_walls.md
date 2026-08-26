# Handoff 04: Parcel Boundary Walls

## Status

Approved — 2026-08-24

## Goal

Render a thin interior wall along every shared edge between two distinct committed parcels in the same zone.

## Authoritative constraints

- Parcel boundaries render for every zone. Do not add a per-zone wall option in this handoff.
- Structural walls retain their existing thickness. Parcel-boundary walls must be visibly thinner.
- Only a shared edge between different parcels in the same zone creates a parcel-boundary wall.
- A Parcel Tenant edge directly adjacent to an internal Transit tile in the same committed zone creates a thin parcel-boundary wall.
- Do not create parcel-boundary walls against external Transit, external circulation, Decoration, residual, zone-boundary, or inter-zone tiles.
- `GameManager.wall_mode` remains the sole visibility control. Cutaway, Partial, and Full apply to both structural and parcel-boundary walls.
- In Cutaway, parcel-boundary walls must clip symmetrically regardless of camera direction. In Full, they render at full height.
- Extend the existing wall edge/run/junction pipeline. Runs must not merge across structural and parcel-boundary profiles.
- Different-zone boundaries remain structural walls, including Transit↔Transit boundaries, until a permitted manual door opens that edge.
- L-corners and true crossings receive a junction cube using the maximum participating wall thickness.
- T-junctions do not receive a redundant corner cube; only the terminating run is trimmed against the continuous run. This prevents false full-height pillars in Cutaway mode at Tenant↔Transit junctions.
- A continuous thin parcel-boundary run meeting a continuous structural inter-zone run is treated as thin runs terminating at the structural wall, not as a true crossing. No structural corner cube is emitted; only the thin run is trimmed.

## Data and event cleanup

- Remove the unused per-zone `walls_enabled` property and the unused `EventBus.zone_wall_mode_changed` signal.
- Existing serialized `walls_enabled` keys may be ignored on load; all restored zones render parcel boundaries.

## Non-goals

- Zone wall-option UI.
- Parcel doors, door gaps, collisions, or pathfinding changes.
- Wall materials, tenant interiors, or changes to zone splitting.

## Validation requirements

- Adjacent parcels generate thin boundary-wall pieces that merge into the expected run.
- Non-parcel gaps do not produce thin boundary walls.
- Same-zone internal Transit produces a thin boundary wall; external circulation and Transit do not.
- L-junctions and true crossings retain the required corner cube and maximum participating thickness.
- Tenant↔Transit T-junctions do not spawn redundant corner cubes and trim only the terminating wall run.
- Aligned Transit strips in adjacent zones retain their structural inter-zone wall but do not create a false structural corner pillar where a thin Tenant↔Transit run meets it.
- Thin-only junctions retain the thin profile; mixed joints remain overlap-free.
- Zone create, modify, and delete events rebuild wall geometry.
- Runtime validation confirms parcel-boundary geometry is present and thinner than structural walls.
- Project scripts compile, existing tests pass, and the main scene starts without debugger errors.
