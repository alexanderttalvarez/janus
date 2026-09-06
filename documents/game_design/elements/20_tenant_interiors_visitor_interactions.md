# Tenant Interiors and Visitor Interactions

## Status

Agreed gameplay design. This document does not approve implementation or an architecture handoff.

## Purpose

Tenant interiors make parcel size, shape, frontage, fixtures, capacity, queues, and tenant type visible and mechanically legible without requiring visitors to navigate inside every business. The player continues to design spaces rather than manually furnish stores.

The first iteration affects:

- procedural interior appearance;
- tenant capacity and throughput;
- exterior queues and corridor congestion; and
- visitor service completion as a non-economic gameplay result.

It does not yet create revenue, viability, closures, tenant-derived Prestige, or satisfaction effects. Existing corridor-door proxy events must never be retroactively interpreted as any of those outcomes.

## Chosen Interior Direction

Three approaches were considered:

1. **Door proxy only:** reliable and cheap, but makes interior space and tenant identity largely meaningless.
2. **Visible procedural interiors with abstract service:** selected. Fixtures visibly justify capacity while visitor service remains robust on irregular parcels.
3. **Fully navigable simulated interiors:** deferred. Indoor pathfinding, seat claims, group movement, and recovery on arbitrary geometry add substantial complexity before producing sufficient player agency.

Visitors initially remain on public circulation. Entering service changes them into an abstract interior-service state. Fixtures show abstract occupied visuals. Real visitor models inside tenants may be evaluated later.

## Parcel and Candidate Rules

### No universal parcel minimum

Every operational subtype defines its own:

- minimum usable area;
- minimum rectangular core and allowed rotations;
- preferred splitter target range;
- frontage and exterior-queue requirements; and
- mandatory fixture program.

Area alone never proves suitability. A parcel must contain the required rectangular core and pass the fixture/circulation preflight.

### Rectangular core and irregular annexes

A parcel may contain:

- a **rectangular core** that guarantees the mandatory program can fit; and
- connected **annex tiles** created by irregular zone boundaries or leftover allocation.

Annexes may contain repeatable fixtures, circulation, or visual dressing when every normal footprint, clearance, and connectivity rule passes. Annex area cannot compensate for a missing required core.

### Initial parcel formation

Automatic splitting seeks a zone-appropriate mixture of compact, standard, and large parcel targets. This distribution is automatic in the first iteration.

The splitter must not collapse every zone into parcels matching its smallest subtype. Target rectangles are preferences: if a large target invalidates the remaining partition, a smaller valid target is attempted.

Leftover tenant tiles are assigned only to valid edge-adjacent parcels. Assignment prefers:

1. preserved connectivity and legal frontage;
2. improved rectangularity;
3. a new valid fixture placement; and
4. a deterministic stable tie-break.

If no valid parcel can receive a leftover tile, it becomes decoration rather than an unusable tenant fragment.

During initial generation, a parcel with no feasible profile is absorbed into the best compatible adjacent parcel or converted to decoration. After established-zone edits, existing parcels are preserved: an incompatible empty parcel may remain as a rent-free **Unsuitable Unit**.

Anchors bypass ordinary splitting. The player must provide one contiguous footprint satisfying the selected anchor category's requirements.

### Unsuitable-unit feedback

An unsuitable unit remains visible and identifies the most actionable one or two causes:

- insufficient usable area;
- missing required core dimensions;
- insufficient frontage;
- no safe queue position;
- door placement blocks a valid approach;
- disconnected circulation;
- mandatory fixture or clearance failure; or
- no currently eligible/unlocked operational subtype.

### Feasible profile pool

Candidate selection begins by listing every profile that passes zone type, tier, adjacency, and physical-layout requirements. An empty pool creates the unsuitable-unit state. Incompatible candidates are never presented and no repeated fit attempts occur.

Each feasible profile receives a qualitative spatial rating:

| Rating | Meaning | Selection tickets |
|---|---|---:|
| Excellent | Preferred size, coherent comfort-density layout, and strong frontage/queue provision | 6 |
| Good | Coherent operation with reduced capacity, some waste, or merely adequate frontage | 3 |
| Acceptable | Mandatory program fits but the parcel is oversized, annex-heavy, or minimum-capacity only | 1 |

