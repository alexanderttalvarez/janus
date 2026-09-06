# Tenant Interiors Handoff 03 — Interior Lifecycle and Candidate Selection

**Status:** Draft — awaiting architecture approval  
**Implementation order:** 3 of 5

## Purpose

Amend Tenant H1–H3 so candidates come from physically feasible operational profiles using deterministic 6/3/1 weighting. Keep commercial application evaluation separate, bind final layout provenance to tenants, and preserve the existing construction-to-Open/rent timeline.

## Supersession

This supersedes Tenant H3's uniform selection and generic area-only legality. It preserves the tenant seed/evaluation ordinal, canonical profile order, tier cap, adjacency legality, H2 commercial formula/cadence, Zone-only occupancy writes, atomic bind, and unchanged `DEBUG_IMMEDIATE` behavior.

## Ownership

| Owner | Owns | Must not own |
|---|---|---|
| TenantManager | Selection, lifecycle, tenant records, ordinals, operational-profile/layout provenance, revision. | Geometry, content mutation, runtime service, visitors, balance. |
| ZoneManager | Parcel/door/queue-envelope facts and occupancy/subtype binding. | Candidate RNG/lifecycle. |
| H1 planner | Detached fit/layout result. | Candidate choice/commit. |
| TenantServiceManager | Operational availability after tenant Open. | Tenant lifecycle or rent eligibility. |
| H2 commercial evaluator | Existing score/threshold. | Physical tickets. |

## Candidate content amendment

Each preserved tenant profile ID gains one required operational-profile reference. Cuisine/brand/theme remains candidate identity; many profiles may reference one operational profile. Session validates the complete candidate/interior bundle before Tenant readiness. No name-based remapping exists.

## Feasible pool

At each due evaluation, Tenant captures one immutable bundle: parcel/core/annex/frontage/physical doors/exclusive queue envelope/neighbors; tier/unlocks; candidate/interior/visitor/planning policies; topology revision; seed, parcel ID, and ordinal. Zone geometry is already published after stable Phase A rerun parity.

It filters by zone type, tier/unlock, and adjacency, then invokes H1 Phase B once per tenant/profile variation inside the candidate/bind/rebuild transaction. Only `VALID` plans survive. `SEARCH_INDETERMINATE` defers evaluation as unavailable; it does not mark geometry unsuitable. Every feasible profile retains its detached best layout/rating. Phase B mismatch or staleness aborts only that Tenant transaction and never rolls back or blocks the already-published Zone geometry.

An empty conclusive pool publishes `NO_FEASIBLE_OPERATIONAL_PROFILE`, binds nothing, and exposes an unsuitable-unit snapshot. Geometry/topology/unlock/content revision changes trigger reevaluation; unchanged scheduled retries reproduce the same pool/diagnostic until the ordinal is legitimately advanced by candidate policy.

## Weighted selection

Canonical profile order plus deterministic seed inputs produce a weighted draw:

- Excellent: 6 tickets
- Good: 3 tickets
- Acceptable: 1 ticket

Seed inputs include tenant session seed, parcel ID, evaluation ordinal, candidate catalog revision, and planning-policy revision. Selectivity remains an independent deterministic `-10..20` value. Physical rating never enters commercial H2 score; the selected candidate proceeds through normal commercial evaluation.

## Final layout provenance

The selected candidate carries operational/content/planning revisions, stable primary parcel-door proxy ID, canonical fixture manifest, layout fingerprint, capacity summary, assigned queue-envelope position IDs, rating, and captured Zone/topology revisions.

This is candidate data until bind. It provides no service or projection before tenant Open. Durable fixture IDs exist because H1 Phase B runs only after stable parcel and physical-door allocation.

## Atomic bind

The existing Zone/Tenant candidate adds operational profile, interior-policy revisions, layout fingerprint, source revisions, and primary operational proxy. Revalidation covers vacancy, geometry/core/annex, doors/proxy, exclusive queue envelope, queue minimum, neighbor subtype, content, topology, and fingerprint. Failure commits neither authority.

Zone stores occupancy and customer-facing subtype only; Tenant stores lifecycle/interior provenance. The layout manifest is derived from those facts.

## Construction, Open, and service availability

Tenant H1's lifecycle and Economy contract remain unchanged:

- ExclusivityLocked/Constructing retain provenance but expose no service.
- At the existing deadline, Tenant transitions to Open and becomes rent-eligible exactly as before.
- Open does not imply service availability.
- TenantServiceManager separately regenerates/fingerprint-checks the layout and commits `OPERATIONAL` or `SERVICE_UNAVAILABLE`.
- A stale/missing layout never delays Open, changes rent, or invokes proxy fallback.
- Identical provenance producing a different fingerprint is a compatibility defect and makes service unavailable; during load staging it rejects the candidate session.

This separation is required because Product MVP service remains non-economic.

## Compatibility snapshot

Tenant publishes detached parcel compatibility with two independent dimensions:

- source state: `AVAILABLE`, `STALE`, `UNAVAILABLE`;
- suitability: `SUITABLE`, `UNSUITABLE`, `INDETERMINATE` when source is available.

It includes parcel/zone IDs/revisions, all compatible profile IDs/ratings, canonical top three, diagnostics, and reevaluation identity. Presentation does not recompute it. It is derived and normally not persisted.

## Current-schema persistence

The current authority-local Tenant snapshot requires its schema discriminator, operational profile ID, candidate/interior policy revisions, primary proxy ID, and layout fingerprint while the root save remains V2.

Full fixture manifests are regenerated only from current-schema provenance. A missing or incompatible discriminator, missing content, illegal profile/parcel binding, or fingerprint mismatch rejects the whole load before staging. Visual references are never persisted, and no older snapshot is transformed.

## Events

Extended lifecycle envelopes carry detached provenance/diagnostics. Operational availability is emitted by TenantServiceManager, not TenantManager. Compatibility-change events notify presentation after source commit; no event commands another authority.

## Acceptance requirements

- Only valid Phase B plans enter the pool; indeterminate results never become unsuitable.
- 6/3/1 selection is deterministic and collection-order independent.
- Physical rating does not alter H2 commercial results.
- Empty pools expose precise diagnostics without incompatible candidate attempts.
- Bind revalidation prevents stale provenance.
- Tenant Open/rent timing is byte-for-byte compatible with Tenant H1 regardless of service readiness.
- Debug mode is unchanged.
- Restore reproduces fingerprint or atomically rejects.
- No Economy, viability, satisfaction, demand, or Prestige mutation occurs.

## Required tests

- Feasible/indeterminate filtering and diagnostics.
- Weighted boundaries, repeatability, and every-profile-has-chance fixtures.
- Commercial separation tests.
- Stable-door Phase B, once-per-variation invocation, and stale candidate/bind/rebuild transaction cases proving Zone geometry remains published.
- Open/rent equivalence under valid, unavailable, and fingerprint-mismatch service.
- Current authority-local discriminator and incompatible/older/missing-schema rejection tests.
- Source-state versus suitability read-model tests.

## Required implementation skills

`resource-pattern`, `godot-testing`, `save-load`, `dependency-injection`, and `event-bus` for notifications only.
