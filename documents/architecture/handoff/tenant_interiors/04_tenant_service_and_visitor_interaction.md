# Tenant Interiors Handoff 04 — Tenant Service and Visitor Interaction

**Status:** Architecture approved, 2026-09-08 follow-on request to complete non-code work. Replaces the former draft under [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md). Implementation and acceptance are NOT VERIFIED. Order: 4 of 5; foundation and detached H1-H3 evidence are prerequisites. H5 controls production cutover.

## Requirement and boundaries

Implement [Current MVP](../../../game_design/current_mvp.md) and [element 20](../../../game_design/elements/20_tenant_interiors_visitor_interactions.md): fixture-driven capacity, visible exterior FIFO, door-time wait decisions, nine abstract service typologies, goals and public congestion. Retain immediate district arrivals, the 200-active cap, public-only movement and existing exit ownership. No indoor navigation, visitor money, revenue, viability, satisfaction, rent changes, attraction scoring or proxy fallback.

FACTS: element 20 defines partial table cohorts, next-batch-only booking, no ordinary abandonment and independent Open/rent eligibility. ASSUMPTIONS: expected door wait means time until exterior-to-abstract admission, not later internal checkout/device waiting; the common table-cohort rule covers counter-then-seating as well as host/seating. These interpretations are explicit review points in ADR 34, not additional gameplay systems. OPEN QUESTIONS: no unspecified engineering tuning may be filled at runtime; alternative player-facing interpretations of those assumptions require design confirmation before the affected acceptance cases can be signed off.

## Ownership and Godot composition

```
MainGame (Node; composition/lifecycle, existing session scene)
├── Simulation (Node)
│   ├── TenantManager (Node; identity, Open state, layout provenance)
│   ├── TenantServiceManager (Node; service runtime)
│   └── VisitorManager (Node; visitor records and central behavior)
├── Projection (Node3D; disposable)
│   ├── TenantInteriorProjectionRoot (Node3D)
│   ├── QueuePresentationRoot (Node3D)
│   └── VisitorProjectionRoot (Node3D)
└── UI (CanvasLayer; existing presentation)
```

Names describe roles, not mandatory new helper classes. Service is session-scoped and injected, not an autoload. Immutable Resources define content; mutable service records belong only to Service. Fixture/view PackedScenes contain presentation, not service timers or gameplay ownership. Session teardown disconnects consumers and frees all service records and projections; content definitions may be shared read-only.

| Owner | Authoritative facts | Lifetime/persistence |
|---|---|---|
| Service | Availability, queue assignments/FIFO, token occupancy, cohorts, stages, active/next batch, join ordinals and service revision | Session runtime; reset on H5 load |
| Visitor | Goals/provenance, state, logical anchor, visitor-side commitment reference, exclusions, progress/results and cap membership | Durable subset under H5 |
| Zone | Parcel/automatic-door records and committed exclusive queue envelopes | Durable under H2/H5 |
| District/public-realm owner | Manual doors; resolved public graph, stable anchors/edges and lobby metadata | Existing district contracts; derived graph |
| Tenant | Binding, profile, lifecycle, primary proxy and layout provenance | Durable under H3 |
| Time | Elapsed clocks and boundary identities | Existing Session H1 snapshot |
| Session | Dependency injection, content validation, shared commit orchestration | Session, no extra mutable gameplay authority |

Service commits visitor-side commitment changes only through Visitor participation. A queue position exists in both prepared states or neither; neither owner writes the other directly. Runtime service identity uses existing canonical stable-ID framing over tenant/profile/service-policy identity. Token/fixture/position identities use semantic layout slots, never Node names, transforms or collection enumeration order.

## Inputs, availability and arrival

Inputs are complete immutable Tenant, Zone/public-graph, Visitor and policy snapshots with source revision tuples. An Open tenant initializes OPERATIONAL only from a matching validated H3 manifest and H2 envelope; otherwise SERVICE_UNAVAILABLE with a diagnostic. This does not close the tenant or stop rent.

Service exposes one atomic availability snapshot: service revision, sorted unique operational category IDs, source Tenant/graph revisions, visitor-policy identity/revision and a canonical fingerprint. It is derived state. The existing session coordinator rebuilds it after relevant source commits, outside observer callbacks, before the next arrival boundary. A candidate cannot publish against stale sources.

