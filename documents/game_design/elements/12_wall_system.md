# Wall System

**Revision:** Approved 2026-09-08 consistency pass. [Current MVP](../current_mvp.md) governs scope. This element owns visible dimensions; ADR 33 amends ADR 04 to match.

## Dimension Authority

All dimensions are multiples of the horizontal tile unit, converted once by the grid-to-world scale. Full height is 3.0 tile units; structural thickness is 0.10, thin parcel thickness is 0.05. A clipped wall retains exactly 10% height (0.30 tile units) plus its non-gameplay cap, never 5%. Cutaway clips front structural walls and all thin parcel walls; Partial clips both profiles on all sides; Full clips neither. Thin parcel walls clip symmetrically so camera orientation never hides the interior plan.

Walls are mandatory in MVP; per-zone No Walls is deferred. Door count is `ceil(eligible parcel tile positions / 10)`, not one door per business. A profile may designate just one of those physical doors as its operational service entrance. Preserve legal selected doors before filling new slots. Explicit retirement removes a vacant retired parcel's owned automatic doors atomically; surviving parcels retain door protection, and manual-door validity still applies. Topology-backed active public Pedestrian Bands count as real access; implicit/unzoned or virtual corner access never does. ADRs 30/31 and `zone_parcels/H5` define authority and endpoint legality.

## Overview

Walls define the architectural boundaries between spaces in Janus. They operate at three scales: business, zone, and floor. Walls are primarily aesthetic (Pillar 1: Physical Representation) but have functional implications for visitor flow and zone identity. They are built automatically based on tile placement and player settings.

---

## Wall Generation Logic

### Corridor Walls

- Each corridor tile generates 4 walls by default.
- **Shared walls between adjacent corridor tiles are removed automatically.**
- A 2-tile-wide corridor becomes a tunnel with 2 outer walls, no inner divider.
- A 3×3 corridor block has only the outer perimeter walls.

### Corners (Corner Cubes)

- Walls are **centered on the boundary line** — half the thickness on each side, **shared between the two adjacent tiles** (a building perimeter wall overhangs the floor edge by half a thickness).
- **L-corners and true crossings get a profile-sized corner cube**, height 3.0, thickness equal to the thickest participating wall, centered on the junction lines:
  - **Convex corners** (both wall runs end at the same point): the cube fills the corner square where the two bodies would overlap; both runs are trimmed flush against its faces.
  - **Concave (inner) corners** (both runs end at a notch): the cube fills the open notch between the end caps.
  - **T-junctions:** no redundant cube; trim the terminating run against the continuous run. A thin run meeting a structural boundary terminates there and never creates a full-height false pillar.
- Consequence: wall boxes **never overlap** — no coplanar faces, no z-fighting, and all walls render at the full `3.0` height. The wall outline is always continuous.
- Cubes are **axis-aligned** (their faces match the wall lines) and use a per-corner material whose baked "outward" direction points away from the room's interior, along the corner diagonal.
- In Cutaway, structural corner visibility follows participating structural wall directions; thin-only corners follow symmetric parcel clipping. A general floor/zone can have any number of corners; there is no invariant of exactly three solid corners. Partial clips all corners, Full clips none, and every mode retains a continuous base outline.

### Zone Perimeter Walls

- A wall surrounds the zone boundary.
- Per-zone "No Walls" is deferred; current zones retain their perimeter and parcel walls.
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
| **Business ↔ Transit/Corridor** | Automatic count from eligible frontage; one primary operational entrance in interior MVP |
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
| **Cutaway** (default) | Bottom 10% strip + cap | 100% height | Building and interior design. Player can see inside rooms while understanding the wall layout. |
| **Partial** | Bottom 10% strip + cap | Bottom 10% strip + cap | Overview of all rooms simultaneously. No walls obstruct the view. |
| **Full** | 100% height | 100% height | Exterior view, final presentation. Shows the building as it would appear in reality. |

> In **Cutaway** and **Partial**, walls that are hidden keep only a strip at their base (~10% of the wall height) so the player can always tell a wall is there without it obstructing the view. A thin **cap plate** sits on top of the strip (on both walls and corner cubes, the cube caps slightly inset to avoid z-fighting) and renders as the wall's top surface, so the cut reads as a real low wall rather than a hollow interior.

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
- Walls add **no maintenance cost**. No recurring per-tile maintenance charge exists either; later condition/repair design is separate.
- This keeps walls as a pure aesthetic/structural choice, not an economic one.

---

## Zone Editing Impact

| Change | Wall Behavior |
|--------|---------------|
| **Add zone tiles** | Walls extend automatically to the new boundary |
| **Remove zone tiles** | Walls retract automatically |
| **Change Walls ↔ No Walls** | Deferred; no current per-zone toggle |
| **Delete zone** | All zone walls removed |
| **Add/remove corridor tiles** | Shared walls update automatically |

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Building & Structure** | Walls are generated based on tile placement and floor boundaries |
| **Zone Design** | Mandatory perimeter/parcel walls and legal door gaps; per-zone No Walls deferred |
| **Transit & Circulation** | Wall gaps at corridor doors and transit connections |
| **Terrace System** | No perimeter walls on terrace edges facing non-built space |
| **UI / Visualization** | Wall rendering modes (Cutaway, Partial, Full) controlled by camera system |

---

## Design Notes

### Player Mental Model

The player should understand: "Walls appear where I build. They adapt to my layout. I can see through them when I need to, or see them fully when I want to admire my design."

### MVP Scope

MVP includes automatic wall generation, Cutaway/Partial/Full visualization modes, and door placement. Post-MVP adds material selection, tech tree unlocks, and advanced material hierarchy.
