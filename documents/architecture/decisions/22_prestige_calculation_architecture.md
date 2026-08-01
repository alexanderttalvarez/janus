## Decision 22: Prestige Calculation Architecture — Aggregator with Snapshot Queries
**Date:** 2026-07-28
**Status:** Accepted

### Context
Prestige is the core progression metric (Scale × Quality). It drives Mall Levels, tech points, and visitor attraction. We needed to decide on calculation ownership, factor computation, and trend tracking.

### Decision
- **PrestigeManager aggregates** — queries systems for current state, computes scores
- **Quality factors are snapshots** — no state tracking, just current values
- **Trend indicator** — daily lightweight estimate vs. last official recalculation
- **Loan multiplier** — applied at recalculation time, not stored
- **Mall Level advancement** — triggered by tier change during recalculation

### PrestigeManager Structure
```
PrestigeManager (Node, child of main_game.tscn)
├── scale: int
├── quality: int
├── prestige: int
├── tier: String
├── trend: String  # ▲, ▼, ◆
├── last_recalculation_day: int
├── recalculate()  ← Full recalculation (monthly)
├── update_trend()  ← Daily trend check
├── _calculate_scale() → int
├── _calculate_quality() → int
│   ├── _calc_tenant_quality() → float
│   ├── _calc_tenant_satisfaction() → float
│   ├── _calc_visitor_volume() → float
│   ├── _calc_visitor_experience() → float
│   ├── _calc_design_architecture() → float
│   └── _calc_accessibility() → float
├── _get_loan_multiplier() → float
├── _get_tier(prestige) → String
└── Signals:
    ├── prestige_recalculated(prestige, scale, quality)
    └── tier_changed(new_tier)
```

### Calculation Flow
```
Sim month passed → PrestigeManager.recalculate()
    → Queries all systems for current state
    → Computes Scale and Quality
    → Applies loan multiplier
    → Emits prestige_recalculated
    → Checks for tier change → emits tier_changed → TechTreeManager earns points

Sim day passed → PrestigeManager.update_trend()
    → Lightweight Quality estimate
    → Compares to last official Quality
    → Updates trend indicator (▲/▼/◆)
```

### Rationale
- Prestige is inherently cross-system — a central aggregator is the cleanest approach
- Snapshot queries avoid complex state synchronization between systems
- Trend indicator provides daily feedback without expensive full recalculation
- Loan multiplier is applied at calculation time to ensure accuracy

### Consequences
- PrestigeManager needs references to GridManager, TenantManager, VisitorManager, StaffManager, SynergyManager
- Quality factors must be carefully tuned to balance each other
- Trend threshold is ±2% of last official Quality
