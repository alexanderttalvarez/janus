# Tenant Interiors Architecture Handoff Index

**Status:** Architecture-approved: H1-H3 approved 2026-09-06; H4-H5 approved 2026-09-08 in the separate follow-on review. Implementation/cutover NOT VERIFIED; Product acceptance and external Gate R PENDING.

**Revision:** 2026-09-08 delegated consistency pass; H1-H3 approval is retained with the staged boundary below, not extended to H4/H5. [Current MVP](../../../game_design/current_mvp.md), element 20 and ADR 33 govern current design/architecture.

This program converts the agreed tenant-interior gameplay design into ordered contracts. It preserves Zone ownership of parcel/wall/door geometry, Tenant ownership of identity/lifecycle, Visitor ownership of visitor behavior, and the non-economic meaning of all legacy proxy results.

**Follow-on review, 2026-09-08:** The revision paragraph above preserves the earlier consistency-pass boundary. [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md) separately approves H4/H5 architecture; [MVP H4](../mvp/04_product_delivery_and_acceptance.md) governs Product delivery/acceptance. Approval alone activates no live capability.

## Handoffs

**Design A1/A2 decisions and A3 reset acknowledgement: PENDING.** See the [Product Design decision register](../../evidence/product_mvp/_index.md#design-decision-register). Architecture approval does not settle open gameplay interpretations. Unaffected engineering may proceed; confirm A1 exterior-only expected wait and A2 shared cafe/food-court cohort counter semantics before locking affected implementation or acceptance.

| Order | Handoff | Status | Scope |
|---:|---|---|---|
| 01 | [Content and Feasibility Contracts](01_content_and_feasibility_contracts.md) | Approved — 2026-09-06 | Immutable profile/fixture/service content, deterministic layout planning, fit diagnostics, and suitability ratings. |
| 02 | [Parcel Formation Integration](02_parcel_formation_integration.md) | Approved — 2026-09-06 | Core/annex parcels, scale distribution, leftovers, anchors, queue-position candidates, preservation, and unsuitable units. |
| 03 | [Interior Lifecycle and Candidate Selection](03_interior_lifecycle_and_candidate_selection.md) | Approved — 2026-09-06 | Weighted feasible-profile selection, tenant provenance, final layout manifests, and lifecycle revalidation. |
| 04 | [Tenant Service and Visitor Interaction](04_tenant_service_and_visitor_interaction.md) | Architecture-approved 2026-09-08, follow-on review | Runtime service authority, queue/admission transactions, service models, visitor states, congestion, and completion. |
| 05 | [Persistence, Presentation, and Cutover](05_persistence_presentation_and_cutover.md) | Architecture-approved 2026-09-08, follow-on review | V2-compatible persistence amendments, deterministic rebuild, projections/read models, legacy isolation, and Product MVP gate. |

## Program rules

- Implement only approved handoffs in order.
- H1 may be unit-tested with immutable fixtures, but production session wiring requires Session H1 content resolution.
- H2 explicitly amends Zone H1/H4/H5/H6 only where stated; preservation-first behavior remains dominant for established parcels.
- H3 explicitly amends Tenant H1–H3 only where stated; commercial H2 scoring remains separate from spatial suitability.
- H4 defines prospective replacement of `visitor/H1` proxy service while retaining its stable public-door identity, arrival/exit boundaries, and historical non-economic semantics. Implement after detached H1-H3 pass; approval alone does not replace the live path.
- H5 defines authority-local schema changes under root V2 and transient reset, not Save V3. Implement after H4 implementation passes; live session/save integration requires H5 candidate cutover passes.
- No handoff authorizes revenue, viability, satisfaction, tenant-derived Prestige, indoor visitor navigation, or a proxy fallback after cutover.

## Dependency order

| Stage | Ready approved outcomes | Explicitly gated outcomes |
|---|---|---|
| H1 | Compile explicit element-20 content, pure layout/goal functions and detached provenance round-trip fixtures | Live operational-category supplier, H8 visitor realization changes, production Visitor schema |
| H2 | Pure prospective core/annex and queue-envelope planning; detached Zone transaction validation; stable-identity tests | Live occupied edits that require Service/Visitor teardown or swap; production geometry capability cutover |
| H3 | Feasible weighted candidates, commercial evaluation, detached bind/lifecycle/layout provenance and tenant-local fixtures | Open-to-Service activation, live Service availability, full-session interior save integration |
| H4 | Approved runtime queue/admission/scheduler/visitor implementation after detached H1-H3 pass | Implementation NOT VERIFIED; production activation still requires H5 candidate cutover passes |
| H5 | Approved save/presentation/candidate cutover implementation after H4 implementation passes | Candidate cutover NOT VERIFIED; Product acceptance PENDING; external Gate R separate |

For H1-H3, a fixture provides explicit immutable inputs of a live port whose implementation is not yet verified. Such fixtures prove detached behavior only and never become a production adapter or fake runtime service. Service-related clauses remain later integration acceptance obligations: H4 implementation must pass and H5 candidate cutover must pass before live activation. Keep the existing foundation session unchanged until those gates pass. This breaks the apparent circular prerequisite without weakening eventual Product acceptance.

```text
Foundation / Session immutable content
  -> H1 pure feasibility/layout contracts
  -> H2 Zone parcel and queue-geometry facts
  -> H3 Tenant candidate/layout provenance
  -> H4 runtime tenant service + visitor behavior
  -> H5 persistence/projection/cutover
  -> Product acceptance

External district Gate R: separate release obligation, PENDING
```
