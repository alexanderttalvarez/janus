# Construction & World Animations

## Construction Phase Transitions (MVP)

| Transition | Visual | MVP Approach |
|------------|--------|--------------|
| **Phase 1 → 2** | Foundation to framing | Color overlay changes from dark gray to medium gray |
| **Phase 2 → 3** | Framing to finishing | Color overlay changes to zone color + business name appears |
| **Phase 3 → Complete** | Finishing to operational | Overlay disappears, final zone appearance |

### MVP Approach

No actual animation. Just instant visual state changes when construction progress crosses phase thresholds. The "animation" is the color overlay changing.

### Post-MVP Approach

- Phase 1: Scaffolding appears around zone perimeter
- Phase 2: Walls rise up (scale animation from 0 to full height)
- Phase 3: Signage drops in from above, windows appear
- Complete: Lights turn on, interior becomes visible

## Elevator Movement (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Elevator cab moves between floors. |
| **Duration** | ~1-2 seconds per floor transition |
| **MVP** | Simple position tween (move cab up/down in shaft). |
| **Post-MVP** | Smooth acceleration/deceleration, door open/close animation. |

## Door Open/Close (Post-MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Business doors and elevator doors open/close. |
| **Duration** | 0.5 seconds |
| **Type** | Rotation or slide animation |

## Reuse Opportunities

- Construction phase transitions use the same pattern (color/material swap)
- Elevator movement is a simple position tween, reusable for any vertical movement
- Door animation is a standard open/close, reusable for all doors
