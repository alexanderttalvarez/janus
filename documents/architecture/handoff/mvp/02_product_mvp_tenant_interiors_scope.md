# MVP Handoff 02: Product Completion Gate

## Status

Approved 2026-09-06; revised 2026-09-08 under delegated documentation approval to centralize scope in [Current MVP](../../../game_design/current_mvp.md) and expose draft dependencies. This is a completion contract, not permission to implement unapproved `tenant_interiors/H4-H5`.

## Purpose

**Follow-on review, 2026-09-08:** The status paragraph above preserves the earlier consistency-pass boundary. [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md) now separately architecture-approves interior H4/H5; [MVP H4](04_product_delivery_and_acceptance.md) owns delivery and candidate-bound acceptance obligations. Implementation/cutover remain NOT VERIFIED; Product acceptance and external Gate R remain PENDING. Approval alone authorizes no activation.

Prevent a technically functioning proxy foundation from being described as the Janus Product MVP. Product completion requires the visible geometry-responsive service experience in current design.

## In-Scope Behavior

The complete behavior set in Current MVP, with all nine element-20 service typologies and prospective session-wide replacement of proxy completion.

## Out-of-Scope Behavior

Current MVP's deferred set. No visitor revenue, viability, satisfaction, tenant-derived Prestige, indoor navigation or post-cutover proxy fallback.

## Authorities

[Current MVP](../../../game_design/current_mvp.md), [element 20](../../../game_design/elements/20_tenant_interiors_visitor_interactions.md), [ADR 33](../../decisions/33_documentation_consistency_and_minimum_contracts.md), [MVP H1](01_implementation_sequence_and_scope.md), and the [Tenant Interiors program](../tenant_interiors/_index.md).

## Inputs and Outputs

Inputs: approved foundation and interior contracts, versioned content and revision-bound acceptance records. Output: a combined Product acceptance disposition. No automatic promotion of a draft, engineering PASS or release signoff is an output.

## State Ownership

Retain program owner boundaries. Product acceptance owns no gameplay state. The approved H5 cutover contract must select a session capability explicitly, never infer it from a tenant mesh or individual save record.

## Invariants

Foundation evidence remains independently reproducible. Product cannot pass with proxy-only tenants. Invalid/missing interior service is unavailable after cutover, never proxy completion. Historical proxy outcomes remain immutable and non-economic. Only explicitly supported authority-local schemas load; no implicit compatibility converter.

## Failure and Edge Cases

Incomplete implementation or candidate-bound cutover evidence leaves Product acceptance pending. Rejected/mismatched content or staging leaves the previous session and slot intact. No failed load can hot-switch service capability. Required visual acceptance is separate from headless authority tests.

## Dependencies

MVP H1, H3 and H4; approved detached `tenant_interiors/H1-H3`; runtime H4 and persistence/presentation H5 architecture-approved separately on 2026-09-08 under ADR 34. Their implementation/candidate cutover remain NOT VERIFIED. `district_layout/H10` external Gate R remains a separate release obligation, not a reason to prevent approved staged implementation.

## Ordered Outcomes

1. Complete the Corridor Service Integration Gate and retain its evidence.
2. Complete approved detached interior H1-H3 outcomes.
3. Implement H4 runtime after detached H1-H3 pass; then implement H5 save/presentation and prove candidate cutover after H4 implementation passes. Live integration requires H5 candidate cutover passes, not architecture approval alone.
4. Run foundation regression and the Product scenario against the same candidate. Record engineering results separately from external release acceptance.

## Acceptance Criteria

- All current-scope behaviors are exercised with actual committed source facts, no placeholder service.
- Normal play can unlock the core vertical/category route without debug and show visible interior/queue/service consequences.
- All nine typologies, safe non-overlapping queues, wait rejection/commitment, topology recovery and deterministic rebuild pass their approved contracts.
- Arrival/exit/cap/rent/atomic restore foundation behavior remains intact.
- Product completion stays pending until H4 implementation, H5 candidate cutover and same-candidate Product acceptance pass. District Gate R is separate and never inferred from Product tests.
