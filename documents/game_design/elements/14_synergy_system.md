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
- Distance is measured **boundary-to-boundary** (shortest distance between any tile of zone A and any tile of zone B).
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
| Complementary | +15 |
| Neutral | 0 |
| Cannibalization | -5 |
| Conflicting | -10 |

### Prestige

Synergy contributes to the **Synergy Score** quality factor in the Prestige System:

- Maximum contribution: **15 points** (out of 100 Quality)
- Calculated as the average synergy across all zones
- Zones with positive synergy raise the district average; zones with negative synergy lower it

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
| **Prestige System** | Synergy Score quality factor (max 15/100 Quality) |
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
