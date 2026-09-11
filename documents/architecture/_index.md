# Janus Architecture

**Reviewed 2026-09-08 under delegated documentation approval.** The separate follow-on review in [ADR 34](decisions/34_product_mvp_runtime_and_cutover.md) approves Tenant Interiors H4/H5 architecture after the earlier consistency pass left them drafts. This package authorizes staged implementation, not live activation or release certification: foundation -> detached H1-H3 -> H4 implementation passes -> H5 candidate cutover passes -> Product acceptance; external Gate R is separate. Implementation/cutover remain NOT VERIFIED; Product acceptance/Gate R remain PENDING.

1. [Design entry point](../game_design/_index.md): premise, one current MVP, numerical owners.
2. [ADR registry](decisions.md), then [ADR 33](decisions/33_documentation_consistency_and_minimum_contracts.md): retained authority and explicit amendments.
3. [Handoff registry](handoff/_index.md): ready versus gated work and program-qualified IDs.
4. [Implementation sequence](handoff/mvp/01_implementation_sequence_and_scope.md), then only the program contracts needed for the next outcome.
5. [Product delivery and acceptance](handoff/mvp/04_product_delivery_and_acceptance.md): candidate-bound runtime/cutover and Product evidence obligations, not claimed results.

The older [central blueprint](design_handoff.md) is historical context, not an additional target architecture. [Evidence](evidence/_index.md) records claimed results, not new requirements or inferred approvals. The [consistency ledger](consistency_pass.md) records this pass's decisions and inventory disposition.

## Governance

**Design A1/A2 decisions and A3 reset acknowledgement: PENDING.** Architecture approval is not approval of open gameplay interpretations. Unaffected engineering may proceed; confirm A1 exterior-only expected wait and A2 shared cafe/food-court cohort counter semantics before locking affected implementation or acceptance. See the [Product Design decision register](evidence/product_mvp/_index.md#design-decision-register).

Authority order: concept premise; explicitly agreed design/current scope; accepted non-superseded ADRs; approved handoffs; drafts; trackers/evidence/history. A newer explicit amendment wins only in its stated scope. Read dated amendments before older bodies/examples.

This pass's changes to approved contracts are documentation-approved by the user's delegated authority on 2026-09-08, not invented prior approvals. They create new acceptance obligations where behavior changes; older PASS records do not prove those revisions. Accepted ADR bodies and evidence are preserved.

[ADR 36](decisions/36_district_zone_spatial_snapshot_and_zone_mutation.md), accepted 2026-09-10, is the current authority for DistrictState local v3, the floor-scoped District-to-Zone spatial snapshot, and coordinated Zone paint mutation. Save remains V2; no implementation or evidence is asserted.

[ADR 37](decisions/37_district_construction_annex_schema.md), accepted 2026-09-10, corrects ADR 36's exact DistrictState v3 root by retaining the construction annex without corridor records or a second concurrency authority. Save V2 and the authority registry remain unchanged; no implementation or evidence is asserted.

Use normal Godot composition and the smallest implementation satisfying owner, identity, deterministic behavior, failure, and acceptance contracts. Named example helpers, file layouts, class hierarchies, or skill lists are not mandates unless an active ADR requires the architectural boundary. No general FSM framework, new service locator, extra EventBus query layer, or speculative manager is a prerequisite.
