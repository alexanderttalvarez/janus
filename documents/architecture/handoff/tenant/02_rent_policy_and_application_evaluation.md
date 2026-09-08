# Tenant Handoff 02 — Rent Policy and Application Evaluation

**Status:** Approved — 2026-09-05
**Prepared:** 2026-09-05
**Implementation order:** 2 of 3 — after Tenant Handoff 01

## Purpose

**Revision:** 2026-09-08 delegated consistency pass. [Element 06](../../../game_design/elements/06_tenant_shop_system.md) supplies exhaustive fixed-point premium bands, zero-recommendation behavior and canonical-elevation Location Score; element 03 supplies recommendation flooring and element 14 the same-floor relation metric. ADR 33 and staged `tenant_interiors/H3` apply. These explicitly supersede the rounded percentage wording below; no extra calculator authority is introduced.

Replace Tenant H1's eligibility-only automatic application with the designed, transparent application evaluation loop. Players set a committed daily rent for each zone, view the calculated recommendation and score inputs, and influence whether seeded candidates apply. This handoff establishes score snapshots and rate policy without implementing tenant performance, visitor spending, closure, or Prestige contribution.

## Authoritative sources

- [Tenant Handoff 01 — Occupancy and Daily Rent](01_occupancy_and_daily_rent.md)
- [Economy design](../../../game_design/elements/03_economy.md)
- [Tenant & Shop System design](../../../game_design/elements/06_tenant_shop_system.md)
- [Decision 22 — Prestige Calculation Architecture](../../decisions/22_prestige_calculation_architecture.md)
- [Decision 14 — UI Architecture](../../decisions/14_ui_architecture.md)
- [Economy Handoff 01 — Transaction Authority and Policy Boundary](../economy/01_transaction_authority_and_policy_boundary.md)
- [District Handoff 09 — Save/Load V2 and District Persistence](../district_layout/09_save_load_v2.md)

## Scope

- Committed, revisioned per-zone daily-rent state owned by `ZoneManager`.
- Immutable rent-recommendation policy and application-evaluation policy snapshots.
- Candidate-tier selection capped by the current supported Prestige tier.
- The complete documented application score and threshold evaluation.
- Detached, revisioned input snapshots from Prestige, zone/district geometry/circulation, and adjacency/competition facts.
- Exact application evaluation outcomes: bind/lock on pass; no binding and three-day retry on decline or unavailable input.
- Rent-rate intent/read model for UI, score-breakdown/read model, V2 persistence, diagnostics, and deterministic tests.

## Explicit non-goals

- Changing H1 candidate seed, subtype legality/graph-coloring, lifecycle timing after a passed application, bind atomicity, daily-rent credit ownership, or debug assignment mode.
- Tenant revenue, visitor transactions, tenant quality/satisfaction, viability, closure, eviction, upgrades, or Prestige input from tenants.
- A new Prestige calculation handoff, changes to Prestige's official/trend cadence, or a fallback Prestige tier.
- Construction pricing, deposits, refunds, notifications, financial-report UI, localization copy, or visual tenant interiors.
- Hard-coded production candidate-tier weights, subtype catalog tuning, or an arbitrary fallback rate when a required policy/input is unavailable.

## FACTS

- Rent is a player-set daily rate per zone in Kreds/tile/day. Daily Open-tenant rent is current zone rate × parcel tiles, rounded down to integer Kreds.
- A new zone starts at its current calculated Recommended Rent. Players may set any non-negative rate; changes are non-retroactive and apply to the next evaluation and daily settlement.
- The documented score is `Prestige Match + Rent Attractiveness + Location Score + Synergy Bonus + Competition Penalty`. Threshold is `80 + (tier - 1) × 10 + Selectivity`.
- A candidate tier is seeded-random from immutable policy but may not exceed the currently supported Prestige tier.
- A passed candidate follows H1 binding, one-week lock, construction, and Open flow. A failed candidate creates no tenant or parcel binding and retries after three simulation days.
- Economy owns money; Tenant/Zone/UI never credit rent themselves.

## ASSUMPTIONS

- Daily-rate values are represented in fixed-point centi-Kreds per tile/day so the documented fractional recommendation can be displayed and persisted without floating-point ambiguity. Settlement uses the approved floor-to-whole-Kred result after multiplying by parcel tiles.
- Candidate tier distribution is authored as immutable policy. H2 defines its cap and consumption contract, but content must provide explicit weights/selection policy before production tuning; implementation tests may inject a fixture policy.
- Every score source can provide a detached snapshot keyed to the exact parcel/zone and authoritative calendar identity. Missing or stale input never receives a guessed score.

## Resolved Inputs and Deferred Work