`district_layout/H8` step 4 reads this complete snapshot once while preparing the visitor. Service is NOT added to H8's arrival validation token/revalidation. Subsequent availability changes never delay, reject or reroute an already prepared arrival. H8's single append/flush commit and ordinal rollback remain unchanged. Empty categories use H1's exact Browsing-then-Leaving exception.

Durable visitor generation provenance is separate from runtime availability provenance. Persist the captured sorted category array, explicit empty marker, visitor-policy ID/revision and `generation_fingerprint`: lowercase SHA-256 of RFC 8785 canonical JSON containing exactly `category_ids`, `empty`, `visitor_policy_id`, `visitor_policy_revision`. Also retain seed domain/value, creation ordinal and generated goals/wait under H1. Do not save a runtime availability fingerprint without all its inputs or compare historical categories to current services. This refines H1's earlier shorthand about category fingerprints. Pure verification may recompute expected generation; it never replaces saved goals or advances RNG/ordinals.

## Target selection and visitor states

Visitor states: DECIDING -> TRAVELING_TO_SERVICE -> EVALUATING_AT_DOOR -> WAITING_EXTERIOR or IN_ABSTRACT_SERVICE -> DECIDING or LEAVING. Rejection returns to DECIDING with the current tenant excluded. All states count toward 200, including abstract occupants and recovery/exit retries. Only a valid `district_layout/H8` exit removes a visitor.

At an H1 decision boundary, capture matching Tenant/Service/public-graph/policy facts and Visitor revision. Filter Open, operational, current-goal-compatible, reachable, non-excluded targets. Choose the first canonical parcel-door proxy (NFC-normalized UTF-8 order). Queue length, expected wait and path congestion do not select the destination. Commit only Visitor after all captured sources revalidate. No target follows H1 goal drop/advance/Leaving; no price or attraction weighting is introduced.

A stale capture commits nothing and retries at the next bounded decision boundary. Once sources stabilize, a fresh selection must succeed without waiting for a Service mutation. A shared revision-keyed target directory is an optional optimization, not a new coordinator/authority. No consumer may combine mismatched source revisions.

## Admission and FIFO

Queue activation uses only H2's committed safe position IDs assigned by the manifest. At most two positions share a parent public tile; neighboring services never share a position. Exterior capacity is `min(policy queue cap, activated safe position count)`. Zero is valid. Only occupied positions contribute queue congestion.

At the door, a candidate is ordered after all existing commitments. Compare one authoritative expected-wait estimate with saved tolerance; equality accepts. Rejection/unavailable estimate adds the current-goal exclusion, reserves nothing and produces no service result. Tolerance does not decay after commitment.

Direct admission bypasses the need for an exterior position, NEVER existing FIFO claims. It is allowed with zero/full exterior capacity only after earlier eligible commitments have been processed and all required occupancy, tokens and start conditions can commit immediately. Otherwise a free exterior position is required; a full/zero queue rejects. Allocation and Visitor state swap are one transaction.

Service orders commitments by `(join_ordinal, visitor_id)`; free resources by canonical token ID. Ordinals advance only on successful commitment. Cohorts are the nonempty FIFO prefix fitting the selected table/activity token and remaining abstract occupancy. Partial fills start immediately; no invented minimum cohort, timeout or no-show mechanics. Later arrivals cannot join an already started cohort.

## Service transitions

Content must explicitly encode element 20's durations, capacity sources and queue caps; no fallback fields. Durations are positive integer visitor ticks. Tokens derive from matching manifest slots. Occupancy remains held through internal waits. Mandatory programs must produce positive usable capacity. Invalid content rejects before production readiness.

| Typology | Entry and progression | Release |
|---|---|---|
| Host/table | FIFO cohort acquires one table, enters seated stage | Whole cohort releases table/occupancy together |
| Counter | FIFO head acquires one counter | Counter stage completion releases token/occupancy |
| Browse/checkout | Admission takes occupancy; browse completion enters internal checkout FIFO ordered by original join ordinal; head claims checkout | Checkout completion releases token/occupancy |
| Service bay | FIFO head claims one bay/consultation/treatment token | Service completion releases token/occupancy |
| Scheduled batch | Reservations populate only one next exterior batch; cadence transfers it inside, up to batch/occupancy capacity | Active completion releases all, followed by turnover |
| Device pool | Admission takes occupancy; pre-device stage leads to internal device FIFO | Device completion releases token/occupancy |
| Cohort/device | FIFO cohort takes one activity token | Shared activity completion releases group/token |
| Open flow | FIFO admission takes an occupancy slot without tokens | Individual duration completion releases occupancy |
| Counter then seating | Table cohort atomically reserves one table and counter; shared counter stage, then shared seated stage | Counter released at stage transition; table/occupancy released together after seating |

