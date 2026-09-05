# Visitor Handoff Index

This program defines the approved MVP behavior of realized visitors after District Layout H8 arrival allocation. It is limited to public-corridor movement and parcel-door service proxies; it does not approve tenant interiors, tenant economics, or visitor contributions to Prestige.

## Handoffs

| Order | Handoff | Status | Scope |
|---:|---|---|---|
| 01 | [Service Proxy and Operational Metrics](01_service_proxy_and_operational_metrics.md) | Approved — 2026-09-05 (delegated architecture authority) | Corridor-only target selection, navigation, proxy queues, non-economic purchase outcomes, exit behavior, and operational visitor metrics. |

## Program rules

- District Layout H8 remains authoritative for demand separation, pedestrian arrival-source eligibility and selection, realization, exit-source selection, and the global 200-active-visitor cap.
- Tenant H1-H3 remain authoritative for tenant identity, occupancy, candidate policy, and rent/application evaluation. This program consumes read-only tenant-facing proxy facts and does not write tenant lifecycle state.
- Tenant interiors, furnishing, real service capacity, tenant revenue, viability, satisfaction, and Prestige inputs require separate approved handoffs. [Future Tenant Architecture Topics](../tenant/_future_topics.md) remains the design-preparation register for those concerns.
- Any change to an approved handoff requires architecture review and user approval before implementation.
