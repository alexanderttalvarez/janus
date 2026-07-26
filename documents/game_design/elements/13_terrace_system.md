# Terrace System

## Overview

Terraces are open-air floor sections that provide visitor amenities, prestige value, and architectural variety. They are distinct from indoor zones and have specific placement rules.

---

## Placement Rules

### Adjacency Requirement

A terrace tile **must be adjacent to at least one non-built tile**. This means:

| Valid Placement | Invalid Placement |
|-----------------|-------------------|
| Edge of the floor (adjacent to plot boundary) | Surrounded by built tiles on all 4 sides |
| Next to an internal gap (non-acquired tile inside the floor) | — |
| Adjacent to another terrace tile | — |

**Rationale:** Terraces are open to the sky. They cannot exist in the middle of a solid floor — there must be open space above or beside them.

### Floor Boundary

- Terraces are part of the floor's acquired tiles.
- They count toward Scale (as developed tiles).
- They do **not** generate rent (no tenant can occupy a terrace).

---

## Wall & Door Interaction

### Perimeter Walls

- Terrace tiles have **no perimeter wall** on edges facing non-built space.
- Edges facing indoor tiles have a wall (or railing, post-MVP).

### Door Access

- Access to terraces requires a **manually placed door** from the interior.
- Doors are placed on the wall between a terrace tile and an adjacent indoor tile.
- The player chooses where to place terrace doors, giving control over visitor flow.

---

## Visitor Behavior

- Terraces are classified as **Amenity** tiles.
- Visitors can walk on terraces, sit on terrace furniture (post-MVP), and enjoy the open space.
- Terraces contribute to **Visitor Experience** (cleanliness, comfort factors).
- Terraces contribute to **Prestige** (Design & Architecture factor).

---

## Visualization

- Terraces render differently from indoor tiles: open sky above, different floor texture, possible railing on edges.
- In **Cutaway** wall mode, terraces are fully visible (no walls to cut).
- In **Full** wall mode, terrace railings (post-MVP) are visible on edges.

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Building & Structure** | Terraces are floor tiles with special placement rules |
| **Wall System** | No perimeter walls on open edges. Manual door placement. |
| **Prestige** | Contributes to Design & Architecture quality factor |
| **Visitor Simulation** | Amenity tiles that improve visitor satisfaction |
| **Economy** | No rent generation. Maintenance cost applies (per tile). |

---

## Design Notes

### MVP Scope

MVP includes basic terrace placement, open-edge rendering, and manual door placement. Post-MVP adds terrace furniture (benches, planters, seating), railings, and prestige bonuses.
