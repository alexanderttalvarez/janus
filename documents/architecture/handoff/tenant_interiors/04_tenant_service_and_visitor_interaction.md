# Tenant Interiors Handoff 04 — Tenant Service and Visitor Interaction

**Status:** Draft — awaiting architecture approval  
**Implementation order:** 4 of 5

## Purpose

Replace placeholder interaction with fixture capacity, visible queues, expected-wait admission, abstract service, cohorts/devices/batches, deterministic congestion-aware public routing, and goal progress. Preserve approved H1-H3 gameplay, corridor-only paths, H8 demand/source ownership and immediate commit, the 200-active cap, and permanently non-economic results.

## Scope, authority, and composition

This handoff extends Session content with `CirculationCostPolicy` and amends H8 realization only as stated below. It does not alter approved H1-H3 or H8 source/demand selection, tokens, revalidation, envelope, flush, exit, or cap contracts.

New tenant-service completion results are non-economic. No price, payment, revenue, budget, viability, satisfaction, demand, rent, or Prestige field or effect is authorized, and unavailable content or runtime state has no proxy-service or economic fallback.

TenantServiceManager is a session-scoped injected Node, not an autoload. A stateless coordinator commits prepared Visitor/Service candidates under the existing session transaction gate and journal protocol.

```text
MainGame
├── Simulation: ZoneManager, TenantManager, TenantServiceManager, VisitorManager
└── Projection: TenantInteriorProjectionRoot, QueuePresentationRoot, VisitorProjectionRoot
```

Service owns service instances, activated envelope positions, exterior FIFO, abstract occupants, tokens, stages, schedules, waits, and Service revision. Visitor owns behavior seed/ordinal, goals/wait/exclusions, movement/logical location, visitor-side queue position, active cap, progress/history, and occupancy snapshots. Zone/H5 owns doors, proxies, envelopes, stable graph cells/anchors/edges, elevator-lobby metadata, vertical links, and graph revision. Tenant owns Open/layout provenance. Session owns compiled policies. Presentation owns no truth.

Preserve parcel-door proxy identity. Stable service instance ID uses the approved canonical stable-ID framing over tenant ID, operational-profile ID, and service-policy ID. Fixture, queue-position, commitment, token, cohort, and batch IDs derive from semantic owner IDs and authored/layout slots, never Nodes, transforms, coordinates, dictionaries, or runtime collection order.

## H8 realization amendment and visitor creation

### Availability publication

After each committed Service state change, TenantServiceManager atomically publishes exactly one deeply immutable `ServiceCategoryAvailabilitySnapshot` derived only from that committed state. It contains exactly:

- `service_revision`;
- `service_category_ids`, a sorted unique array of canonical service-category IDs for categories having at least one tenant that is both Tenant `Open` and Service `OPERATIONAL`;
- source `tenant_revision`;
- source `topology_graph_revision`;
- `visitor_policy_id` and `visitor_policy_revision`; and
- `fingerprint`, lowercase SHA-256 of RFC 8785 canonical JSON containing exactly the preceding fields with their current-schema integer/string/array types.

The injected read-only availability provider returns one complete snapshot value per call and never exposes a live collection. Publication cannot expose a new revision with an old category array or provenance.

### Exact H8 amendment

Demand production and source allocation remain tenant-independent. During existing H8 step 4, while preparing the detached visitor record, VisitorManager calls the injected provider exactly once and captures the returned complete `ServiceCategoryAvailabilitySnapshot`. Service is not added to the H8 demand/source validation token, captured source revisions, or step-5 revalidation. The captured snapshot may become stale immediately after the call; staleness causes no retry, rejection, delay, source reselection, or arrival rollback.

H1 generates its approved 1-3 goals and wait tolerance from that captured category array. The approved empty-category exception remains exactly one Browsing goal followed by normal no-target drop/Leaving. Existing H8 step 6 swaps one prepared Visitor state containing the goals, wait, full captured category ID array, snapshot fingerprint, explicit empty marker consistent with the array, visitor-policy ID/revision, consumed behavior-seed domain/value, and creation ordinal. Creation ordinal advances only in this swap.

Every fault before the existing single `arrival_realized` envelope append restores all Visitor fields and the ordinal and invalidates the existing H8 token. The existing single envelope append remains the commit point and the existing protected synchronous flush remains unchanged. Service state/revision never participates in this transaction. Current-schema Visitor persistence retains the complete captured category array and its fingerprint plus explicit empty marker, policy, seed, ordinal, generated goals, and wait, so restore validates generation from captured provenance without consulting current service availability or rerolling.

