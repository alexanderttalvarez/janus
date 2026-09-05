# Economy

## Overview

The economy drives the tension between creative ambition and financial reality. The player needs Kreds to build, but Kreds come from the district performing well. It's a self-reinforcing (or self-destructing) loop.

**Currency:** Kred (singular), Kreds (plural).
**Starting balance:** 500,000 Kreds.

---

## Revenue Streams

| Stream | Description | Frequency |
|--------|-------------|-----------|
| **Rent** | Player-set daily rate per zone (Kreds/tile/day), credited from each active tenant. | Daily (sim clock) |
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

#### Daily settlement

Rent is credited once on every authoritative simulation-day boundary. At 1× speed, one simulation day is 24 real seconds. For an Open tenant, daily rent is the current zone daily rate multiplied by its parcel tile count, rounded down to integer Kreds. No rent is credited during application, exclusivity lock, or construction. The daily rate remains the player-facing and tenant-viability input; it is not converted into a weekly rate or deferred to weekly settlement.

#### Market Rate Formula

```
Unclamped Recommendation = Rent Ceiling × Floor Factor × Accessibility Factor × Adjacency Factor
Recommended Rent = min(Rent Ceiling, Unclamped Recommendation)
```

| Component | Formula / Values |
|-----------|-----------------|
| **Rent Ceiling** | From prestige tier table ($5–$60/tile/day) |
| **Floor Factor** | Ground (G) = 1.00. F1, the first floor above G, = 1.05. Each further floor above ground: +0.05 (max 1.25 at the fifth upper floor and above). Each floor below ground: -0.10 (min 0.50 at U5). |
| **Accessibility Factor** | Based on zone circulation score: Poor = 0.70, Average = 0.85, Good = 1.00, Excellent = 1.15 |
| **Adjacency Factor** | Based on synergy with neighboring zones: Negative = 0.80, Neutral = 1.00, Positive = 1.15 |

**Example:** A zone on F1, the second above-ground level (1.05), with Good accessibility (1.00) and Positive synergy (1.15) in a Neighborhood Center (ceiling $18):
```
Unclamped Recommendation = 18 × 1.05 × 1.00 × 1.15 = 21.74 Kreds/tile/day
Recommended Rent = min(18, 21.74) = 18 Kreds/tile/day
```

The player sees this as the **recommended rate**. A newly created zone initializes its committed daily rate to the currently calculated recommended rate. The player can set any non-negative rate; rate changes take effect for the next application evaluation and next daily settlement only, never retroactively. Setting above recommended increases tenant dissatisfaction risk. Setting below increases tenant happiness but reduces income.

---

## Expense Streams

### Land and Floor-Space Acquisition

Ground land is purchased as atomic Plot Sections. Purchasing a Plot Section grants vertical rights over its mask but does not demolish an existing building. Upper and underground floor space is purchased tile-by-tile and sequentially. Street Segments are purchased and converted as whole units when their layout, frontage, economy, and progression requirements are satisfied. Geometry and eligibility rules are authoritative in [District Layout & Land Expansion](19_district_layout_land_expansion.md).

The approved tile-cost calibrations remain in force. Labels below are reconciled to the canonical elevation scheme: `G`, `F1`–`F9`, and `U1`–`U5`, with a physical maximum of 10 above-ground levels including G plus 5 underground.

| Floor | Multiplier | Tile Cost |
|-------|-----------|-----------|
| **Ground (G)** | 1.0x | 1,000 Kreds |
| **Floor 1 (F1)** | 1.2x | 1,200 Kreds |
| **Floor 2 (F2)** | 1.4x | 1,400 Kreds |
| **Floor 3 (F3)** | 1.6x | 1,600 Kreds |
| **Floor 4 (F4)** | 1.8x | 1,800 Kreds |
| **Floor 5 (F5)** | 2.0x | 2,000 Kreds |
| **Floor 6 (F6)** | 2.2x | 2,200 Kreds |
| **Floor 7 (F7)** | 2.4x | 2,400 Kreds |
| **Floor 8 (F8)** | 2.6x | 2,600 Kreds |
| **Floor 9 (F9)** | 2.8x | 2,800 Kreds |
| **Underground 1 (U1)** | 1.2x | 1,200 Kreds |
| **Underground 2 (U2)** | 1.4x | 1,400 Kreds |
| **Underground 3 (U3)** | 1.6x | 1,600 Kreds |
| **Underground 4 (U4)** | 1.8x | 1,800 Kreds |
| **Underground 5 (U5)** | 2.0x | 2,000 Kreds |

