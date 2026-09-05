# Staff Handoff 01 — Cleaning, Security, and Wages

**Status:** Approved — 2026-09-05 (delegated architecture authority)

## Purpose

Define the smallest testable staff MVP. A session-scoped Staff authority validates hiring only into an existing valid Operations Room, owns generic Cleaner and Security records, exposes source-backed coverage and cleaning-task facts, and supplies an immutable weekly paid-staff snapshot to Economy.

This is deliberately a record-based authority. It does not require staff agents, pathfinding, patrols, spawned garbage, world props, animations, or UI to prove the staff/economy contract.

## Authoritative sources

- [Decision 18 — Staff System Architecture](../../decisions/18_staff_system_architecture.md)
- [Staff System design](../../../game_design/elements/15_staff_system.md)
- [Decision 12 — Time System Architecture](../../decisions/12_time_system_architecture.md)
- [Decision 13 — Economy System Architecture](../../decisions/13_economy_system_architecture.md)
- [Economy Handoff 01 — Transaction Authority and Policy Boundary](../economy/01_transaction_authority_and_policy_boundary.md)
- [Decision 15 — Save/Load Architecture](../../decisions/15_save_load_architecture.md)
- [Session Handoff 02 — Atomic Session Restore and MVP Acceptance](../session/02_atomic_session_restore_and_mvp_acceptance.md)

## Scope

- A session-scoped `StaffManager` authority and revisioned, immutable Staff read snapshot.
- Operations Room reference validation as the gate for staffing; Operations Room construction and placement remain external.
- Generic `Cleaner` and `Security` staff records with stable IDs and an employing Operations Room ID.
- Hiring intent validation, per-type room occupancy validation, and firing/unemployment removal.
- The exact source-provided capacity: at most 2 Cleaners and at most 2 Security staff per Operations Room.
- Immutable coverage facts: room floor plus one floor above and one floor below, limited to the same building, subject to the valid existing Operations Room record.
- Cleaner task facts limited to garbage-removal and bathroom-cleaning work on a covered floor; Security supplies passive coverage only.
- Immutable paid-staff snapshot delivery to Economy at each authoritative weekly boundary.
- Detached `authorities.staff` Save V2 snapshot validation, import, and round-trip tests.

## Explicit non-goals

- Operations Room placement, geometry, ownership/emptiness validation, construction catalog, or the design's one-time room cost.
- Bins, garbage-spawn reduction, bin placement, garbage-spawn formulas, bathroom-dirtiness formulas, cleanliness scores, insecurity scores, or any scoring formula.
- Maintenance staff, recurring maintenance/repair work, and maintenance or repair charges.
- Visitor satisfaction, tenant satisfaction, tenant viability, Prestige, comfort, demand, revenue, or rent consequences.
- Staff Nodes, spawning, navigation, nearest-task selection, routes, patrols, worker states, animations, world garbage/grime, or other visuals.
- UI panels, localized copy, notifications, debug controls, staff names, individual attributes, salary variance, hiring cost, firing cost, proration, or payroll arrears policy.
- A global staff cap. Decision 18's approximate Node overhead observation is not a gameplay capacity contract.

## Facts and unresolved policy

| Fact | Approved contract |
| --- | --- |
| Staff types | MVP types are `Cleaner` and `Security`. Staff are generic; no individual attributes or salary differences are authorized. |
| Wage | Every eligible MVP employee costs 500 integer Kreds per authoritative simulation week. |
| Room capacity | Each Operations Room holds at most 2 Cleaners and at most 2 Security staff. Capacity is per type, not a shared total. |
| Coverage | An Operations Room covers its floor, one floor above, and one floor below in the same building. |
| Cleaner work | Garbage removal and bathroom cleaning are the only approved Cleaner task kinds. A task must be on a covered floor. |
| Security work | Security has no active task queue in this MVP; it publishes passive coverage facts only. |
| Calendar | `TimeManager.sim_week_passed(week)` is the sole payroll boundary. Staff does not reconstruct weeks or elapsed time. |

The sources say wage accrual begins on hire and stops on firing, but do not define whether a partial week is charged, credited, or rounded. This handoff therefore authorizes no mid-week payroll calculation: the weekly snapshot contains only staff records that are employed at the authoritative week boundary. A later payroll-policy handoff must decide any proration or other mid-period behavior.

## Ownership and boundaries

