# Tenant Interiors Handoff 04 — Tenant Service and Visitor Interaction

**Status:** Draft — awaiting architecture approval  
**Implementation order:** 4 of 5

## Purpose

Replace placeholder interaction with fixture capacity, visible queues, expected-wait admission, abstract service, cohorts/devices/batches, and goal progress. Preserve corridor-only paths, H8 source ownership, 200-active cap, and permanently non-economic historical results.

## Scope and composition

New tenant-service completion results are non-economic. No revenue, price, budget, viability, satisfaction, demand, rent, or Prestige effect.

TenantServiceManager is a session-scoped injected Node, not autoload. A stateless coordinator commits Visitor/Service candidates under the session gate.

```text
MainGame
├── Simulation: ZoneManager, TenantManager, TenantServiceManager, VisitorManager
└── Projection: TenantInteriorProjectionRoot, QueuePresentationRoot, VisitorProjectionRoot
```

Service owns instances, activated envelope positions, FIFO, abstract occupants, tokens, schedules/waits/revision. Visitor owns behavior seed/ordinal, goals/wait/exclusions, movement, visitor-side queue position, active cap, progress/history, occupancy snapshots. Zone/H5 owns doors/proxies/envelopes/graph. Tenant owns Open/layout provenance. Presentation owns no truth.

Preserve parcel-door proxy ID. Stable service instance ID uses the approved canonical stable-ID framing over tenant ID, operational-profile ID, and service-policy ID; fixture, queue-position, commitment, token, and batch IDs derive from semantic owner IDs/slots, never Nodes/transforms or runtime collection order.

## H8 realization amendment and visitor creation

Demand and source allocation stay tenant-independent. When H8 commits realization, VisitorManager atomically consumes its behavior seed/creation ordinal and one **one-time captured** ServiceCategoryAvailabilitySnapshot. The snapshot need not be revalidated and later service changes do not roll back/delay arrival; goals naturally retarget/drop under current state.

If categories exist, H1 generates 1–3 goals only from them and derives wait tolerance. If empty, H1 generates one Browsing goal, followed by normal no-target drop/Leaving. Creation ordinal advances only with committed realization. Captured fingerprint/empty marker, policy provenance, consumed seed domain/ordinal, goals, and wait persist without reroll.

## Target selection

Preserve Visitor H1 after approved filters: select first canonical proxy among Open, operational, goal-compatible, non-excluded, reachable targets from one graph snapshot. Path cost, congestion, queue, wait, price, attraction do not choose destination. Wait is learned at arrival. No target drops/advances goal or leaves. Exclusions clear on goal completion/drop.

## Service initialization, snapshots, and visitor states

Open tenants independently initialize OPERATIONAL or SERVICE_UNAVAILABLE from H3 fingerprint/H2 envelope; Open/rent never changes and no proxy fallback exists.

Service snapshots publish identities/revisions, availability, typology, active positions/FIFO, tokens/occupancy, expected wait, batch/next transition, diagnostics. UI/Visitor never estimate from visuals.

Visitor states distinguish DECIDING, TRAVELING_TO_SERVICE, EVALUATING_AT_DOOR, WAITING_EXTERIOR, IN_ABSTRACT_SERVICE, LEAVING. Travel ends at public proxy; no interior path.

## Door evaluation and admission

At arrival, coordinator captures Visitor/Service/Tenant/Zone/topology revisions, compares authoritative wait once with tolerance, rejects/excludes if full/excessive/unavailable, or prepares queue/immediate admission. Wait does not decay; ordinary needs suspend; only invalidation/teardown cancels.

## Cross-authority service transaction protocol

Every ordinary admission, rejection that writes exclusions/state, cancellation, promotion, batch transition, and completion that changes both authorities uses this protocol; topology mutations additionally use H2's broader protocol.

1. Capture Service/Visitor plus required Tenant/Zone/topology revisions and prepare complete detached next states and fact envelopes.
2. Complete every fallible calculation and append-capability preflight.
3. Acquire the session transaction gate and revalidate all captured revisions.
4. Apply non-failing prepared swaps Visitor then Service and advance both authority revisions.
5. Append exactly one complete aggregate envelope to the non-failing journal; this append is the commit point.
6. Synchronously flush aggregate, Service, then Visitor fact notifications in that fixed order while the gate remains held; subscriber faults are isolated/diagnosed and cannot roll back/reorder the commit.
7. Release the gate.

Failure before append restores both prior states, invalidates the prepared token, and emits nothing. After append there is no rollback. Save, topology mutation, input, or another service transaction cannot interleave between swap, append, and flush. Scheduler work for one service/tick is one aggregate transaction containing canonically ordered subtransitions.

## Queue occupancy and exact congestion policy

FIFO is join ordinal then visitor ID. Queue visitors stay visible/active/count toward 200. VisitorManager publishes immutable per-floor occupancy snapshots once per authoritative `visitor_tick`, including queued visitors and queue-tile classification. Movement between boundaries does not revise the snapshot; TimeManager's tick identity is authoritative and this handoff defines no duration.

This activates Transit congestion for Product MVP and supersedes MVP H1's deferral. Immutable CirculationCostPolicy uses integer units:

