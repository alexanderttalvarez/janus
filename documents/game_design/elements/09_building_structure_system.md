# Building & Structure System

## Overview

This system defines building tiles, floors, and construction state. District geometry, Plot Sections, ownership expansion, vertical rights, road dimensions, and street conversion are authoritative in [District Layout & Land Expansion](19_district_layout_land_expansion.md).

**MVP scope:** One initially owned 25 x 25 Plot with one full-plot section. Multiple Plots, section purchases, and inter-plot connections are post-MVP.

---

## Building Plots

### Plot Definition

| Property | Value |
|----------|-------|
| **Size** | 25 × 25 tiles (625 tiles per plot) |
| **Ownership** | The MVP Plot's single full-plot section is initially owned. Plot ownership and activation follow element 19. |
| **Boundaries** | Defined by the plot edges, not by the building footprint |

### District Context

Plots are bounded by the district layout rather than by their building footprints. Pedestrian Bands, carriageways, Street Corridors, Street Segments, and Intersections use the dimensions and ownership rules in element 19; they are not per-Plot rings.

---

## Tile Composition

Each tile in the game has 4 characteristics. A tile can only hold **1 element** at a time (no stacking of functional elements).

| Characteristic | Options | Description |
|----------------|---------|-------------|
| **Ownership** | Ground section right / floor-space tile right | Ground land is acquired by Plot Section; upper and underground floor space is acquired tile-by-tile. |
| **Construction** | Floor built / Not built, Walls built / Not built | Structural presence on this tile |
| **Zone** | Assigned to zone X / None | Which zone this tile belongs to (if any) |
| **Element** | Shop / Decoration / Column / Circulation / Amenity / None | The functional element on this tile. **Only 1 element per tile allowed.** |

**Element exclusivity examples:**
- A tile cannot have both a column and a decoration
- A tile cannot have both a shop and an amenity
- A tile can have a zone assignment AND an element (e.g., zone = Retail, element = Shop)

---

## Floor Acquisition

Upper and underground floor-space tiles are purchased individually and sequentially by signed elevation. Ground land is acquired by Plot Section, not by individual tile.

**Rules:**
- Upper and underground floors may be smaller than the adjacent floor.
- A floor may overhang up to 2 tiles beyond the immediately lower floor.
- No floor may extend beyond the combined vertical-rights mask of owned Plot Sections.
- Exact acquisition prices and progression requirements are open in element 19.

### Floors

| Property | Value |
|----------|-------|
| **Canonical elevations** | `0 = G`, `+1..+9 = F1..F9`, `-1..-5 = U1..U5` |
| **Default maximum** | 10 above-ground levels including G, plus 5 underground |
| **Stricter limits** | Plot Template, Block Slot override, and current progression may each reduce access |

---

## Multi-Plot & Connections (Post-MVP)

### Multiple Plots

- Player can construct additional buildings on adjacent plots
- Plot relationships and intervening infrastructure are determined by the District track grid.

### Plot Connections

| Type | Description | Requirements |
|------|-------------|--------------|
| **Skybridge** | Above-ground enclosed walkway between plots | Both plots must have matching floor levels |
| **Underground Passage** | Subterranean connection between plots | Both plots must have underground floors |
| **Shared Plaza** | Ground-level open space connecting plots | Rules remain to be defined |

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Economy** | Authoritative purchase constraints; exact district-expansion prices remain open in element 19 |
| **Zone Design** | Plots and floors define where zones can be placed. Tile composition affects zone layout. |
| **Transit & Circulation** | Vertical movement (stairs, elevators, escalators) connects floors. Connections link plots. |
| **Wall System** | Floor perimeter walls, terrace gaps, skybridge connection points |
| **Prestige** | Building scale, architectural features, connection design contribute to prestige |
| **Visitor Simulation** | Active Plots, pedestrian gateways, and future arrival sources affect visitor realization and flow |

---

## Design Notes

### Player Mental Model

The player should understand: "I own sections of a Plot and build within the vertical rights they grant, acquiring upper and underground space floor by floor."

### MVP Scope

MVP focuses on one initially owned Plot and its building loop: build floors -> place zones -> add circulation -> observe visitors -> optimize. Post-MVP may add section purchases, multiple Plots, connections, and exterior customization.

### Tuning Targets

- 25×25 plot (625 tiles) provides ample space for early experimentation without overwhelming the player
- Tile composition rules should be clear and enforceable without confusing the player
- The 2-tile overhang allowance should support creative floor shapes while respecting owned vertical rights.

### OPEN QUESTIONS

- Demolition timing and consequences for buildings that remain after a Plot Section purchase. An eligible whole fixed-structure demolition costs the approved flat 20-Kred fee and creates no refund.
- Progression gates for floor-space acquisition.
