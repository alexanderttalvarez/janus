# Visitor Simulation

## Overview

Visitors are the lifeblood of the district. Every visible visitor is an individual agent with their own objectives, preferences, and decision-making process. The simulation follows a **"What You See Is What Is Simulated"** philosophy: statistics reflect the actual population present, and crowd behavior emerges from independent decisions rather than scripted patterns.

Visitors only exist while inside the mall. Once they leave, they are removed from the simulation. The game models activity within the district, not the lives of citizens outside it.

---

## Visitor Lifecycle

Every visitor progresses through a continuous loop during their stay:

```
Enter → Set Goals → [Goal Pursuit / Need Satisfaction / Exploration] → React → Leave
```

1. **Enter:** Visitor arrives at the mall through an entrance point (main entrance, transportation facility, pedestrian walkway)
2. **Set Goals:** Visitor assesses available zone types and sets 1–3 goals
3. **Continuous Loop:**
   - Pursue active goal
   - Satisfy emerging state needs
   - Explore and respond to attractive storefronts
   - Make purchases from primary or secondary budget
4. **React:** Visitor's satisfaction is calculated based on goals fulfilled and overall experience
5. **Leave:** Visitor exits the mall (budget depleted, goals completed, or satisfaction too low)

The path is not predetermined. Visitors continuously reassess based on their goals, needs, and mall state.

---

## Individual Attributes

### Goals (1–3 per visitor)

Visitors spawn with 1 to 3 goals. Goals are **always reachable by definition** — the generator only assigns goals that match existing zone types in the district.

| Goal | Description | What They Look For |
|------|-------------|-------------------|
| **Shopping** | Buy items from retail stores | Retail zones, specific subtypes (fashion, electronics, etc.) |
| **Dining** | Eat a meal or grab a snack | Food & Beverage zones |
| **Services** | Get something done (haircut, bank, repair) | Service zones |
| **Entertainment** | Have fun (cinema, arcade, bowling) | Entertainment zones |
| **Browsing** | Walk around, no specific purchase intent | Anything attractive, follows visual cues |

**Goal count distribution:**
- 1 goal: 40% of visitors
- 2 goals: 45% of visitors
- 3 goals: 15% of visitors

### Dual Budget System

Visitors have two separate budgets:

| Budget | Purpose | Calculation |
|--------|---------|-------------|
| **Primary Budget** | Goal fulfillment only | Σ(Recommended Price per goal) × Willingness to Pay (100%+) |
| **Secondary Budget** | Impulse purchases, exploration | Scaled by Exploration Tendency (see below) |

**Willingness to Pay:** Always ≥ 100%. Some visitors will pay more than recommended (110%, 130%, 150%), but never less. This represents visitors who value quality, prestige, or convenience.

**Primary Budget rules:**
- Reserved exclusively for fulfilling the visitor's stated goals
- Cannot be spent on non-goal items
- If a goal cannot be fulfilled (business closed, unreachable), this budget remains unspent
- Unspent primary budget at exit = negative satisfaction impact

**Secondary Budget rules:**
- Used for impulse purchases, spontaneous decisions, and exploration
- Can be spent on any business the visitor finds attractive
- Unspent secondary budget at exit = neutral (no penalty)
- Spent on matching preferred subtypes = positive satisfaction bonus

### Exploration Tendency & Secondary Budget

| Exploration Tendency | Secondary Budget (% of Primary) | Behavior |
|---------------------|--------------------------------|----------|
| **Low** | 0–20% | Focused, goal-oriented. Rarely deviates from path. |
| **Medium** | 20–40% | Balanced. Open to distractions if storefront is attractive. |
| **High** | 40–80% | Wanderer. Frequently stops to browse, high impulse spending. |

### State Needs

Each visitor tracks state needs on a 0–100 scale. Needs decrease by 1 point per visitor tick (5 sim minutes).

| Need | Description | Default Spawn Range | Goal Exception |
|------|-------------|---------------------|----------------|
| **Hunger** | Desire for food | 40–100 | If Dining goal: starts at 30 |
| **Thirst** | Desire for drinks | 40–100 | If Dining goal (cafe): starts at 30 |
| **Fatigue** | Tiredness from walking/exertion | 40–100 | — |
| **Bathroom** | Need for restroom | 40–100 | — |

**Threshold:** When a need reaches 30 or below, the visitor attempts to satisfy it before continuing with their goals. Upon satisfaction, the need resets to 80–100.

### Other Attributes