| Owner | Owns | Must not own |
| --- | --- | --- |
| `StaffManager` | Staff records, Operations Room staffing occupancy indexes, coverage derivation from validated room facts, committed cleaning-task facts, staff revision, and immutable payroll snapshot production. | Operations Room geometry/construction, balance mutation, calendar progression, tenant/visitor/prestige effects, staff Nodes, or UI. |
| Operations Room / owning construction authority | Stable room ID, building ID, floor identity, and whether the room is committed and valid for staffing. | Staff records, room occupancy counts, payroll, or staff tasks. |
| `TimeManager` | Authoritative week identity and `sim_week_passed`. | Staff hiring, coverage, payroll calculation, or financial mutation. |
| `EconomyManager` | Weekly debit, its idempotence marker, committed balance, and financial result. | Staff employment/lifecycle, capacity, coverage, or task mutation. |
| `SaveManager` | V2 envelope, detached staging, atomic restore, and `authorities.staff` registry coordination. | Fabricating staff, rooms, coverage, tasks, or payroll entries. |
| Presentation / EventBus | Read-only projections of committed Staff and Economy facts. | Authoritative staff, task, room, or balance writes. |

Dependency direction:

```text
committed Operations Room snapshot
  -> StaffManager validates hire/fire and derives coverage
  -> immutable paid-staff weekly snapshot
  -> EconomyManager settles the weekly debit
  -> committed financial result / read-only presentation / SaveManager
```

## Data contracts

### Operations Room staffing reference

Staff consumes one detached Operations Room fact with stable `operations_room_id`, `building_id`, `floor_id`, and a committed-valid-for-staffing flag. Room identity is never a Node path, transform, or traversal position.

A hiring intent must include the requested staff type and room ID. `StaffManager` rejects it when the room fact is missing, stale, invalid for staffing, or when the requested type already occupies 2 slots in that room. It must not create a room, infer room validity from scene content, use a different room, or borrow capacity from the other staff type.

### Staff record and read snapshot

Each committed staff record contains only:

- stable `staff_id`;
- `staff_type` (`Cleaner` or `Security`);
- employing `operations_room_id`;
- captured building and floor identities required to validate the employment reference; and
- staff schema and revision provenance.

The immutable Staff read snapshot is canonically sorted by `staff_id` and includes committed records, room occupancy counts by staff type, derived coverage floor identities, and the staff revision. It excludes Nodes, transforms, paths, animations, UI state, salary ledgers, task assignment, and pending hire/fire intents.

### Cleaning-task facts and coverage

`StaffManager` may commit a cleaning-task fact only for `garbage_removal` or `bathroom_cleaning`. The fact contains a stable task ID, task kind, floor identity, source reference, and its lifecycle state. It must not encode a visual sprite, route, worker Node, timing formula, or a derived cleanliness score.

Only a Cleaner whose employing room's validated coverage includes the task floor may be associated with that task. This handoff does not approve an assignment strategy, nearest-worker rule, task duration, task producer, or automatic completion. A Security record never receives a cleaning task; its only operational publication is its derived passive coverage.

### Weekly paid-staff snapshot

At `TimeManager.sim_week_passed(week)`, Economy requests one detached `PaidStaffWeeklySnapshot` from `StaffManager`. It is immutable, revisioned, canonical by `staff_id`, and contains:

- authoritative simulation-week identity;
- Staff snapshot revision;
- one entry per employee eligible at that week boundary: `staff_id`, staff type, and employing Operations Room ID;
- approved integer wage amount of 500 Kreds for each entry; and
- enough schema/provenance data for Economy to validate the snapshot.

The snapshot excludes balance, debit results, Economy settlement markers, partial-week amounts, total cost caches, Nodes, and any employee not committed as employed at that boundary. Economy validates the week identity and settles each stable staff ID at most once for that week through its own persisted idempotence markers. Staff never writes balance or marks a wage settled.

## Commit flow

### Hire

```text
hire intent(room ID, staff type)
  -> capture detached committed Operations Room and Staff revisions
  -> validate room existence, staffing validity, type, and type-specific occupancy < 2
  -> revalidate captured revisions
  -> commit one new generic Staff record and room occupancy update
  -> increment Staff revision
  -> publish one post-commit staff event
```

No Economy operation is authorized for hiring. A rejected or stale intent commits no staff or occupancy change.

### Fire

Firing identifies one committed `staff_id`. `StaffManager` validates its current employing room reference, removes the record and its occupancy contribution in one Staff commit, increments the revision, and publishes one post-commit event. It does not mutate Economy, calculate a partial-week wage, or destroy a staff Node because Nodes are outside this MVP.

### Weekly settlement

```text
TimeManager.sim_week_passed(week)
  -> Economy requests immutable PaidStaffWeeklySnapshot(week)
  -> Economy validates snapshot and its own settlement markers
  -> Economy debits 500 Kreds once per eligible staff ID
  -> Economy publishes committed financial result(s)
```

Replayed signals, speed changes, pause, multi-boundary frames, and save/load restoration must not double-charge a staff ID for a week. Economy Handoff 01 remains authoritative for financial result shape, debit behavior, and idempotence-marker persistence.

## Persistence and restoration

`authorities.staff` is a detached, exact-key, versioned Save V2 authority snapshot. It persists only committed authoritative Staff state:

- Staff schema and revision;
- canonical active Staff records;
- canonical per-room occupancy facts or data that can be deterministically validated from the records; and
- committed cleaning-task facts only if the implementation exposes them as durable Staff facts.