## Target directory and deterministic selection

The target directory is a pure revision-keyed derived snapshot/cache, not Service-owned truth and not something published only after a Service mutation. Its exact key is the tuple of Tenant revision, Service revision, topology graph revision, and every relevant policy revision. For one exact key, TenantServiceManager atomically publishes or reuses one immutable `ServiceTargetDirectorySnapshot`. It contains that complete key and only base-eligible targets whose tenant is Open and whose service is `OPERATIONAL`, sorted by canonical NFC-normalized UTF-8 bytes of `parcel_door_proxy_id`. Each target contains stable service/tenant/category/proxy/public-anchor IDs and the committed compatibility facts required by H1 filters; it contains no Node, transform, price, attraction, queue preference, or mutable collection.

The session target-directory coordinator invalidates and requests a rebuild after any commit that changes a key source. Rebuild requests for the same revision tuple are coalesced. A rebuild captures complete immutable source snapshots under the session gate, derives outside the gate, then reacquires the gate and revalidates the exact tuple before atomically publishing or using the result. A stale derivation is discarded and never published.

At a DECIDING boundary, selection is one bounded prepare/revalidate transaction:

1. Under the session gate, capture the exact current directory key, the matching immutable Tenant, Service, H5 `PedestrianGraphSnapshot`, and relevant policy snapshots, plus the current Visitor revision/state. If no cached directory matches, selection may invoke the bounded detached rebuild protocol above rather than waiting for a Service mutation.
2. From the matching directory's canonical order, filter to Open, `OPERATIONAL`, current-goal-compatible, non-excluded targets whose public anchor is reachable from the visitor's current logical public anchor in that exact graph.
3. Select the first remaining canonical proxy. Path cost, congestion, queue length, expected wait, price, attraction, weighting, fairness, and runtime collection order do not choose the destination.
4. Before committing `TRAVELING_TO_SERVICE`, revalidate the exact Tenant, Service, graph, relevant policy, directory-key, and Visitor revisions plus that visitor's DECIDING state/current goal. Commit only Visitor because the sources and directory were read-only.
5. Use the normal complete journal envelope and protected synchronous flush. A stale capture commits nothing and defers one bounded retry to that visitor's next approved H1 decision boundary. If source revisions stabilize, that next bounded retry must obtain and use a matching directory without requiring a Service mutation. If revisions continue changing, the visitor remains `DECIDING` and follows the existing bounded H1 retry policy. No selection combines sources or target facts from different revision tuples.

No target follows approved H1 goal drop/advance/Leaving behavior. Exclusions clear only under approved H1 completion/drop rules.

## Service initialization, states, and queue capacity

Open tenants independently initialize `OPERATIONAL` or `SERVICE_UNAVAILABLE` from matching H3 layout fingerprint and committed H2 envelope provenance. Open/rent never changes, and no proxy fallback exists.

Visitor states are `DECIDING`, `TRAVELING_TO_SERVICE`, `EVALUATING_AT_DOOR`, `WAITING_EXTERIOR`, `IN_ABSTRACT_SERVICE`, and `LEAVING`. Travel ends at a validated public proxy. A visitor in every one of these states remains active and counts toward the global 200 cap, including evaluation, queueing, abstract service, cancellation/recovery, and exit retry. Removal occurs only at a valid H8 exit source.

For an `OPERATIONAL` service, activated queue positions are the canonically sorted subset of its safe committed H2 queue-position IDs assigned by the layout. At most two activated position IDs may share one parent public graph tile; the IDs already embody H2's safe two-position geometry and H4 does not derive extra positions. Non-operational services activate none. Exact exterior capacity is:

```text
effective_exterior_capacity = min(service_policy.queue_cap,
                                  count(activated_safe_committed_position_ids))
```

Zero is valid. Effective exterior capacity governs only `WAITING_EXTERIOR`. FIFO order is `(join_ordinal, visitor_id)`. An occupied queue position causes its parent graph tile to have class `QUEUE`; an empty activated position does not. Position occupancy is one-to-one in Service and Visitor candidate states and never inferred from presentation.