| Attribute | Description | Range |
|-----------|-------------|-------|
| **Patience** | Maximum queue position willing to accept | 3–20 people |
| **Willingness to Pay** | Maximum price multiplier for goal items | 100%–150% |
| **Preferred Subtypes** | Specific business types within goal categories | Weighted preferences (e.g., 60% Fashion, 30% Electronics, 10% Home Goods) |

---

## Decision Loop

```
While visitor is in mall:
  1. Check: Is a State Need ≤ 30?
     YES → Find nearest facility that satisfies the need
           Navigate to it, satisfy need (reset to 80-100)
           Spend from Primary Budget (if need matches a goal) or Secondary Budget
  2. Check: Is there an attractive storefront nearby?
     YES → Roll against Exploration Tendency
           PASS → Stop, browse, possibly impulse buy (spends Secondary Budget)
                  If item matches Preferred Subtypes → +satisfaction bonus
           FAIL → Continue to current goal
  3. Check: Is current goal reachable?
     YES → Navigate to business
           If queue_position ≤ Patience → Join queue, purchase, mark progress
           If queue_position > Patience → Leave queue, find alternative or drop goal
     NO  → Drop goal, pick next goal, or leave
  4. Check: Primary Budget = 0 OR all goals fulfilled OR satisfaction too low?
     YES → Leave
```

### Storefront Attractiveness

A visitor stops at a storefront if:
- It matches one of their **Preferred Subtypes** (even if not a current goal)
- Its **Attractiveness Score** exceeds their **Exploration Threshold**
- Attractiveness = function of storefront design, prestige, window displays, queue length, signage

### Purchase Decision

```
If Business Price ≤ Visitor's Willingness to Pay × Recommended Price:
  Purchase → Spend Primary Budget (if goal match) or Secondary Budget (if impulse)
  Update satisfaction based on price fairness and experience
Else:
  No purchase → Visitor may try a cheaper alternative or abandon goal
```

---

## Visitor Generation

### Spawn Rate Formula

```
Spawn Rate = Base Rate × Prestige Multiplier × Transportation Bonus × Seasonal Modifier × Time-of-Day Modifier
```

| Component | Description |
|-----------|-------------|
| **Base Rate** | Game constant (e.g., 5 visitors/sim minute at 1x) |
| **Prestige Multiplier** | From prestige tier table (0.5x to 3.0x) |
| **Transportation Bonus** | From transportation facilities (+5% to +40%) |
| **Seasonal Modifier** | Season-dependent (e.g., summer = 1.2x, winter = 0.8x) |
| **Time-of-Day Modifier** | From visual clock (morning = 0.6x, lunch = 1.5x, evening = 1.3x, night = 0.3x) |

### Goal Distribution

The visitor generator assigns goals weighted by zone type availability:

| Mall Composition | Visitor Goal Distribution |
|------------------|---------------------------|
| **Mostly Food & Beverage** | 70% Dining, 20% Browsing, 10% Shopping |
| **Mostly Retail** | 70% Shopping, 20% Browsing, 10% Dining |
| **Mixed (balanced)** | 30% Shopping, 25% Dining, 20% Browsing, 15% Services, 10% Entertainment |
| **Entertainment-focused** | 50% Entertainment, 30% Dining, 20% Browsing |

### Entry Points

Visitors enter the mall through:
- Main entrances (ground floor)
- Transportation facilities (bus stops, metro stations, etc.)
- Pedestrian walkways (sidewalk access from surrounding neighborhood)
- Skybridges or building connections (post-MVP)

---

## Satisfaction Calculation

### Individual Satisfaction

Satisfaction is calculated when the visitor leaves:

```
Satisfaction = Base (50) + Goal Fulfillment + Experience Modifiers + Exploration Bonus
```

| Factor | Impact |
|--------|--------|
| **All primary goals fulfilled** | +30 to +50 |
| **Some primary goals fulfilled** | +10 to +25 |
| **No primary goals fulfilled** | -20 to -30 |
| **Primary budget unspent (goals failed)** | -10 to -20 |
| **Secondary budget spent on preferred subtypes** | +5 to +15 |
| **Secondary budget wasted (no interesting finds)** | -5 to 0 |
| **Short wait times** | +5 to +15 |
| **Long wait times** | -5 to -20 |
| **Fair prices** | +5 to +10 |
| **Expensive prices** | -5 to -15 |
| **Clean, comfortable environment** | +5 to +15 |
| **Dirty, uncomfortable environment** | -5 to -15 |
| **Easy navigation** | +5 to +10 |
| **Confusing layout, dead ends** | -5 to -10 |

