# MVP Handoff 01: Implementation Sequence

## Status

Approved 2026-09-05; revised 2026-09-08 under delegated documentation approval. The original flat/proxy release definition is superseded by [Current MVP](../../../game_design/current_mvp.md) and MVP H2. This revision corrects predecessor order and adds MVP H3's minimum progression/input integration. No implementation evidence is asserted.

## Purpose

**Follow-on review, 2026-09-08:** [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md) separately approves interior H4/H5 architecture after the earlier consistency-pass revision above. [MVP H4](04_product_delivery_and_acceptance.md) extends this sequence through candidate cutover and Product acceptance. Implementation/cutover remain NOT VERIFIED; Product acceptance and external Gate R remain PENDING.

Order the approved technical foundation, detached interior stages, runtime implementation, candidate cutover and Product acceptance. The Corridor Service Integration Gate is a technical checkpoint, not a Product MVP release.

## In-Scope Behavior

Build one legal district, paint zones, form parcels/doors, accept and construct tenants, collect rent, exercise pedestrian proxy arrival/service/exit, optionally employ staff/pay wages, expose committed state and safely save/load. Then build detached interior planning/geometry/lifecycle outcomes, followed by H4 runtime and H5 persistence/presentation/candidate cutover under the gates below.

## Out-of-Scope Behavior

Everything deferred by Current MVP; in particular no proxy gameplay polish and no live interior Service/Visitor/save capability activation from documentation approval alone. Debug-only zone visualizations are optional tooling, not prerequisites for player behavior.

## Authorities

- [Current MVP](../../../game_design/current_mvp.md), [element register](../../../game_design/elements/_index.md), [ADR registry](../../decisions.md) and [ADR 33](../../decisions/33_documentation_consistency_and_minimum_contracts.md).
- Each program's current handoff and explicit supersession record; IDs below are program-local and qualified.
- [MVP H3 integration clarification](03_foundation_integration_clarifications.md) for previously incomplete owner/failure boundaries.

## Inputs and Outputs

Inputs are explicit validated production content, immutable policies, stable IDs/revisions and calendar identities. Outputs are committed domain state, detached read facts, deterministic tests and acceptance records. Missing policy/input is unavailable with diagnostics, never a guessed substitute. Test fixtures may stand in for declared ports in isolated tests; they cannot be production fallback content.

## State Ownership

District owns district state; Zone owns zones/parcels/automatic doors/rates; Tenant owns candidate/lifecycle/rent inputs; Economy owns money/settlement; Progression owns points/unlocks; Prestige owns official snapshots; Visitor owns realized visitors; Staff owns employment; Time owns clocks; Session/Save owns lifecycle and atomic orchestration. Projection/UI owns no gameplay state. ADRs 30/31 retain District ownership of manual door records.

## Invariants

One writer per fact; canonical G/F1/U1 addresses; no legacy grid or Node-derived authority; coherent snapshots; exactly-once calendar effects; no economic proxy outcomes; no unsupported metrics. History does not satisfy a revised contract without new evidence.

## Failure and Edge Cases

Reject missing/stale/invalid inputs before mutation. Use the common session gate for multi-owner commit/save. Failed staging preserves the old session/slot; stale visuals disable world intents until rebuilt. Authoritative optional features absent from content are explicitly unavailable. Runtime/cutover-dependent acceptance rows do not block the approved detached stages, but cannot be marked passed there.

## Dependencies and Ordered Outcomes

1. Freeze/read `district_layout/H1-H2` KEEP and current content identities. Implement the `session/H1` content/calendar spine and Economy/Progression policy ports; isolated fixtures avoid circular startup dependencies.
2. Establish `economy/H1-H2`, `progression/H1-H3` policy contracts and `district_layout/H3` transactions. Bus eligibility is policy-only; no facilities required. MVP H3 supplies the minimal Tech award rule.
3. Establish `zone_parcels/H1/H4/H5/H6` geometry/mutation and required debug-assignment isolation from H2. Parcel/zone label tooling H3/H7 is optional and does not block walls/doors. Apply ADRs 24-26 and 30-31.
4. Establish `district_layout/H4` runtime projection, then H5 public realm and `construction/H1`. H6 camera/gateways follows H5. H7 ambient traffic and H8 immediate arrivals are separate branches after H5; H8 additionally uses H6. Public crossing traversal consumes H7 controls; arrival allocation does not.
5. Establish `prestige/H1`, then `spatial_evaluation/H1` with frozen Tenant H2 input types (not a running Tenant evaluator). Establish `prestige/H2` using the coherent developed-tile read source. No circular dependency on tenant evaluation.
6. Establish `tenant/H1-H3`, then `visitor/H1` proxy lifecycle and `staff/H1` employment/payroll. Integrate exactly-once rent/payroll and normal-play Progression awards/intents under MVP H3.
7. Establish `presentation/H1` source-backed intents/read views, `district_layout/H9`, and `session/H2` coherent capture/atomic restore. Prove the Corridor Service Integration Gate below.
8. Preserve/reconcile `district_layout/H4` preview and H10 engineering evidence without rerunning an implementation audit in this documentation pass. External Gate R does not block isolated follow-on engineering, nor count as passed.
9. Implement approved detached `tenant_interiors/H1`, then H2, then H3 per their [readiness matrix](../tenant_interiors/_index.md). Detached acceptance does not activate live Service/Visitor/persistence integration.
10. Implement architecture-approved `tenant_interiors/H4` runtime and prove its implementation acceptance after detached H1-H3 pass.
11. Implement `tenant_interiors/H5` persistence/presentation and candidate cutover after H4 implementation passes. Live integration requires H5 candidate cutover passes, not document approval.
12. Perform same-candidate Product acceptance under [MVP H4](04_product_delivery_and_acceptance.md). External district Gate R is a separate pending release obligation, never inferred from Product tests.

## Acceptance Criteria

- New session uses an explicit validated production layout and has no legacy fallback.
- Clock catch-up, pause/speed and coincident boundaries are deterministic.
- Successful/rejected construction, zone and rent intents prove all-or-nothing state.
- A Tier-1 tenant reaches Open and receives exactly-once daily rent; arrivals/proxy service/exit respect the active cap and stay non-economic.
- Optional employment proves whole-week wages, negative-balance behavior and replay safety.
- Source-backed UI receives only committed facts; required normal-play build/unlock/hire actions are available, not debug-only.
- V2 round-trip and faults at every restore stage preserve one coherent session and the old slot on rejection.
- Detached interior stages prove only their approved outcomes; tests requiring H4/H5 are explicitly gated, not skipped-and-counted-as-passing Product acceptance.
