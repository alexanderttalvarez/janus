# Zone / Space Design

## Overview

Zones are the player's primary creative tool. A zone is a contiguous area of tiles designated for a specific commercial purpose. The player defines the zone's shape, size, type, and internal layout. The game's AI handles splitting the zone into individual businesses, populating them with tenants, and managing their spatial needs.

The player designs spaces. The game fills them. (Pillar 2: Spaces Over Stores)

---

## Zone Creation & Editing

### Unified "Edit Zone" Mode

Both creating a new zone and modifying an existing zone use the same interface and ruleset: **Edit Zone mode**.

**Creating a new zone:**
1. Player selects a zone type from the build palette (Retail, Food & Beverage, Entertainment, Services, Anchor)
2. Player clicks on an empty tile to start painting
3. Edit Zone mode activates
4. Player paints adjacent tiles (click individually or click-and-drag)
5. Player can change internal tile typologies (Tenant, Decoration, Transit)
6. "Finish Zone" button appears
7. Player clicks "Finish Zone" to confirm

**Editing an existing zone:**
1. Player selects an existing zone
2. Player clicks "Edit Zone"
3. Edit Zone mode activates (same interface as creation)
4. Zone type is locked and cannot be changed
5. Player can add/remove tiles, change internal typologies
6. "Finish Zone" button appears
7. Player clicks "Finish Zone" to confirm

**Edit Zone mode rules:**
- Can only paint tiles adjacent to existing zone tiles
- Can only paint on empty tiles (not occupied by other zones, circulation, or amenities)
- Can remove tiles from the zone by clicking on them
- Can change tile typology within the zone (Tenant ↔ Decoration ↔ Transit)
- Zone type selection is only available during new zone creation

### Zone Shape

Zones can be **any contiguous shape**. There is no restriction to rectangles or L-shapes. The player paints freely as long as tiles are connected.

**Maximum size:** Limited only by the floor boundary. There is no artificial cap on zone size.

---

## Zone Types & Subtypes

### Zone Types (MVP)

| Type | Description | Avg Store Size |
|------|-------------|----------------|
| **Retail** | General shopping: clothing, electronics, gifts, etc. | 6 tiles |
| **Food & Beverage** | Restaurants, cafes, food courts | 8 tiles |
| **Entertainment** | Cinemas, arcades, bowling, etc. | 12 tiles |
| **Services** | Banks, salons, repair shops, offices | 5 tiles |
| **Anchor** | Large-format tenants: department stores, supermarkets | 30 tiles |

### Subtypes

Each zone type has 5+ subtypes. Subtypes define the specific business category and have minimum/maximum tile requirements.

| Zone Type | Example Subtypes |
|-----------|-----------------|
| **Retail** | Fashion, Electronics, Home Goods, Jewelry, Bookstore |
| **Food & Beverage** | Sushi Restaurant, Italian Restaurant, Cafe, Mexican Restaurant, Local Food |
| **Entertainment** | Cinema, Arcade, Bowling Alley, Escape Room, VR Experience |
| **Services** | Bank, Hair Salon, Repair Shop, Clinic, Travel Agency |
| **Anchor** | Department Store, Supermarket, Gym, Food Court, Exhibition Hall |

**Subtype tile requirements** (min/max per business):
- Defined per subtype (e.g., Sushi Restaurant: min 6, max 12 tiles)
- AI uses these to filter which subtypes can fit in generated parcels

---

## Internal Tile Typologies

Every tile within a zone has a typology. By default, all tiles are **Tenant tiles**.

| Typology | Description | Purpose |
|----------|-------------|---------|
| **Tenant** (default) | Rentable space for businesses | Generates revenue |
| **Decoration/Amenity** | Plants, benches, art, water features | Boosts visitor experience and prestige |
| **Transit** | Internal corridors within the zone | Provides door access points for businesses |

**Changing typology:**
- In Edit Zone mode, player selects a typology tool and paints over tiles
- Converting Tenant → Decoration/Transit reduces rentable space
- Converting Decoration/Transit → Tenant increases rentable space

---

## Frontage-Based Splitting Algorithm

When a zone is finalized, the AI splits it into rectangular business parcels. The algorithm runs in five phases.

### Phase 1: Detect Valid Frontage Tiles

Identify every tile in the zone that borders a walkable circulation area (building corridors, plazas, entrances, or internal Transit tiles). These are the **frontage tiles** — the only valid locations for store entrances.

Interior tiles cannot become entrances.

### Phase 2: Reserve Store Frontages

Calculate the target number of stores:
```
Target Stores = floor(Total Tenant Tiles / Average Store Size for Zone Type)
```

For each future store:
- Select one or more adjacent frontage tiles based on the store's size needs
- Small kiosk: 1 tile frontage
- Small shop: 2–3 tiles frontage
- Medium store: 3–5 tiles frontage
- Anchor store: 6+ tiles frontage
- Each frontage segment is assigned to exactly one future store

### Phase 3: Grow Rectangular Parcels

