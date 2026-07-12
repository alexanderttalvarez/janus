# Building & Structure System

## Overview

This system defines the physical structure of the district: buildings, floors, structural elements, and the spatial rules that govern construction. Buildings are the structural shell; zones, circulation, and amenities fill the interior.

**MVP scope:** Single building with multiple floors. Multiple buildings and inter-building connections are post-MVP.

---

## Building Fundamentals

### Floors

| Property | Value |
|----------|-------|
| **Above ground** | Up to 10 floors (F1–F10) |
| **Underground** | Up to 3 floors (U1–U3) |
| **Total levels** | Maximum 14 (10 above + 3 below + ground) |

### Floor Acquisition

Each floor's tiles are purchased individually. The player builds upward floor by floor, tile by tile.

**Rules:**
- Upper floors can be **smaller** than the floor below
- Upper floors **cannot exceed** the overall building footprint
- **Overhang rule:** A floor may extend up to **2 tiles per edge** beyond the floor directly below it, but never beyond the building's overall footprint
- Each tile purchase requires Kreds (price scales with floor level)

### Footprint

The building footprint is the maximum ground-level area the building can occupy.

- Defined by the first set of tiles purchased on F1 (ground floor)
- All upper floors must fit within this boundary
- The footprint can be expanded by purchasing additional ground-floor tiles (post-MVP)

---

## Structural Elements

### Columns

Structural columns are **automatically placed** by the game based on floor size and shape. The player does not choose their location.

| Property | Value |
|----------|-------|
| **Spacing** | Every 5 tiles (grid-aligned) |
| **Visibility** | Visible as structural elements on each floor |
| **Zone interaction** | Zones can include columns; columns become part of the interior space |

**Design rationale:** Automatic column placement ensures structural realism without burdening the player with engineering decisions. Columns create natural visual rhythm and subtle zone boundaries.

### Exterior

| Property | MVP | Post-MVP |
|----------|-----|----------|
| **Default style** | Concrete with windows | Multiple styles (glass, brick, metal, etc.) |
| **Roof** | Flat | Flat, sloped, green roof, terrace |
| **Façade customization** | None | Unlockable via tech tree |

---

## Pedestrian Areas & Roads

### Pedestrian Areas

- **Width:** 2 tiles wide, surrounding the entire building perimeter
- **Ownership:** Not controlled by the player unless purchased
- **Purchase rule:** Must buy the **entire pedestrian area segment** between two buildings (or around a single building) at once. Individual tile purchases are not allowed.
- **Use:** Decoration, amenities, seating, planters. No zones allowed.

### Roads

- **Width:** 6 tiles wide between buildings
- **Ownership:** Not controlled by the player unless purchased
- **Purchase rule:** Must buy the **entire road segment** between two buildings at once. Individual tile purchases are not allowed.
- **Use:** Decoration only (fountains, art, landscaping). **No zones allowed.**
- **Price:** 2× normal tile cost (e.g., 2,000 Kreds for a ground-floor road tile, scaling with floor level)

**Design rationale:** Requiring bulk purchases for pedestrian areas and roads prevents piecemeal decoration and encourages thoughtful urban planning. The higher road tile price reflects the premium of public space conversion.

---

## Multi-Building & Connections (Post-MVP)

### Multiple Buildings

- Player can construct additional buildings on adjacent plots
- Each building has its own footprint, floors, and exterior style
- Buildings must be separated by roads (6 tiles wide) and pedestrian areas (2 tiles wide)

### Building Connections

| Type | Description | Requirements |
|------|-------------|--------------|
| **Skybridge** | Above-ground enclosed walkway between buildings | Both buildings must have matching floor levels |
| **Underground Passage** | Subterranean connection between buildings | Both buildings must have underground floors |
| **Shared Plaza** | Ground-level open space connecting buildings | Pedestrian areas must be purchased and connected |

**Connection rules:**
- Connections allow visitor flow between buildings
- Each connection has a construction cost
- Connections count toward Scale (as developed tiles)
- Connections may have prestige value (well-designed skybridges, grand plazas)

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Economy** | Tile purchase costs, road tile premiums, construction costs |
| **Zone Design** | Floors and footprints define where zones can be placed. Columns affect zone layout. |
| **Transit & Circulation** | Vertical movement (stairs, elevators, escalators) connects floors. Connections link buildings. |
| **Wall System** | Floor perimeter walls, terrace gaps, skybridge connection points |
| **Prestige** | Building scale, architectural features, connection design contribute to prestige |
| **Visitor Simulation** | Building layout affects visitor pathfinding, flow, and satisfaction |

---

## Design Notes

### Player Mental Model

The player should understand: "I'm building a structure. I buy the space, fill it with zones and amenities, and connect it to the world. The structure supports everything I put inside it."

### MVP Scope

MVP focuses on a single building with multiple floors. The player learns the core loop: buy tiles → place zones → add circulation → observe visitors → optimize. Post-MVP adds the complexity of multiple buildings, connections, and exterior customization.

### Tuning Targets

- Column spacing (every 5 tiles) should create a natural grid that zones work with, not against
- Floor acquisition costs should encourage thoughtful expansion, not reckless building
- The overhang rule (2 tiles per edge) should allow creative floor shapes without breaking structural logic
- Road and pedestrian area bulk purchase rules should encourage planning, not frustration
