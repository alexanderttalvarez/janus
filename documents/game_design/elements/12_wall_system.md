# Wall System

## Overview

Walls define the architectural boundaries between spaces in Janus. They operate at three scales: business, zone, and floor. Walls are primarily aesthetic (Pillar 1: Physical Representation) but have functional implications for visitor flow and zone identity. They are built automatically based on tile placement and player settings.

---

## Wall Generation Logic

### Corridor Walls

- Each corridor tile generates 4 walls by default.
- **Shared walls between adjacent corridor tiles are removed automatically.**
- A 2-tile-wide corridor becomes a tunnel with 2 outer walls, no inner divider.
- A 3×3 corridor block has only the outer perimeter walls.

### Zone Perimeter Walls

- A wall surrounds the zone boundary.
- If the zone is set to **"No Walls"** (open-plan mode), perimeter walls are hidden. Doors remain as visual markers at transit connections.
- **Gaps** are created automatically at:
  - External Transit tile connecting to internal Transit tile (open passage)
  - Building corridor bordering the zone (door opening)

### Floor Perimeter Walls

- A wall surrounds all acquired tiles on the floor.
- **Exception:** Terrace tiles have no perimeter wall on edges facing non-built space.
- **Exception:** Skybridge connection points (post-MVP).

### Door Placement

| Connection Type | Door Placement |
|-----------------|----------------|
| **Zone ↔ Corridor** | Automatic |
| **Internal Transit ↔ External Transit** | Automatic |
| **Business ↔ Transit/Corridor** | Automatic (1 door per business) |
| **Floor ↔ Terrace** | Manual (player places door tile) |
| **Terrace ↔ Non-built tile** | No door (open edge) |

---

## Material System (Post-MVP)

### Material Hierarchy

Materials cascade from broad to specific:

| Level | Scope | Override |
|-------|-------|----------|
| **Global** | Entire building | Sets default for all floors and zones |
| **Floor** | Single floor | Overrides global for that floor |
| **Zone** | Single zone | Overrides floor/global for that zone |

**Example:** Global = concrete with windows → Floor 4 = glass → Zone A on Floor 4 = brick. Zone A uses brick, other zones on Floor 4 use glass, all other floors use concrete.

### Available Materials (Post-MVP, Tech Tree Unlocks)

| Material | Unlock | Visual Style |
|----------|--------|--------------|
| **Concrete + Windows** | Default (start) | Standard commercial |
| **Glass Curtain** | Tech tree | Modern, transparent |
| **Brick** | Tech tree | Warm, traditional |
| **Metal Panel** | Tech tree | Industrial, sleek |
| **Decorative** | Tech tree | Ornamental, premium |

**Note:** Materials are **purely visual**. They have no gameplay effect on visitor attraction, prestige, or tenant behavior.

---

## In-Game Visualization

Wall rendering follows the isometric camera system used in games like *The Sims*. The camera rotates in 4 directions (90° increments). Wall height is adjusted based on the active visualization mode and the wall's position relative to the camera.

### Wall Visualization Modes

| Mode | Front Walls (facing camera) | Back Walls (away from camera) | Use Case |
|------|----------------------------|------------------------------|----------|
| **Cutaway** (default) | 5% height | 100% height | Building and interior design. Player can see inside rooms while understanding the wall layout. |
| **Partial** | 5% height | 5% height | Overview of all rooms simultaneously. No walls obstruct the view. |
| **Full** | 100% height | 100% height | Exterior view, final presentation. Shows the building as it would appear in reality. |

### Camera-Relative Rendering

- **Front walls:** Walls whose outward normal faces toward the camera direction.
- **Back walls:** Walls whose outward normal faces away from the camera direction.
- When the camera rotates 90°, front and back walls swap.
- Wall rendering updates instantly on camera rotation.

### Toggle Controls

- Wall visualization mode is toggled via a button in the HUD or a keyboard shortcut.
- The mode persists across camera rotations.
- Default mode on game start: **Cutaway**.

---

## Cost & Maintenance

- Walls are **free** to build. They are part of the floor construction and require no additional Kreds.
- Walls add **no maintenance cost**. Maintenance is calculated per tile, not per wall segment.
- This keeps walls as a pure aesthetic/structural choice, not an economic one.

---

## Zone Editing Impact

| Change | Wall Behavior |
|--------|---------------|
| **Add zone tiles** | Walls extend automatically to the new boundary |
| **Remove zone tiles** | Walls retract automatically |
| **Change Walls ↔ No Walls** | Instant visual change. No cost. No eviction. |
| **Delete zone** | All zone walls removed |
| **Add/remove corridor tiles** | Shared walls update automatically |

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Building & Structure** | Walls are generated based on tile placement and floor boundaries |
| **Zone Design** | Zone perimeter walls, "No Walls" mode, door placement at transit connections |
| **Transit & Circulation** | Wall gaps at corridor doors and transit connections |
| **Terrace System** | No perimeter walls on terrace edges facing non-built space |
| **UI / Visualization** | Wall rendering modes (Cutaway, Partial, Full) controlled by camera system |

---

## Design Notes

### Player Mental Model

The player should understand: "Walls appear where I build. They adapt to my layout. I can see through them when I need to, or see them fully when I want to admire my design."

### MVP Scope

MVP includes automatic wall generation, Cutaway/Partial/Full visualization modes, and door placement. Post-MVP adds material selection, tech tree unlocks, and advanced material hierarchy.
