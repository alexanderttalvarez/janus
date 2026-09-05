# Spatial Evaluation Inputs Handoff 01 — Spatial Context and Rent Recommendation

**Status:** Approved — 2026-09-05 (delegated architecture authority)
**Prepared:** 2026-09-05
**Implementation order:** 1 of TBD

## Purpose

Supply the missing authoritative facts required by Tenant H2's complete application evaluation and rate initialization: circulation/accessibility, zone relationships/competition, and an exact recommended-rent calculation. This handoff publishes detached revisioned facts and pure calculations; it does not own tenant decisions, money, Prestige calculation, navigation agents, or UI.

## Authoritative sources

- [Tenant Handoff 02 — Rent Policy and Application Evaluation](../tenant/02_rent_policy_and_application_evaluation.md)
- [Prestige Handoff 01 — Official Tier Publication](../prestige/01_official_tier_publication.md)
- [District Handoff 03 — Variable Floor Grid Migration](../district_layout/03_variable_floor_grid_migration.md)
- [District Handoff 05 — Street and Pedestrian Generation](../district_layout/05_street_and_pedestrian_generation.md)
- [Economy design](../../../game_design/elements/03_economy.md)
- [Tenant & Shop System design](../../../game_design/elements/06_tenant_shop_system.md)
- [Synergy System design](../../../game_design/elements/14_synergy_system.md)
- [District Handoff 09 — Save/Load V2 and District Persistence](../district_layout/09_save_load_v2.md)

## Scope

- Immutable data-driven `RentRecommendationPolicy` and a pure fixed-point recommendation calculator.
- Detached `CirculationEvaluationSnapshot` from committed pedestrian topology/floor/vertical-link facts.
- Detached `ZoneRelationshipSnapshot` from committed zone/parcel geometry and pure relationship evaluation.
- Deterministic accessibility band, synergy classification, and competition-band rules for Tenant H2.
- Revision capture, source-staleness diagnostics, direct typed publication, and deterministic tests.

## Explicit non-goals

- Tenant candidate selection, scoring/threshold ownership, lifecycle transitions, rate writes, balance writes, or UI implementation.
- Visitor spawning, live congestion, navigation-agent probes, traffic simulation, or visitor spending.
- Full Synergy Score aggregation, Synergy revenue modifiers, Prestige calculation, Quality factors, trend, or loan effects.
- A legacy navigation fallback, mutable global factors, or a new persistent gameplay authority snapshot.

## Decisions made for MVP

- The documented Prestige rent ceiling is a hard cap: `recommended = min(ceiling, calculated_rate)`.
- `F1` is the first elevation above `G` and has factor `1.05`.
- Tenant application synergy is `+20 / 0 / -10` for complementary / neutral / conflicting. Same-zone-type behavior belongs exclusively to competition.
- Synergy considers other zones within five tiles by boundary-to-boundary distance. Its bounded application classification uses greatest absolute impact; a tie resolves negative first, then canonical zone ID.
- Accessibility derives from committed public pedestrian topology and vertical-link coverage only—never live visitor density, runtime agent probes, or legacy navigation.
- If the required committed H3/H5 topology snapshot is unavailable/stale, Tenant H2 defers evaluation. No temporary fallback exists.

## Ownership

| Owner | Owns | Must not own |
|---|---|---|
| Spatial evaluation policy content | Fixed-point factors, relationship matrix, distance bands, classification version. | Runtime zone/tenant state or scores. |
| District circulation/public-realm authority | Committed pedestrian graph, floor identities, gateways, and valid stairs/elevator links. | Tenant scores, zone rate, visitor occupancy. |
| `ZoneManager` | Committed zone/parcel geometry, stable IDs/types, geometry revision; relationship snapshot projection. | Synergy score state, tenant decision, rent calculation. |
| `ZoneRelationshipEvaluator` | Pure transform from immutable zone geometry/policy to relationship and competition facts. | Scene mutation, zone writes, lifecycle state. |
| `RentRecommendationCalculator` | Pure transform from immutable policy + Prestige + spatial facts to centi-Kred recommendation. | Policy mutation, rate storage, balance. |
| `TenantManager` | Captures these snapshots to assemble Tenant H2 context and decide applications. | Source fact mutation/calculation ownership. |
| `ZoneManager` | Initializes/stores player zone rate using successful recommendation output. | Recommendation policy or score ownership. |

## Data contracts

### `RentRecommendationPolicy`

This is read-only, versioned content (a typed Resource/catalog, never a mutable shared runtime object). It contains:

- floor factors in basis points: `G=10000`; F1 and every subsequent upper level add `500` to cap `12500`; U1 and every lower level subtract `1000` to floor `5000`;
- accessibility factors: Poor `7000`, Average `8500`, Good `10000`, Excellent `11500`;
- adjacency factors: Negative `8000`, Neutral `10000`, Positive `11500`;
- five-tile relationship range; competition bands at 10 and 20 tiles; and
- the policy revision/reference.

