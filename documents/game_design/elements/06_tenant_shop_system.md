# Tenant / Shop System

## Overview

Tenants are the businesses that populate the player's zones. The player does not manage individual tenants — they create attractive conditions and tenants respond automatically. The system is built on transparency: tenants apply, operate, succeed, or fail based on visible, calculable factors.

**Design principle:** Spaces over stores. The player designs zones. The game fills them. Tenants are an emergent result of good design, not a management task.

---

## Tenant Tiers

Tenants are organized into 5 tiers representing brand prestige and market position.

| Tier | Name | Description | Prestige Contribution |
|------|------|-------------|----------------------|
| **Tier 1** | Basic | Local shops, independent businesses | Low |
| **Tier 2** | Standard | Regional chains, established brands | Medium |
| **Tier 3** | Premium | National chains, recognizable brands | High |
| **Tier 4** | Luxury | High-end boutiques, specialty stores | Very High |
| **Tier 5** | Exclusive | Flagship stores, unique destinations | Exceptional |

### Tier Progression (Post-MVP)

Tenants can only **upgrade** — never downgrade. If a tenant cannot maintain its tier, it closes and the space becomes vacant.

```
Tier 1 → Tier 2 → Tier 3 → Tier 4 → Tier 5 (upgrade path)
       ↓
    Close (if can't maintain)
```

Upgrade conditions (post-MVP):
- Tenant revenue exceeds target for X consecutive check periods
- District prestige supports the next tier
- Zone conditions remain favorable

---

## Application System

Tenants apply automatically to vacant zones. The player has no direct control over which tenants apply — only over the conditions that attract them.

### Evaluation Trigger

- **First evaluation:** 1 sim day after zone becomes vacant
- **Subsequent evaluations:** Every 3 sim days until filled

Each evaluation generates a random tenant candidate matching the zone type. The candidate has a **Selectivity** attribute (-10 to +20) that modifies their application threshold.

### Application Score Formula

```
Score = Prestige Match + Rent Attractiveness + Location Score + Synergy Bonus + Competition Penalty
```

| Component | Min | Max | Description |
|-----------|-----|-----|-------------|
| **Prestige Match** | -50 | 100 | Does district prestige support this tenant tier? |
| **Rent Attractiveness** | -20 | 30 | Is rent reasonable for the zone? |
| **Location Score** | 0 | 50 | Floor level and circulation quality |
| **Synergy Bonus** | -10 | 20 | Adjacency with complementary/clashing zones |
| **Competition Penalty** | -20 | 0 | Similar zone types nearby |
| **Total** | **-100** | **200** | |

#### Prestige Match

| Condition | Score |
|-----------|-------|
| District prestige supports tenant tier | +100 |
| District prestige one tier below tenant | -50 |
| District prestige two+ tiers below | Won't apply |
| District prestige above tenant tier | +100 (happy to be here) |

#### Rent Attractiveness

