# District Layout & Land Expansion

## Purpose and Authority

This document is the central design authority for district geometry, land vocabulary, ownership expansion, vertical rights, street conversion, and arrival-source placement. Other system documents should reference these rules rather than redefine them.

**Revision:** Approved 2026-09-08 consistency pass. [Current MVP](../current_mvp.md) limits implementation scope; approved future geometry/pricing is not a requirement to ship multi-Plot play. Historical road timing is superseded by the exact intervals below.

---

## FACTS

### Vocabulary

| Term | Definition |
|------|------------|
| **District** | The complete playable urban layout. |
| **Block Slot** | A rectangular cell in the district track grid. |
| **Plot** | A player-capable block that may contain purchasable land. |
| **Plot Section** | An atomic ground-land purchase area within a plot. |
| **Street Corridor** | The full cross-section between block slots: two Pedestrian Bands plus the carriageway. |
| **Street Segment** | A purchasable rectangular portion of a Street Corridor bounded by intersections. |
| **Pedestrian Band** | City-owned public pedestrian space between a block and the carriageway. |
| **Carriageway** | The vehicle-lane portion of a Street Corridor. |
| **Intersection** | The road area where Street Segments meet. |

Do not use **parcel** for land. A parcel is a tenant-sized business unit inside a zone; it can be vacant, unsuitable, constructing or occupied. It is not the tenant identity itself. Land uses Plot and Plot Section.

### District Grid and Block Slots

- A District is a rectangular row/column track grid of rectangular Block Slots.
- All Block Slots in a row share the same depth.
- All Block Slots in a column share the same width.
- Every row depth and column width is at least 18 tiles.
- A Block Slot has one role: player-capable Plot, fixed decorative/non-player block, public plaza, park, or unavailable.
- Slot-role transitions may be supported later, but are disabled for MVP.
- The District has a complete, permanent outer road ring.
- The camera boundary is the union of all Active Plot rectangles and selected/unlocked Plot rectangles plus an infrastructure margin. An unlocked Plot is camera-accessible before any section is owned.

### Roads

- A layout uses one uniform road profile.
- Each Pedestrian Band is 5-10 tiles wide.
- Each vehicle lane is 3 tiles wide.
- A road has 2-6 total lanes inclusive, including at least one lane in each direction.
- Lanes traveling in the same direction are contiguous.
- Carriageway width is derived from lane count.
- Street Corridor width equals two Pedestrian Bands plus the carriageway.
- There are no bus-only lanes.
- Carriageways are generated dark-gray asphalt from Street Segment length and lane count. Flat batched marking overlays, rather than authored decal Nodes or raised geometry, provide 0.25-tile ordinary markings and 0.50-tile stop lines.
- Each Street Segment has one centered midpoint crosswalk: 5 tiles along-road wide, alternating 0.5-tile white and exposed-asphalt stripes, and spanning the carriageway. Curbs are 0.10 tile high and 0.15 tile wide with flush crosswalk interruptions; intersections are plain dark-gray surfaces with square corners and no internal lane-direction markings.

### Plot Templates, Sections, and Activation

- Reusable Plot Templates define plot content and constraints. A district Block Slot may apply constrained overrides to its assigned template.
- A Plot contains one or more arbitrary Plot Sections. Sections must be four-directionally contiguous and may not overlap.
- A Plot Section is the atomic ground-land purchase unit.
- Entry-eligible Plot Sections activate orthogonally adjacent Plots when purchased.
- A selected/unlocked Plot is a permanently player-chosen, camera-accessible Plot that may receive Plot Section purchases but has no owned land yet.
- A Plot becomes **Active** when any one of its sections is owned.
- A Plot becomes **Fully Owned** when every acquirable section is owned.
- The initial 25 x 25 Plot contains one full-plot section and is initially owned. Up to eight additional Plot Access selections are granted by Mall Level; each selected Plot must be orthogonally adjacent to an Active or already unlocked Plot. Multiple Plot/section purchases remain post-MVP implementation work.
- Purchasing a section does not remove an existing building. Ownership, availability, occupancy, buildability, and construction are separate states.

### Vertical Rights and Floor Space

- A purchased Plot Section grants vertical rights above and below its section mask.
- Upper and underground floor space is purchased tile-by-tile and sequentially by elevation.
- A floor may overhang no more than 2 tiles beyond the immediately lower floor.
- An overhang may never extend beyond the combined vertical-rights mask of owned sections.
- Signed elevations are canonical: `0 = G`, `+1..+9 = F1..F9`, and `-1..-5 = U1..U5`.
- The default physical maximum is 10 above-ground levels including G, plus 5 underground levels.
- A Plot Template may impose stricter limits. A Block Slot override may impose stricter limits still.
- Progression may further restrict which otherwise permitted elevations the player can currently acquire or build.

### Street Segment Conversion

- A Street Segment is purchased and converted as a whole, including both Pedestrian Bands and its carriageway.
- Conversion costs 3,000 Kreds per tile in that complete Street Corridor. The value is sourced from centralized tunable Economy policy and captured immutably for the transaction.
- Conversion creates pedestrian public space and removes general vehicle traffic from that segment.
- A Street Segment is eligible only when all of these conditions are met:
  - The layout marks it purchasable.
  - Player-owned frontage is at least 50% independently on each side.
  - It is not part of the permanent outer road ring.
  - Applicable economy and progression requirements are satisfied.
- Traffic connectivity does not veto a conversion. The player accepts the resulting consequences.
- An internal Intersection transfers only after all incident internal Street Segments have been converted.
- Outer-ring Street Segments and Intersections never transfer.
- Only positive-length collinear Plot/Street contact contributes frontage; corner-only contact contributes zero.
- Conversion removes the carriageway, markings, curbs, crosswalk, traffic lights, and stop lines, replacing the full segment with unrestricted pedestrian topology using ordinary Pedestrian Band paving.

