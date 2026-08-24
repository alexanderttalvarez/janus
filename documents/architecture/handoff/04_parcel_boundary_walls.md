# Handoff 04: Parcel Boundary Walls

## Status

Approved — 2026-08-24

## Goal

Render a thin interior wall along every shared edge between two distinct committed parcels in the same zone.

## Authoritative constraints

- Parcel boundaries render for every zone. Do not add a per-zone wall option in this handoff.
- Structural walls retain their existing thickness. Parcel-boundary walls must be visibly thinner.
- Only a shared edge between different parcels in the same zone creates a parcel-boundary wall.
- Do not create parcel-boundary walls against Transit, Decoration, residual, zone-boundary, or inter-zone tiles.
- `GameManager.wall_mode` remains the sole visibility control. Cutaway, Partial, and Full apply to both structural and parcel-boundary walls.
- In Cutaway, parcel-boundary walls must clip symmetrically regardless of camera direction. In Full, they render at full height.
- Extend the existing wall edge/run/junction pipeline. Runs must not merge across structural and parcel-boundary profiles. Junction cubes and trimming use the maximum participating wall thickness to prevent overlaps and z-fighting.

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
- Thin-only junctions retain the thin profile; mixed joints remain overlap-free.
- Zone create, modify, and delete events rebuild wall geometry.
- Runtime validation confirms parcel-boundary geometry is present and thinner than structural walls.
- Project scripts compile, existing tests pass, and the main scene starts without debugger errors.
