# Tenant Interiors Handoff 03 — Interior Lifecycle and Candidate Selection

**Status:** Approved — 2026-09-06  
**Implementation order:** 3 of 5

**Revision:** 2026-09-08 delegated consistency pass. [Current MVP](../../../game_design/current_mvp.md), elements 01/06/20 and ADR 33 apply. The [readiness matrix](_index.md) permits detached candidate/lifecycle/local-schema proofs, not live Service activation or session schema cutover. `TenantServiceManager` references below describe gated future integration. Adjacency uses customer-facing subtype/theme identity; spatial ratings/default content follow element 20. Any eligible indeterminate profile defers the whole draw with the existing unavailable/retry outcome, not biased selection from a partial feasible pool.

## Purpose

**Follow-on review, 2026-09-08:** The revision above records the earlier consistency pass. [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md) separately architecture-approves H4/H5. H3 remains detached-first after foundation and H1/H2; Open-to-Service activation and whole-session persistence require H4 implementation passes and H5 candidate cutover passes, then [Product acceptance](../mvp/04_product_delivery_and_acceptance.md). Implementation/cutover remain NOT VERIFIED; Product acceptance and separate external Gate R remain PENDING. Approval alone does not integrate the live path.

Amend Tenant H1–H3 so candidates come from physically feasible operational profiles using deterministic 6/3/1 weighting. Keep commercial evaluation separate, bind final layout provenance to tenants, and preserve the existing construction-to-Open/rent timeline and application cadence.

## Supersession

This supersedes Tenant H3 uniform selection and generic area-only legality. It preserves tenant session seed, scheduled evaluation identity/ordinal, canonical profile order, tier cap, edge-adjacency legality, H2 commercial formula/cadence/outcome semantics, Zone-only occupancy writes, atomic bind, and unchanged `DEBUG_IMMEDIATE` behavior.

## Ownership

| Owner | Owns | Must not own |
|---|---|---|
| TenantManager | Selection, lifecycle, tenant records, ordinals, operational-profile/layout provenance, revision. | Geometry, content mutation, runtime service, visitors, balance. |
| ZoneManager | Parcel/door/queue-envelope facts and occupancy/subtype binding. | Candidate RNG/lifecycle. |
| H1 planner | Detached fit/layout result. | Candidate choice/commit. |
| TenantServiceManager | Operational availability after Open. | Tenant lifecycle/rent eligibility. |
| H2 commercial evaluator | Existing score/threshold/cadence. | Physical tickets. |

## Candidate content amendment

Each preserved tenant profile ID gains one required operational-profile reference. Cuisine/brand/theme remains candidate identity; many profiles may reference one operational profile. Session validates complete candidate/interior bundle before Tenant readiness. No name-based remapping exists.

## Scheduled evaluation and compatibility

Geometry, topology, unlock, or content revision invalidates/recomputes only the detached compatibility snapshot. It never initiates an application evaluation or advances its ordinal. Normal application evaluation occurs solely at Tenant H2's scheduled boundary; decline, unavailable, and retry cadence remain exactly H2. Debug behavior remains exactly the approved exception.

At a due evaluation Tenant captures one immutable bundle: parcel/core/annex/frontage/doors/exclusive envelope/neighbors; tier/unlocks; candidate/interior/visitor/planning policies; topology revision; session seed, parcel ID, evaluation identity/ordinal. Zone geometry is already published after stable Phase A parity.

## Bounded feasible pool

Before acquiring any shared mutation/save gate, Tenant filters by zone type, tier/unlock, and approved edge-adjacency, then invokes H1 Phase B once per legal tenant/profile variation. Planning policy must provide positive `max_phase_b_variations_per_evaluation` and `aggregate_phase_b_work_budget`; Session rejects content whose legal catalog can exceed the variation cap. Every planner work unit counts toward the aggregate budget. Budget exhaustion produces `SEARCH_INDETERMINATE`, never partial-pool selection.

Only `VALID` plans survive. Any one `SEARCH_INDETERMINATE` result invalidates the complete evaluation bundle and pool, not only that variation; Tenant never selects from the remaining entries. An empty conclusive pool is also a Tenant H2 unavailable outcome. Any one Phase B `CONTENT_INVALID` result likewise invalidates the complete evaluation bundle and pool, and Tenant never selects from the remaining entries. It commits the exact Tenant H2 unavailable outcome with diagnostic `CONTENT_INVALID`: advance the persisted per-parcel evaluation ordinal once, schedule the three-simulation-day retry, persist the diagnostic and evaluation provenance, advance Tenant revision, emit exactly one approved `tenant_application_evaluated` fact, and perform no Zone write. Session readiness validation should prevent this result, so its occurrence is a technical/content-integrity fault. These outcomes are not geometry mutation. Every feasible profile in a wholly conclusive, content-valid pool retains its detached best layout/rating.