Satisfaction range: 0–100.

### Aggregate Satisfaction

The district's **Visitor Experience** quality factor (see Prestige System) is calculated from the average satisfaction of all visitors over the past sim week.

### Long-Term Attractiveness

- Visitors with satisfaction ≥ 70 contribute positively to long-term attractiveness
- Visitors with satisfaction ≤ 30 contribute negatively
- This creates a feedback loop: good design → happy visitors → higher prestige → more visitors

---

## Movement & Navigation

### Pathfinding

- **MVP:** Shortest path algorithm (A* on the tile grid)
- Visitors navigate from their current position to their target business
- Paths use building corridors, transit tiles, elevators, escalators, and stairs
- Pathfinding recalculates when the visitor changes destination or encounters congestion

### Queue Mechanics

- Each business has a maximum capacity (based on tile count)
- Queue capacity: **3 visitors per tile** at the business entrance
- Visitors join a queue if capacity is reached
- Queue patience: visitor's Patience attribute (3–20 people they're willing to wait behind)
- If queue position exceeds patience, visitor leaves the queue and makes a new decision

---

## Thought Bubbles

### On-Screen Display

- 3 random on-screen visitors show thought bubbles at any time
- Bubbles rotate every ~5 seconds to different visitors
- Bubbles reflect the visitor's current active goal or state need

| Bubble | Meaning |
|--------|---------|
| "I need new shoes" | Primary Goal: Shopping (Fashion) |
| "I'm hungry!" | State Need: Hunger (interrupting primary goal) |
| "That restaurant looks good" | Evaluating a business |
| "My feet hurt..." | State Need: Fatigue |
| "Nothing here for me" | Primary Goal unfulfilled, satisfaction dropping |
| "Great visit!" | Satisfied, preparing to leave |
| "Where's the bathroom?" | State Need: Bathroom |
| "Worth the price!" | Price satisfaction (willingness to pay met) |
| "Too expensive..." | Business price exceeds willingness to pay |

### Aggregation Panel

A toggleable panel shows the 5 most common thoughts among all current visitors:

```
Top Visitor Thoughts (right now):
1. "I'm hungry!" — 23 visitors
2. "I need new shoes" — 18 visitors
3. "This place is great!" — 12 visitors
4. "Too crowded..." — 8 visitors
5. "Where's the bathroom?" — 5 visitors
```

---

## Performance Considerations

### Agent Management

- Visitors are individual agents, but the simulation uses optimization techniques:
  - **Spatial partitioning:** Only simulate visitors in the active camera view + buffer zone
  - **Visitor Tick:** Decisions update every 5 sim minutes (5 seconds real time at 1x), not every frame
  - **Path caching:** Common paths are cached and reused when possible
  - **Batch updates:** Satisfaction and attribute updates are batched per sim tick

### Scalability Targets

- MVP: Up to 200 simultaneous visitors
- Post-MVP: Up to 500+ simultaneous visitors with optimized algorithms
- The simulation should maintain 60fps at target visitor counts

---

## Integration with Other Systems

| System | Connection |
|--------|------------|
| **Prestige** | Visitor satisfaction feeds into Visitor Experience quality factor |
| **Economy** | Visitor spending generates tenant revenue, which generates rent |
| **Tenant System** | Tenant tier and quality affect visitor satisfaction and spending |
| **Metrics & Visualization** | Heatmaps, flow data, and congestion indicators display visitor patterns |
| **Transit & Circulation** | Visitor pathfinding uses corridors, elevators, escalators, and stairs |
| **Synergy System** | Visitor exploration is influenced by zone adjacencies and complementarity |

---

## Design Notes

### Player Mental Model

The player should understand: "I create an environment. Visitors respond to it. Their behavior tells me what's working and what isn't."

The simulation is transparent: every visible visitor is real, every statistic reflects actual behavior, and every pattern emerges from individual decisions. The player never sees a number that doesn't correspond to something happening in the world.

### Tuning Targets

- Goal count distribution (1–3) should create variety without overwhelming complexity
- Dual budget system should allow most visitors to fulfill their primary goals with secondary budget for discovery
- Need decay rate (1 point per visitor tick) should create natural mid-visit interruptions
- Satisfaction factors should be balanced so that good design is rewarded but perfection isn't required
- The feedback loop should be strong enough to create meaningful consequences but slow enough to allow recovery