The approved vertical schedule advances by 200 Kreds per elevation step after the initial listed calibration. It fully covers F1–F9 and U1–U5.

### Plot Section Pricing

A Plot Section costs its tile count multiplied by the approved Ground tile cost of **1,000 Kreds**. The purchase grants vertical rights over the section mask but does not include demolition, construction, or a separate vertical-rights surcharge.

### Street Segment Conversion Pricing

A Street Segment conversion costs **3,000 Kreds per tile in the complete Street Corridor** being converted, including both Pedestrian Bands and the carriageway. Conversion is irreversible in MVP and creates no refund.

### Demolition Pricing

An eligible demolition transaction costs a flat **20 Kreds per whole fixed structure**. The transaction addresses one stable fixed-occupant identity across all of its occupied elevations; partial demolition is not supported. Demolition of occupied zone/tenant dependencies remains unavailable in MVP and rejects without charge. Completed demolition creates no refund.

### Tunable Economy Policy

All approved economy values, including the 3,000-Kred Street Corridor tile cost and 20-Kred demolition fee, belong to one centralized economy-policy configuration. They are tunable for playtesting, but runtime transactions consume an immutable captured policy snapshot; no caller, UI, or mutable global variable may alter a value during a transaction.

### Construction

One-time cost for placing zones, amenities, and circulation elements. Prices vary by type and are defined in their respective system documents.

### Transaction and debug policy

Economy is the sole balance authority. Purchases use the approved quote → reserve → guaranteed capture → cancel transaction contract. Prices and progression eligibility are immutable policy inputs; they are not invented by Economy.

A reservation is short-lived transaction state only: it is not saved and creates no committed balance change. Cancelling before capture is free. Completed Street Segment conversion is irreversible in MVP and completed demolition has no refund. Construction-cancellation refunds remain unapproved policy.

When debug cost bypass is active, every player-paid action is free. It still performs normal gameplay validation and commits normally, but its economic quote and captured debit are zero.

### Staff Wages

Flat rate per employee. **500 Kreds/week/employee** (MVP). Post-MVP: wages may scale with prestige.

### Maintenance

Maintenance is handled through the Maintenance System **post-MVP**. There are no recurring maintenance charges, repairs, repair costs, or maintenance staff in MVP.

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
- Elements 05 and 19 newly prioritize pedestrian arrivals followed by buses, parking cars, taxis, and metro. How legacy tram, monorail, and train facilities relate to those arrival modes requires later reconciliation; their approved calibration is retained until then.

### Loan Repayment

The player can access loans at any time. Max **2 active loans** simultaneously.

| Prestige Tier | Max Loan Amount | Monthly Interest Rate |
|---------------|----------------|----------------------|
| **Empty Lot** | 100,000 Kreds | 8% |
| **Small Market** | 250,000 Kreds | 6% |
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
4. Expenses (staff and loans; maintenance post-MVP) continue → net loss
5. Debt grows → loan interest compounds
6. Player can't afford improvements → situation worsens
7. Game warns recovery is unlikely → player chooses to continue or restart

**No hard game over.** The player always has agency to keep trying, but the financial reality makes recovery increasingly difficult.

---

## Design Notes

### Tuning Philosophy

All numerical values are starting calibrations for playtesting. Key targets:
- Starting 500,000 Kreds should fund meaningful early expansion (~200-300 tiles + basic construction)
- Rent income should comfortably cover staff in a well-designed district; maintenance is a future post-MVP cost.
- Loan interest should be punishing but not instant-death
- Transportation ROI should be achievable but require planning

### Progressive Complexity

MVP economy: daily rent, approved tile purchase, approved construction, staff wages, and loans. The MVP Plot's single ground section is initially owned.
Post-MVP additions: maintenance, additional Plot Section acquisition, Street Segment conversion, parking fees, event income, prestige-scaled wages, and transportation.