## Prospective variation identity

Phase B receives a plan-local immutable variation key framed through the approved canonical stable-ID policy from:

- domain `tenant_interior_variation_v1`;
- tenant session seed;
- parcel ID;
- scheduled evaluation identity and ordinal;
- tenant profile ID and candidate catalog revision; and
- operational profile ID and planning-policy revision.

It consumes no tenant ID, persistent counter, or collection index. Failed/declined evaluations allocate no durable identity. A successful bind retains this exact variation key in Tenant provenance; fixture IDs/fingerprint derive from it and stable Zone identities. Replanning identical provenance reproduces the same manifest.

## Exact weighted selection

Sort feasible entries by canonical tenant profile ID. Their ticket intervals are contiguous in that order with Excellent=6, Good=3, Acceptable=1. Let `T` be total tickets.

For draw counter `k` beginning at zero, hash canonical UTF-8 RFC 8785 JSON containing exactly:

```text
{"candidate_catalog_revision":<int>,"domain":"tenant_profile_weighted_draw_v1",
 "evaluation_ordinal":<int>,"parcel_id":<string>,"planning_policy_revision":<int>,
 "pool_fingerprint":<lowercase-sha256>,"session_seed":<canonical-seed>,"draw_counter":<int>}
```

Actual canonical JSON has no whitespace and RFC 8785 key order; the multiline display is descriptive only. Interpret SHA-256 digest as an unsigned big-endian 256-bit integer `n`. Let `L = floor(2^256 / T) × T`; reject `n >= L`, increment `k`, and rehash. Otherwise ticket `n mod T` selects its interval. This prevents modulo bias and is collection-order independent. `pool_fingerprint` hashes the ordered profile IDs, ratings, ticket counts, Phase B fingerprints, and source revisions with H1's canonical fingerprint contract.

Selectivity preserves the approved range `-10..20`. For Selectivity draw counter `draw_counter` beginning at integer zero, hash the UTF-8 encoding of RFC 8785 canonical JSON containing exactly these record keys and types: `candidate_catalog_revision` <int>, `domain` <string literal `tenant_selectivity_v1`>, `draw_counter` <int starting 0>, `evaluation_ordinal` <int>, `parcel_id` <string>, `planning_policy_revision` <int>, `selected_profile_id` <string>, `selected_variation_key` <string>, and `session_seed` <the same canonical seed scalar used by the weighted draw>. Interpret the SHA-256 digest as an unsigned big-endian 256-bit integer `n`. Let `L31 = floor(2^256 / 31) × 31`; reject `n >= L31`, increment `draw_counter`, and hash the new canonical record. Otherwise `selectivity = -10 + (n mod 31)`. This Selectivity draw never reuses the profile-draw digest or counter and does not depend on enumeration position. Physical rating/Selectivity never alter the commercial H2 formula beyond the already-approved Selectivity input.

## Outcome and transaction boundaries

A due evaluation has two separated commits:

1. **Tenant-only evaluation outcome.** `SEARCH_INDETERMINATE`, `CONTENT_INVALID`, no feasible profile, commercial decline, or a stale/rejected bind attempt commits the exact Tenant H2 unavailable/decline outcome: advances the persisted per-parcel evaluation ordinal once, schedules the three-simulation-day retry, persists diagnostic/provenance, advances Tenant revision, and emits exactly one approved `tenant_application_evaluated` fact. It never writes Zone.
2. **Successful Zone/Tenant bind.** Only a commercially passed, fully prepared candidate enters the existing atomic bind. Revalidation covers vacancy, geometry/core/annex, doors/proxy/envelope/minimum, edge-adjacent subtype, content, topology, variation key, and layout fingerprint. Failure before the bind commit writes neither Zone nor the successful Tenant record; control returns to the Tenant-only unavailable outcome above if the scheduled evaluation identity is still current. Success retains the source evaluation ordinal in candidate and Tenant provenance and does not advance the persisted per-parcel evaluation ordinal through a fabricated success path. It does not also emit an unavailable outcome.

Thus Phase B mismatch/staleness blocks only the candidate/bind/rebuild transaction and never rolls back published Zone geometry or leaves a due evaluation immediately retriggerable.