The last row applies element 20's table-cohort interpretation explicitly; it does not add per-seat navigation or independent customer orders. Confirm that interpretation in visual/design acceptance; changing it changes capacity/throughput and is not an engineer tuning choice.

## Clock, scheduling and expected wait

Use Time's visitor ordinal, not per-tenant Timers. Session H1 persists simulation elapsed time, including sub-boundary remainder: `t = floor(simulation_elapsed_seconds / 5)` and the remainder reconstruct the current ordinal and delay to the next tick. Preserve numeric round-trip precision and validate finite, nonnegative elapsed values. Calendar labels alone are insufficient. No second persisted clock/origin is introduced. Save occurs only between fully delivered boundary chains, not midway through a catch-up frame.

At each visitor tick, phase order is GLOBAL COMPLETE -> BATCH_START -> PROMOTE -> ADMIT; within each phase use service ID, token ID and visitor ID. COMPLETE releases every due stage first across all services. Internal stage transitions and token swaps are atomic. ADMIT processes door evaluations after prior commitments. Requests arriving after a phase cannot retroactively join it. Each phase commits all enabled work; positive durations and 200 active visitors bound work. The former draft's promotion budgets/deferred cursors are removed: CPU budgets must not change service timing or FIFO. A failed authoritative phase halts the boundary chain for diagnostic/retry; no later tick/save proceeds with a half-consumed chain.

A service may have one active and one next batch. Cadence phase is derived from the existing draft convention: SHA-256 over canonical JSON with `domain = tenant_service_phase_v1`, `service_id`, `service_policy_id`, `service_policy_revision`; unsigned big-endian digest modulo cadence. Epoch is visitor ordinal zero. A batch starts only at a valid cadence boundary after turnover, using reservations committed BEFORE BATCH_START. Reservations arriving in ADMIT wait for the following valid boundary; never start off-cadence or book a third batch. Empty batches do not occupy service. Exact completion identity is start ordinal plus positive duration.

Expected wait is integer ticks until admission to abstract service, including initial joint-resource acquisition or scheduled entry. Internal checkout/device waits are not exterior wait. Compute from the same pure per-service transition rules, current phase, committed FIFO/tokens/stages and prospective candidate after existing commitments. Assume no future arrivals or topology changes; estimates are not promises about future mutations. All prior claims are included. Simulation advances to relevant stage/cadence events, not through every empty tick. With no cyclic stages and at most 200 active commitments, establish a finite event bound from the configured stage graph; inability to prove it is invalid content. Unexpected bound exhaustion returns unavailable, not a guessed wait. No global budget cursor or whole-building future simulation is needed.

## Routing and congestion

Preserve `district_layout/H5`/Construction public graph and base edge costs. Add the destination cell cost once per traversed edge, not the current source cell. No indoor graph or operational elevator simulation is introduced.

Versioned CirculationCostPolicy encodes the element-11 weighting: base 100; per-mille multipliers empty 1000, lobby 1200, occupied queue 2000, congested 2500; congestion means current logical count > 5. Choose the greatest applicable multiplier. Endpoint cost is `floor(100 * multiplier * (1000 + 150 * count) / 1000000)`. Validate checked integer arithmetic against the active cap. Snapshot all floors at one boundary and graph revision. A moving/deciding/leaving visitor contributes once at its logical cell; door evaluation at proxy cell; exterior waiter at position parent; abstract service contributes zero. Vertical traversal remains at source lobby until authoritative arrival at destination. Transforms are never occupancy inputs.

Deterministic shortest-path evaluation uses stable edge order and hash-ranked equal-cost alternatives, keyed by visitor, source/destination, graph, policy and effective occupancy-content fingerprint. Timestamp is provenance, not part of effective-cost identity. Use H1 canonical framing, never a call-order RNG. Re-evaluate a valid route when a remaining-route cell changes cost class, at most once per visitor per tick; replace only with a strictly cheaper path (integer improvement >= 1). This removes undefined draft attempt/budget tuning. At most 200 visitor route requests occur per tick; static reachability work may be shared. A topology-invalid route stops immediately at a validated anchor, independent of this cadence. Safety recovery cannot traverse stale edges while queued for work.

