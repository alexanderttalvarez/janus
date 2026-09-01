# Civic Perimeter & Surroundings

## Identity

**Asset IDs:** `3d_env_plot_ground`, `3d_env_pedestrian_ring`, `3d_env_road_kit`, `3d_vehicle_traffic_base`, `3d_env_parking_structure`, `3d_transit_external_station_family`  
**Category:** 3D environment  
**Family:** Tile-aligned civic perimeter

## Purpose

The perimeter grounds the player-built complex in a living urban setting. Generated roads, public bands, crossings, and traffic controls provide a readable civic boundary around the current controlled area.

## Source

- `19_district_layout_land_expansion.md` — district road, public-band, conversion, and crossing rules.
- `architecture/design_handoff.md` — public-realm and traffic ownership boundaries.
- H5 Street and Pedestrian Generation — public-realm descriptors and pedestrian topology.
- H7 Traffic Topology Migration — traffic descriptors, anchors, and control semantics.

## Gameplay Context

- Visible around Active Plots at district and floor-one view. Visitor crossings use approved midpoint pedestrian graph crossings; outer-ring crosswalks remain traffic-functional but are not visitor crossings.
- The player does not zone Pedestrian Bands or active roads. Pedestrian space supports decorative and amenity placement; converted segments become unrestricted pedestrian topology.
- Traffic presentation consumes H7 topology and controls; it does not establish scene-authored road authority.

## Required Assets & Variants

| Asset | MVP representation | Production representation | Required variants |
|---|---|---|---|
| Plot ground | Calm neutral surface visible through unbuilt tiles | Contextual ground surface consistent with civic setting | Day/night material response |
| Pedestrian band | Tile-aligned public walking edge | Generated paving kit that supports amenities, midpoint crossings, and future connected plots | Straight, exterior intersection continuation, converted-segment paving |
| Road kit | Generated asphalt, curbs, flat markings, crossings, and signals | Cohesive descriptor-driven civic street kit for variable profiles | Segment surface, square intersection, curb, marking overlay, crosswalk, traffic-light pole |
| Traffic vehicle | Readable generic civilian car silhouette | Small non-hero civilian vehicle family | Palette/material variants only |
| Parking facility | N/A | A physical parking entry/structure that visibly supports parking fees | Surface/structured form only after design approval |
| External station family | N/A | Clearly identifiable visitor-attraction stations without becoming generic menu upgrades | Bus, tram, monorail, metro, train |

## Dependencies & Reuse

- Align all pieces to [scale_guide.md](../scale_guide.md) and generated H5/H7 descriptors; do not embed fixed widths or scene-owned topology.
- The kit must support 5-10-tile Pedestrian Bands, 2-6 3-tile lanes, variable Street Segment lengths, and `C x C` intersections.
- Road surfaces, markings, curbs, crossings, and signals are generated reusable elements, not bespoke scene-only Nodes.
- Vehicle appearance must not compete with zone overlays or visitor readability.
- Future stations and parking must remain part of the civic perimeter, with a visibly understandable pedestrian route to a plot entry.

## Visual Requirements

- Follow the confirmed contemporary-Japanese urban identity in [style_guide.md](../style_guide.md): clear curbs, compact commercial civic detail, restrained markings, and clean low-poly silhouettes.
- The civic edge must use subdued materials so zone colors, heatmaps, and contextual warnings remain dominant when active.
- Avoid traffic clutter, dense roadside signage, and a cyberpunk/neon presentation.
- Use dark-gray carriageway asphalt. Markings are flat epsilon-offset overlays batched per segment/chunk, never raised geometry or hand-authored decal Nodes.
- Use solid edge lines against Pedestrian Bands, a solid opposing-direction divider, and 1-tile white/1-tile gap dashed same-direction dividers. Ordinary markings are 0.25 tile thick; stop lines are 0.50 tile thick and appear only on approaching lanes 2 tiles before a crosswalk or intersection boundary.
- Each active Street Segment has exactly one centered, 5-tile-wide midpoint crosswalk with alternating 0.5-tile white and exposed-asphalt stripes across the full carriageway. Curbs are 0.10 tile high and 0.15 tile wide, with flush crosswalk interruptions and square intersection corners.
- Intersections remain plain dark-gray surfaces with no internal lane markings. Converted segments remove all road kit elements and use ordinary Pedestrian Band paving throughout.
- Midpoint crosswalk lights are paired compact dark-charcoal/black rectangular-headed poles in opposite Pedestrian Bands, with signal centers 2.5 tiles high. Their faces and phase are supplied by H7; outer-ring lights remain traffic-functional without implying a pedestrian route.

## Scale & Technical Requirements

- Plot ground follows resolved Plot dimensions and remains visible through unbought floor areas.
- Street width derives from two 5-10-tile Pedestrian Bands plus the selected 2-6-lane carriageway; one world unit per tile remains a projection metric where applicable.
- This document is a generated visual kit. It consumes H5 public-realm descriptors and H7 traffic descriptors; it does not define pedestrian width, road width, plot-corner arrival authority, road graph semantics, or traffic behavior.

## Acceptance Criteria

- Players can read public bands, road boundaries, midpoint crossings, and converted pedestrian segments at normal floor-one zoom.
- Generated perimeter parts join without seams or orientation-dependent visual breaks across supported widths and segment lengths.
- The road boundary reads as a public street rather than buildable floor space.
- Each future transport type is visually distinguishable at normal overview zoom, while sharing one coherent civic design language.
- Zone overlays, heatmaps, and floor edges remain readable over the surroundings.

## Open Questions

1. Where may parking and each external station be placed, and how do they connect visually to a building entrance?

## 2026-08-31 Road & Intersection Addendum

This visual plan now describes a generated road kit rather than a fixed six-tile perimeter. H5 supplies public-realm descriptors, H7 supplies traffic descriptors, and H4 remains projection lifecycle only. Future transit notes remain intentionally open; this addendum adds no bus-lane content.
