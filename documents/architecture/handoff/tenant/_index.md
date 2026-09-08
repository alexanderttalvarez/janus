# Tenant Handoff Index

This program defines authoritative tenancy from parcel occupancy through later business performance. It does not reopen Zone, Economy, Progression, Visitor, or Save authority boundaries.

**Current revision:** 2026-09-08. [Current MVP](../../../game_design/current_mvp.md), ADR 33 and `mvp/H3` apply. Approved `tenant_interiors/H3` amends H1-H3 selection/provenance for its detached stage; its live Service/save integration remains gated by draft H4/H5. Uniform selection here remains foundation-only, not Product selection authority.

**Follow-on review, 2026-09-08:** The preceding revision records the earlier consistency pass. [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md) separately architecture-approves interior H4/H5. Foundation -> detached interior H1-H3 -> H4 implementation passes -> H5 candidate cutover passes -> Product acceptance; external Gate R is separate. Live Tenant/Service/save integration requires those passes, not approval alone. Implementation/cutover remain NOT VERIFIED; Product acceptance/Gate R remain PENDING.

## Handoffs

| Order | Handoff | Status | Scope |
|---:|---|---|---|
| 01 | [Occupancy and Daily Rent](01_occupancy_and_daily_rent.md) | Approved — 2026-09-05 | Seeded legal candidate selection, lifecycle occupancy, atomic parcel binding, daily-rent input, and V2 tenant persistence. |
| 02 | [Rent Policy and Application Evaluation](02_rent_policy_and_application_evaluation.md) | Approved — 2026-09-05 | Zone-owned rent, recommendation, full score evaluation, candidate-tier cap, retry policy, and presentation read/intent contracts. |
| 03 | [Candidate Policy and Catalog](03_candidate_policy_and_catalog.md) | Approved — 2026-09-05 (delegated architecture authority) | Immutable MVP candidate profiles, uniform seeded selection, Selectivity, catalog provenance, and compatibility. |

## Program rules

- Implement only approved handoffs in order.
- H1 requires implemented Zone stable-parcel/transaction authority, Time calendar authority, Economy H1, and District H9 V2 orchestration.
- H2 requires H1 plus revisioned Prestige, circulation, synergy, competition, and rent-policy input snapshots; missing inputs defer evaluation rather than fabricate values.
- `DEBUG_IMMEDIATE` remains `zone_parcels/H2`'s independent debug contract; lifecycle mode must not mutate it.
- H2 and `spatial_evaluation/H1` already approve score inputs/rent defaults; `presentation/H1` owns their UI intents/read views. Performance/spending/closure/upgrades/satisfaction and tenant-derived Prestige remain deferred. See [Future Tenant Architecture Topics](_future_topics.md); no draft is approved by reference.
- Any change to an approved handoff requires architecture review and user approval before implementation.
