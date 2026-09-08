# MVP Handoff 03: Foundation Integration Clarifications

## Status

**Follow-on review, 2026-09-08:** The consistency-pass status below records the earlier draft boundary. [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md) separately approves interior H4/H5 architecture; [MVP H4](04_product_delivery_and_acceptance.md) extends delivery as foundation -> detached interior H1-H3 -> H4 implementation passes -> H5 candidate cutover passes -> Product acceptance. This foundation contract does not require interior runtime to pass its own outcomes. Implementation/cutover remain NOT VERIFIED; Product acceptance and external Gate R remain PENDING.

Approved, 2026-09-08 documentation consistency pass under delegated authority. Amends the listed approved foundation contracts only at their missing integration boundaries; no implementation or release result is asserted. `tenant_interiors/H4-H5` remain drafts.

## Purpose

Close the minimal owner, input, failure and player-action gaps needed to implement the approved foundation without inventing policy or building deferred systems.

## In-Scope Behavior

Normal-play Tech awards/intents, coherent developed-tile reads, whole-week mandatory payroll, source-owned notification conditions, coherent save capture and candidate-only derived restore. These are integrations of existing owners, not new managers.

## Out-of-Scope Behavior

Live interior service/cutover, achievements, six-factor Quality, tasks/staff agents, dynamic simulation of synergy, new dashboards, background threading, migration adapters, and speculative shared frameworks.

## Authorities

[Current MVP](../../../game_design/current_mvp.md), design elements [02](../../../game_design/elements/02_prestige_system.md), [03](../../../game_design/elements/03_economy.md), [08](../../../game_design/elements/08_mall_levels_tech_tree.md), [14](../../../game_design/elements/14_synergy_system.md), and [ADR 33](../../decisions/33_documentation_consistency_and_minimum_contracts.md). Amends `economy/H1`, `progression/H1`, `prestige/H1-H2`, `spatial_evaluation/H1`, `staff/H1`, `presentation/H1`, `session/H1-H2` and `district_layout/H3/H8/H9` where stated.

## Inputs and Outputs

| Input | Output and owner |
|---|---|
| Committed official tier + element-08 milestone table | Progression awards each reached threshold once, publishes points/unlocks, persists earned/spent/milestone IDs |
| Coherent District, Zone and Tenant development facts | Prestige's existing calculation producer builds a detached union/count with the exact captured revision tuple |
| Boundary-employed employee snapshot + week ID + element-03 wage | Economy settles the complete week atomically, then publishes the balance and consumed-week identity |
| Economy balance/revision | Economy supplies stable `economy.balance_below_zero` active/resolved condition; Presentation displays/dismisses only |
| Complete detached authority set | Session/Save writes one coherent V2 snapshot and restores one candidate, using ADR 33's gate and reserved synergy payload |
| Player action + stable target ID + expected revision | Existing owning authority accepts or rejects one build/zone/rent/unlock/hire/fire intent; presentation returns its structured result |

## State Ownership

Progression alone writes selected Plot IDs; District writes section ownership/activation and floor/Street state, never duplicates selection. Prestige's calculation producer is the sole **read assembler** of developed tiles, not a second mutable authority. Its source identity is the complete `(district_revision, zone_revision, tenant_revision)` tuple plus policy revision, not the maximum or sum of unrelated revisions. Each qualifying stable tile counts once; no amenity authority is added while placement is deferred. The source is recomputed from a coherent capture, not serialized as separate state.

Staff owns employment and the detached boundary snapshot. Once a week becomes due, retain the validated boundary-employed roster and due identity until Economy confirms settlement; later hire/fire cannot rewrite that roster. This retained due-payroll input is durable Staff-owned data, not a live reference, and validates/round-trips with employment. With no hires, the valid input is an empty roster and the week consumes once at zero cost. Full per-employee task queues are excluded; this scope persists no tasks (an existing required task collection is explicitly empty and rejects nonempty entries). Only task-specific acceptance is deferred, not employment/payroll tests.

## Invariants

- Tech awards follow element 08 exactly, including skipped tiers; tier loss/load/replay never duplicates or revokes an earned award. Unlock intents validate points, prerequisite and capability availability atomically.
- The session/calendar coordinator calls Progression reconciliation after the monthly Prestige commit returns, with the gate released, before the boundary chain yields to input/save. Do not mutate Progression from a protected Prestige observer; ADR 33 rejects such reentrancy. A failure pauses the chain and blocks save rather than losing the milestone across load.
- Developed facts are captured and revalidated together. Geometry/lifecycle change before Prestige publication invalidates the candidate; never mix revisions.
- Payroll can overdraw; discretionary purchases cannot. Every employee in the retained due roster settles in the same weekly commit, or none do. Consume missed due weeks in ascending identity order.
- Below-zero resolution comes from committed balance recovery, never toast closure. Restore reconstructs current conditions without replaying historical toasts.
- Save capture excludes all concurrent owner mutations and calendar boundary delivery. Import all durable owner snapshots before deriving eligibility/spatial context or starting evaluations. Rebuild only against the candidate. Resume after one ready publication, without retrospective awards or service ticks.

## Failure and Edge Cases

Unknown content, invalid IDs, overflow, missing/stale source revision or invalid due roster reject without partial state. Retain a due payroll week for retry after a source/settlement failure; block later payroll weeks until it succeeds. If the source cannot produce its boundary roster, stop calendar advancement at that boundary and expose a retryable diagnostic rather than reconstructing the roster from later employment. File-write failure preserves the old slot. Reentrant mutations receive busy, not recursion. A failed live projection keeps its old root but disables world picking until current; failed restore keeps the old session fully usable.

While a due roster has not been captured, block employment edits and save capture as well as calendar advancement. Once captured, it is durable and normal safe save is allowed even if settlement retries. A historical due roster cannot become stale merely because current employment changed; validate its captured provenance/policy and Economy consumption marker, not equality to the current Staff revision.

## Dependencies

Existing foundation owner contracts in MVP H1 order. Immutable fixtures may test individual ports before composition. No approved outcome here depends on interior Service, an amenity/task authority or a SynergyManager. Layout/visual proof records are not substituted for gameplay inputs.

## Ordered Implementation Outcomes

1. Make explicit content/clock/owner ports available in the session composition.
2. Publish coherent developed-tile inputs; integrate official Prestige and exactly-once Progression rewards.
3. Integrate whole-week payroll, durable due input and source-owned balance conditions.
4. Expose a minimal source-backed action list for Tech purchases and Operations Room hire/fire, alongside existing build/zone/rent controls. A graphical Tech tree or Staff panel is unnecessary.
5. Exercise coherent export, candidate restore and failure handling with those states included.

## Acceptance Criteria

- Direct Empty Lot-to-Neighborhood publication grants 8 points once; 100/300 developed tiles reach the expected tiers at the next monthly boundary. The 8-point core route is usable in normal play.
- Overlapping zone/tenant qualifiers deduplicate; equal cell coordinates on different floors/Plots remain distinct; stale capture refuses publication.
- Zero staff settles zero once; four staff cost 2,000 Kreds/week; balance 100 becomes -1,900, while an unaffordable purchase rejects.
- Fault before payroll commit settles nobody; retry settles the original boundary roster once; save/load or later hire/fire cannot change it or duplicate it.
- Mutations attempted during save capture/commit callbacks cannot tear snapshots; a restore uses candidate Prestige and publishes no import-time awards.
- Users can submit required unlock/hire/fire/build/zone/rent actions through non-debug controls and see rejected reasons without a fake metric.
- No task agents, durable synergy cache, generic FSM or interior runtime is needed to pass these foundation outcomes.
