# Transit & Circulation

## Overview

Transit & Circulation governs how visitors and staff move through the district. It covers horizontal movement (corridors, plazas) and vertical movement (stairs, elevators, escalators). Effective circulation is essential for visitor satisfaction, tenant viability, and prestige.

**Design principle:** Circulation is the connective tissue of the district. Poor circulation creates bottlenecks, dead ends, and unreachable floors. Good circulation creates smooth flow, accessibility, and pleasant visitor experiences.

---

## Horizontal Circulation

### Corridors

- **Definition:** Any tile marked as "Transit" type. These tiles are designated for visitor movement.
- **Width:** Any width allowed. The player places corridor tiles freely, creating paths of any shape or size.
- **Cost:** Free to place on purchased tiles. No additional cost beyond tile purchase and maintenance.
- **Tenant interaction:** Corridors inside a tenant zone act as internal circulation. They provide door access points for businesses and allow visitors to move through the zone without disrupting shop layouts.
- **External corridors:** Corridors outside zones connect different zones, floors, and transit points.

### Zone-Internal Transit

- When a zone is created, the player can designate specific tiles within it as "Transit" type.
- These tiles appear visually distinct from tenant tiles but belong to the same zone.
- Internal transit tiles provide door access for businesses within the zone.
- They reduce rentable space but improve accessibility and visitor flow.

### Plaza Tiles (Post-MVP)

- Open, wide areas for visitor gathering.
- Functionally identical to corridors but with different visual treatment.
- May provide small prestige bonuses (open space, seating, landscaping).

---

## Vertical Transit

### Stairs

- **Unlock:** Requires "Stairs" tech node (1 pt).
- **Footprint:** 2×2 tiles minimum (landing + steps). Can be extended for wider staircases.
- **Connection:** Adjacent floors only (F1↔F2, F2↔F3, etc.).
- **Placement cost:** 500 Kreds per stair placement.
- **Capacity:** High. No queue system.
- **Speed:** Slower than elevators for multi-floor travel, but instant for adjacent floors.
- **Prestige impact:** Small positive contribution to Accessibility factor.

### Elevators

- **Unlock:** Requires "Elevators" tech node (2 pts, requires Stairs).
- **Footprint:** Player manually places:
  - **Shaft tile:** 1×1 tile (vertical shaft, spans all connected floors)
  - **Lobby tiles:** 1×1 tile per floor where the elevator stops
- **Connection:** All floors in the building (player selects which floors the elevator serves).
- **Placement cost:** 2,000 Kreds per shaft + 500 Kreds per lobby tile.
- **Capacity:** 8 visitors per trip. Queue forms if capacity is reached.
- **Speed:** Fast for multi-floor travel. Travel time scales with floor distance.
- **Prestige impact:** Moderate positive contribution to Accessibility factor.

### Escalators (Post-MVP)

- **Unlock:** Requires "Escalators" tech node (2 pts, requires Elevators).
- **Footprint:** 2×1 tiles per direction (up + down).
- **Connection:** Adjacent floors only.
- **Placement cost:** 1,500 Kreds per escalator pair.
- **Capacity:** Very high. No queue system.
- **Speed:** Fast for single-floor transitions. Continuous flow.
- **Prestige impact:** Moderate positive contribution to Accessibility factor.

---

## Pathfinding & Visitor Behavior

### Layered Graph

The pathfinding graph is **layered by floor**. To move between floors, visitors must use designated vertical transit elements.

| Tile Type | Vertical Access | Horizontal Access |
|-----------|----------------|-------------------|
| **Corridor tile** | No | Yes |
| **Zone tile** | No | Yes |
| **Stairs** | Yes (adjacent floors only) | Yes |
| **Elevator lobby** | Yes (all connected floors) | Yes |
| **Escalator** | Yes (adjacent floors only) | Yes |

**If no vertical transit connects the required floors, the destination is unreachable.** The visitor will either choose an alternative destination or leave the mall.

### Weighted Route Selection

A* pathfinding uses **weighted tile costs** to simulate crowd behavior and congestion avoidance.

```
Tile Cost = Base Cost × Weight Multiplier × (1 + Occupancy × 0.15)
```

Where `Occupancy` = number of visitors currently on the tile.

| Tile State | Weight Multiplier | Effect |
|------------|------------------|--------|
| **Empty corridor** | 1.0x | Normal priority |
| **Elevator lobby** (base) | 1.2x | Slightly less preferred (naturally busy) |
| **Queue tile** | 2.0x | Avoided if alternatives exist; still passable |
| **Congested corridor** (>5 visitors/tile/sim min) | 2.5x | Strongly avoided if alternatives exist |

**Crowd Distribution Rules:**
- **Dynamic occupancy weighting:** As tiles fill up, they become less attractive. A tile with 3 visitors costs ~1.45x base, pushing later visitors to adjacent empty tiles. This creates self-balancing crowd distribution.
- **Randomized tie-breaking:** When two adjacent tiles have equal cost, the algorithm randomly chooses between them instead of always picking the same direction. The randomness is small but prevents deterministic corridor clustering.
- Queue tiles are never blocked — they remain passable but less preferred.
- If no alternative exists, the visitor uses the queue tile (slower but functional).

**Behavior:** Together, these rules create natural crowd distribution without trapping visitors or requiring per-agent state. Visitors spread across available corridor width, mimicking real pedestrian flow.

### Route Selection Priority

Visitors choose routes based on:
1. **Weighted shortest path:** A* with tile weight multipliers
2. **Queue avoidance:** If elevator queue exceeds patience, visitor chooses stairs
3. **Exploration:** High-exploration visitors may take scenic routes (wider corridors, plazas)

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Building & Structure** | Circulation tiles occupy purchased floor tiles. Vertical transit connects floors. |
| **Zone Design** | Internal transit tiles provide door access. Corridors connect zones. |
| **Wall System** | Wall gaps at corridor doors. Transit connections bypass perimeter walls. |
| **Visitor Simulation** | Pathfinding uses corridors, stairs, elevators, escalators. Congestion affects satisfaction. |
| **Prestige** | Accessibility factor driven by circulation quality and coverage. |
| **Metrics & Visualization** | Congestion heatmap shows bottleneck locations. Flow data tracks transit usage. |

---

## Design Notes

### Player Mental Model

The player should understand: "I create paths for people to walk. Good paths connect everything efficiently. Bad paths create bottlenecks and dead ends."

### MVP Scope

MVP includes corridors and stairs/elevators as tech unlocks. Post-MVP adds escalators, plazas, skybridges, and underground passages.

### Tuning Targets

- Corridor width flexibility should allow creative layouts without confusing the player
- Elevator capacity (8 visitors) should create meaningful queue decisions at peak times
- Congestion thresholds should be achievable but require intentional mitigation
- Pathfinding should prioritize efficiency but allow for exploration behavior