### Public Pedestrian Bands and Transport Facilities

- Pedestrian Bands remain city-owned.
- An adjacent active Pedestrian Band may supply a topology-backed physical door/access edge for a Plot Section or tenant parcel without ownership transfer. The edge must be an active pedestrian graph edge with stable identity.
- The player may fund curbside transport facilities on a Pedestrian Band adjacent to owned frontage without owning that land.
- Converting a Street Segment removes affected curbside facilities after warning the player.
- A bus stop requires the Bus Stop progression node, Small Market, an active road, and an active route.
- Maximum bus stops are `ceil(Active Plot count / 3)`. Because any owned section makes a Plot Active, any owned section counts toward this limit.
- Bus Stop is the sole approved first transport capability. Placement, facility ownership, prices/fees, and bus arrivals remain future handoffs. All other transport facilities are unavailable.

### Traffic and Crossings

- Traffic routes are initially straight-through only. Intersection reservation behavior remains authoritative for straight crossings; there are no intersection traffic lights or pedestrian crossings.
- Controlled traffic boundaries derive from orthogonally adjacent **Active Plot slots**, not a literal connected union of Plot rectangles (roads separate those rectangles). Selected/unowned slots do not count. Each active-slot component uses its bordering roads; disconnected components are valid, including proof Fixture C. Never fill intervening unowned slots or a bounding box. Every outward-facing lane at a component's road perimeter has paired spawn/despawn anchors just outside its boundary intersection, deduplicated by stable lane/control identity. Expansion moves those boundaries; converted/inactive roads have no anchors. The permanent outer ring remains.
- Midpoint crosswalks have two opposing traffic-light poles in Pedestrian Bands. Use elapsed simulation seconds from element 01, pausing/scaling with simulation, with normalized phase `p = (elapsed / T + offset) mod 10`: north-south offset 0, east-west offset **6**. At epoch zero north-south vehicle lights are green and east-west red. This replaces the incompatible 5T-offset/red-at-zero pair; opposite phases need not be half a cycle because these are independent midpoint controls, not intersection control.
- Vehicle phases: green `[0,5)`, yellow `[5,6)`, red `[6,10)`. Pedestrian entry green is `[6,9)`; all other phases are pedestrian red. `[9,10)` is a final-T pedestrian clearance interval with vehicles still red. During yellow, cars past their stop line clear and other cars stop. Pedestrians enter only while entry-green and vehicle occupancy is clear; cars enter only while vehicle-green and pedestrian occupancy is clear. A late/stalled occupant extends the conflicting movement hold, never its nominal phase or entry permission. Thus clock transitions cannot cause collisions or strand a crossing visitor.
- `T` is the full carriageway crossing distance divided by canonical crosswalk speed. Every visitor uses this canonical speed regardless of status.
- Canonical crosswalk speed is 1 tile per scaled elapsed second for this baseline. `T` therefore equals the carriageway width in tiles, independent of visitor attributes. Traffic presentation owns transient occupancy/reservations; the clock is a pure read of Time, not another saved timer. Public-route traversal observes the crossing hold, but arrival-source allocation does not depend on traffic signals.
- Midpoint crosswalks are the only pedestrian crossings. Outer-ring midpoint crosswalks and their lights remain traffic-functional but are not pedestrian graph links or visitor crossings.

### Visitor Demand and Arrival Realization

- Visitor demand and the realization of arrivals are separate concerns.
- A Visitor Arrival Coordinator allocates demand among available arrival sources.
- MVP realizes arrivals immediately through pedestrian gateways.
- Future arrival sources are buses, parking cars, taxis, and metro, in that priority order.
- Pending public-transport arrivals remain lightweight data until a presentation arrival releases real visitor agents.

### Economy and Progression Authority

- Economy and progression systems determine whether an eligible purchase, conversion, facility, or floor-space acquisition is currently allowed.
- Approved expansion prices/refunds are in [element 03](03_economy.md); approved elevation, Plot Access and Bus Stop eligibility are in [element 08](08_mall_levels_tech_tree.md). Those are single numerical authorities. Facilities and bus arrivals remain deferred; no purchase rule is inferred from a visual or future fee proposal.

---

## ASSUMPTIONS

- Typed Godot Resource metadata plus token-grid layers is the architecture format frozen by `district_layout/H1-H2` KEEP, not an unresolved design question. Geometry and initial-state fixture records are unchanged by this pass.

### 2026-08-31 Road & Intersection Addendum

The road profile, generated public-realm, conversion, frontage/access, and traffic/crossing rules above are approved. TrafficTopology owns road topology, anchors, and control semantics; TrafficManager owns transient traffic presentation; public-realm generation owns pedestrian topology. No costs or formulas are approved by this addendum.

---

## Resolved Defaults and Deferred Work

- Eligible fixed-structure demolition commits immediately and atomically across the whole occupant; occupied tenant/zone dependencies reject, with no charge. There is no demolition timer or cancellation job.
- Pre-commit cancellation is free; completed paid actions have no refund, per element 03.
- Full physical elevation gates and the hybrid content format are resolved in the authorities above, not open questions.
- Later transport facilities, fees, arrival presentation and slot-role transitions need future handoffs. Current behavior is explicit unavailable, not a runtime fallback.
- The production single-owned-Plot rule does not constrain proof-only Fixture C's exact three initial entry sections. Fixture C is not a player start or proof of geometrically connected Plot rectangles.