At a valid proxy, door evaluation captures Visitor, Service, Tenant, and graph revisions, reads authoritative expected wait once, and compares it with the persisted tolerance. If the wait passes and the service can immediately acquire every required occupancy slot, token, and start condition, the visitor is admitted directly even when effective exterior capacity is zero or every exterior position is occupied. If immediate admission cannot commit, acceptance requires the next free exterior position and enters `WAITING_EXTERIOR`; zero or full effective exterior capacity then rejects without reservation and adds the current tenant exclusion. Excessive-wait, incompatible, or unavailable cases also reject and add that exclusion. Wait tolerance does not decay, ordinary needs remain suspended, and only the cancellation/invalidation rules below interrupt a commitment.

## ServicePolicy and deterministic typology scheduler

### Required compiled policy

Every `ServicePolicy` has canonical ID/revision and explicit typology-required fields. Durations and cadences are positive integer visitor ticks; capacities/counts are integers with ranges validated for their use. Missing fields, extra typology-incompatible fields, invalid ranges, unresolved layout count sources, duplicate token IDs, or a mismatch with H3 layout provenance makes content invalid; there are no defaults.

Required fields are:

- `typology`, `occupancy_cap`, and `queue_cap`;
- ordered token-pool definitions, each with token kind, semantic layout slot/tag count source, canonical token-ID derivation, and required per-token capacity where applicable;
- named positive integer stage durations for every stage used by the typology;
- for scheduled batch: positive `batch_cadence_ticks`, `batch_capacity`, active-stage duration, and positive `turnover_ticks`;
- for host/table and cohort/device: positive `cohort_min`, `cohort_max` with min <= max, explicit `allow_partial_cohort`, and positive `partial_timeout_ticks`; and
- positive `max_service_transitions_per_tick` and `max_expected_wait_simulation_steps_per_request`.

`occupancy_cap` is the maximum simultaneous abstract occupants and must be positive for every typology. `queue_cap` may be zero. Token pools are instantiated only from the referenced committed layout slots and sorted by canonical token ID. Numeric tuning is authored policy; this handoff adds no implicit tuning values. Session/content validation must calculate, from the configured services and the global 200-active cap, the theoretical maximum visitor-affecting transitions that can be due in `COMPLETE` on one tick, including cohort/batch fan-out and atomic stage boundaries, and reject content unless `max_service_transitions_per_tick` is at least that maximum.

Typology-required pool and duration names are exact:

| Typology | Required token pools | Required duration/cadence fields |
|---|---|---|
| Host/table | `table_tokens` with authored capacity per table | `seated_duration_ticks`, cohort fields |
| Counter | `counter_tokens` | `counter_duration_ticks` |
| Browse/checkout | `checkout_tokens` | `browse_duration_ticks`, `checkout_duration_ticks` |
| Service bay | `bay_tokens` | `bay_service_duration_ticks` |
| Scheduled batch | none | `batch_cadence_ticks`, `batch_capacity`, `batch_duration_ticks`, `turnover_ticks` |
| Device pool | `device_tokens` | `pre_device_duration_ticks`, `device_duration_ticks` |
| Cohort/device | `activity_device_tokens` with authored capacity per token | `activity_duration_ticks`, cohort fields |
| Open flow | none | `open_flow_duration_ticks` |
| Counter then seating | `counter_tokens`, `table_tokens` | `counter_duration_ticks`, `seated_duration_ticks` |

### Common transition semantics

Each request receives a monotonic Service-owned `join_ordinal`; FIFO ties are `(join_ordinal, visitor_id)`. A token tie chooses canonical token ID. A joint token tie compares the ordered tuple of canonical token IDs. A cohort is always the longest FIFO prefix allowed by the selected token capacity, `cohort_max`, and available occupants: it starts normally only when its size is at least `cohort_min`; when `allow_partial_cohort` is true, the nonempty prefix may start below `cohort_min` only after the head has waited `partial_timeout_ticks`. No later visitor bypasses the FIFO head.

At one tick, canonical scheduler phase order is service ID, `COMPLETE`, `BATCH_START`, `PROMOTE`, `ADMIT`, then token ID and visitor ID. `COMPLETE` includes active-batch release and turnover start. Every completion and required token release occurs exactly at `start_tick_identity + stage_duration_ticks`; all due `COMPLETE` work is processed first and unconditionally within the content-proven bound and may never be deferred by a work budget. Stage-to-stage acquisition/release is atomic in the same service/tick transaction. Capacity and tokens are never overcommitted.

The nine typologies have these exact transitions:

