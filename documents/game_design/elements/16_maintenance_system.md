# Maintenance System

> **Status:** Post-MVP. Defined for future implementation. No degradation or repair mechanics in MVP.

## Overview

The Maintenance System governs physical degradation of the building over time and the player's ability to repair it. Neglect leads to visible decay, reduced prestige, and tenant dissatisfaction. Maintenance is handled exclusively through **Maintenance Staff** — there is no recurring tile-based maintenance cost.

---

## Degradation

### Condition Score

Each tile has a **Condition Score** (0–100). Condition decreases at a flat rate over time.

```
Degradation Rate = 0.5 per sim day
```

- All tiles degrade at the same natural pace, regardless of usage or floor level.
- This creates a predictable, manageable maintenance schedule.

### Repair Cost Formula

Repair cost scales with degradation level. Early repair is cheaper; waiting costs more.

```
Repair Cost = Base Cost × (1 + (100 - Condition) / 100) × Floor Multiplier
```

**Base Cost:** 50 Kreds

| Condition | Degradation | Multiplier | F1 Cost | F3 Cost | F5+ Cost |
|-----------|-------------|------------|---------|---------|----------|
| **90** | 10% | 1.10x | 55 | 66 | 90 |
| **60** | 40% | 1.40x | 70 | 84 | 114 |
| **30** | 70% | 1.70x | 85 | 102 | 138 |
| **10** | 90% | 1.90x | 95 | 114 | 153 |

**Design rationale:** The formula creates a ~2x cost difference between early repair (55 Kreds) and critical repair (95 Kreds). The floor multiplier adds verticality pressure. Players are incentivized to maintain regularly rather than wait for decay.

### Floor Multiplier

| Floor | Base Cost Multiplier |
|-------|---------------------|
| **F1** | 1.0x |
| **F2** | 1.2x |
| **F3** | 1.4x |
| **F5+** | 1.8x |
| **U3** | 2.0x |

### Visual Manifestation

Condition is represented through a progressive visual overlay:

| Condition Range | Visual State |
|-----------------|--------------|
| **80–100** | Pristine. Clean surfaces, bright lighting. |
| **50–79** | Worn. Minor scuffs, slightly dim lighting. |
| **20–49** | Damaged. Visible cracks, peeling paint, flickering lights. |
| **0–19** | Critical. Broken fixtures, stains, dark areas. |

---

## Repair System

### Maintenance Staff

- Hired through **Operations Rooms** (same as Cleaners and Security).
- Each Operations Room can host up to 2 Maintenance staff (in addition to 2 Cleaners + 2 Security).
- Wage: 500 Kreds/week/employee (MVP rate, may scale post-MVP).
- Coverage: Floor where Operations Room is placed + 1 floor above + 1 floor below.

### Task Queue (Spatial Clustering)

Maintenance staff use a priority queue that favors spatial efficiency:

```
1. Tile condition drops below repair threshold (e.g., 60)
2. Tile enters repair queue for its floor
3. System finds closest FREE maintenance staff on coverage floors
4. Staff is assigned a CLUSTER of nearby degraded tiles (not just one)
5. Staff pathfinds to the cluster, repairs tiles in sequence, becomes FREE
6. If no free staff: tiles wait in queue, condition continues dropping
```

**Clustering Logic:**
- When a tile enters the queue, the system checks for other degraded tiles within a 5-tile radius.
- These are grouped into a single task cluster.
- The staff member repairs all tiles in the cluster before returning to FREE state.
- This prevents inefficient "jumping" between distant tiles.

### Repair State & Visitor Impact

- When a tile enters repair, its status changes to **"Under Repair"**.
- The tile is **excluded from the visitor pathfinder** immediately.
- Repair duration: **~2–3 sim seconds** (fast, but noticeable).
- Visitors currently pathfinding through the tile are **not recalculated**. They will encounter the blocked tile and naturally re-route or pause briefly before continuing.
- Once repair is complete, the tile returns to normal status and becomes available for pathfinding again.

### Repair Cost

Calculated per tile using the degradation formula above. Cost is deducted from player balance when repair begins.

---

## Impact of Low Condition

| Condition Range | Effect |
|-----------------|--------|
| **80–100** | No penalty. |
| **50–79** | -2 Visitor Experience (Comfort). |
| **20–49** | -5 Comfort, -3 Tenant Satisfaction. |
| **0–19** | -10 Comfort, -8 Tenant Satisfaction, -5 Prestige. |

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Economy** | Repair costs deducted per action. No recurring maintenance cost. |
| **Staff System** | Maintenance staff hired through Operations Rooms. Same wage structure. |
| **Prestige** | Low condition reduces Comfort factor and Prestige. |
| **Visitor Simulation** | Degraded tiles reduce visitor satisfaction and dwell time. |
| **Tenant System** | Low condition reduces Tenant Satisfaction, affecting viability. |

---

## Design Notes

### MVP Scope

No degradation, no repair, no maintenance staff in MVP. This document defines the system for post-MVP implementation.

### Player Mental Model

The player should understand: "Buildings wear down over time, especially in busy areas. I hire maintenance staff to keep things in good shape. Clustering repairs keeps them efficient."

### Tuning Targets

- Degradation rate should be slow enough that neglect takes meaningful time to manifest
- Clustering radius (5 tiles) should balance efficiency with coverage
- Repair cost should be affordable but meaningful enough to encourage preventive hiring
- Condition thresholds should create visible progression without feeling punitive