A seeded weighted draw selects the candidate profile. Every feasible profile retains a chance. The full compatibility list and ratings appear in detailed parcel information; the normal view summarizes the top three.

Spatial selection remains separate from the commercial application score. Rent, Prestige, location, synergy, competition, and Selectivity decide whether the selected candidate applies; they do not enter spatial suitability.

## Fixture Content Contract

Every fixture definition specifies:

- occupied tile footprint and shape;
- allowed rotations;
- visual model variants that fit the same envelope;
- interaction face;
- separate use/clearance footprint;
- required connection to circulation;
- wall, frontage, rear-wall, or freestanding placement rules;
- queue behavior, if any;
- compatible and incompatible neighbor tags;
- capacity or throughput contribution;
- mandatory, repeatable, or optional status; and
- placement priority.

Compatibility uses reusable tags such as `food_prep`, `customer_seating`, `public_counter`, `checkout`, `browse_display`, `service_bay`, `device`, `back_of_house`, `wall_display`, and `noise_source`. Pairwise rules are added only when tags cannot express a real constraint.

Each operational subtype has one mandatory operational program. Visual variants may change models, signs, colors, and props without changing footprints or gameplay. Multiple operational variants per subtype are deferred.

### Fixture priority

1. Reserve legal entrance/service anchor and circulation.
2. Place mandatory service fixtures.
3. Place mandatory capacity/activity fixtures.
4. Place required back-of-house blocks.
5. Validate the minimum viable layout.
6. Add repeatable capacity modules toward comfort density.
7. Add optional visual fixtures.

Repeatable placement prioritizes circulation, coherent rows/groups, low unusable waste, and preservation of useful open areas. It never maximizes capacity by sacrificing clarity or access. Not every tile must be occupied.

Back-of-house blocks are mandatory where specified even though logistics are not simulated. Attraction/display fixtures are visual-only in this iteration.

## Visitor Service Loop

```text
Choose a compatible reachable target
-> travel through public circulation
-> inspect live service conditions at the tenant door
-> accept queue/service or reject tenant
-> receive abstract service
-> complete or cancel
-> select another goal/tenant or leave
```

Visitors do not know the live queue before arriving. This preserves the visible behavior of traveling to a business, observing its line, and deciding whether to wait.

If a visitor rejects a tenant, that tenant is excluded for the visitor's current goal. This prevents immediate retargeting loops.

## Wait Tolerance and Commitment

The former Patience definition based on the number of people ahead is replaced by **maximum acceptable expected wait**.

At the door, the tenant reports expected wait from its service model, active capacity, queue, and schedule. The visitor compares that estimate once against their wait tolerance:

- acceptable: join and commit;
- excessive or full: reject and immediately re-evaluate.

Wait tolerance is a decision threshold, not a meter that decreases while queued. After commitment, normal waiting does not cause abandonment or negative emotion. Ordinary needs are suspended until service completes. Cancellation occurs only if service, tenant, door, or required topology becomes invalid.

## Exterior Queue Rules

- Queue positions are public-side and visibly occupied by real visitor agents.
- One validated exterior queue tile supports two visible waiting visitors.
- Actual cap is `min(subtype visitor cap, safe queue tiles x 2)`.
- Neighboring tenants cannot share the same physical queue positions.
- Queue positions remain alongside frontage and cannot exclusively block an entire circulation tile.
- Queued visitors count toward real corridor occupancy and congestion.
- If the queue is full or expected wait exceeds tolerance, the arriving visitor does not join.

## Queue and Service Typologies

| Pattern | Rule | Typical profiles |
|---|---|---|
| Host/seating | Exterior queue feeds available table tokens | Sit-down restaurant |
| Counter | One FIFO line feeds one or more short service stations | Takeaway, bank, repair |
| Browse/checkout | Abstract interior browsing followed by checkout; exterior queue appears at occupancy limit | Retail, supermarket, department store |
| Service bay | A small number of long-duration bays serve FIFO visitors | Salon, clinic, travel agency |
| Scheduled batch | Visitors reserve only the next timed entry | Cinema, escape room |
| Device pool | Interior occupancy feeds individual devices as they free; exterior queue replaces admitted visitors | Arcade, VR |
| Cohort/device pool | FIFO visitors form temporary groups and claim an activity unit | Bowling |
| Open flow | Admission continues until abstract occupancy is full | Gym, exhibition hall |
| Counter then seating | A table is reserved before counter service, then occupied afterward | Café, food court |