- Tenant H3 supplies the foundation catalogue; staged `tenant_interiors/H1-H3` and element 20 supply interior content/weights. Tier 1 is explicit authored initial content, not a runtime fallback.
- `spatial_evaluation/H1` supplies required circulation/relations after `prestige/H1`; missing implementation is a predecessor gate, not an unresolved design choice.
- `prestige/H1-H2` define initial Empty Lot, ceiling and monthly baseline. `presentation/H1` exposes rent/score details in the single primary panel.
- Satisfaction, revenue and viability remain explicitly deferred. No current evaluation depends on them.

## Ownership and dependency direction

| Owner | Owns | Must not own |
|---|---|---|
| `ZoneManager` | Committed zone rate, rate revision, zone creation initialization, zone/parcel geometry and configuration persistence. | Score calculation, Prestige, candidate RNG, tenant state, balance. |
| Rent policy content | Rent ceiling table and formula constants/factors; immutable policy revision. | Per-zone chosen rate, UI state, balances. |
| `TenantManager` | Candidate seed/ordinal/profile, evaluation scheduling, score aggregation from snapshots, threshold decision, application outcome, lifecycle transition. | Zone-rate writes, source-factor calculation ownership, balance. |
| `PrestigeManager` | Official supported tier and rent-ceiling-facing snapshot/revision. | Candidate selection, zone rates, tenant application decision. |
| District/zone circulation source | Detached floor, stairs/elevator, circulation, adjacency, and competition facts/revisions. | Tenant state, rate mutation, Prestige calculation. |
| UI | Submit rate-change intent; render committed rate, recommendation, score result, and diagnostics. | Direct writes to Zone/Tenant/Prestige/Economy. |
| `EconomyManager` | Daily balance credit from H1 active-rent snapshot. | Rate UI, score, candidate decision. |

```text
Immutable policy + Prestige snapshot + zone/district context snapshot
  -> TenantManager evaluates persisted seeded candidate
  -> pass: existing H1 Zone/Tenant atomic bind
  -> fail/defer: Tenant schedule update only

UI rate intent -> ZoneManager rate commit -> post-commit rate event
Zone current rate + H1 Open tenant snapshot -> Economy daily settlement
```

## Rate policy and mutation

### Stored zone rate

Each committed zone gains a `daily_rent_rate_centi_kreds` value and a rate/configuration revision owned solely by `ZoneManager`. The rate applies uniformly to every parcel/tenant in that zone. It is not duplicated as a mutable tenant field.

On new-zone creation, ZoneManager requests an immutable recommendation context. If all required recommendation policy and input revisions validate, it initializes the stored rate to the calculated recommended rate in centi-Kreds. If not, the zone's rate state is `PENDING_RECOMMENDATION`; application evaluation is deferred and the UI presents structured diagnostics. No zero, prior-zone, global-default, or guessed rate may be substituted.

### Player rate intent

A rate-change intent names stable zone ID, desired non-negative fixed-point rate, expected zone-rate revision, and UI/request reference. ZoneManager validates zone existence, ownership, revision, and representation, then atomically commits the new rate and increments its revision. It is valid during every H1 lifecycle state, including Open.

The rate change has no Economy quote/reservation because setting rent is not a player-paid action. It does not change an already consumed application evaluation or an already settled day. It is visible to the next evaluation captured after commit and the next authoritative daily settlement after commit.

## Immutable evaluation inputs

At a scheduled H1 vacancy evaluation, TenantManager captures one detached `ApplicationEvaluationContext`; it is not allowed to query live Nodes during calculation. It contains stable IDs, calendar identity, and revisions for:

| Input | Required facts | Source owner |
|---|---|---|
| Candidate profile | Candidate subtype, seeded tier, Selectivity, profile-policy revision. | Tenant candidate policy / TenantManager. |
| Prestige | Current official supported tier and rent ceiling applicable to that tier. | PrestigeManager + immutable rent policy. |
| Rate/recommendation | Committed zone rate, recommended rate, and their revisions. | ZoneManager + policy/context calculator. |
| Location | Parcel/zone floor level and presence of elevator/stairs on that floor. | District/zone circulation snapshot source. |
| Synergy | Adjacent-zone relation classified complementary, neutral, or clashing. | Adjacency/synergy snapshot source. |
| Competition | Nearest same-zone-type distance band: within 10 tiles, within 20 tiles, or neither. | Zone spatial snapshot source. |
| Subtype legality | Current valid parcel, type/size eligibility, and edge-adjacent subtype colors. | ZoneManager + pure assigner. |

The context must be internally revision-consistent. A missing/stale/contradictory source creates `EVALUATION_INPUT_UNAVAILABLE`, binds nothing, and schedules the next evaluation after three simulation days.

## Candidate and score evaluation

Tenant H2 retains H1's persisted session seed and per-parcel evaluation ordinal. At every due evaluation it derives a new candidate profile deterministically from those values and immutable candidate policy. The profile's tier must be less than or equal to the captured supported Prestige tier; no candidate is silently down-tiered after selection. A candidate policy with no eligible tier is an input-unavailable outcome, not a fallback Tier 1 candidate.