It excludes payroll snapshots, Economy settlement markers/results, hire/fire intents, task assignment, transient work, Nodes, transforms, routes, animations, UI state, coverage caches, and presentation projections.

During Session Handoff 02 restore, `StaffManager` validates every staff record's stable room, building, and floor reference against the detached committed Operations Room authority, recomputes/validates occupancy and coverage, and rejects the complete candidate on a missing, invalid, stale, cross-building, or over-capacity reference. It never silently drops, relocates, or recreates staff. No staff or payroll event is replayed while staging. `SaveManager` publishes the candidate only through its one atomic session commit.

## Events and diagnostics

`StaffManager` may publish typed, detached, post-commit events:

- `staff_hired`;
- `staff_fired`;
- `staff_cleaning_task_committed` when durable task facts are implemented; and
- `staff_snapshot_changed`.

Each payload contains stable IDs, old/new Staff revision where relevant, room ID, staff type where relevant, and a structured diagnostic code on rejection. It contains no Node references, visual commands, balance delta, tenant/visitor/prestige values, or direct UI instructions.

Minimum diagnostics are `STAFF_TYPE_INVALID`, `OPERATIONS_ROOM_MISSING`, `OPERATIONS_ROOM_INVALID`, `OPERATIONS_ROOM_STALE`, `ROOM_TYPE_CAPACITY_REACHED`, `STAFF_MISSING`, `STAFF_REFERENCE_INVALID`, `TASK_KIND_INVALID`, `TASK_FLOOR_OUT_OF_COVERAGE`, and `PAID_STAFF_SNAPSHOT_INVALID`.

## Acceptance requirements

- A Cleaner or Security record can be committed only from a valid committed Operations Room reference.
- A room never exceeds 2 Cleaners or 2 Security staff; a full Cleaner allocation cannot prevent a valid Security hire, and vice versa.
- Hire/fire failure and stale-revision paths leave committed Staff state and room occupancy unchanged.
- Coverage is exactly the room floor plus adjacent above/below floors in the same building; no unsupported cross-building coverage is inferred.
- Cleaner task facts accept only garbage-removal and bathroom-cleaning work on covered floors. Security has passive coverage only and never receives cleaning work.
- At each authoritative week boundary, Economy receives an immutable canonical paid-staff snapshot with one 500-Kred entry per eligible boundary-employed staff record.
- Economy alone debits wages and cannot charge any staff ID more than once for the same authoritative week, including after save/load or replayed calendar boundaries.
- Save V2 round-trips committed Staff records and valid durable task facts only; it rejects broken room references and over-capacity snapshots without altering the current session.
- No MVP Staff state, event, snapshot, or test asserts bins, maintenance, visual agents, tenant satisfaction, visitor satisfaction, Prestige, revenue, or other deferred consequences.

## Required tests

- Hire validation for missing, invalid, stale, and cross-building Operations Room references; each rejection leaves no record or occupancy mutation.
- Per-type capacity boundaries: two accepted and third rejected for Cleaners, independently repeated for Security.
- Hire/fire snapshot determinism, stable ID ordering, revision changes, and no shared-type capacity leakage.
- Coverage derivation at room, above, and below floors, plus rejection outside coverage and across buildings.
- Cleaning-task kind validation and proof that no Security record can receive a cleaning task.
- Weekly snapshot canonicalization, 500-Kred-per-entry integrity, boundary employment behavior, Economy exactly-once settlement, replayed week boundaries, pause/speed/multi-boundary behavior, and no Staff balance mutation.
- Save V2 detached validation/import round trip, invalid/missing room rejection, over-capacity rejection, no event replay while staging, and full-session preservation on failure.
- Negative tests proving no bin, maintenance, tenant/visitor satisfaction, Prestige, agent, pathfinding, animation, or visual dependency is introduced.

## Risks and follow-up

| Risk | Mitigation |
| --- | --- |
| A room's approximate runtime-node count becomes an accidental gameplay limit. | Enforce only the approved per-room 2 Cleaner and 2 Security capacities; leave a global cap unapproved. |
| Payroll is charged twice after a calendar replay or restore. | Economy owns persistent per-week settlement markers and settles immutable Staff entries exactly once. |
| Mid-week hire/fire behavior is silently invented. | Snapshot only boundary-employed records; defer proration/accrual policy. |
| Cleaning facts become an undeclared simulation or agent system. | Restrict records to two source-backed kinds and coverage validation; defer producers, assignment, movement, and completion policy. |
| Passive security facts are consumed as satisfaction or Prestige policy. | Exclude every cross-system effect until a later approved handoff owns its input and formula. |

Future handoffs must separately approve Operations Room construction/economics, bins and garbage generation, bathroom state and task production, task assignment/completion, staff movement and visuals, global staffing limits, mid-week wage policy, maintenance, and any visitor, tenant, Prestige, or financial consequence beyond the approved weekly wage.