For valid inputs, all arithmetic is integer-only:

```text
unclamped_centi = floor(
  rent_ceiling_centi * floor_factor_bps * accessibility_factor_bps * adjacency_factor_bps
  / 1,000,000,000,000
)
recommended_centi = min(rent_ceiling_centi, unclamped_centi)
```

No factor or ceiling fallback is permitted. The calculator returns a detached result with all source revisions and intermediate values for H2 presentation/diagnostics.

### `CirculationEvaluationSnapshot`

The circulation authority provides detached, revisioned facts for a parcel/zone evaluation target:

- target parcel/zone and canonical elevation identity;
- whether at least one valid public pedestrian route reaches a committed parcel-frontage gateway;
- count/presence of valid stairs and elevator links serving that elevation; and
- district/public-realm topology revision and source calendar/commit identity.

Accessibility classification is deterministic:

| Condition | Band |
|---|---|
| No valid public route to a parcel-frontage gateway | Poor |
| Route exists, target is `G` or has no valid vertical link on its elevation | Average |
| Route exists and one of stairs/elevator serves a non-ground elevation | Good |
| Route exists and both stairs and elevator serve a non-ground elevation | Excellent |

A future circulation handoff may improve these bands only through an approved policy revision; it may not replace them with live congestion data.

### `ZoneRelationshipSnapshot`

`ZoneManager` supplies a detached canonical set of other committed zones with stable IDs, type, footprint/boundary geometry, floor identity, and geometry revision. The pure evaluator then returns for the target zone:

- application adjacency classification: `positive`, `neutral`, or `negative`;
- nearest other zone of the same type using boundary-to-boundary tile distance, excluding the target zone itself;
- competition band: within 10, within 20, or none; and
- policy and source revisions plus the selected relationship provenance.

The relationship matrix derives complementary/neutral/conflicting from immutable policy. For application evaluation, all nearby relations at distance `<= 5` map to impacts `+20/0/-10`. Select highest absolute impact; ties choose negative, then the lowest canonical stable zone ID. Same-type zones contribute **only** competition: `-20` within 10, `-10` within 20, otherwise `0`. They do not also create a synergy impact.

## Capture and event flow

```text
H3/H5 committed topology or Zone geometry commit
  -> source revision changes
  -> direct typed spatial-context-invalidated(revisions)

Tenant H2 scheduled evaluation
  -> capture Prestige H1 snapshot + circulation + relationship + immutable policy
  -> pure recommendation calculation
  -> verify all captured source revisions
  -> Tenant H2 evaluates or defers for three days
```

Authority consumers use direct typed snapshot methods/signals, not EventBus. EventBus may project a post-commit/invalidated event to UI after authority consumers finish. Snapshots are immutable/deep detached values; Node references and scene queries are prohibited after capture.

## Persistence and load

This handoff introduces no independent mutable save authority. Policy content is versioned assets; committed zone/district/Prestige state retains the references/revisions required by its own handoffs. Derived circulation, relationship, and recommendation results are recomputed after V2's atomic restoration from restored committed authorities.

During V2 staging, Tenant H2 must not evaluate. After all Zone/District/Prestige sources stage successfully, source authorities rebuild derived snapshots; `game_loaded` exposes the session. A missing or incompatible policy/content revision leaves tenant evaluation unavailable with diagnostics rather than silently substituting a value.

## Failure behavior

| Condition | Required result |
|---|---|
| H3/H5 graph or vertical-link snapshot missing/stale | `CIRCULATION_CONTEXT_UNAVAILABLE`; Tenant H2 defers. |
| Zone geometry/revision missing/stale | `RELATIONSHIP_CONTEXT_UNAVAILABLE`; Tenant H2 defers. |
| Prestige policy/ceiling unavailable | Existing H2 Prestige diagnostic; Tenant H2 defers. |
| Policy malformed/unknown factor or matrix relation | `SPATIAL_POLICY_UNAVAILABLE`; no recommendation/evaluation. |
| Source changes before H2 bind | H2 rejects stale context and reschedules; no bind. |

## Acceptance requirements

- The recommendation uses exact fixed-point arithmetic and never exceeds the approved Prestige ceiling.
- F1 calculates with factor 1.05; upper/underground caps are respected.
- Every relationship/competition result is independent of dictionary/input order and contains reproducible provenance.
- Same-type competition never double-counts as application synergy.
- Accessibility reads only committed topology/link facts; no live agent, visitor-load, or legacy-navigation fallback is used.
- Missing/stale sources cause no Tenant binding and follow H2's three-day deferral rule.
- Derived results are never serialized as mutable authority state and rebuild after a successful V2 load.

## Required implementation skills

Before implementation, load `resource-pattern`, `dependency-injection`, `event-bus`, `save-load`, and `godot-testing`. H5/H3 implementers must additionally load the relevant 3D/navigation skill before exposing the committed pedestrian topology contract.