| Typology | Deterministic stages and token rules |
|---|---|
| Host/table | Exterior FIFO forms a cohort by the common cohort rule against the earliest available table whose authored capacity can hold it. One atomic promotion acquires that table for the cohort, enters the authored seated stage, and holds the table until every cohort member completes together. |
| Counter | Only FIFO head may promote. It acquires the earliest available counter token, enters the counter stage, and releases the token on completion. |
| Browse/checkout | Admission up to `occupancy_cap` enters the browse stage without a checkout token. Browse completion joins an internal checkout FIFO using original join ordinal/visitor ID; its head acquires the earliest checkout token, completes checkout, then releases token and occupancy. Abstract occupancy is held while waiting internally. |
| Service bay | Only FIFO head may acquire the earliest available bay token. It holds the bay through the authored bay-service stage and releases it on completion. |
| Scheduled batch | Service owns at most one active batch and one next batch. Accepted FIFO visitors may populate only the next batch up to `batch_capacity`; no third/future batch exists. At a valid cadence boundary, if no active batch exists and turnover has completed, `BATCH_START` atomically promotes the complete next FIFO (up to capacity), frees its exterior positions, and makes it active. Active-stage completion releases all members together during `COMPLETE`, starts the authored turnover interval, and only a later valid cadence boundary after turnover may start the next batch. |
| Device pool | Admission up to `occupancy_cap` enters the authored pre-device stage, then joins an internal device FIFO using original join ordinal/visitor ID. Its head acquires the earliest device token, enters the device stage, and releases token and occupancy on completion; occupancy remains held while internally waiting. |
| Cohort/device | Exterior FIFO forms a cohort by the common cohort rule against the earliest available activity/device token and its authored capacity. Promotion atomically acquires that token for the cohort; all members complete the authored activity stage together and then release it. |
| Open flow | FIFO admission proceeds while abstract occupancy is below `occupancy_cap`; each visitor occupies one slot for the authored open-flow duration and releases it independently at completion. No token or internal FIFO exists. |
| Counter then seating | Only FIFO head may promote, and only by atomically acquiring the earliest available counter token and earliest available table token as the canonical pair. The table is reserved immediately and held through both counter and seated stages; the counter is released when the counter stage ends, and the table/occupancy are released only after seated completion. Partial acquisition is forbidden. |

Expected wait is computed by a side-effect-free run of this same transition simulator from the same committed Service snapshot, request-effective tick, FIFO ordinals, token IDs, capacity, cadence, phase order, cohort rules, candidate request, transition budget, and deferred cursor semantics. Due `COMPLETE` work remains exact in the simulation. It does not use a separate formula or presentation estimate.

### Epoch and phase

Service scheduler epoch is the mathematical constant `E = 0` in TimeManager's monotonic visitor-boundary ordinal domain. It is an H4 service-policy convention, not a persisted or published TimeManager origin/snapshot field. TimeManager supplies current monotonic tick identity `t` and continues to persist its already-approved current calendar identity only; H4 adds no Time state.

For service `s`, policy `p`, and positive cadence `c`, compute SHA-256 over RFC 8785 canonical JSON:

```text
{"domain":"tenant_service_phase_v1","service_id":s,
 "service_policy_id":p.id,"service_policy_revision":p.revision}
```

Interpret digest bytes as one unsigned big-endian integer and set `phase_offset = digest mod c`. A boundary is valid exactly when `t >= E + phase_offset` and `(t - E - phase_offset) mod c == 0`. Text concatenation is forbidden; golden vectors define canonical scalar types. Fixed completion remains `start_tick_identity + duration_ticks`.

Service owns a transient last-consumed marker. Restore initializes it to restored current `t`, so no retroactive scheduler work runs. A request outside dispatch commits queue occupancy immediately but is scheduler-effective at the next unconsumed tick. During dispatch it is effective at current `t` only if `ADMIT` has not passed, otherwise at the next tick. H5 supplies graph/topology revisions only and has no scheduler-origin dependency.

Only not-yet-committed `PROMOTE` and `ADMIT` work may be deferred by the scheduler budget, in canonical order without cursor bypass. `BATCH_START` is promotion work for this rule and may defer only before its atomic start commits. The actual admission/start identity is the tick on which that work commits. Once any individual, cohort, or scheduled batch has started, its due completion and release remain exact and cannot defer.

## Cross-authority transaction protocol

Only owners whose immutable state changes participate, and only participating owner revisions advance. Visitor-only rejection, exclusion, decision, or route state never swaps or advances Service. Service-only token, stage, expected-wait, or scheduler-marker changes never swaps or advances Visitor. Read-only captured owners are revalidated but do not receive fabricated revisions or fact notifications.