## Transactions, events and invalidation

Use ADR 33's one non-reentrant session gate. Capture -> detached prepare -> revalidate -> non-failing participating swaps -> existing aggregate append commit -> protected ordered facts -> release. Existing append/flush means in-memory notification coordination, not durable event sourcing or a new transaction framework. Only changed owners advance revisions. Service-only stage changes do not fabricate Visitor revisions; rejection/route changes do not fabricate Service revisions. Multi-visitor facts carry sorted affected IDs and before/after owner revisions. Observer faults after commit are diagnostics, never rollback. No callback reentrancy, save or topology edit interleaves a commit.

| Fact/intent | Producer -> consumer | Payload/boundary |
|---|---|---|
| Door evaluation intent | Visitor -> session transaction -> Service | Visitor/proxy/goal IDs, captured revisions; accepted commitment or structured rejection |
| Service committed | Service -> read-only UI/projection observers | Service/tenant IDs, revision, affected visitor IDs; fetch immutable snapshot |
| Goal completion | Service+Visitor joint commit -> observers | Exactly-once non-economic result, scheduled/actual completion ordinal, goal/provenance |
| Topology candidate | Existing Zone/District coordinator -> participating Tenant/Service/Visitor | Prospective graph and invalidation set under H2; prepared replacements/resume anchors |
| Load committed | SaveManager -> session consumers | One post-publication game_loaded; no replayed service results |

Ordinary cancellation releases all commitments/tokens, excludes the tenant, and resumes DECIDING at its still-valid public proxy; no progress/result. H2 topology mutation prepares a valid surviving public resume anchor for each affected visitor before any owner commits. If no permitted resume exists, use the approved H8 valid-anchor exit/retry contract; never nearest-cell/transform fallback or silent deletion. If no legal candidate state exists, reject the mutation rather than publish an invalid visitor. Tenant deadlines/rent remain independent of service/projection failure.

## Scalability, extensibility and risks

Use central records and shared immutable snapshots; no per-fixture processing, service Timer Nodes, generic FSM or second service locator. Revision caches and incremental occupancy are recommended only if profiling warrants them; results must equal the uncached reference contract. Bound retained caches and clear all session references on teardown. Add future typologies through explicit content validation and transition contracts, not arbitrary script execution from saves. Multiple entrances, exact in-flight persistence, economics and indoor navigation require separate approval.

Risks: maximum-service workloads may exceed frame limits; optimize detached work without changing dates or FIFO. Canonical hashing/JSON must match H1 and exact integer domains; default engine JSON output is not assumed RFC 8785. Reload intentionally resets service commitments; it preserves cadence, not elapsed service. The wait/cohort interpretations above require explicit acceptance review, not silent production assumptions.

## Required acceptance and tests (NOT RUN)

- All nine transition traces: minimum/preferred capacity, partial groups, internal waits, joint-token failures, one-active/one-next batches, zero/full queues and FIFO direct-admission regression.
- Wait simulator/live parity with frozen external inputs; equal tolerance; no feasible estimate; no future-arrival assumptions; arrival immediately before/after batch phase and turnover boundaries.
- Phase-first order across multiple services; exact release, catch-up, pause/speeds, no CPU-budget delay; fault/retry cannot duplicate transitions or permit a torn save.
- H8 reads availability once without changing its token/revalidation; captured historical category provenance survives current category changes and empty-category generation.
- Visitor-only, Service-only and joint commits; every pre-commit failure; isolated observer faults; reentrant mutation/save rejection; exactly-once progress/non-economic result.
- Logical occupancy per state/floor, queue cap/exclusivity, integer weight precedence, stable route ties, cheaper-only repath, topology recovery and valid-exit-only removal.
- 200 active visitors across all states/typologies/floors; no unbounded work or retained-state growth; measure service/route/wait work, allocations and frame/memory metrics against the existing H10 release contract.

Implementation skills: `scene-organization`, `resource-pattern`, `state-machine`, `ai-navigation`, `dependency-injection`, `event-bus`, `godot-testing`, `godot-optimization`. Skill examples do not override the domain graph, authority or save contracts.
