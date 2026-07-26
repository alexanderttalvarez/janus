# Prestige System

## Overview

Prestige is the core progression metric in Janus. It represents the district's reputation, desirability, and overall quality. It is the product of two visible components: **Scale** and **Quality**. Prestige drives visitor attraction, tenant desirability, rent ceilings, and mall level advancement.

---

## Core Formula

```
Prestige = Scale (0–100) × Quality (0–100)
```

Maximum baseline prestige: **10,000**. Exceptional design, bonus milestones, or rare prestige features can push it higher.

The formula is intentionally multiplicative: a small perfect district and a huge terrible district both score low. Only a district that is **both large and well-designed** achieves high prestige.

### Loan Default Multiplier

When a player fails to make a loan payment, a multiplier reduces the final prestige calculation:

```
Final Prestige = Scale × Quality × Loan Default Multiplier
```

| Failed Payments (per active loan) | Multiplier |
|-----------------------------------|------------|
| 0 | 1.00 (no penalty) |
| 1 | 0.90 |
| 2 | 0.80 |
| 3 | 0.70 |
| 4 | 0.60 |
| 5+ | 0.50 (minimum) |

**Rules:**
- The multiplier is calculated per loan. If multiple loans have defaults, the **lowest multiplier** applies (they do not stack).
- The multiplier resets to 1.00 **only when the entire loan is fully repaid** (not just caught up on payments).
- The HUD shows the current multiplier when it's below 1.00: `⚠ Loan Default: ×0.80`

---

## Scale

Scale measures the physical size of the **developed** district.

| Property | Value |
|----------|-------|
| **Per-tile contribution** | 0.25 Scale points |
| **Scale cap** | 100 (requires 400 developed tiles) |
| **What counts** | Tiles with a zone, tenant, or amenity placed on them |
| **What doesn't count** | Empty purchased land, undeveloped plots |

**Design rationale:** Empty land contributes zero to Scale. This creates meaningful tension: buying land is an investment that only pays off when developed. It forces the player to think before expanding and prevents "land hoarding" as a strategy.

**Scale breakdown (UI):**
- Active tiles: X / 400
- Buildings: X
- Floors: X
- Current Scale: XX / 100

**Scale changes:**
- **Increases** when a zone, tenant, or amenity is placed on an empty tile
- **Decreases** when a built tile is sold or demolished
- **Does not change** when purchasing empty land

---

## Quality

Quality measures how well the district functions and looks. It is composed of six weighted factors.

| Factor | Max Contribution | Weight | What Drives It Up | What Drives It Down |
|--------|-----------------|--------|-------------------|---------------------|
| **Tenant Quality** | 25 | 25% | Higher-tier tenants (premium brands, specialty shops) | Tenants close, downgrade, or are replaced by low-tier |
| **Tenant Satisfaction** | 20 | 20% | Strong foot traffic, revenue exceeds costs, good working conditions | Poor sales, long customer wait times, understaffing |
| **Visitor Volume** | 15 | 15% | High daily visitor count, consistent flow | Empty corridors, low attraction, seasonal dips |
| **Visitor Experience** | 15 | 15% | Clean floors, good amenity variety, short queues, pleasant atmosphere | Dirty surfaces, broken facilities, long waits, poor lighting |
| **Design & Architecture** | 15 | 15% | Atriums, gardens, art installations, cohesive zone layouts, visual harmony | Mismatched adjacencies, cluttered corridors, removed prestige features |
| **Accessibility** | 10 | 10% | Elevator coverage, escalator reach, clear sightlines, no dead-ends | Poor vertical connectivity, bottlenecked corridors, unreachable floors |

**Quality minimum:** 20. Even a poorly designed district has a baseline floor representing "the building exists and is functional."

**Quality breakdown (UI):**
- Each factor shows its current value, max value, and trend (▲/▼/◆)
- Total Quality: XX / 100

---

## Prestige Tiers