Every transaction uses the existing session gate, non-failing journal append commit point, and protected synchronous flush:

1. Capture participating owner states and every read-only source revision; prepare complete detached next states and one complete fact envelope outside the gate where possible.
2. Complete every fallible calculation and append-capability preflight.
3. Acquire the session gate and revalidate all captured revisions, tokens, and affected visitor states.
4. Apply non-failing prepared swaps in existing order, Visitor then Service, but only for changed participating owners; advance only those revisions.
5. Append exactly one complete aggregate envelope to the non-failing journal. Append is the commit point.
6. Synchronously flush aggregate then participating owner facts in fixed Service-before-Visitor notification order while the gate remains held. Subscriber faults are isolated diagnostics and cannot roll back/reorder commit.
7. Release the gate.

A multi-visitor scheduler transaction lists affected visitor IDs sorted canonically and exact before/after revisions for every participating owner in its aggregate envelope. A visitor absent from the affected array cannot be mutated. Admission, promotion, cohort/batch transition, cross-owner cancellation, and completion use this protocol. Owner-local transactions use the same gate/journal/preflight/append/flush pattern with only that owner's before/after revision; they never fake participation by another owner.

Any pre-append fault restores every participating prior state, invalidates prepared tokens, and emits nothing. After append there is no rollback. Save, topology mutation, input, or another service transaction cannot interleave between swap, append, and flush. H2 topology mutations continue to use H2's broader approved owner order and protocol.

## CirculationCostPolicy and occupancy snapshot

Session selects and compiles one deeply immutable versioned `CirculationCostPolicy`. Missing, mistyped, non-integral, overflowing, or invalid values reject content; there are no runtime defaults. It contains policy ID/revision and all arithmetic constants: `base_tile_cost = 100`; per-mille class multipliers `empty = 1000`, `elevator_lobby = 1200`, `queue = 2000`, `congested = 2500`; `congested_count_threshold = 5`; occupancy factor base `1000`, per-occupant coefficient `150`, and divisor `1,000,000`; signed-64-bit arithmetic requirement; plus authored absolute integer `repath_improvement_threshold`, positive `max_dynamic_repaths_per_visitor_per_goal`, and positive `max_route_evaluations_per_tick`. Session validation proves worst-case arithmetic under the 200 cap cannot overflow.

Logical occupancy comes only from stable IDs in committed Visitor movement state, never world interpolation, transforms, or Nodes:

- one active moving/deciding/leaving visitor contributes to exactly one current public graph cell;
- a visible exterior queue visitor contributes to its queue-position parent graph tile instead;
- `EVALUATING_AT_DOOR` contributes to the proxy public cell;
- `IN_ABSTRACT_SERVICE` contributes zero corridor occupancy;
- a visitor traversing a vertical link remains in the source elevator-lobby cell until the authoritative transition, then occupies the destination elevator-lobby cell; and
- no visitor can contribute to two cells in one snapshot.

VisitorManager maintains incremental cell counts and occupied-queue-tile indexes and publishes one whole-building immutable `VisitorOccupancySnapshot` at each authoritative visitor tick. It contains exactly one `occupancy_tick_identity`, sorted `(stable_graph_cell_id, count)` entries across all floors, sorted queue-class cell IDs, H5 `graph_revision`, CirculationCostPolicy ID/revision, and a lowercase RFC 8785/SHA-256 fingerprint over exactly those fields. Queue class exists iff at least one visible queue occupant is on the tile. Congested class exists iff count > 5. The effective class is the applicable class with the greatest multiplier; therefore queue+congested is 2500, lobby+queue is 2000, and lobby+queue+congested is 2500. Queue class changes cost but never blocks an edge. For cache identity, `occupancy_class_fingerprint` is the lowercase RFC 8785/SHA-256 digest of the sorted whole-building `(stable_graph_cell_id, count, effective_class, endpoint_cell_cost)` array plus CirculationCostPolicy ID/revision; it intentionally excludes tick identity so byte-identical effective costs reuse paths.

For a cell with occupancy `n` and effective class multiplier `m`:

```text
occupancy_factor = 1000 + 150 * n
endpoint_cell_cost = floor(100 * m * occupancy_factor / 1_000_000)
```

