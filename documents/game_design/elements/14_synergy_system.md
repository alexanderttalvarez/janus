# Synergy System

## Overview

Synergy rewards thoughtful zone placement. When complementary zone types are near each other, both benefit. When conflicting types are adjacent, both suffer. When identical types are too close, they cannibalize each other's visitor base. This creates interesting spatial decisions and encourages the player to design cohesive, diverse commercial environments.

**Design principle:** Synergy is a spatial puzzle. The player learns through observation and feedback which zone combinations work well together and which compete or conflict.

---

## Synergy Types

| Type | Value | Description |
|------|-------|-------------|
| **Complementary** | +5 | Zones that naturally benefit each other (e.g., Food + Entertainment) |
| **Neutral** | 0 | No significant interaction (e.g., Retail + Services) |
| **Cannibalization** | -3 | Same zone type within range. Competes for the same visitor base. |
| **Conflicting** | -5 | Zones that detract from each other (e.g., noisy Entertainment + quiet Services) |

---

## Synergy Matrix

| Zone Type | Retail | Food & Beverage | Entertainment | Services | Anchor |
|-----------|--------|-----------------|---------------|----------|--------|
| **Retail** | Cannibalization | Complementary | Complementary | Neutral | Neutral |
| **Food & Beverage** | Complementary | Cannibalization | Complementary | Neutral | Complementary |
| **Entertainment** | Complementary | Complementary | Cannibalization | Conflicting | Complementary |
| **Services** | Neutral | Neutral | Conflicting | Cannibalization | Neutral |
| **Anchor** | Neutral | Complementary | Complementary | Neutral | Cannibalization |

---

## Range & Calculation

### Proximity Range

- Synergy is calculated for zones within **5 tiles** of each other.
- Distance is same-floor Manhattan **boundary gap** in canonical district tile coordinates: minimize `max(abs(ax-bx) + abs(ay-by) - 1, 0)` over occupied cells in the two zone footprints. Edge-adjacent cells have distance 0; diagonal-only cells distance 1. Compare only equal signed elevations, including distinct Plots translated through the district grid. No cross-floor synergy or competition applies. This 2026-09-08 default avoids an unrequired 3D influence simulation.
- Zones beyond 5 tiles have no synergy interaction.

### Zone Synergy Score

```
Zone Synergy = Σ(all zone relationships within 5-tile range)
```

| Example | Calculation | Score |
|---------|-------------|-------|
| Food zone next to Entertainment (+5) + Retail (+5) | +5 + +5 | +10 |
| Services zone next to Entertainment (-5) | -5 | -5 |
| Retail zone next to another Retail zone (-3) | -3 | -3 |
| Anchor next to Food (+5) + Entertainment (+5) + Retail (0) | +5 + +5 + 0 | +10 |

---

## Gameplay Effects

### Application Score

Synergy affects whether tenants apply to a zone (see Tenant / Shop System):

| Relationship | Application Score Impact |
|--------------|-------------------------|
| Complementary | +20 |
| Neutral | 0 |
| Conflicting | -10 |

For tenant application evaluation, same-zone-type effects are represented exclusively by the separate Competition Penalty distance bands. The evaluator considers other zones within 5 boundary-to-boundary tiles and uses the relationship with the greatest absolute application impact; ties resolve toward the negative impact, then canonical stable zone ID. It does not sum relationship impacts for this bounded application component. The base Synergy Score and future revenue modifiers remain separate systems.

### Prestige

There is no seventh "Synergy Score" Quality factor. Element 02's six factors already total 100. Cohesive zone layout may be a future input to its existing Design & Architecture factor, not an extra 15 points. Current fixed Quality 20 has no synergy effect; application synergy remains active independently. This resolves the duplicated quality budget without adding a calculation system.

### Tenant Revenue

Synergy affects tenant revenue:

| Relationship | Revenue Modifier |
|--------------|------------------|
| Complementary | +3% |
| Neutral | 0% |
| Cannibalization | -1% |
| Conflicting | -2% |

Modifiers stack if a zone has multiple synergistic adjacencies.

---

## Visualization (Post-MVP)

Synergy visualization is planned for post-MVP and will include:

- **Synergy heatmap:** Green for positive, red for negative, gray for neutral
- **Zone inspector:** Shows all synergy relationships for a selected zone
- **Placement preview:** Shows expected synergy bonus/penalty before placing a zone

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Tenant System** | Application Score bonus/penalty affects tenant attraction |
| **Prestige System** | No current effect; future layout input within existing Design & Architecture budget |
| **Economy** | Tenant revenue modifier affects overall district income |
| **Zone Design** | Encourages thoughtful zone placement and diversity |
| **Metrics & Visualization** | Heatmap and inspector tools (post-MVP) |

---

## Design Notes

### Player Mental Model

The player should understand: "Similar zones compete. Complementary zones help each other. Conflicting zones hurt each other. Good design balances variety and cohesion."

### Tuning Targets

- Cannibalization penalty (-3) should discourage redundant zones without punishing large single zones
- Complementary bonus (+5) should make diverse layouts noticeably more attractive to tenants
- Conflicting penalty (-5) should strongly discourage poor adjacency choices
- The 5-tile range should feel intuitive: close enough to matter, far enough to allow strategic spacing
