# Building Kit

## Identity

**Asset IDs:** `3d_arch_floor_system`, `3d_arch_wall_system`, `3d_arch_building_entrance`, `3d_arch_stairs_standard`, `3d_arch_elevator_system`, `3d_arch_terrace_system`, `3d_arch_escalator_pair`, `3d_arch_plot_connections`, `3d_arch_column_system`  
**Category:** 3D architecture  
**Family:** Modular, grid-built commercial structure

## Purpose

The building kit makes player construction visible: floor acquisition, zone boundaries, vertical circulation, terraces, and future multi-building connections. It must preserve the game's core fantasy of watching a personal commercial district take shape.

## Source

- `09_building_structure_system.md`, `11_transit_circulation.md`, `12_wall_system.md`, `13_terrace_system.md`.
- `10_structural_system_columns.md` (draft; columns only).
- `04_wall_rendering.md`, `06_floor_representation.md`, `16_camera_system_architecture.md`.

## Gameplay Context

- Floors and walls appear throughout building, observation, and exterior presentation modes.
- Stairs and elevators create the only MVP vertical routes; their silhouettes must make connection type obvious at zoomed-in view.
- Terraces are open-air amenity tiles at a floor edge or interior void; future connections bridge multiple plots.

## Required Assets & Variants

| Asset | MVP representation | Production representation | Required variants |
|---|---|---|---|
| Floor system | Neutral purchased-floor treatment with a clear unbuilt edge | Architectural finish family supporting indoor, terrace, and later condition states | Indoor, terrace, unbuilt boundary |
| Wall system | Continuous wall body, camera-cutaway strip/cap, junction treatment, automatic opening | Visual-only material choices layered on same structural silhouette | Straight, convex/concave corner, T-junction, door opening; Cutaway/Partial/Full |
| Building entrance | A distinct ground-floor pedestrian threshold | Facade-integrated entry family that makes arrivals/exits intelligible | Orientation; optional day/night interior cue |
| Stairs | A minimum-2×2 circulation volume that visibly rises to adjacent floor | Width/style variants that retain identical footprint behavior | Rotation; optional wider form |
| Elevator system | One-tile shaft/lobby identity and readable cab/travel state | Lobby and shaft finishes supporting floor service indication | Shaft, per-floor lobby, cab; served/unserved floor state |
| Terrace system | Different open-air floor treatment and accessible interior edge | Railing, access, and furnishing-ready terrace kit | Open edge, interior edge, manual access opening |
| Escalator pair | N/A until scope is resolved | Two-direction adjacent-floor circulation pair | Orientation |
| Plot connections | N/A | Enclosed skybridge, underground passage, shared-plaza transitions | Connection type and orientation |
| Columns | N/A | Automatic support family that never obstructs tile readability | Material-matched style only |

## Dependencies & Reuse

- `floor.tscn` owns structural floor and wall nodes; tile/zone/circulation content is populated at runtime. Do not require hand-authored instances for every tile.
- Walls are a shared continuous system, not independent room decoration. Their materials must work with the clipping and cap rules.
- Use the same architectural material family for floors, walls, stair bodies, elevator surrounds, and perimeter edges where appropriate.
- Terrace furniture, door treatment, and exterior connection content depend on [tenant_amenities.md](../props/tenant_amenities.md).

## Visual Requirements

- Contemporary Japanese commercial architecture translated into soft, clean low-poly masses.
- Prioritize modular floor divisions, clear structural volumes, large readable openings, and restrained façade detail.
- In cutaway/partial modes, surviving low-wall strips and cap plates must read as intentional architecture, not broken mesh.
- Full mode should reward the player's layout with a coherent exterior silhouette without obscuring the modular construction language.

## Scale & Technical Requirements

- Floor tiles, stair bases, elevator bases, and terrace edges follow [scale_guide.md](../scale_guide.md).
- Full wall height is **3.0 world units**. The cutaway/partial retained base strip and cap plate are required, but its exact retained height is unresolved: current game design says approximately 10%, while the earlier rendering decision says 5%.
- Walls are centred on tile boundaries. Junction treatments must preserve a continuous outline without overlapping wall bodies.
- Current floors use one reusable `floor.tscn` structural scene; upper floor masks can vary and may overhang the floor below by up to two tiles per edge.
- Floor-to-floor rise, nominal door dimensions, axes, and pivots remain open technical decisions.

## Acceptance Criteria

- Any valid tile layout produces an intelligible continuous floor/wall perimeter in all four camera rotations.
- Straight walls, corners, T-junctions, and door openings meet cleanly without visible gaps, overlaps, or visual ambiguity.
- A player can distinguish stairs, elevator service points, terraces, and ordinary corridors without using a tooltip.
- A player can identify where pedestrians conceptually enter/leave the building relative to its civic perimeter.
- Terrace edges visibly read as open air in both Cutaway and Full modes.

## Open Questions

1. Escalators are in the tech-tree MVP total but described as post-MVP in circulation design. Which source controls scope?
2. What is the exact floor-to-floor rise required for stairs/elevators?
3. Column placement/update logic remains a draft design decision.
4. When are player-selectable wall finishes introduced, and which of the documented materials are production scope?
5. Is a building entrance player-placed, auto-derived from a floor edge, or only a visual association with the plot-corner spawn points?
6. Does the current 10% cutaway strip supersede the 5% value in the wall-rendering architecture decision?