Each route edge retains H5/Construction's authoritative base edge cost. H4 adds the destination endpoint cell cost once when that cell is entered; the route's current source cell is not charged again. This also applies to vertical-link endpoints, but vertical-link base cost/topology remains exclusively H5/Construction. H5 graph-node metadata owns the elevator-lobby class; H4 applies its 1.2 multiplier. Operational elevator queues, trips, timing, and capacity are explicitly deferred to a separate Transit runtime handoff. H4 defines no hidden vertical travel model.

A same- or cross-floor route captures one complete whole-building occupancy snapshot at one tick and one matching graph revision. It never combines per-floor ticks. New routes use the latest matching snapshot. Immutable snapshots are reused across requests.

## Routing, ties, and repath

A* enumerates each node's outgoing edges sorted by stable edge ID. Every route request computes `request_seed_digest = SHA256(RFC8785(record))`, where the record contains exactly:

```text
{"circulation_policy_id":<canonical string>,"circulation_policy_revision":<integer>,
 "destination_id":<canonical string>,"domain":"visitor_route_tie_v1",
  "graph_revision":<integer>,"occupancy_class_fingerprint":<lowercase hexadecimal string>,
  "source_anchor_id":<canonical string>,"visitor_id":<canonical string>}
```

The complete route request and path-cache identity is exactly graph revision, `occupancy_class_fingerprint`, CirculationCostPolicy ID/revision, visitor ID, source anchor ID, and destination ID. `occupancy_tick_identity` remains snapshot provenance but does not participate in request identity, cache identity, or equal-cost tie ranking; byte-identical effective costs therefore reuse the same path across ticks. For candidates with equal integer `f` and `g`, rank the candidate edge/node by SHA-256 of RFC 8785 canonical JSON containing exactly `request_seed_digest` as its lowercase hexadecimal string and `candidate_stable_edge_id` as a canonical string. Compare digest values as unsigned bytes, then stable edge ID if digests are equal. No dictionary order, insertion order, mutable route ordinal, floating-point value, or RNG state participates. This deterministic hash ranking realizes the approved randomized route variation.

At visitor ticks, an existing valid route is considered for dynamic repath only when an endpoint cell on its remaining route changes effective multiplier class. Compare integer remaining cost from the visitor's current logical cell with a fresh alternative under one matching graph/occupancy snapshot. Repath only when `current_remaining_cost - alternative_cost >= repath_improvement_threshold`. Each attempted alternative consumes one of `max_dynamic_repaths_per_visitor_per_goal`; reset that count only when goal ID, destination ID, or topology revision changes.

All route evaluations consume the per-tick `max_route_evaluations_per_tick` budget in canonical visitor-ID order. Budget exhaustion defers canonical non-invalid work to a later tick. A route invalidated by topology is discarded immediately; its visitor pauses at the validated logical anchor and never traverses stale edges while awaiting safety recovery. Topology-invalid work is safety work and is not converted into ordinary deferred travel.

## Completion, cancellation, and topology recovery

Completion atomically releases all tokens/occupancy, advances or completes the current goal exactly once, clears exclusions only under H1 rules, chooses DECIDING or LEAVING, and records one immutable tenant-service result. The result contains stable identity/provenance, approved current calendar identity, result kind, `scheduled_completion_tick_identity`, and `actual_completion_tick_identity`; both completion identities are the exact `start_tick_identity + duration_ticks` value and therefore equal. It has no economic field/effect and never reinterprets historical proxy results.

Ordinary cancellation at a still-valid target proxy releases queue/token/service records, adds the tenant exclusion for the current goal, and returns the visitor to `DECIDING` at that exact public proxy. It is idempotent and creates no result or progress.

Topology invalidation uses the public resume anchor prepared and validated by H2's shared topology transaction: the last valid route anchor or proxy that exists in the prospective graph. If none exists, the visitor enters `LEAVING` at a validated current public anchor and invokes approved H8 canonical exit selection/retry. There is no coordinate, transform, nearest-cell, Node, interior, or obsolete-proxy fallback. Route and exit retries remain bounded by Visitor H1; exhausted exit selection leaves the visitor active and paused for the approved later H8 retry, never removed elsewhere.

## Scalability and work budgets