### Table cohorts

Sit service uses 2-person 1x2 and 4-person 2x2 table modules. When a table frees, the first `min(table capacity, queued visitors)` form a temporary FIFO cohort. Partial table fills are allowed. The cohort shares one service duration and releases the table together.

### Device pools

Devices determine active play capacity. Additional general occupancy permits abstract interior waiting. When a device frees, an interior visitor claims it; an exterior visitor may enter when general occupancy frees.

### Scheduled batches

Each tenant has one active abstract batch inside and one next-batch queue outside. Entering visitors free exterior queue positions immediately, allowing the next batch to form. No visitor may reserve a later batch. If the next batch is full or its expected wait exceeds tolerance, the visitor rejects the tenant.

## Operational Subtype Baselines

All target maxima guide automatic splitting and are not hard eligibility maxima. Larger parcels remain eligible but lose preferred-size suitability and may retain unused visual/open space.

### Food and Beverage

| Subtype | Minimum/core | Target | Queue cap | Mandatory program | Repeatable capacity |
|---|---|---|---:|---|---|
| Drinks/snack kiosk | 4; 2x2 | 4–6 | 4 | 1x2 frontage counter, 1x2 stock/prep | None |
| Takeaway food | 6; 2x3 | 6–12 | 6 | Frontage counter, prep, and back-of-house rows | 1x3 service-lane strips |
| Café | 9; 3x3 | 9–18 | 6 | 1x2 counter, 1x2 prep, 1x1 storage, one 1x2 table | Service stations and 2-person tables |
| Sit-down restaurant | 12; 3x4 | 12–24 | 8 | Host, 2x2 kitchen, one 2-person table, circulation | 2- and 4-person tables; no hard table cap |

Sit-down restaurant themes such as sushi, Italian, Mexican, or local cuisine share the operational profile. Theme-specific interiors may initially differ only by signage.

### Retail

| Subtype | Minimum/core | Target | Queue cap | Mandatory program | Repeatable capacity |
|---|---|---|---:|---|---|
| Jewelry | 6; 2x3 | 6–12 | 4 | 1x2 secure counter, display, storage | 1x1 displays |
| Fashion | 9; 3x3 | 9–18 | 4 | Checkout, 1x2 fitting block, 1x2 rack | Racks and fitting blocks |
| Bookstore | 9; 3x3 | 9–18 | 4 | Checkout, 1x2 shelving, 1x2 storage | Shelving modules |
| Electronics | 12; 3x4 | 12–24 | 6 | 1x2 checkout, 1x2 demonstration table, 1x2 secure storage | Demonstration/display modules |
| Home goods | 12; 3x4 | 12–24 | 4 | 1x2 checkout, 2x2 bulky display, 2x2 stock block | 2x2 display modules |

Retail may operate with no exterior queue positions, but turns away new arrivals immediately when its abstract occupancy is full.

### Services

| Subtype | Minimum/core | Target | Queue cap | Mandatory program | Repeatable capacity |
|---|---|---|---:|---|---|
| Repair shop | 6; 2x3 | 6–12 | 4 | Reception, 2x2 workshop, storage | 1x2 workbenches |
| Travel agency | 6; 2x3 | 6–12 | 4 | Reception, consultation desk, back-office | Consultation desks |
| Bank | 9; 3x3 | 9–18 | 6 | 1x2 teller counter, waiting module, secure back-office | Teller stations |
| Hair salon | 9; 3x3 | 9–18 | 4 | Reception, 1x2 service bay, 1x2 back room | Service bays |
| Clinic | 12; 3x4 | 12–24 | 4 | Reception, waiting module, 2x2 treatment room, back-office | Treatment rooms |

