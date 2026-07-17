# Building & Structure System

## Overview

This system defines the physical structure of the district: building plots, floors, tile composition, and the spatial rules that govern construction. Building plots are the available land; the building is what the player constructs on them.

**MVP scope:** Single building plot with multiple floors. Multiple plots and inter-plot connections are post-MVP.

---

## Building Plots

### Plot Definition

| Property | Value |
|----------|-------|
| **Size** | 25 × 25 tiles (625 tiles per plot) |
| **Ownership** | First plot is fully pre-bought at game start. Additional plots must be purchased (post-MVP). |
| **Boundaries** | Defined by the plot edges, not by the building footprint |

### Pedestrian Areas & Roads (Relative to Plots)

Pedestrian areas and roads exist **around building plots**, not around buildings themselves.

| Feature | Width | Ownership Rule | Use |
|---------|-------|----------------|-----|
| **Pedestrian Area** | 2 tiles wide, surrounding the entire plot | Must buy the entire segment at once. No individual tile purchases. | Decoration, amenities, seating, planters. No zones allowed. |
| **Road** | 6 tiles wide between plots | Must buy the entire segment at once. No individual tile purchases. | Decoration only (fountains, art, landscaping). **No zones allowed.** |
| **Road Tile Price** | 2× normal tile cost | Scales with floor level | Premium for public space conversion |

**Design rationale:** Requiring bulk purchases for pedestrian areas and roads prevents piecemeal decoration and encourages thoughtful urban planning.

---

## Tile Composition

Each tile in the game has 4 characteristics. A tile can only hold **1 element** at a time (no stacking of functional elements).

| Characteristic | Options | Description |
|----------------|---------|-------------|
| **Ownership** | Bought / Not Bought | Whether the player owns this tile |
| **Construction** | Floor built / Not built, Walls built / Not built | Structural presence on this tile |
| **Zone** | Assigned to zone X / None | Which zone this tile belongs to (if any) |
| **Element** | Shop / Decoration / Column / Circulation / Amenity / None | The functional element on this tile. **Only 1 element per tile allowed.** |

**Element exclusivity examples:**
- A tile cannot have both a column and a decoration
- A tile cannot have both a shop and an amenity
- A tile can have a zone assignment AND an element (e.g., zone = Retail, element = Shop)

---

## Floor Acquisition

Each floor's tiles are purchased individually. The player builds upward floor by floor, tile by tile.

**Rules:**
- Upper floors can be **smaller** than the floor below
- Upper floors **cannot exceed** the overall plot boundary
- **Overhang rule:** A floor may extend up to **2 tiles per edge** beyond the floor directly below it, but never beyond the plot boundary
- Each tile purchase requires Kreds (price scales with floor level)

### Floors

| Property | Value |
|----------|-------|
| **Above ground** | Up to 10 floors (F1–F10) |
| **Underground** | Up to 3 floors (U1–U3) |
| **Total levels** | Maximum 14 (10 above + 3 below + ground) |

---

## Multi-Plot & Connections (Post-MVP)

### Multiple Plots

- Player can construct additional buildings on adjacent plots
- Each plot has its own pedestrian area and road boundaries
- Plots are separated by roads (6 tiles wide)

### Plot Connections

| Type | Description | Requirements |
|------|-------------|--------------|
| **Skybridge** | Above-ground enclosed walkway between plots | Both plots must have matching floor levels |
| **Underground Passage** | Subterranean connection between plots | Both plots must have underground floors |
| **Shared Plaza** | Ground-level open space connecting plots | Pedestrian areas must be purchased and connected |

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Economy** | Tile purchase costs, road tile premiums, construction costs |
| **Zone Design** | Plots and floors define where zones can be placed. Tile composition affects zone layout. |
| **Transit & Circulation** | Vertical movement (stairs, elevators, escalators) connects floors. Connections link plots. |
| **Wall System** | Floor perimeter walls, terrace gaps, skybridge connection points |
| **Prestige** | Building scale, architectural features, connection design contribute to prestige |
| **Visitor Simulation** | Plot layout affects visitor pathfinding, flow, and satisfaction |

---

## Design Notes

### Player Mental Model

The player should understand: "I'm given a plot of land. I build on it, tile by tile, floor by floor. The plot defines my boundaries. Everything I build sits inside those boundaries."

### MVP Scope

MVP focuses on a single plot with multiple floors. The player learns the core loop: build floors → place zones → add circulation → observe visitors → optimize. Post-MVP adds the complexity of multiple plots, connections, and exterior customization.

### Tuning Targets

- 25×25 plot (625 tiles) provides ample space for early experimentation without overwhelming the player
- Tile composition rules should be clear and enforceable without confusing the player
- The overhang rule (2 tiles per edge) should allow creative floor shapes without breaking structural logic
- Road and pedestrian area bulk purchase rules should encourage planning, not frustration
