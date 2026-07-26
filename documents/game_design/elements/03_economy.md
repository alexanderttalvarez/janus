# Economy

## Overview

The economy drives the tension between creative ambition and financial reality. The player needs Kreds to build, but Kreds come from the district performing well. It's a self-reinforcing (or self-destructing) loop.

**Currency:** Kred (singular), Kreds (plural).
**Starting balance:** 500,000 Kreds.

---

## Revenue Streams

| Stream | Description | Frequency |
|--------|-------------|-----------|
| **Rent** | Player-set daily rate per zone (Kreds/tile/day). Collected from each active tenant. | Daily (sim clock) |
| **Parking Fees** | If parking structures are built (post-MVP). | Per visitor visit |
| **Event Income** | Seasonal events, pop-up spaces (post-MVP). | Event-driven |

### Rent Mechanics

The player sets a **daily rent rate per zone** (in Kreds/tile/day). This rate applies to all tenants in that zone. The player has full freedom to set any rate, but consequences follow:

| Rent Level | Consequence |
|------------|-------------|
| **Below market rate** | Tenants are happy, apply quickly. Player leaves money on the table. |
| **At market rate** | Normal application speed. Tenant satisfaction is neutral. |
| **Above market rate** | Fewer applications. Tenants that do apply have lower satisfaction. Risk of closure if revenue doesn't cover rent. |
| **Far above market rate** | No applications. Zone stays vacant. |

#### Market Rate Formula

```
Recommended Rent = Rent Ceiling × Floor Factor × Accessibility Factor × Adjacency Factor
```

| Component | Formula / Values |
|-----------|-----------------|
| **Rent Ceiling** | From prestige tier table ($5–$60/tile/day) |
| **Floor Factor** | Ground (F1) = 1.00. Each floor above ground: +0.05 (max 1.25 at F5+). Each floor below ground: -0.10 (min 0.50 at U5). |
| **Accessibility Factor** | Based on zone circulation score: Poor = 0.70, Average = 0.85, Good = 1.00, Excellent = 1.15 |
| **Adjacency Factor** | Based on synergy with neighboring zones: Negative = 0.80, Neutral = 1.00, Positive = 1.15 |

**Example:** A zone on F2 (1.05) with Good accessibility (1.00) and Positive synergy (1.15) in a Neighborhood Center (ceiling $18):
```
Recommended Rent = 18 × 1.05 × 1.00 × 1.15 = 21.74 Kreds/tile/day
```

The player sees this as the **recommended rate**. They can set any value. Setting above recommended increases tenant dissatisfaction risk. Setting below increases tenant happiness but reduces income.

---

## Expense Streams

### Tile Purchase

One-time cost per tile. Price scales with floor level (above or below ground). Base cost: **1,000 Kreds/tile**.

| Floor | Multiplier | Tile Cost |
|-------|-----------|-----------|
| **Ground (F1)** | 1.0x | 1,000 Kreds |
| **Floor 2 (F2)** | 1.2x | 1,200 Kreds |
| **Floor 3 (F3)** | 1.4x | 1,400 Kreds |
| **Floor 4 (F4)** | 1.6x | 1,600 Kreds |
| **Floor 5+ (F5+)** | 1.8x | 1,800 Kreds |
| **Underground 1 (U1)** | 1.2x | 1,200 Kreds |
| **Underground 2 (U2)** | 1.4x | 1,400 Kreds |
| **Underground 3 (U3)** | 1.6x | 1,600 Kreds |
| **Underground 4 (U4)** | 1.8x | 1,800 Kreds |
| **Underground 5 (U5)** | 2.0x | 2,000 Kreds |

**Maximum floors:** 5 above ground + 5 underground = 11 total levels.

### Construction

One-time cost for placing zones, amenities, and circulation elements. Prices vary by type and are defined in their respective system documents.

### Staff Wages

Flat rate per employee. **500 Kreds/week/employee** (MVP). Post-MVP: wages may scale with prestige.

