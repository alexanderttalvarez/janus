# Roads & Pedestrian Areas

Initial surroundings implementation. These spaces are currently static and
decorative; ownership, bulk purchasing, traffic, and player-placed props are
not implemented yet.

## Road Segments

| Property | Value |
|----------|-------|
| **Purpose** | Visual roads between plots. No zones allowed on road tiles. |
| **Width** | 6m (6 tiles) |
| **Length** | 29m side section around a 25m plot, including the 2m pedestrian margins |
| **Material** | Asphalt texture, dark gray |
| **Markings** | Lane lines, crosswalks (post-MVP) |

## Pedestrian Area Tiles

| Property | Value |
|----------|-------|
| **Purpose** | Sidewalk area surrounding the plot. Decoration only, no zones. |
| **Width** | 2m (2 tiles) |
| **Material** | Sidewalk texture, light gray/warm neutral |
| **Decorations** | Benches, planters, street lamps (placed by player) |

## Current Implementation

- A continuous 2-tile pedestrian ring surrounds the 25×25 plot.
- A continuous 6-tile road ring surrounds the pedestrian area.
- Ring corners are filled so there are no empty gaps between side segments.
- The ground plane extends to at least 50m × 50m around the plot.
- Four visitor spawn anchors are derived at the pedestrian-ring corners of each
  plot. These are the controlled entry and voluntary-exit points for visitors.
- Pedestrian-ring waypoints remain traversal geometry and are not independent
  visitor entry sources.
- No neighboring buildings, lane markings, crosswalks, traffic, ownership, or zone assignment exists yet.