Production implementation must use incremental logical-occupancy and queue-class indexes, reuse immutable directory/graph/occupancy snapshots, and cache paths by the exact complete route request identity defined above. It must not rebuild topology, all-floor occupancy, or token pools per visitor. Target-directory work caches one immutable snapshot per exact revision tuple and coalesces rebuild requests; bounded on-demand selection may populate that shared cache but does not create a private per-visitor directory. Detached target, route, expected-wait, and scheduler preparation runs outside gates where possible; gate-held work is capture/revalidation, atomic cache publication, non-failing swaps, append, and protected flush only.

Route work uses `max_route_evaluations_per_tick`; scheduler work uses `max_service_transitions_per_tick`; each wait query uses `max_expected_wait_simulation_steps_per_request`. The validated scheduler bound always processes all due `COMPLETE` work first and exactly; it may defer only not-yet-committed `BATCH_START`/`PROMOTE`/`ADMIT` work in canonical service ID, phase, token ID, then visitor ID order without partially applying a transition or bypassing the deferred cursor. Here `BATCH_START` is the scheduled-batch form of promotion; after its start commits, its completion cannot defer. Deferred admission/start work takes the tick of eventual commit as its actual admission/start identity. The expected-wait simulator applies the same budget and deferred cursor semantics. A wait simulation that exhausts its bound returns explicit unavailable and rejects admission without a fabricated estimate. Safety/topology-invalid visitors stop at validated anchors until recovery work completes. No work limit permits late completion/release, stale traversal, capacity overcommit, mixed revisions, or dropping a visitor.

Release evidence must run a representative 200-active-visitor workload spanning moving, DECIDING/EVALUATING, visible queued, abstract-service, and LEAVING visitors; all nine typologies; same-floor and cross-floor routing; congestion class changes and repath; scheduler cohort/batch/token transitions; and concurrent topology invalidation. The candidate must satisfy H10 Hybrid R1 absolute and same-hardware-relative release performance limits. Evidence records tick duration, allocations, route evaluations, path-cache hits/misses/entries, scheduler transitions/simulator work/deferred counts, occupancy-index update work, and retained objects, in addition to H10 FPS/frame/draw-call/Node/memory/build/rebuild/save/load/leak metrics.

## Mutation, save, capability, and events

H2 coordinates every topology invalidation. Save barriers block mutations/events and torn commitments. Interior capability is persisted/bootstrap-selected and never hot-switched. EventBus announces detached committed facts only. Layout rebuild is revision-driven; fixture/projection Nodes own no authority or processing. Service snapshots expose committed identities/revisions, availability, typology, activated positions/FIFO, tokens/occupancy/stages, expected wait, batch/next transition, and diagnostics; UI and Visitor never estimate these from visuals.

## Acceptance requirements

- H8 step 4 captures exactly one complete availability snapshot; Service never joins the H8 token/revalidation, and post-capture staleness never changes arrival timing.
- Full category provenance, goals, wait, policy, seed, and ordinal persist and validate without current availability or reroll, including the explicit empty case.
- Target selection uses one exact revision-keyed directory/source/Visitor capture, invalidates after any source commit, can perform a bounded detached on-demand rebuild, obtains a matching directory on the next bounded retry once revisions stabilize without requiring Service mutation, selects the first canonical compatible reachable proxy, and preserves pre-commit revalidation and Visitor-only commit without mixed revisions.
- Effective exterior capacity is the exact minimum rule and governs only `WAITING_EXTERIOR`; immediate admission bypasses zero/full exterior capacity when all occupancy/tokens/start conditions are immediately acquirable and wait passes, while a visitor that cannot immediately admit requires a free exterior position or is rejected. Only occupied position parents classify as queue tiles, and all two-per-tile cases hold.
- Every typology and expected wait use the same exact stage/token/cohort/batch simulator and authored required fields without defaults.
- Only changed owners/revisions participate; owner-local and multi-visitor aggregate envelopes preserve the existing append/flush commit protocol.
- Whole-building logical occupancy, integer costs, H5 lobby/vertical ownership, deterministic A* ties, repath thresholds/resets/budgets, and topology pause rules hold exactly.
- Scheduler epoch is constant zero, no Time origin is persisted, restore runs no retroactive work, and phase survives reload by deterministic recomputation.
- All Visitor states count toward 200; cancellation/recovery has only validated public-anchor and H8 exit behavior; removal occurs only at a valid H8 exit.
- Results remain exactly-once, non-economic, and disjoint from historical proxy results; no unavailable, recovery, or capability fallback exists.
- Due completion/release is exact and unconditional within the validated theoretical maximum; only uncommitted admission/promotion work may defer with matching scheduler/simulator cursors, and result scheduled/actual completion identities are equal.
- Route ties and cache identity use `occupancy_class_fingerprint`, not tick identity, so byte-identical effective costs reuse one path across ticks.
- Representative 200-active evidence satisfies H10 limits without per-visitor directory rebuilds, duplicate same-tuple rebuilds, unbounded work, stale traversal, or retained-object growth.