Each reserved frontage becomes the seed of a rectangular parcel:
- The rectangle extends inward (perpendicular to the frontage) until it reaches its target area or hits a boundary
- Boundaries include: zone edges, decoration tiles, transit tiles, other parcels
- Rectangles cannot overlap
- Spare tiles from the division (e.g., 40 tenant tiles / 6 avg = 6 stores + 4 spare) are distributed as extra space to some parcels

### Phase 4: Validate and Repair

- Verify each parcel meets minimum area requirements for its intended subtype
- Merge parcels that are too small into adjacent parcels
- Fill any remaining isolated gaps (convert to decoration)
- Ensure all parcels are connected to their frontage

### Phase 5: Assign Businesses

- Each parcel becomes a business slot
- Tenants apply based on their size requirements, zone type, and prestige
- **Graph Coloring constraint:** No two adjacent parcels (sharing a wall) may be assigned the same subtype. This prevents competing businesses (e.g., two sushi restaurants) from being placed side-by-side.
- The AI selects the best-fitting subtype for each parcel using a graph coloring algorithm:
  1. Build an adjacency graph of all parcels
  2. For each parcel, determine the set of valid subtypes (meeting size requirements)
  3. Assign subtypes using a greedy coloring approach, prioritizing subtypes that minimize adjacency conflicts
  4. If conflicts remain, resolve by swapping assignments between non-adjacent parcels
- A business is only assigned if its tile requirements are met

### Algorithm Properties

- All generated parcels are **rectangular**
- Every business has **direct door access** to circulation
- No gaps between businesses (leftover space becomes decoration)
- Parcel generation is **separate from business assignment** (modular design)

---

## Wall System Reference

*(Full wall mechanics are defined in the Wall System element. The following is a summary for context.)*

- **Business walls:** Each business is enclosed by default. "No Walls" mode creates open-plan layout.
- **Zone perimeter walls:** Surround the zone, with gaps at transit connections and corridor doors.
- **Floor perimeter walls:** Surround the floor, with gaps at terraces and skybridges.
- Wall setting is binary per zone (all walls or no walls).
- Changing walls ↔ no walls is a visual change only — no eviction or recalculation needed.

---

## Zone Editing Consequences

Editing a zone after tenants have moved in has consequences:

| Change | Consequence |
|--------|-------------|
| **Add tiles to edges** | AI recalculates split. New business slots may appear. Tenants apply normally. No eviction. |
| **Remove tiles** | If existing businesses are affected (tiles removed from their parcel), they are evicted. 1-week exclusivity lock triggers. AI recalculates remaining space. |
| **Convert Tenant → Transit** | AI recalculates. May create new access points. No eviction unless a parcel falls below minimum size. |
| **Convert Tenant → Decoration** | Reduces rentable space. AI recalculates. No eviction unless a parcel falls below minimum size. |
| **Convert Decoration/Transit → Tenant** | AI recalculates. New business slots may appear. No eviction. |
| **Change Walls ↔ No Walls** | Visual change only. No eviction. No recalculation needed. |

**Eviction rule:** A business is only evicted if its parcel falls below its minimum tile requirement. Minor edits that don't affect existing parcels are free.

**Exclusivity lock:** Any eviction triggers a 1-week simulation lock on affected parcels. No new tenant can apply during this period.

---

## Visual Feedback

### Zone Colors

Each zone type has an associated color for visual clarity:

| Zone Type | Color |
|-----------|-------|
| **Retail** | Purple |
| **Food & Beverage** | Green |
| **Entertainment** | Orange |
| **Services** | Blue |
| **Anchor** | Red |

**Edit Zone mode visual behavior:**
- **Hovering** over tiles: zone color shown at 50% opacity (preview)
- **Painting** (click held): zone color shown at 100% opacity
- **Finished** (edit mode closed): zone color overlay disappears entirely

### Zone Perimeter Indicators

- Bold colored lines around each zone perimeter using the zone type color
- Zone type name and custom name displayed at the center of the zone (e.g., "Food & B — Zone A")

### Business Labels

- Each business displays its name and subtype at the center of its parcel (e.g., "Sakura Sushi")
- Labels are visible at appropriate zoom levels

---

## Zone Naming

Zones are automatically named based on their type and position:
- Examples: "Retail Zone A", "Food & Beverage Zone B", "Entertainment Zone 3"
- Players can rename zones at any time via the Edit Zone panel
- Zone names appear in notifications, reports, and the zone inspector

---

## Design Notes

### Player Mental Model

The player should think in terms of: "I'm creating a space for businesses. I define the area, the type, and the internal flow. The game handles the rest."

The frontage-based algorithm reinforces this: the player learns that zones with good corridor access attract more and better businesses. This is a real architectural principle made into gameplay.

### Tuning Targets

- Average store sizes should produce 3–8 businesses per typical zone
- Spare tile distribution should feel fair (not always giving extra space to the same parcel)
- The algorithm should never produce unusable parcels (Phase 4 validation guarantees this)
- Wall/no-wall choice should be a meaningful aesthetic decision, not a mechanical one
