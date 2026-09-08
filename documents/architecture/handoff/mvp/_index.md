# MVP Scope Handoff Index

**Reviewed 2026-09-08.** [Current MVP](../../../game_design/current_mvp.md) is the sole scope authority. H1 orders implementation; H3 closes foundation integration gaps; H2 gates eventual Product completion. All three are documentation-approved, not evidence of completed implementation.

| Order | Handoff | Status | Scope |
|---:|---|---|---|
| 01 | [Implementation Sequence and Scope Lock](01_implementation_sequence_and_scope.md) | Approved — 2026-09-05 (delegated architecture authority) | Cross-program foundation order, minimal proxy-based integration loop, exclusions, conflict resolutions, and original end-to-end gate. |
| 02 | [Product MVP Tenant Interiors Scope](02_product_mvp_tenant_interiors_scope.md) | Approved — 2026-09-06 | Renames proxy-only behavior as the Corridor Service Integration Gate and requires Tenant Interiors H1–H5 for Product MVP completion. |
| 03 | [Foundation Integration Clarifications](03_foundation_integration_clarifications.md) | Approved — 2026-09-08, delegated consistency pass | Minimal awards/player intents, coherent developed-tile reads, payroll and save/restore failure boundaries. Read alongside H1, not after Product cutover. |
| 04 | [Product Delivery and Acceptance](04_product_delivery_and_acceptance.md) | Architecture-approved 2026-09-08, separate follow-on review | Foundation, detached interior stages, runtime, candidate cutover and Product acceptance evidence; external Gate R separate. |

**Follow-on review, 2026-09-08:** The earlier consistency pass revised H1/H2 and approved H3 without approving interior H4/H5. [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md) now separately architecture-approves `tenant_interiors/H4-H5` and MVP H4. Order: foundation -> detached interior H1-H3 -> H4 implementation passes -> H5 candidate cutover passes -> Product acceptance. External Gate R is separate. Implementation/cutover remain NOT VERIFIED; Product acceptance/Gate R remain PENDING. Approval alone does not activate the live path.
