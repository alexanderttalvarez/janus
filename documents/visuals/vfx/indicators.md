# Contextual Indicator Assets

Indicators appear directly on the 3D view near relevant elements.

## Low Viability Glow (MVP)

| Property | Value |
|----------|-------|
| **Trigger** | Zone application score below threshold |
| **Visual** | Subtle yellow/orange glow around zone perimeter |
| **MVP** | Colored outline or glow effect on zone boundary. |
| **Post-MVP** | Pulsing glow with particle effect. |

## Congestion Pulse (MVP)

| Property | Value |
|----------|-------|
| **Trigger** | Corridor/entrance exceeds capacity |
| **Visual** | Red pulsing indicator above affected tile |
| **MVP** | Simple red sprite or Label3D with "!" that pulses. |
| **Post-MVP** | Animated particle effect showing crowd density. |

## Tenant Warning Icon (MVP)

| Property | Value |
|----------|-------|
| **Trigger** | Tenant enters Concerned/Critical/Closing stage |
| **Visual** | Icon above zone, tooltip on hover |
| **MVP** | Simple icon (⚠ for Concerned, ⚠⚠ for Critical, ✖ for Closing). |
| **Post-MVP** | Animated icon with color coding. |

## Prestige Feature Preview (MVP)

| Property | Value |
|----------|-------|
| **Trigger** | Player hovers over garden, fountain, etc. |
| **Visual** | "+X Quality" preview text |
| **MVP** | Label3D with text. |

## Under Repair Overlay (Post-MVP)

| Property | Value |
|----------|-------|
| **Trigger** | Tile currently being repaired |
| **Visual** | Orange overlay on tile |
| **MVP** | Not needed (maintenance is post-MVP). |

## Reuse Opportunities

- All indicators use the same Label3D or Sprite3D approach
- Warning icons share the same visual style (simple symbols)
- Glow effects can use the same shader with different colors
