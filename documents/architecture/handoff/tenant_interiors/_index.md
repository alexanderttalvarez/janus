# Tenant Interiors Architecture Handoff Index

**Status:** Draft program — awaiting architecture approval

This program converts the agreed tenant-interior gameplay design into ordered contracts. It preserves Zone ownership of parcel/wall/door geometry, Tenant ownership of identity/lifecycle, Visitor ownership of visitor behavior, and the non-economic meaning of all legacy proxy results.

## Handoffs

| Order | Handoff | Status | Scope |
|---:|---|---|---|
| 01 | [Content and Feasibility Contracts](01_content_and_feasibility_contracts.md) | Draft | Immutable profile/fixture/service content, deterministic layout planning, fit diagnostics, and suitability ratings. |
| 02 | [Parcel Formation Integration](02_parcel_formation_integration.md) | Draft | Core/annex parcels, scale distribution, leftovers, anchors, queue-position candidates, preservation, and unsuitable units. |
| 03 | [Interior Lifecycle and Candidate Selection](03_interior_lifecycle_and_candidate_selection.md) | Draft | Weighted feasible-profile selection, tenant provenance, final layout manifests, and lifecycle revalidation. |
| 04 | [Tenant Service and Visitor Interaction](04_tenant_service_and_visitor_interaction.md) | Draft | Runtime service authority, queue/admission transactions, service models, visitor states, congestion, and completion. |
| 05 | [Persistence, Presentation, and Cutover](05_persistence_presentation_and_cutover.md) | Draft | V2-compatible persistence amendments, deterministic rebuild, projections/read models, legacy isolation, and Product MVP gate. |

## Program rules

- Implement only approved handoffs in order.
- H1 may be unit-tested with immutable fixtures, but production session wiring requires Session H1 content resolution.
- H2 explicitly amends Zone H1/H4/H5/H6 only where stated; preservation-first behavior remains dominant for established parcels.
- H3 explicitly amends Tenant H1–H3 only where stated; commercial H2 scoring remains separate from spatial suitability.
- H4 replaces Visitor H1 proxy service prospectively while retaining its stable public-door identity, arrival/exit boundaries, and historical non-economic semantics.
- H5 does not introduce Save V3. In-flight service remains transient; exact durable service restoration is a future split trigger.
- No handoff authorizes revenue, viability, satisfaction, tenant-derived Prestige, indoor visitor navigation, or a proxy fallback after cutover.

## Dependency order

```text
Session immutable content
  -> H1 pure feasibility/layout contracts
  -> H2 Zone parcel and queue-geometry facts
  -> H3 Tenant candidate/layout provenance
  -> H4 runtime tenant service + visitor behavior
  -> H5 persistence/projection/cutover
```