Prestige values map to named tiers. Each tier provides mechanical benefits. Within each tier, effects scale smoothly — there are no sudden jumps at thresholds.

| Tier | Prestige Range | Visitor Attraction (spawn multiplier) | Tenant Tier Access | Rent Ceiling ($/tile/day) |
|------|---------------|--------------------------------------|-------------------|--------------------------|
| **Empty Lot** | 0–500 | 0.5x | Tier 1 (basic) | $5 |
| **Local Shop** | 501–1,500 | 1.0x | Tiers 1–2 | $10 |
| **Neighborhood Center** | 1,501–3,500 | 1.5x | Tiers 1–3 | $18 |
| **Regional Mall** | 3,501–6,500 | 2.0x | Tiers 1–4 | $30 |
| **City Destination** | 6,501–9,000 | 2.5x | Tiers 1–5 | $45 |
| **Megacity Mall** | 9,001–10,000+ | 3.0x | Tiers 1–5 + Exclusive | $60 |

### Hybrid Threshold/Multiplier Behavior

- **Within a tier:** Visitor attraction scales linearly with prestige. Going from 1,600 to 2,000 prestige gives a smooth, continuous increase in visitors.
- **At a threshold:** Crossing into a new tier unlocks new tenant tiers and raises the rent ceiling. These are the milestone moments the player works toward.
- **UI display:** The current tier is always visible. Progress to the next tier is shown as a bar or percentage (e.g., "Neighborhood Center — 62% to Regional Mall").

---

## Calculation Frequency

| Calculation | Frequency | Sim Time | Real Time (1x) | Purpose |
|-------------|-----------|----------|----------------|---------|
| **Full Prestige** | Every 30 sim days (1 in-game month) | 30 days | ~12 minutes | Official value used for tenant gating, rent ceilings, milestone checks |
| **Trend Indicator** | Every 1 sim day | 1 day | 24 seconds | Live ▲/▼/◆ indicator in HUD showing direction of change |

**Design rationale:** Full recalculation is expensive (averages across all tenants, visitors, tiles, etc.). Monthly calculation keeps CPU usage manageable while keeping the game responsive. The daily trend indicator bridges the gap — the player sees immediate feedback without constant heavy computation.

**Trend indicator logic:**
- ▲: Current estimated quality > last official prestige
- ▼: Current estimated quality < last official prestige
- ◆: Within ±2% of last official prestige

---

## Prestige Display

### HUD (Always Visible)
```
★ Prestige: 2,850
  Scale: 42  |  Quality: 68
  [Neighborhood Center — 62% to Regional Mall]
```

### Prestige Panel (Toggleable)
- Breakdown of Scale: active tiles, buildings, floors
- Breakdown of Quality: all six factors with values and trends
- History graph: prestige over time (last 30/60/90 days)
- Tier progress bar

### Contextual Feedback
- When placing a prestige-generating feature (garden, fountain, atrium): "+X Quality preview"
- When selling a built tile: "-Y Scale warning"
- When a tenant applies that would raise Tenant Quality: "Premium tenant — +Z Quality"

---

## Design Notes

### Progression Guard
The multiplicative formula (Scale × Quality) prevents speedrunning. A player cannot max prestige by building a tiny perfect district. They must grow (Scale) AND optimize (Quality). This forces long-term engagement.

### Quality Drop on Expansion
When a player adds new space without supporting infrastructure (circulation, staff, amenities), Quality will dip. This is intentional — it teaches the player to build thoughtfully, not just broadly. The trend indicator warns them before the next official recalculation.

### Tuning Philosophy
All numerical values (per-tile Scale, factor weights, tier thresholds, rent ceilings, visitor multipliers) are starting calibrations. They will be adjusted during playtesting to ensure:
- Tier transitions feel earned but achievable
- The death spiral is slow enough to recover from
- The progression curve matches session length expectations
- Scale cap (100) aligns with target district size at endgame
