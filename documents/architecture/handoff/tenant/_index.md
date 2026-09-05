# Tenant Handoff Index

This program defines authoritative tenancy from parcel occupancy through later business performance. It does not reopen Zone, Economy, Progression, Visitor, or Save authority boundaries.

## Handoffs

| Order | Handoff | Status | Scope |
|---:|---|---|---|
| 01 | [Occupancy and Daily Rent](01_occupancy_and_daily_rent.md) | Approved — 2026-09-05 | Seeded legal candidate selection, lifecycle occupancy, atomic parcel binding, daily-rent input, and V2 tenant persistence. |
| 02 | [Rent Policy and Application Evaluation](02_rent_policy_and_application_evaluation.md) | Approved — 2026-09-05 | Zone-owned rent, recommendation, full score evaluation, candidate-tier cap, retry policy, and presentation read/intent contracts. |

## Program rules

- Implement only approved handoffs in order.
- H1 requires implemented Zone stable-parcel/transaction authority, Time calendar authority, Economy H1, and District H9 V2 orchestration.
- H2 requires H1 plus revisioned Prestige, circulation, synergy, competition, and rent-policy input snapshots; missing inputs defer evaluation rather than fabricate values.
- `DEBUG_IMMEDIATE` remains Handoff 02's independent debug contract; lifecycle mode must not mutate it.
- Later tenant handoffs must separately approve score inputs, rent UI/defaults, performance/visitor spending, closure/eviction, Prestige, notifications, visuals, and construction economics. See [Future Tenant Architecture Topics](_future_topics.md) for deferred design-preparation items; these are not approved features or implementation work.
- Any change to an approved handoff requires architecture review and user approval before implementation.