## Final layout provenance

Selected candidate carries variation key, operational/content/planning revisions, stable primary parcel-door proxy ID, canonical fixture manifest, layout fingerprint, capacity summary, assigned envelope IDs, rating, captured Zone/topology revisions. It is candidate data until bind and exposes no service/projection before Open. Zone stores occupancy/customer-facing subtype only; Tenant stores lifecycle/interior provenance. Manifest is derived.

## Construction, Open, and service availability

- ExclusivityLocked/Constructing retain provenance but expose no service.
- Existing deadline transitions Tenant to Open/rent-eligible exactly as before.
- Open does not imply service availability.
- TenantServiceManager regenerates/fingerprint-checks and commits `OPERATIONAL` or `SERVICE_UNAVAILABLE` independently.
- Stale/missing layout never delays Open, changes rent, or invokes proxy fallback.
- Same provenance producing another fingerprint is a compatibility defect; during load validation it rejects the candidate session.

## Compatibility snapshot

Tenant publishes detached parcel compatibility with independent source (`AVAILABLE/STALE/UNAVAILABLE`) and suitability (`SUITABLE/UNSUITABLE/INDETERMINATE` when available). It includes parcel/zone IDs/revisions, all compatible profile IDs/ratings, canonical top three ordered by rating then profile ID, diagnostics, reevaluation identity. Presentation does not recompute it. It is derived and normally not persisted. Compatibility events emit only after Tenant commits a revised snapshot; source events merely invalidate inputs.

## Current Tenant schema

This handoff normatively requires `state_schema_id = "tenant_operational_interior"` and integer `state_schema_version = 1`, matching the Product MVP save contract. It preserves all Tenant H1/H2 current fields and adds exactly: operational profile ID/revision, variation key, candidate-catalog revision, interior-planning-policy ID/revision, service-policy ID/revision, primary proxy ID, assigned queue-envelope IDs, layout fingerprint, rating, and captured Zone/topology revisions. Unknown extra keys and missing/wrongly typed fields reject in detached owner validation.

Full fixture manifests regenerate only from current provenance. Missing/incompatible schema/content, illegal binding, or fingerprint mismatch rejects the whole load before authority import. Visual references are never persisted; no older snapshot transforms.

## Events

Extended lifecycle/evaluation envelopes carry detached provenance/diagnostics. Operational availability is emitted by TenantServiceManager, not TenantManager. No event commands another authority. Atomic bind follows the approved shared commit-envelope and protected synchronous notification protocol.

## Acceptance requirements

- Phase B work is detached, aggregate-bounded, once per canonical variation; any `SEARCH_INDETERMINATE` or `CONTENT_INVALID` invalidates the complete pool and no partial pool is selected.
- Exact 6/3/1 draw and independent Selectivity are deterministic and unbiased.
- Physical rating does not alter commercial results.
- Revision changes refresh compatibility but never bypass H2 cadence.
- Every due failed/unavailable evaluation advances the persisted per-parcel ordinal and schedules retry exactly once; successful bind retains its source ordinal without advancing it and has no duplicate outcome.
- Bind prevents stale provenance; Zone remains published on Phase B/bind failure.
- Open/rent timing is byte-compatible with Tenant H1 regardless of service readiness.
- Restore reproduces manifest/fingerprint or rejects before import.
- No Economy, viability, satisfaction, demand, or Prestige mutation occurs.

## Required tests

- Feasible/indeterminate/content-invalid/aggregate-budget filtering, whole-pool invalidation, exact unavailable diagnostics, and no-partial-pool selection.
- Weighted interval/rejection/hash goldens, collection permutations, every-profile chance, independent Selectivity vectors.
- Revision invalidation versus scheduled-cadence tests.
- Prospective variation identity, no persistent-ID consumption, stable fixture/fingerprint reproduction.
- Every unavailable/decline/stale-bind branch: ordinal/retry/event exactly once and no Zone write, including `CONTENT_INVALID` as a technical/content-integrity fault.
- Successful atomic bind, retained source evaluation ordinal with no per-parcel ordinal advance, and pre-commit fault injection.
- Open/rent equivalence under valid/unavailable/fingerprint-mismatch service.
- Exact Tenant discriminator, key/type, incompatible/older/missing-schema rejection.
- Compatibility snapshot source/suitability/top-three ordering and event timing.

## Required implementation skills

`resource-pattern`, `godot-testing`, `save-load`, `dependency-injection`, and `event-bus` for notifications only.
