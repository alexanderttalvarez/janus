# Visitor Animations

## Visitor Idle (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Default animation when visitor is stationary. |
| **Duration** | Looping, ~2 seconds |
| **MVP** | No animation (static pose). Or very subtle breathing motion. |
| **Post-MVP** | Subtle weight shift, looking around, checking phone. |

## Visitor Walk (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Animation when visitor is moving to a destination. |
| **Duration** | Looping, ~0.5 seconds per cycle |
| **Speed** | Matches movement speed (~1.5 m/s) |
| **MVP** | Simple leg swing or sliding motion. No complex arm movement needed. |
| **Post-MVP** | Full walk cycle with arm swing, head bob, natural gait. |

### MVP Walk Approach

Simplest viable walk animation:
- **Option A**: No animation, just position interpolation (move_toward). Visitor slides smoothly.
- **Option B**: Very simple 2-frame walk cycle (left foot forward, right foot forward).
- Option A is acceptable for MVP. The smooth movement is enough to convey "walking."

## Visitor Spawn Fade (MVP)

- New visitors fade from fully transparent to fully opaque over 2 seconds.
- This is a script-driven visual transition on each visitor's geometry, not an
  `AnimationPlayer` animation and not a separate animation asset.

## Visitor Browse (Post-MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Animation when visitor stops to look at a storefront. |
| **Duration** | 2-4 seconds |
| **Actions** | Stop, look at storefront, possibly nod or point, continue or leave |

## Visitor Queue (Post-MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Animation when visitor is waiting in a queue. |
| **Duration** | Looping, idle variations |
| **Actions** | Shift weight, check phone, look around, tap foot |

## Animation State Machine

```
Idle ←→ Walk
  ↓       ↓
Browse  Queue (post-MVP)
  ↓
Leave (walk to exit)
```

## Reuse Opportunities

- Single walk animation shared across all visitors
- Idle animation shared across all visitors
- Animation speed can be slightly randomized per visitor for natural variation