- base tile cost 100;
- per-mille multipliers: empty 1000, elevator 1200, queue 2000, congested occupancy >5: 2500;
- overlaps use maximum multiplier;
- occupancy factor `1000 + 150 × occupancy`;
- tile cost=floor(`base × multiplier × occupancy_factor / 1,000,000`);
- signed 64-bit intermediates; content validation plus 200 cap proves no overflow.

Queue+congested=2500; elevator+queue=2000; all three=2500. Queue never blocks edges.

New routes use latest same-floor snapshot. Existing routes reconsider only at visitor ticks when a remaining path tile changes multiplier class; repath only if alternative improves integer cost by at least policy threshold. Unrelated tiles/floors do not trigger. Topology invalidation remains immediate/bounded.

Equal-cost A* tie seed uses visitor ID, source anchor, destination ID, graph revision, occupancy tick identity, policy revision—no mutable route ordinal.

## Deterministic service scheduler

Session-scoped TimeManager supplies authoritative monotonic visitor-tick boundary identity `t` and its persisted boundary-ordinal origin `o`. Durations/cadences are integer boundary counts; Service defines no clock.

For service `s` with policy `p` and positive cadence `c`, canonical UTF-8 RFC 8785 JSON is:

```text
{"domain":"tenant_service_phase_v1","service_id":s,
 "service_policy_id":p.id,"service_policy_revision":p.revision}
```

Keys/values use the exact current-schema scalar types shown by the policy contracts; no textual concatenation is permitted. Lowercase SHA-256 digest bytes are interpreted as one unsigned big-endian integer. `phase_offset = digest mod c`. Scheduled batch boundaries are exactly identities `t >= o + phase_offset` where `(t - o - phase_offset) mod c == 0`. Fixed-duration completion is exactly `start_tick_identity + duration_ticks`. Implementations may stream the modulo calculation but must match golden vectors.

Service owns a transient last-consumed tick marker. Restore staging initializes it to TimeManager's restored current boundary, so no retroactive work occurs. Every Service mutation stamps an authoritative tick identity. A door request outside scheduler dispatch commits queue occupancy immediately, but its scheduler-effective admission identity is the next unconsumed tick. During dispatch it uses current identity only if ADMIT has not passed; otherwise next identity.

At each identity canonical order is service ID, COMPLETE, BATCH_START, PROMOTE, ADMIT, token ID, visitor ID. Expected-wait simulation uses the same origin, hash record/equation, last-consumed boundary, request-effective identity, phase order, and ties.

| Typology | Rule | Wait basis |
|---|---|---|
| Host/seating | Earliest table; ID tie; partial FIFO cohort. | Releases + predecessors. |
| Counter | Earliest station. | Station simulation. |
| Browse/checkout | Occupancy, fixed browse, internal FIFO checkout. | Occupancy release. |
| Service bay | Earliest bay. | Bay simulation. |
| Scheduled batch | Next batch only; one active. | Next start if capacity. |
| Device pool | Occupancy + internal FIFO device. | Occupancy release. |
| Cohort/device | Earliest activity token + partial cohort. | Token release. |
| Open flow | Occupancy for fixed duration. | Occupancy release. |
| Counter then seating | Reserve table before counter through completion. | Joint availability. |

## Completion and cancellation

Batch start atomically moves next FIFO into abstract occupancy, frees positions, assigns IDs, advances arithmetic ordinal. Phase uses the exact equation above; restore cannot reset it.

Completion atomically releases tokens, advances/completes goal exactly once, clears exclusions when complete/dropped, chooses DECIDING/LEAVING, records one result, publishes. Result has identity/provenance/calendar/kind only.

Cancellation is idempotent, creates no result/progress, releases both records, rematerializes at valid proxy or uses recovery/exit.

## Mutation, save, capability, events

H2 coordinates topology invalidation. Save barrier blocks mutations/events and torn commitments. Interior capability is persisted/bootstrap-selected, never hot-switched. EventBus announces facts only. Layout rebuild is revision-driven; fixture Nodes own no authority processing.

## Acceptance requirements

- H8 arrival timing is unaffected by later service revision; creation ordinal advances once.
- Category generation/provenance follows H1 and persists without reroll.
- Targets use compatible canonical proxy order.
- All cross-authority transitions have one commit envelope and protected notification order.
- Scheduler and expected wait match exact hash/phase/tick rules; goals advance once; needs suspend.
- Integer congestion precedence/tick/repath/tie rules hold.
- Batch phase survives reload; Open/rent independent.
- Results exactly-once/non-economic; no fallback.

## Required tests

- H8 creation with empty/nonempty snapshot and post-capture service changes proving no arrival retry/delay.
- Current-schema goal provenance, goals/wait/progress/drop/exclusions, target ordering without reroll.
- Fault injection at every pre-append boundary, subscriber faults, reentrant save/mutation attempts, and exact envelope order for every transition.
- Scheduler/wait goldens for every typology, canonical phase-hash vectors, restored epoch, outside/during-dispatch admissions, same-time events.
- Congestion arithmetic/precedence/tick/local repath/cross-floor isolation/A* ties.
- Batch reload, save barrier, 200 cap, non-economic isolation.

## Required implementation skills

`state-machine`, `ai-navigation`, `event-bus`, `dependency-injection`, `resource-pattern`, `scene-organization`, `math-essentials`, and `godot-testing`.
