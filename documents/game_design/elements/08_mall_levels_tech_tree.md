# Mall Levels & Tech Tree

## Overview

Progression in Janus is driven by prestige. As the district grows in prestige, it advances through named **Mall Levels**. Each level-up grants **Tech Points**, which the player spends in a branching **Tech Tree** to unlock new construction types, circulation options, amenities, and features.

The tech tree gives the player agency over *how* their district evolves. The pacing ensures there are always meaningful choices and new capabilities to work toward.

---

## Mall Levels

| Level | Prestige Threshold | Description |
|-------|-------------------|-------------|
| **Empty Lot** | 0 | Starting state. No buildings, no tenants. |
| **Small Market** | 500 | A few basic businesses serving the immediate area. |
| **Neighborhood Center** | 1,500 | A growing commercial hub for the local community. |
| **Regional Mall** | 3,500 | Drawing visitors from across the city. |
| **City Destination** | 6,500 | A landmark commercial center. |
| **Megacity Mall** | 9,000 | A world-class commercial ecosystem. |

### Level-Up Rewards

| Level Reached | Tech Points Earned | Cumulative Points |
|---------------|-------------------|-------------------|
| **Small Market** (500) | +3 | 3 |
| **Neighborhood Center** (1,500) | +5 | 8 |
| **Regional Mall** (3,500) | +7 | 15 |
| **City Destination** (6,500) | +10 | 25 |
| **Megacity Mall** (9,000) | +15 | 40 |

---

## Tech Tree

### Point Economy

| Branch | Total Node Cost |
|--------|-----------------|
| **Construction** | 8 points |
| **Circulation** | 6 points |
| **Amenities** | 9 points |
| **Total MVP** | **23 points** |

With 40 total points available by Megacity Mall, the player can unlock the entire MVP tree and still have 17 points for post-MVP additions.

### Construction Branch

| Node | Cost | Prerequisites | Unlocks |
|------|------|---------------|---------|
| **Basic Zoning** | Free (start) | None | Retail, Food & Beverage zones |
| **Advanced Zoning** | 1 pt | None | Entertainment, Services zone types |
| **Anchor Tenants** | 2 pts | Advanced Zoning | Anchor zone type (large-format tenants) |
| **Multi-Floor** | 2 pts | Stairs | 2nd and 3rd floors |
| **Underground** | 3 pts | Multi-Floor | Underground floors U1–U3 |

### Circulation Branch

| Node | Cost | Prerequisites | Unlocks |
|------|------|---------------|---------|
| **Basic Corridors** | Free (start) | None | Standard corridor tile placement |
| **Stairs** | 1 pt | None | Stair placement between floors |
| **Elevators** | 2 pts | Stairs | Elevator placement |
| **Escalators** | 2 pts | Elevators | Escalator placement |

### Amenities Branch

| Node | Cost | Prerequisites | Unlocks |
|------|------|---------------|---------|
| **Basic Amenities** | Free (start) | None | Trash cans, basic signage |
| **Green Spaces** | 1 pt | None | Plants, small gardens, planters |
| **Water Features** | 2 pts | Green Spaces | Fountains, small pools |
| **Art Installations** | 2 pts | Green Spaces | Sculptures, murals, displays |
| **Rooftop Terrace** | 3 pts | Multi-Floor + Green Spaces | Terrace zones on upper floors |

### Available from Start (No Tech Required)

| Feature | Description |
|---------|-------------|
| **HUD & Metrics** | Money, visitors, prestige, simulation speed controls |
| **Basic Panels** | Finances, Prestige, Tenants, Visitors, Metrics Dashboard |
| **Basic Heatmaps** | Visitor Density, Zone Viability |
| **Graphs** | Line charts with 7/30/90 day toggles |
| **Contextual Indicators** | Low viability, congestion, tenant warnings, vacant zones |

---

## Dependency Map

```
Basic Zoning (free) ──→ Advanced Zoning (1) ──→ Anchor Tenants (2)
                                                  │
Stairs (1) ───────────────────────────────────→ Multi-Floor (2) ──→ Underground (3)
                                                  │
Basic Corridors (free) ──→ Stairs (1) ──→ Elevators (2) ──→ Escalators (2)
                                                  │
Basic Amenities (free) ──→ Green Spaces (1) ──→ Water Features (2)
                                │                    │
                                └────────────────→ Art Installations (2)
                                │
Multi-Floor (2) ────────────→ Rooftop Terrace (3)
```

---

## Pacing & Player Choices

### Early Game (Small Market → Neighborhood Center)

**Points available: 3 → 8**

The player faces early choices:
- **Expand vertically?** Unlock Stairs (1) → save for Multi-Floor (2)
- **Diversify zones?** Unlock Advanced Zoning (1) → save for Anchor Tenants (2)
- **Beautify immediately?** Unlock Green Spaces (1) → save for Water Features (2)

By Neighborhood Center, the player has 8 points and can unlock ~4 nodes. They should have stairs and at least one branch started.

### Mid Game (Neighborhood Center → Regional Mall)

**Points available: 8 → 15**

The player can now afford 2-cost nodes. Key unlocks:
- Elevators (2) for efficient vertical circulation
- Multi-Floor (2) to build upward
- Water Features or Art Installations (2) for prestige
- Advanced Analytics is already available from start

By Regional Mall, the player has 15 points and can unlock most MVP nodes.

### Late Game (Regional Mall → Megacity Mall)

**Points available: 15 → 40**

All MVP nodes are accessible. The surplus points (40 - 23 = 17) are reserved for post-MVP additions:
- Transportation facilities (bus stops, metro stations)
- Advanced staff management
- Maintenance systems
- Premium materials and architectural options
- Challenge mode features

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Prestige System** | Mall levels are prestige thresholds. Prestige drives progression. |
| **Economy** | Tech unlocks enable new revenue streams (anchor tenants, multi-floor expansion) |
| **Zone Design** | Construction branch unlocks new zone types and building capabilities |
| **Transit & Circulation** | Circulation branch unlocks elevators, escalators, and vertical movement |
| **Metrics & Visualization** | All metrics and panels are available from start (no tech gate) |

---

## Design Notes

### Player Mental Model

The player should understand: "My district grows. As it grows, I unlock new tools. I choose which tools to unlock based on my vision."

The tech tree is not a checklist — it's a menu of possibilities. The player's choices shape their district's character.

### Tuning Targets

- Early game should feel like meaningful choices with real trade-offs
- Mid game should unlock the core building toolkit
- Late game should provide surplus points for post-MVP content
- Dependencies should feel logical, not arbitrary
- No tech node should be mandatory; all should be optional enhancements
