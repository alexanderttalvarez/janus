# Mall Levels & Tech Tree

**Scope/revision:** [Current MVP](../current_mvp.md), 2026-09-08. This is the single authority for thresholds, node costs, grants and eligibility. The catalogue contains deferred nodes; its total is not an MVP requirement.

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

Start with zero earned/spent points. On a committed official tier, award every newly reached milestone at or below that tier once, in ascending threshold order. Persist awarded milestone IDs with earned/spent points. Tier loss revokes neither awards nor purchased nodes; regaining a tier, replaying a notification or loading a save never grants twice. On first reaching Neighborhood directly, grant 3 + 5 = 8, not only 5. Progression owns these mutations; Prestige only publishes official facts. This minimal award path is current MVP, resolving the older architecture deferral without adding achievements.

### Plot Access Rewards

The initial Plot is already owned. The district supports at most **9 Plots**: the initial Plot plus eight player-selected unlocked Plots.

| Level reached | New Plot Access selections | Maximum unlocked Plots |
|---|---:|---:|
| Empty Lot | 0 | 1 initial Plot |
| Small Market | 0 | 1 |
| Neighborhood Center | 2 | 3 |
| Regional Mall | 2 | 5 |
| City Destination | 2 | 7 |
| Megacity Mall | 2 | 9 |

Each selection permanently unlocks one eligible Plot but grants no ownership. A selected Plot becomes available for camera access and later Plot Section purchases. It becomes Active only when the player purchases its first Plot Section. A selected Plot must be orthogonally adjacent to an Active or already unlocked Plot; diagonal selection is invalid.

---

## Tech Tree

### Point Economy

| Branch | Total Node Cost |
|--------|-----------------|
| **Construction** | 12 points |
| **Circulation** | 6 points |
| **Amenities** | 8 points |
| **Total listed catalogue** | **26 points** |

The listed catalogue costs 26 of the 40 eventual points, leaving 14. This corrects old 23/27/28 totals without inventing nodes. The current core route (Advanced Zoning, Anchors, Stairs, Multi-Floor, Elevators) costs 8; current baseline Prestige can grant exactly those 8 through Neighborhood Center. Deferred nodes are hidden/disabled in player-facing MVP purchase lists, even where future policy is approved. No points are spent on an unavailable feature.

### Construction Branch

| Node | Cost | Prerequisites | Unlocks |
|------|------|---------------|---------|
| **Basic Zoning** | Free (start) | None | Retail, Food & Beverage zones |
| **Advanced Zoning** | 1 pt | None | Entertainment, Services zone types |
| **Anchor Tenants** | 2 pts | Advanced Zoning | Anchor zone type (large-format tenants) |
| **Multi-Floor** | 2 pts | Stairs | F1 and F2 (G is the first building level) |
| **Underground** | 3 pts | Multi-Floor | Underground floors U1–U2 |
| **Vertical Expansion I** | 1 pt | Multi-Floor | Floors F3–F5; requires Neighborhood Center |
| **Vertical Expansion II** | 1 pt | Vertical Expansion I | Floors F6–F7; requires Regional Mall |
| **Vertical Expansion III** | 1 pt | Vertical Expansion II | Floors F8–F9; requires City Destination |
| **Deep Foundations** | 1 pt | Underground | Underground floors U3–U5; requires Regional Mall |

### Circulation Branch

| Node | Cost | Prerequisites | Unlocks |
|------|------|---------------|---------|
| **Basic Corridors** | Free (start) | None | Standard corridor tile placement |
| **Bus Stop** | 1 pt | Basic Corridors | Bus-stop eligibility; requires Small Market |
| **Stairs** | 1 pt | None | Stair placement between floors |
| **Elevators** | 2 pts | Stairs | Elevator placement |
| **Escalators** | 2 pts | Elevators | Deferred, post-MVP escalator placement |

### Amenities Branch

| Node | Cost | Prerequisites | Unlocks |
|------|------|---------------|---------|
| **Basic Amenities** | Free (start) | None | Trash cans, basic signage |
| **Green Spaces** | 1 pt | None | Plants, small gardens, planters |
| **Water Features** | 2 pts | Green Spaces | Fountains, small pools |
| **Art Installations** | 2 pts | Green Spaces | Sculptures, murals, displays |
| **Rooftop Terrace** | 3 pts | Multi-Floor + Green Spaces | Terrace zones on upper floors |

### Available from Start (No Tech Required)

This legacy full-game UI catalogue means no Tech gate, not that absent sources must be implemented. Current MVP exposes only the panels/metrics in current scope; no viability, history or unsupported heatmap value is fabricated.

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

All listed full-game nodes become affordable. The catalogue surplus (40 - 26 = 14) leaves room for later approved additions:
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
| **District Expansion** | Physical ownership, geometry, and elevation limits are defined in [District Layout & Land Expansion](19_district_layout_land_expansion.md); progression gates access within those limits. |

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

### District Architecture Amendment

- Physical plot caps are separate from tech-tree progression. The canonical physical elevation range is `0 = G`, `+1..+9 = F1..F9`, and `-1..-5 = U1..U5`: 10 above-ground levels including G plus 5 underground. Plot Templates and Block Slot overrides may impose stricter physical limits.
- **Multi-Floor** unlocks `F1` and `F2`: Ground (`G`) is the first building level, so these are the second and third floors. **Underground** unlocks `U1`–`U2` at its existing 3-point cost and prerequisite.
- **Vertical Expansion I/II/III** unlock `F3`–`F5`, `F6`–`F7`, and `F8`–`F9` respectively. Each costs 1 Tech Point and requires both its listed prerequisite node and Mall Level.
- **Deep Foundations** unlocks `U3`–`U5`, costs 1 Tech Point, and requires Underground plus Regional Mall.
- Plot Section acquisition requires a selected/unlocked Plot. Plot Access selections are granted by the Mall Level table above.
- Street Segment conversion is available from **Neighborhood Center** onward, subject to all non-progression District and Economy requirements.
- **Bus Stop** is the sole currently approved non-pedestrian transport capability. It costs 1 Tech Point, requires Basic Corridors and Small Market, and grants eligibility only; placement still requires the separate District road/route/frontage/cap validation.
- All other non-pedestrian transport facilities remain unavailable until a dedicated transport/progression handoff approves them. The corrected catalogue total is 26, with 14 of 40 points unallocated. Bus Stop is eligibility-only and deferred from player-facing MVP spending.
