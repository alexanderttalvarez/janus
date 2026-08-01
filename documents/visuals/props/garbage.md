# Garbage Assets

## Garbage Sprite (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Visible garbage on corridor tiles. Spawned based on visitor count. Cleaned by staff. |
| **Size** | 0.3m × 0.3m in world space |
| **Type** | Sprite3D or decal on floor |
| **Spawn rate** | floor(floor_visitor_count / 50) per visitor tick |
| **MVP** | Simple dark spot or small sprite on the floor. |
| **Post-MVP** | 2-3 garbage variations (paper, cup, wrapper). |

### Garbage Visual States

| State | Visual |
|-------|--------|
| **Fresh** | Small dark spot |
| **Aged** | Slightly larger, more visible |
| **Being cleaned** | Disappears (cleaner animation) |

## MVP Approach

Simplest approach: a small dark circle sprite or decal placed on the corridor tile. No animation, no variation. Just a visible indicator that the tile needs cleaning.
