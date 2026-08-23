# Civic Perimeter & Surroundings

## Identity

**Asset IDs:** `3d_env_plot_ground`, `3d_env_pedestrian_ring`, `3d_env_road_kit`, `3d_vehicle_traffic_base`, `3d_env_parking_structure`, `3d_transit_external_station_family`  
**Category:** 3D environment  
**Family:** Tile-aligned civic perimeter

## Purpose

The perimeter grounds the player-built complex in a living urban setting. The pedestrian ring gives visitors visible arrival and voluntary-exit locations; roads and traffic provide a readable civic boundary around the current scene.

## Source

- `05_visitor_simulation.md` — arrivals and exits use plot-owned corner spawn points.
- `09_building_structure_system.md` — plots, pedestrian area, road, and post-MVP multi-plot rules.
- `03_visitor_agents.md` and `08_plot_scalability.md` — four stable corner spawn points.
- Current `main_game.tscn` — ground, pedestrian ring, road sides/corners/crosswalks, and traffic are already represented.

## Gameplay Context

- Visible around the plot at district and floor-one view; visitor spawning and exits occur at pedestrian-ring corners.
- The player does not zone pedestrian or road space. Pedestrian space supports decorative and amenity placement; roads permit decoration only in the game design.
- Road traffic is present in the live scene, but its gameplay role is not documented.

## Required Assets & Variants

| Asset | MVP representation | Production representation | Required variants |
|---|---|---|---|
| Plot ground | Calm neutral surface visible through unbuilt tiles | Contextual ground surface consistent with civic setting | Day/night material response |
| Pedestrian ring | Tile-aligned continuous walking edge with four unambiguous corners | Public-realm kit that supports amenities and future connected plots | Straight side, outer corner, connection end |
| Road kit | Modular road side, road corner, curb, crossing, lane/stop markings | Cohesive civic street kit that can surround adjacent plots | Side, corner, crosswalk, intersection |
| Traffic vehicle | Readable generic civilian car silhouette | Small non-hero civilian vehicle family | Palette/material variants only |
| Parking facility | N/A | A physical parking entry/structure that visibly supports parking fees | Surface/structured form only after design approval |
| External station family | N/A | Clearly identifiable visitor-attraction stations without becoming generic menu upgrades | Bus, tram, monorail, metro, train |

## Dependencies & Reuse

- Align all pieces to [scale_guide.md](../scale_guide.md); do not embed fixed-world scenery that prevents a changed pedestrian width.
- Pedestrian assets must visually preserve the four plot-corner spawn locations.
- Road side/corner/crosswalk elements are a reusable modular set, not four bespoke scene-only assets.
- Vehicle appearance must not compete with zone overlays or visitor readability.
- Future stations and parking must remain part of the civic perimeter, with a visibly understandable pedestrian route to a plot entry.

## Visual Requirements

- Follow the confirmed contemporary-Japanese urban identity in [style_guide.md](../style_guide.md): clear curbs, compact commercial civic detail, restrained markings, and clean low-poly silhouettes.
- The civic edge must use subdued materials so zone colors, heatmaps, and contextual warnings remain dominant when active.
- Avoid traffic clutter, dense roadside signage, and a cyberpunk/neon presentation.

## Scale & Technical Requirements

- Plot ground covers the 25×25 active plot and remains visible through unbought floor areas.
- Road width is six tiles. Current live perimeter assets use one world unit per tile.
- Current scene/architecture uses a 5-tile pedestrian margin, while game design specifies 2 tiles. Pieces must be width-agnostic until this conflict is resolved.
- The active road/pedestrian perimeter is already scene-level content; this plan specifies reusable appearance requirements only.

## Acceptance Criteria

- Players can locate every pedestrian-ring corner as an arrival/exit point at normal floor-one zoom.
- Perimeter parts join without seams or orientation-dependent visual breaks.
- The road boundary reads as a public street rather than buildable floor space.
- Each future transport type is visually distinguishable at normal overview zoom, while sharing one coherent civic design language.
- Zone overlays, heatmaps, and floor edges remain readable over the surroundings.

## Open Questions

1. Is the current road/pedestrian/traffic presentation a permanent MVP requirement or a provisional implementation ahead of the game-design scope?
2. Should pedestrian width be two tiles (game design) or the current configurable default of five tiles (architecture/live scene)?
3. Does traffic remain purely ambient, or is it a future gameplay system?
4. Where may parking and each external station be placed, and how do they connect visually to a building entrance?
