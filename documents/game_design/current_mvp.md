# Current Product MVP

**Status:** Approved, revision 2026-09-08, documentation consistency pass under delegated design authority. Consolidates the approved 2026-09-06 Product MVP decision; adds the minimum normal-play progression and input surfaces needed to make it playable. This is the sole MVP scope authority.

## Purpose

Deliver a small vertical commercial complex whose spatial design visibly determines which tenants fit, how they serve visitors, and how public circulation performs. The player builds spaces, not individual shops or fixture arrangements. Preserve [the concept](concept.md): architectural creativity, physical representation, transparent feedback, and no tenant micromanagement.

## Milestones

| Name | Meaning | Completion condition |
|---|---|---|
| Corridor Service Integration Gate | Technical foundation, formerly called the flat/proxy MVP | Reproducible foundation contracts and session acceptance; not a player release |
| Product MVP | Player-facing scope below | Foundation evidence plus approved interior runtime/cutover contracts and their acceptance evidence |
| district_layout Gate E | District engineering completion, not whole-product completion | Recorded engineering evidence under ADR 32 |
| district_layout Gate R | External district release acceptance | Actual release exports, physical performance evidence, artifact binding, and independent signoffs |

Design approval, architecture approval, dependency readiness, implementation completion, Gate E, and Gate R are independent. None implies the others. **Follow-on review, 2026-09-08:** Tenant Interiors H4/H5 are architecture-approved under [ADR 34](../architecture/decisions/34_product_mvp_runtime_and_cutover.md), separately from the earlier consistency pass that left them drafts. Follow foundation -> detached H1-H3 -> H4 implementation passes -> H5 candidate cutover passes -> Product acceptance; external Gate R is separate. Implementation and cutover remain NOT VERIFIED; Product acceptance and Gate R remain PENDING. Documentation approval does not activate live capabilities; see the [handoff index](../architecture/handoff/_index.md) and [Product delivery contract](../architecture/handoff/mvp/04_product_delivery_and_acceptance.md).

## Included Behavior

**Design A1/A2 decisions and A3 reset acknowledgement: PENDING.** H4/H5 architecture approval does not settle open gameplay interpretations. Unaffected engineering may proceed; confirm A1 exterior-only expected wait and A2 shared cafe/food-court cohort counter semantics before locking affected implementation or acceptance. The [Product Design decision register](../architecture/evidence/product_mvp/_index.md#design-decision-register) records these decisions separately from approved scope.

- One initially owned 25 x 25 Plot, explicit production layout selection, signed elevations, floor construction, public corridors, stairs and elevator links. No player-facing multi-Plot expansion is required.
- Zone painting, preservation-first editing, legal physical doors and walls, subtype-specific core/annex parcels, dedicated Anchor parcels, automatic size variation, and visible unsuitable vacant units.
- Seeded feasible candidate selection, commercial application scoring, exclusivity/construction/Open lifecycle, zone rent controls, daily rent, balance and affordability. Rent is income from Open tenancy, not visitor sales.
- Visible deterministic procedural tenant interiors, fixture-derived capacity, real exterior queues, door-time expected-wait decisions, abstract service for the nine agreed typologies, and one active plus one next scheduled batch. No indoor visitor navigation.
- Immediate pedestrian arrivals, a 200-active-visitor cap, public routing, traffic-safe midpoint crossings, goal/service/exit behavior, and recovery from topology invalidation.
- Monthly developed-tile Prestige with fixed Quality 20; normal-play Tech-point awards and purchases sufficient to unlock Advanced Zoning, Anchors, Stairs, Multi-Floor, and Elevators. Later-tier content may remain unavailable under this limited calculation.
- Optional Operations Room employment: two Cleaners and two Security per room, coverage records, hire/fire intents, and exactly-once weekly wages. No staff agents or cleaning/security simulation.
- Pause/1x/2x/3x, floor/camera/wall controls, build/zone/rent/progression/staff intents, money and visitor HUD, official Prestige summary, contextual diagnostics, and source-backed detail panels. A simple action list is sufficient for Tech and Staff; dedicated graph/dashboard panels are not required.
- Atomic new/load/save behavior, deterministic interior rebuilding, reset of transient in-flight service at the approved cutover, and no proxy fallback after cutover.

## Normal-Play Reachability

Use [element 02](elements/02_prestige_system.md) for the baseline calculation and [element 08](elements/08_mall_levels_tech_tree.md) for thresholds, grants, costs, and unlocks. No debug-only bypass satisfies Product acceptance. At 100 distinct developed tiles the next valid monthly publication reaches Small Market and grants 3 points; at 300 it reaches Neighborhood Center and grants 5 more. The resulting 8 points can buy Advanced Zoning (1), Anchors (2), Stairs (1), Multi-Floor (2), and Elevators (2). These are optional player choices, but acceptance must demonstrate that this route is possible. No artificial Quality bonus, starting points, or accelerated calendar is needed.

## Deferred Behavior

- Visitor spending/revenue, viability-driven closures, tenant upgrades, satisfaction, attraction scoring, and tenant-derived Prestige; loans/defaults and the six-factor Quality simulation.
- Bus facilities/arrivals, parking, taxis, metro, pending arrival cohorts, transport fees/capacities, intersection turns or intersection lights. Approved Bus Stop eligibility is future policy, not an operational bus requirement.
- Playable multi-Plot acquisition and Street conversion; the district contracts and proof fixtures still cover those future capabilities.
- Escalators, terraces, decorative amenity placement, columns/structural simulation, material variants, maintenance/repair, bathroom/garbage simulation, staff agents and scoring effects.
- Indoor visitors, player fixture placement, multiple operational variants, multiple active Anchor entrances, parallel independently scheduled rooms, and bookings beyond the next batch.
- Full Tech graph/Staff dashboards, history/trend simulation, unsupported heatmaps, simultaneous panel comparison, preferences, and localization delivery. Keep stable content identities; do not build deferred frameworks.

## Interpretation

Older element sections describe full-game design unless included here. Their bare "MVP" labels do not add features to this scope. Numerical rules stay with their named element authority; handoff copies are reference values. The [implementation sequence](../architecture/handoff/mvp/01_implementation_sequence_and_scope.md) orders work but cannot expand scope.