| Rent vs Recommended | Score |
|---------------------|-------|
| Rent ≤ Recommended | +30 |
| +1% to +10% above | +20 |
| +11% to +20% above | +10 |
| +21% to +30% above | 0 |
| >+30% above | -20 (won't apply) |

#### Location Score

```
Location Score = max(0, 50 - (4 - elevator_bonus - stairs_bonus) × floor_distance)
```

Where:
- `elevator_bonus = 1` if elevator present on floor, `0` otherwise
- `stairs_bonus = 1` if stairs present on floor, `0` otherwise
- `floor_distance = abs(floor_level - 1)` (Ground = 0 distance)

| Floor | Circulation | Score |
|-------|-------------|-------|
| F1 (Ground) | Any | 50 |
| F2 | Nothing | 46 |
| F2 | Both | 48 |
| F3 | Nothing | 42 |
| F3 | Both | 44 |
| F5 | Nothing | 34 |

#### Synergy Bonus

| Condition | Score |
|-----------|-------|
| Complementary adjacent zones (e.g., Food near Entertainment) | +20 |
| Neutral adjacency | 0 |
| Clashing adjacency (e.g., noisy Entertainment near Services) | -10 |

#### Competition Penalty

| Condition | Penalty |
|-----------|---------|
| Same zone type within 10 tiles | -20 |
| Same zone type within 20 tiles | -10 |
| Same zone type > 20 tiles or none | 0 |

### Application Threshold

```
Threshold = 80 + (Tier - 1) × 10 + Selectivity
```

| Tier | Base Threshold |
|------|----------------|
| **Tier 1** | 80 |
| **Tier 2** | 90 |
| **Tier 3** | 100 |
| **Tier 4** | 110 |
| **Tier 5** | 120 |

**Selectivity:** Random value from -10 to +20 per candidate tenant.
- -10 (flexible/desperate): Lowers threshold
- +20 (picky/exclusive): Raises threshold

**Application Decision:**
```
If Score ≥ Threshold → Tenant applies → 1-week exclusivity lock → Construction begins
If Score < Threshold → No application → Wait 3 sim days → Next candidate
```

---

## Tenant Lifecycle

```
Vacant Zone → Application → Exclusivity Lock (1 week) → Construction → Open → Operate → [Upgrade / Close]
```

### Construction

- Duration: `0.3 sim weeks × tile count`
- Visual phases: 3 stages (0-33%, 34-66%, 67-100%)
- During construction: no revenue, no visitors

### Opening

- Tenant becomes operational
- Starts generating revenue from visitors
- First viability check scheduled for `Check Period` sim days after opening

### Operation

- Tenant serves visitors, generates revenue
- Viability checked periodically (see below)
- Player can view financials and status at any time

### Closure

A tenant closes when:
1. **Financial failure:** Revenue < (Rent + Profit Margin) for 3 consecutive check periods
2. **Player eviction:** Player demolishes or re-zones the tenant's space

**Eviction consequences:**
- 1-week exclusivity lock on affected parcels
- Tenant leaves immediately
- Zone becomes vacant

---

## Viability System

### Check Period

```
Check Period = min(35, 15 + (Tier × 2) + (Tile Count × 0.5))
```

| Example | Calculation | Check Period |
|---------|-------------|--------------|
| Tier 1, 6 tiles | 15 + 2 + 3 = 20 | **20 sim days** |
| Tier 3, 20 tiles | 15 + 6 + 10 = 31 | **31 sim days** |
| Tier 5, 40 tiles | 15 + 10 + 20 = 45 → capped | **35 sim days** |

Checks are staggered by opening date to prevent mass closures.

### Viability Calculation

```
Viability = Revenue - (Rent + Profit Margin)
```

Where:
- **Revenue:** Σ(visitor spending) over the check period
- **Rent:** Daily rent rate × tiles × check period days
- **Profit Margin:** Rent × (5% to 20%) — unique per tenant, fixed at application

### Warning Stages

| Stage | Condition | Visual Indicator |
|-------|-----------|------------------|
| **Healthy** | Revenue ≥ Rent + Margin | Normal operation, green indicator |
| **Concerned** | Revenue < Rent + Margin (1st period) | "⚠ Revenue below target" |
| **Critical** | Revenue < Rent + Margin (2nd period) | "⚠ Risk of closure" |
| **Closing** | Revenue < Rent + Margin (3rd period) | "Closing soon" notice |

After the 3rd consecutive failed check, the tenant closes and the space becomes vacant.

### Grace Period

Tenants get **3 consecutive check periods** of failure before closing. This gives them time to recover from temporary setbacks (seasonal dips, construction nearby, etc.).

---

## Revenue Model

### Visitor Spending

Each visitor who enters a business spends based on:

```
Spending = min(Visitor Budget, Business Price × Quantity)
```

Where:
- **Visitor Budget:** Primary or Secondary budget (see Visitor Simulation)
- **Business Price:** Set by tenant AI based on rent pressure
- **Quantity:** Number of items/services purchased per visit

### Business Pricing

```
Business Price = Recommended Price × (1 + Rent Pressure)
```

Where `Rent Pressure = (Actual Rent - Recommended Rent) / Recommended Rent`

If rent is at recommended → Prices = Recommended
If rent is 20% above recommended → Prices = 1.2x Recommended

### Revenue Collection

- Revenue is calculated per visitor visit, accumulated daily
- Player receives rent daily (regardless of tenant revenue)
- Tenant revenue is tracked for viability checks

---

## Tenant Financials (Player View)

The player can view each tenant's financial status:

| Metric | Description |
|--------|-------------|
| **Revenue** | Σ(visitor spending) over last check period |
| **Rent** | Daily rent rate × tiles × check period days |
| **Profit Margin** | 5–20% of rent (unique per tenant) |
| **Viability** | Revenue vs (Rent + Margin). Green/Yellow/Red indicator |
| **Status** | Healthy → Concerned → Critical → Closing |
| **Selectivity** | The tenant's application threshold modifier (-10 to +20) |

**Expenses = Rent only.** Tenants have no other costs (staff, utilities, maintenance are handled by the player's economy system).

---

## Player Feedback

The player does not manage tenants directly. Feedback comes through:

| Indicator | What It Shows | Player Action |
|-----------|---------------|---------------|
| **Zone Viability Meter** | Green/Yellow/Red based on application score | Adjust rent, improve circulation, add prestige features |
| **Vacant Zone Timer** | "Next evaluation: X sim days" | Wait, or adjust conditions before next evaluation |
| **Notification** | "A Tier 2 tenant is moving into Zone A!" | Observe, prepare supporting infrastructure |
| **Warning** | "Zone X has had no interest for 2 weeks" | Investigate: rent too high? poor accessibility? low prestige? |
| **Tenant Status** | Healthy/Concerned/Critical/Closing indicators | Adjust rent, improve zone conditions, or accept closure |

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Economy** | Tenant revenue → rent payment → player income. Rent pressure → business pricing → visitor spending |
| **Visitor Simulation** | Tenant quality affects visitor satisfaction and spending. Visitor budgets drive tenant revenue |
| **Prestige** | Tenant quality and satisfaction are major prestige factors (Tenant Quality 25%, Tenant Satisfaction 20%) |
| **Staff System** | Insecurity and Cleanliness scores affect Tenant Satisfaction. Poor conditions reduce tenant viability. |
| **Zone Design** | Tenant subtypes, parcel sizes, graph coloring constraints. Zone type determines which tenants can apply |
| **Metrics & Visualization** | Tenant status indicators, viability warnings, financial reports |

---

## Design Notes

### Player Mental Model

The player should understand: "I create attractive spaces. Tenants respond to the conditions I set. Their success or failure tells me if my design is working."

### Tuning Targets

- Application thresholds should make Tier 1 tenants accessible early game, Tier 5 tenants aspirational late game
- Viability check periods should give tenants enough time to prove themselves without letting failures drag on
- Rent pressure → pricing → visitor spending chain should be transparent and tunable
- The 3-period grace period should allow recovery from temporary setbacks
- Competition penalty should encourage spreading similar businesses across the district
