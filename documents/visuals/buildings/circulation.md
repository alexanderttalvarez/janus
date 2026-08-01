# Circulation Assets

Elements that enable vertical and horizontal movement between floors.

## Stairs

| Property | Value |
|----------|-------|
| **Purpose** | Connect adjacent floors. High capacity, no queue. |
| **Footprint** | 2×2 tiles (4m × 4m) |
| **Height** | 4m (one floor) |
| **MVP** | Simple low-poly staircase with landing. Single mesh. |
| **Post-MVP** | Wider variants, decorative railings, different styles. |

### Stairs Components

| Component | Description |
|-----------|-------------|
| **Steps** | 10-12 steps per flight |
| **Landing** | Flat area at top and bottom |
| **Railing** | Simple low-poly railing on both sides |

## Elevator

### Elevator Shaft

| Property | Value |
|----------|-------|
| **Purpose** | Vertical shaft spanning all connected floors. |
| **Footprint** | 1×1 tile (2m × 2m) |
| **Height** | Full building height |
| **MVP** | Simple box/cylinder shaft. Visible through unbought tiles. |
| **Post-MVP** | Glass shaft, visible cab movement, decorative frame. |

### Elevator Lobby

| Property | Value |
|----------|-------|
| **Purpose** | Waiting area on each floor where elevator stops. |
| **Footprint** | 1×1 tile (2m × 2m) |
| **Height** | 4m |
| **MVP** | Floor marker + simple door frame on wall. |
| **Post-MVP** | Decorative lobby area, call buttons, floor indicator display. |

### Elevator Cab

| Property | Value |
|----------|-------|
| **Purpose** | Moving cabin inside the shaft. |
| **Size** | 1.5m × 1.5m × 2.5m |
| **Capacity** | 8 visitors |
| **MVP** | Simple box inside shaft. Moves between floors. |
| **Post-MVP** | Interior detail, doors that open/close, floor indicator. |

## Escalator (Post-MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Continuous flow between adjacent floors. |
| **Footprint** | 2×1 tiles per direction (up + down = 4×1 total) |
| **Height** | 4m |
| **Visual** | Moving steps, handrails, glass sides |

## Skybridge (Post-MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Enclosed walkway between buildings on matching floor levels. |
| **Width** | 2-4 tiles |
| **Height** | 4m |
| **Visual** | Glass-enclosed corridor connecting buildings |

## Underground Passage (Post-MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Subterranean connection between buildings. |
| **Width** | 2-4 tiles |
| **Height** | 4m |
| **Visual** | Tunnel-like corridor, dimmer lighting |

## Reuse Opportunities

- Stairs: single mesh, rotated/flipped as needed for direction
- Elevator shaft: single mesh, scaled to building height
- Elevator lobby: single mesh, reused per floor
- Elevator cab: single mesh, animated position