## Required tests

- H8 exact snapshot shape/fingerprint/category ordering and atomic publication; exactly-one provider read; empty/nonempty generation; post-capture Service/Tenant/graph changes; every pre-append fault; unchanged H8 token, step-5 checks, single envelope, and flush.
- Persistence/restore of the full captured category array, fingerprint/empty marker, visitor policy, seed/ordinal, goals/wait/progress/drop/exclusions, with generation validation independent of current availability and no reroll.
- Exact directory revision-key construction including relevant policies, invalidation after every source commit, same-tuple rebuild coalescing/cache reuse, bounded detached capture/derive/reacquire/revalidate publication, on-demand rebuild without Service mutation, stabilization success on the next bounded decision retry, continued-change `DECIDING` behavior, all H1 filters, canonical proxy order, same/cross-floor reachability, stale Tenant/Service/graph/policy/Visitor revalidation, Visitor-only revision/envelope, and no mixed revisions.
- Queue capacity minimum, direct admission with zero/full exterior capacity when wait and all immediate occupancy/token/start conditions pass, zero/full rejection only when waiting is required, operational activation, safe committed IDs only, maximum two positions per parent, FIFO ties, occupied-versus-empty queue classification, and one-to-one Visitor/Service positions.
- Content rejection for each missing/invalid typology-required field and unresolved token count source, plus rejection when `max_service_transitions_per_tick` is below the theoretical configured-service maximum under the 200-active cap; scheduler and expected-wait golden traces for all nine typologies, every stage/token tie, FIFO/cohort min/max/partial/timeout, joint acquisition, occupancy hold, one-active/one-next batch, cadence/release/turnover, exact non-deferrable due completion/release, uncommitted-only batch-start deferral, deferred admission/start commit identities and cursors, equal scheduled/actual result completion identities, and same-tick phase order.
- Constant-zero phase RFC 8785/SHA-256 vectors, boundary equation, outside/during-dispatch admission, restored last-consumed marker, no Time-origin field, no retroactive work, and current calendar identity preservation.
- Owner participation matrix covering Visitor-only rejection/exclusion/route, Service-only token/stage/marker, two-owner admission/cancellation/completion, sorted multi-visitor before/after revisions, append fault rollback, subscriber faults, and reentrant save/input/mutation exclusion.
- Logical occupancy for every Visitor state, queue parent substitution, abstract zero, vertical source/destination boundary, all-floor atomic snapshots/fingerprints, incremental index parity, queue iff visible occupant, congestion `count > 5`, multiplier precedence, integer arithmetic/overflow, and H5 base-edge/lobby ownership.
- A* canonical neighbors and exact two-stage hash goldens using `occupancy_class_fingerprint`, dictionary/enumeration permutations, same/cross-floor snapshot provenance, byte-identical-cost path reuse across different occupancy ticks, exact graph/fingerprint/policy/visitor/source/destination cache identity and invalidation, class-change-only repath, absolute threshold equality, attempt reset rules, canonical route-budget deferral, and immediate stale-edge stop.
- Ordinary cancellation exclusion/resume, every H2 prepared-anchor branch, no-valid-resume H8 exit selection/retry, bounded H1 exhaustion, idempotence, no coordinate/Node fallback, and active-cap accounting through every state until valid exit removal.
- Fault injection at every pre-append boundary; exactly-once goal/result behavior; proof no Economy, price, revenue, rent, viability, satisfaction, demand, or Prestige mutation and no proxy/capability fallback.
- Representative 200-active release workload with all typologies and states, same/cross-floor routing, congestion repath, scheduler/topology invalidation, exact due completion under budget pressure, deferred uncommitted promotion/admission cursor parity with expected-wait simulation, coalesced revision-keyed directory rebuilds, safety pauses, tick/allocation/cache/scheduler/index/retained-object instrumentation, repeated cycles, H10 absolute/relative limits, and leak-free exit.

## Required implementation skills

`state-machine`, `ai-navigation`, `event-bus`, `dependency-injection`, `resource-pattern`, `scene-organization`, `math-essentials`, `godot-testing`, and `godot-optimization`.
