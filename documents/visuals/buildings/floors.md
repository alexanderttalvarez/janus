# Floor Assets

## Floor Plane

| Property | Value |
|----------|-------|
| **Purpose** | The ground surface of each floor. Visible when tiles are purchased. Unbought tiles show the floor below or ground. |
| **Size** | Per-tile: 2m × 2m. Full floor: up to 50m × 50m (25×25 tiles). |
| **Shape** | Grid of individual tile planes OR single mesh with tile-sized UV regions |
| **Thickness** | 0.2m |
| **Material** | Neutral floor material (MVP: flat color). Zone color overlays applied on top. |
| **MVP** | Single flat-colored plane per floor, with per-tile color overlays for zones. |
| **Post-MVP** | Textured floor material, different materials per zone type, wear/damage overlays. |

### Floor Tile Visual States

| State | Visual |
|-------|--------|
| **Not bought** | No mesh (transparent, shows floor below) |
| **Bought, empty** | Bare floor material |
| **Zone tile** | Floor material + zone color overlay |
| **Corridor tile** | Floor material + corridor texture/overlay |
| **Terrace tile** | Different floor material (outdoor look) |
| **Under repair** | Orange overlay (post-MVP) |

## Floor Edge / Boundary

| Property | Value |
|----------|-------|
| **Purpose** | Visual edge of the floor where it meets unbought space. |
| **MVP** | Simple edge line or slight bevel on the floor plane. |
| **Post-MVP** | Railing, glass barrier, or decorative edge treatment. |

## Floor Height Reference

- Each floor is positioned at Y = floor_index × 4m
- F1 (ground): Y = 0
- F2: Y = 4
- F3: Y = 8
- U1: Y = -4
- U2: Y = -8

## Reuse Opportunities

- Single floor plane mesh, instanced per floor with different Y positions
- Tile overlays use the same mesh with different material parameters
- Floor edge is a simple strip mesh, reused per floor
