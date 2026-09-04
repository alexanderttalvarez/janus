# Handoff 08: Visitor Arrival MVP Migration

## Status

**Approved — 2026-09-03.** Implementation requires H3 source state, H5 pedestrian graph, H6 gateway eligibility, and VisitorManager lifecycle output; MVP/H9 are not blocked by future durable cohort policy or H7 traffic topology.

## Purpose

Separate demand, deterministic source selection, immediate cross-authority realization, and existing realized visitor lifecycle without source reservation state.

## Dependencies

- [H6](06_camera_and_pedestrian_gateways.md) structural eligibility and pass-through H2 attachment/pose.
- H3 District Runtime source validation/state and H5 pedestrian graph.
- Existing VisitorManager lifecycle and the approved global 200-active-visitor MVP population budget.

## Source-of-truth documents

- [Decision 28](../../decisions/28_visitor_arrival_architecture.md)
- [Decision 3](../../decisions/03_visitor_agents.md)

## Current-state findings

VisitorManager combines demand, random corners, realization, lifecycle, fixed doors/ring, floor `G`, and serialization.

## Target state

MVP flow is one immediate transaction under a shared Arrival Commit Gate and notification/save barrier. There is no source reservation state, durable pending window, weighted allocation, capacity, or fairness policy. Future asynchronous transport cohorts remain open and must select persistence before they ship.

## Scope

Demand separation, deterministic MVP selection, revision validation, immediate pedestrian realization, stable `arrival_source_id`, exit selection, token invalidation, fault rollback, and legacy visitor bridge.

## Explicit non-goals

Durable pending cohorts, new capacities/weights/rates/formulas, non-pedestrian modes, or persisted source geometry.

## System ownership

| Owner | Responsibility |
| --- | --- |
| Demand authority | Desired counts/profiles only. |
| Arrival Coordinator | Deterministic MVP selection and commit-gate orchestration. |
| District Runtime | Sole `ArrivalSourceState` writer and ephemeral source validator. |
| H6 | Structural eligibility input only. |
| VisitorManager | Realized visitor records/lifecycle/Nodes after allocation and the global 200-active-visitor MVP population budget. It does not own source capacity. |

## Data contracts

Every source reference is `arrival_source_id`. The candidate set contains only sources whose mode is `PEDESTRIAN`, current source state is enabled, H6 reports structurally eligible, and the committed `district_revision` plus H5/H6 topology/eligibility revision match the coordinator's captured values. Every source-state change advances H2/H3 `district_revision`; no source-specific concurrency revision exists. Sort candidates ascending by NFC-normalized UTF-8 bytes of `arrival_source_id`; MVP selects the first. This is only a deterministic tie-break among equally eligible sources, not weighting, fairness, or capacity policy. A future policy may replace it only by separate approval. Demand profile never affects spatial source selection.

The Arrival Commit Gate is shared by District Runtime and VisitorManager. Allocation captures the demand snapshot identity, H2/H3 `district_revision`, and H5/H6 topology/eligibility revision. A District Runtime validation token is ephemeral, non-persistent, non-authoritative, bound to those captured values and the selected `arrival_source_id`, and causes no `ArrivalSourceState` or revision mutation. It is single-use and invalid after failure, gate release, any captured revision change, or successful consumption.

## Communication and event flow

The immediate transaction is exact:

1. Coordinator captures demand snapshot identity, H2/H3 `district_revision`, and H5/H6 topology/eligibility revision; computes the canonical candidate order; and selects the first source.
2. Coordinator acquires the shared Arrival Commit Gate.
3. District Runtime validates the selected source against the captured demand identity and revisions and returns an ephemeral validation token without state or revision mutation.
4. VisitorManager prepares a detached visitor record.
5. Coordinator revalidates the selected source, demand snapshot identity, `district_revision`, topology/eligibility revision, token, and detached record.
6. Under one notification/save/input barrier, the coordinator verifies that the in-memory non-failing commit dispatcher can accept one complete `arrival_realized` envelope. VisitorManager then swaps only its own immutable visitor state and the token is consumed.
7. The coordinator appends that complete envelope to the dispatcher. Append is contractually non-throwing/non-failing and is the commit point. Any fault before append restores prior VisitorManager state and invalidates the token; after append there is no rollback.
8. The coordinator releases the barrier while retaining the Arrival Commit Gate. Barrier release synchronously flushes the envelope; subscriber faults are isolated diagnostics and cannot alter committed authority or event order.
9. The coordinator releases the Arrival Commit Gate only after flush. No transaction, save, or input may intervene.

