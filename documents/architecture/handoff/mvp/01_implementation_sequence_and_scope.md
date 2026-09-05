# MVP Handoff — Implementation Sequence and Scope Lock

**Status:** Approved — 2026-09-05 (delegated architecture authority)

## Purpose

Turn the approved handoffs into one testable MVP delivery sequence. This does not replace any owner contract. It defines the smallest playable slice: build a legal district, populate Tier-1 tenants, collect daily rent, observe corridor-door-proxy visitors, pay staff weekly if hired, save/load safely, and inspect outcomes through presentation read models.

## Mandatory implementation order

1. **Foundation:** District H1–H3; Zone/Parcel H1–H6; Economy H1–H2; Progression H1–H3.
2. **Session/content/time:** Session H1, including the exact calendar and immutable content registry.
3. **Construction/topology:** District H5–H8 contracts, Construction H1, Zone/Parcel doors/walls H4–H5, Spatial Evaluation H1.
4. **Tenant economy:** Prestige H1–H2; Tenant H1–H3; daily Economy rent settlement.
5. **Visitors/staff:** Visitor H1; Staff H1; weekly Economy wage settlement.
6. **Presentation and persistence:** Presentation H1; District H9 plus Session H2 atomic restore/acceptance gate.
7. **Cutover evidence:** District H4 editor-preview only if tools are required; District H10 only after all prior implementation evidence passes. H10 is a release/cutover gate, not a prerequisite for isolated authority tests.

No layer may substitute legacy grid, navigation, mutable scene nodes, ad-hoc timers, direct UI mutation, or fallback policy values while a prerequisite is absent.

## MVP player loop

```text
new/load session
  -> acquire/build valid floor cells and circulation
  -> paint valid zones and create parcels/doors
  -> spatial/rent context initializes
  -> seeded Tier-1 candidates evaluate
  -> lock -> construct -> open tenant
  -> daily rent credited
  -> pedestrian visitors arrive, use corridor-door service proxies, and exit
  -> optional Operations Room staff hire -> weekly wages
  -> HUD/panels expose committed facts and diagnostics
  -> V2 save/load reproduces the session atomically
```

Visitor proxy outcomes are deliberately non-economic in this MVP. The economic loop is tenant rent, not simulated visitor purchases. This keeps the slice truthful until the deferred interiors/service/revenue handoff exists.

## Required content at test start

The immutable registry must ship coherent versions of:

- one approved district layout definition and fingerprint;
- Economy H2 prices plus Construction H1 circulation/vertical-link/Operations Room prices;
- Prestige H1 tier/rent-ceiling policy and H2 baseline policy;
- Spatial Evaluation H1 factors/relationship matrix;
- Tenant H3 Tier-1 candidate catalog; and
- any approved zone subtype catalog required by legal candidate selection.

Missing/incompatible content is a structured startup/evaluation rejection, never a default value.

## Explicit MVP exclusions

The following remain intentionally deferred and require new handoffs before implementation:

- tenant interiors, furniture, real purchases/revenue, viability, closures, upgrades, satisfaction, and tenant-derived Prestige;
- full Prestige Quality factors, loan-default effects, daily trend, visitor attraction, and Tech-point awards;
- buses/parking/taxis/metro, arrival capacities, pending cohorts, transport economics, and congestion weighting;
- escalators, terraces, decorative amenities, dynamic columns, structural simulation, material themes, and maintenance/repair systems;
- staff agents/visuals, garbage/bathroom spawn formulas, scoring effects, and staff-driven tenant/visitor effects;
- advanced dashboards/history, unbacked heatmaps, panel comparison, preferences, localization, and notification conditions not emitted by an authority;
- playable multi-plot expansion/street conversion beyond the target-compatible District foundations.

## Conflict resolutions for MVP

### 2026-09-05 Spatial Evaluation ordering addendum

Spatial Evaluation H1 requires implemented H3/H5 topology providers,
ZoneManager geometry revisions, Prestige H1, and frozen Tenant H2 contract
types. It does not require Tenant H2 implementation. Prestige H1 is therefore
implemented before Spatial Evaluation H1. Prestige H2 may follow or proceed in
parallel. Tenant H1/H2 production implementation follows Spatial Evaluation
H1; Tenant H2 may be unit-tested earlier only against immutable fixture
snapshots. Missing or stale inputs remain unavailable and never receive a
fallback score, rate, tier, or accessibility value.

- Approved Zone/Parcel wall/door handoffs win over the older per-zone `No Walls` design option: parcel divider walls and legal parcel doors are mandatory committed facts. Per-zone wall removal is deferred.
- Canonical elevation is `G`, then `F1` upward and `U1` downward; F1 is the first level above ground.
- No recurring maintenance cost exists in MVP. Any older corridor/terrace maintenance wording is deferred with maintenance.
- Same-type zone effects use the Spatial H1 competition bands, not application-synergy double counting.
- The presentation MVP has one primary detail panel plus optional summary drawer; it does not implement every historically listed panel concurrently.

## End-to-end acceptance gate

A headless deterministic scenario must prove:

1. registry/layout validation and legacy-free new-session bootstrap;
2. calendar catch-up order across speed/pause and daily/weekly/monthly identities;
3. a successful and rejected construction/zone/rent intent with no partial authority mutation;
4. a legal Tier-1 tenant application through Open and exactly-once daily rent;
5. pedestrian arrival/service-proxy/exit under the global active cap;
6. optional staff hire and exactly-once weekly wage;
7. presentation receives only committed snapshots/results/diagnostics; and
8. V2 save/load plus injected failure at each restore stage leaves the old session intact or restores one coherent new session.

Implementation is not MVP-ready until this scenario, unit suites for every referenced handoff, and District H10 cutover evidence all pass.