### Maintenance

Monthly upkeep per tile. Scales with floor level.

| Floor | Maintenance Cost |
|-------|-----------------|
| **F1** | 10 Kreds/tile/month |
| **F2** | 12 Kreds/tile/month |
| **F3** | 14 Kreds/tile/month |
| **F4** | 16 Kreds/tile/month |
| **F5+** | 18 Kreds/tile/month |
| **U1** | 12 Kreds/tile/month |
| **U2** | 14 Kreds/tile/month |
| **U3** | 16 Kreds/tile/month |
| **U4** | 18 Kreds/tile/month |
| **U5** | 20 Kreds/tile/month |

Maintenance increases further as the building degrades (see Maintenance System).

### Transportation Fees

Transportation facilities are physical structures the player builds. They charge a monthly fee to the transportation authority and boost visitor attraction.

| Transport Type | Construction Cost | Monthly Fee | Visitor Attraction Bonus |
|----------------|-------------------|-------------|-------------------------|
| **Bus Stop** | 10,000 Kreds | 200 Kreds/month | +5% visitor volume |
| **Tram Stop** | 30,000 Kreds | 500 Kreds/month | +12% visitor volume |
| **Monorail Stop** | 60,000 Kreds | 800 Kreds/month | +18% visitor volume |
| **Metro Station** | 100,000 Kreds | 1,500 Kreds/month | +25% visitor volume |
| **Train Station** | 250,000 Kreds | 3,000 Kreds/month | +40% visitor volume |

**Design notes:**
- Transportation is a **physical facility** the player builds and maintains (Pillar 1).
- The visitor attraction bonus is a **flat multiplier** on the base visitor spawn rate. It compounds with prestige attraction.
- These are **post-MVP**. The design space is reserved to avoid conflicts with other systems.

### Loan Repayment

The player can access loans at any time. Max **2 active loans** simultaneously.

| Prestige Tier | Max Loan Amount | Monthly Interest Rate |
|---------------|----------------|----------------------|
| **Empty Lot** | 100,000 Kreds | 8% |
| **Local Shop** | 250,000 Kreds | 6% |
| **Neighborhood Center** | 500,000 Kreds | 5% |
| **Regional Mall** | 1,000,000 Kreds | 4% |
| **City Destination** | 2,000,000 Kreds | 3% |
| **Megacity Mall** | 5,000,000 Kreds | 2% |

**Rules:**
- Loans are repaid monthly (principal + interest).
- Early repayment is allowed with no penalty.
- If the player defaults (can't pay), interest compounds on the missed payment.
- Each failed payment extends the loan term by 1 additional month.
- Defaulting on both loans simultaneously triggers a severe financial crisis warning.
- Failed payments apply a **Loan Default Multiplier** to prestige (see Prestige System). The multiplier persists until the entire loan is fully repaid (not just caught up).

---

## The Death Spiral

Bad designs underperform slowly but inevitably:

1. Low visitor attraction → shops earn less
2. Shops can't cover rent → tenant satisfaction drops → shops close
3. Vacant zones generate no rent → revenue falls
4. Expenses (staff, maintenance, loans) continue → net loss
5. Debt grows → loan interest compounds
6. Player can't afford improvements → situation worsens
7. Game warns recovery is unlikely → player chooses to continue or restart

**No hard game over.** The player always has agency to keep trying, but the financial reality makes recovery increasingly difficult.

---

## Design Notes

### Tuning Philosophy

All numerical values are starting calibrations for playtesting. Key targets:
- Starting 500,000 Kreds should fund meaningful early expansion (~200-300 tiles + basic construction)
- Rent income should comfortably cover maintenance + staff in a well-designed district
- Loan interest should be punishing but not instant-death
- Transportation ROI should be achievable but require planning

### Progressive Complexity

MVP economy: Rent, tile purchase, construction, staff wages, maintenance, loans.
Post-MVP additions: Parking fees, event income, prestige-scaled wages, transportation.