Before append, any fault restores the prior VisitorManager state and invalidates the token. Save, input, and observers are blocked for the full barrier. Append commits one complete envelope; subscriber faults during its synchronous flush emit isolated diagnostics only and cannot roll back or reorder the committed result. Leaving visitors use the same canonical eligible-source ordering and remain counted until physical removal.

## Persistence impact

Persist realized visitors and H2's sparse enabled overrides only. Tokens, commit-gate state, barriers, reservations, MVP pending records, source transforms, topology, and routes are never persisted. Future durable cohorts must approve persistence before shipping.

## Editor/runtime behavior

Editor displays H6 eligibility and pass-through H2 pose without demand or mutation. Runtime consumes that pose only at matching committed revisions; neither H6 nor H8 resolves or alters it, and Nodes remain transient.

## Migration and compatibility requirements

`LegacyVisitorSpawnAdapter` bridges selected target source records to old `VisitorManager` behavior. It does not map persisted corner IDs; H9 detached migration owns persisted source mapping. Conforming saves write only `arrival_source_id`.

## Expected affected files/systems

Arrival Coordinator, shared Arrival Commit Gate/barrier, District Runtime source validation, VisitorManager/data, composition, H9 serializers, tests.

## Acceptance criteria

Demand is spatially independent; global active population caps at 200 through VisitorManager lifecycle policy, without introducing source capacity/weight/fairness; allocation captures demand snapshot identity, H2/H3 `district_revision`, and H5/H6 topology/eligibility revision; source-state changes advance `district_revision`; no source-specific concurrency revision exists; canonical selection is deterministic; District Runtime remains sole source writer without reservation mutation; immediate realization has no observable or durable pending window; every pre-append fault restores prior visitor state and invalidates its token; append commits exactly one envelope; subscriber faults cannot roll back or reorder it; source geometry is unsaved; legacy adapter has no persisted mapping.

## Required tests

Demand-profile independence; global 200-active-visitor lifecycle budget without source-capacity behavior; captured demand snapshot identity; mode/enabled/H6 filtering; matching and stale `district_revision` and H5/H6 topology/eligibility revision cases; source-state changes advancing `district_revision`; rejection of any source-specific revision field or check; NFC UTF-8 bytewise ordering; first-source selection; rejection of unselected weighting/fairness/capacity behavior; sole-writer proof; token single-use/invalidation; exit ordering/invalidation; lifecycle/culling; save exclusion; adapter isolation. Inject every pre-append fault, append-capability rejection, and subscriber fault during synchronous flush; assert prior visitor-state restoration before append, no source/revision mutation, no save/input/observer visibility through the barrier, no intervening transaction/save, exactly one complete envelope after append, preserved event order, and no post-append rollback.

## Performance/scalability checks

Allocation scales with eligible sources and does not rebuild topology per visitor.

## Failure and rollback behavior

No source or stale revision changes nothing. Any pre-append failure restores prior VisitorManager state, invalidates the token, releases barrier/gate safely, and emits diagnostics only. Append is the commit point; subscriber faults during barrier-release flush are isolated and cannot cause rollback. Invalid exits wait and reselect canonically without nearest-coordinate fallback.

## Technical risks

Dual source writers, accidental source-specific revision authority, barrier escape, token reuse, append without dispatcher preflight, flush after gate release, stale revisions, and legacy fixed geometry leaking through helpers.

## FACTS

- Immediate pedestrian realization with no durable pending window is approved for MVP.
- MVP source choice is the first canonically ordered equally eligible source; no source reservation state exists.

## ASSUMPTIONS

- Realized visitor state restores independently of original gateway transform.

## OPEN QUESTIONS

- Future durable transport-cohort persistence, capacity/weight/fairness, and no-exit policy. These do not block MVP/H9 but must be decided before such cohorts ship.

## GodotPrompter skills required by implementation agents

- `state-machine`, `ai-navigation`, `save-load`, `event-bus`, `dependency-injection`, `godot-testing`.