The documented formulas are applied exactly from the captured context:

```text
score = prestige_match + rent_attractiveness + location_score
      + synergy_bonus + competition_penalty
threshold = 80 + (candidate_tier - 1) * 10 + selectivity
```

- Prestige Match: `+100` when supported; `-50` one tier below; two or more tiers below is a hard decline.
- Rent Attractiveness: use element 06's exhaustive integer inequalities in order; +30 at/below recommendation, +20 through 10% premium, +10 through 20%, 0 through 30%, otherwise hard decline. For zero recommendation, only zero rent gets +30; any positive rent hard-declines. No percentage rounding gaps.
- Location Score uses element 06 with `abs(signed_elevation)`; Synergy/Competition use element 14's same-floor Manhattan boundary gap. Source snapshots provide facts, not scores. Unsupported-tier Prestige penalties are defensive only; normal candidate selection never generates them.
- A hard decline does not bypass diagnostics and follows the normal three-day retry.

A passing score prepares the existing H1 candidate subtype selection and atomic Zone/Tenant bind. Before bind, the coordinator revalidates the parcel/zone/rate/context revisions and subtype legality. Any staleness aborts the binding and reschedules; a rate or score result from an old context cannot bind a tenant.

A failed or unavailable evaluation increments the persisted parcel evaluation ordinal, records only the minimal outcome/next-due calendar identity, and creates no candidate record, tenant ID, parcel subtype assignment, or reservation. A passed bind persists the candidate profile fields required by H1 and the evaluation-context provenance necessary for diagnostics; it does not freeze rent for later daily settlement.

## Persistence and save/load

Zone V2 state persists rate representation, rate revision, and whether recommendation initialization is pending. Tenant V2 state persists session seed, per-parcel evaluation ordinal, next evaluation identities, required passed-candidate profile fields, and evaluation-policy provenance. It excludes transient score UI, unbound rejected candidate objects, live snapshots, and computed presentation text.

On restore, Zone restores validated committed rates with its zone state before Tenant restores schedules/records. Tenant then validates bound candidate references against zone/parcel state. SaveManager rejects the complete V2 load if a stored rate is invalid, an evaluation state has no valid parcel, a bound candidate exceeds its persisted policy/context constraints, or required cross-authority revisions cannot stage consistently. Economy continues to restore its idempotence markers before future settlement.

## Events, UI, and diagnostics

Post-commit events include `zone_rent_initialized`, `zone_rent_changed`, `tenant_application_evaluated`, and existing H1 lifecycle events. Evaluation events contain stable IDs, calendar identity, policy/input revisions, component scores/hard-decline reason, threshold, outcome, next evaluation date where applicable, and no mutable references.

The H2 UI is an intent/read consumer only: it displays committed zone rate, recommendation, component breakdown, candidate result when one is committed, next evaluation date, and diagnostics; it submits rate-change intents. Notification delivery is explicitly out of scope.

Minimum diagnostics: `ZONE_RATE_PENDING`, `RATE_REPRESENTATION_INVALID`, `RATE_REVISION_STALE`, `RECOMMENDATION_INPUT_UNAVAILABLE`, `EVALUATION_INPUT_UNAVAILABLE`, `CANDIDATE_TIER_POLICY_UNAVAILABLE`, `PRESTIGE_TIER_UNAVAILABLE`, `HARD_DECLINE_PRESTIGE`, `HARD_DECLINE_RENT`, `APPLICATION_SCORE_BELOW_THRESHOLD`, and `APPLICATION_BIND_STALE`.

## Acceptance requirements

- New zones initialize to their exact current recommendation only with a valid immutable context; otherwise no fallback rate/evaluation occurs.
- Any non-negative player rate is accepted only through ZoneManager's revisioned intent, in every H1 lifecycle state, and affects neither past evaluation nor past settlement.
- Replaying/save-loading a due evaluation produces the same candidate profile and decision for the same seed, parcel ID, ordinal, policy, and context.
- Candidate tier never exceeds captured supported Prestige tier.
- All documented score components, hard-decline rules, and threshold formula are evaluated from revisioned facts.
- Failed/missing/stale evaluations bind no tenant and retry in three simulation days; passed evaluations use H1's atomic bind protocol.
- Economy sees the current committed zone rate only through H1's Open-tenant rent snapshot and cannot be credited twice.
- V2 load rejects invalid rate/evaluation cross-references without partially restoring the session.
- H2 adds no visitor revenue, viability, Prestige contribution, notification, construction-cost, or interior behavior.

## Required implementation skills

Before implementation, load `resource-pattern`, `dependency-injection`, `event-bus`, `save-load`, `godot-ui`, and `godot-testing`. H2 also depends on the existing Zone/District transaction/revision patterns; implementation must not bypass them with direct mutable cross-manager reads.