Appointments and calendars are not simulated; service bays continuously take the next committed visitor.

### Entertainment

| Subtype | Minimum/core | Target | Queue cap | Mandatory program | Repeatable capacity |
|---|---|---|---:|---|---|
| Arcade | 12; 3x4 | 12–24 | 8 | Entry desk, storage, three 1x1 devices, circulation | Device modules |
| Escape room | 12; 3x4 | 12–24 | 8 | Reception, 2x3 activity room, 1x2 control room | Activity rooms |
| VR experience | 12; 3x4 | 12–24 | 8 | Reception, 2x2 VR module, back room | VR modules |
| Cinema | 24; 4x6 | 24–48 | 16 | 1x2 ticket point, auditorium block, projection/back-of-house | Auditorium-capacity rows |
| Bowling alley | 24; 4x6 | 24–48 | 8 | 1x2 reception, 2x4 lane module, equipment block | Lane modules |

### Anchors

| Subtype | Minimum/core | Target | Queue cap | Mandatory program | Repeatable capacity |
|---|---|---|---:|---|---|
| Gym | 30; 5x6 | 30–60 | 8 | Reception, 2x3 changing/back-of-house block, activity zone | 2x2 equipment zones |
| Exhibition hall | 30; 5x6 | 30–60 | 12 | Entry desk, back-of-house, exhibit zone, circulation loop | Exhibit zones |
| Food court | 36; 6x6 | 36–72 | 12 | Vendor frontage, prep blocks, shared table pool | Vendor stations and tables |
| Supermarket | 40; 5x8 | 40–80 | 12 | Checkout bank, 3x3 stockroom, shelf aisles, circulation loop | Shelves and checkout modules |
| Department store | 48; 6x8 | 48–96 | 12 | Checkout bank, 3x3 back-of-house, department zones, circulation loop | 2x3 department modules |

First-iteration anchors have one primary operational visitor entrance. Additional visual entrances and multiple active queues feeding shared capacity are deferred.

## Layout Validation and Fallback

For each profile, deterministic bounded layout search must prove:

- every occupied footprint lies inside usable parcel geometry;
- fixtures and clearances do not overlap illegally;
- mandatory interaction faces connect to circulation or frontage;
- all mandatory customer-accessible points connect to the entrance;
- queue positions are safe and non-overlapping;
- the minimum program fits before optional placement; and
- repeatable placement cannot invalidate an earlier requirement.

Outcomes degrade as follows:

1. Full preferred layout fits: open at preferred capacity.
2. Mandatory layout plus reduced repeatables fits: open at reduced capacity.
3. Only the explicit minimum program fits: open as a valid minimum-capacity tenant.
4. Mandatory program fails: profile is excluded before candidate selection.
5. Unexpected generation failure after commitment: show a closed fit-out state and block service; never fabricate inaccessible interactions.

## Deferred Decisions

- Real visitor models and pathfinding inside interiors.
- Individual chairs, shopping baskets, stock, staff, kitchens, and back-of-house logistics.
- Player fixture placement, renovations, or operational variants.
- Parallel auditoriums, parallel independently scheduled rooms, and reservations beyond the next batch.
- Multiple active anchor entrances.
- Shared vendor ownership inside food-court anchors.
- Theme-specific model sets beyond basic signage/visual variants.
- Revenue, purchases with amounts, pricing, viability, closures, upgrades, satisfaction, attraction scoring, and tenant-derived Prestige.
- Performance, persistence, authority boundaries, and implementation contracts, which require a later architecture handoff.

## Player Mental Model

> I create appropriately shaped and accessible spaces. The game fills them with businesses whose visible interiors explain their capacity and queues. Better frontage and usable geometry support more varied tenants and smoother visitor flow.

## Playtest Priorities

- Verify that compact profiles remain useful without consuming every zone.
- Verify that 6/3/1 weighting produces variety without implausible matches.
- Verify that comfort-density interiors remain readable rather than sparse or overcrowded.
- Verify that queue caps generate visible pressure without routinely obstructing corridors.
- Retune all area ranges, fixture envelopes, durations, and queue caps from observed play rather than treating current values as permanent.
