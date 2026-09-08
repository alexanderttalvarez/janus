# Visitor Handoff Index

This program defines the approved MVP behavior of realized visitors after District Layout H8 arrival allocation. It is limited to public-corridor movement and parcel-door service proxies; it does not approve tenant interiors, tenant economics, or visitor contributions to Prestige.

**Current revision:** 2026-09-08, delegated documentation pass. H1 is the Corridor Service Integration Gate only, with element 05's explicit foundation-only proxy admission/retry baseline and ADR 33's common session gate. [Current MVP](../../../game_design/current_mvp.md) requires later actual interior service; that runtime/cutover remains draft H4/H5. No proxy polish or fallback is authorized.

**Follow-on review, 2026-09-08:** The preceding revision records the earlier consistency pass. [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md) separately architecture-approves interior H4/H5. Preserve foundation -> detached interior H1-H3 -> H4 implementation passes -> H5 candidate cutover passes -> Product acceptance; external Gate R is separate. The foundation live path is not replaced by document approval. Implementation/cutover remain NOT VERIFIED; Product acceptance/Gate R remain PENDING.

## Handoffs

| Order | Handoff | Status | Scope |
|---:|---|---|---|
| 01 | [Service Proxy and Operational Metrics](01_service_proxy_and_operational_metrics.md) | Approved — 2026-09-05 (delegated architecture authority) | Corridor-only target selection, navigation, proxy queues, non-economic purchase outcomes, exit behavior, and operational visitor metrics. |

## Program rules

- District Layout H8 remains authoritative for demand separation, pedestrian arrival-source eligibility and selection, realization, exit-source selection, and the global 200-active-visitor cap.
- Tenant H1-H3 remain authoritative for tenant identity, occupancy, candidate policy, and rent/application evaluation. This program consumes read-only tenant-facing proxy facts and does not write tenant lifecycle state.
- `tenant_interiors/H1-H3` retain detached-first content/planning/geometry/lifecycle work; H4/H5 architecture is approved in the follow-on review, but live integration requires H4 implementation and H5 candidate cutover passes. Use [the current interior index](../tenant_interiors/_index.md), not the superseded future-topic list. Revenue/viability/satisfaction/tenant-derived Prestige remain deferred.
- Any change to an approved handoff requires architecture review and user approval before implementation.
