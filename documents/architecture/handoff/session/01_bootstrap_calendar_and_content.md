# Session Handoff 01 - Bootstrap, Calendar, and Content

**Status:** Approved — 2026-09-05 (delegated architecture authority)

## Purpose

**Revision:** 2026-09-08 delegated consistency pass. [Current MVP](../../../game_design/current_mvp.md), ADR 33 and MVP H3 explicitly amend minimum progression/player intents and coherent transaction/restore boundaries. Content tables are explicit, versioned values from their design element authority, not runtime defaults.

**Follow-on review, 2026-09-08:** [ADR 34](../../decisions/34_product_mvp_runtime_and_cutover.md), [interior H5](../tenant_interiors/05_persistence_presentation_and_cutover.md) and [MVP H4](../mvp/04_product_delivery_and_acceptance.md) now approve the Product runtime/cutover architecture separately from the preceding consistency pass. Preserve foundation -> detached interior H1-H3 -> H4 implementation passes -> H5 candidate cutover passes -> Product acceptance. Bootstrap must not activate interior capability from documentation approval alone. Implementation/cutover remain NOT VERIFIED; Product acceptance and separate external Gate R remain PENDING.

Define the smallest deterministic gameplay-session composition: select validated immutable content, create or restore session authorities, deliver the [Decision 12](../../decisions/12_time_system_architecture.md) calendar, project committed state, then expose presentation only when the session is ready. This handoff coordinates owners; it creates no gameplay values or fallback content.

## Sources and boundaries

- [Decision 12](../../decisions/12_time_system_architecture.md) owns clock rates, calendar constants, speed, and authoritative boundary signals.
- [District H3](../district_layout/03_variable_floor_grid_migration.md) owns session District Runtime; [H4](../district_layout/04_world_projection_and_editor_preview.md) owns generated projection lifecycle; [H9](../district_layout/09_save_load_v2.md) owns V2 staging, atomic commit, and `game_loaded`.
- [District H10](../district_layout/10_legacy_removal_and_acceptance.md) prohibits legacy fallback selection and requires removal of compatibility adapters at cutover.
- [Tenant H3](../tenant/03_candidate_policy_and_catalog.md), Economy H1, and Progression H1 own their respective immutable policy and authority contracts. This handoff does not alter their content, formulas, tiers, prices, or recurrence consumers.

## Minimal composition and ownership

`main_game.tscn` is the gameplay composition root. It creates one session-scoped `TimeManager`, one session bootstrap/load coordinator, domain authorities already approved by their handoffs, and presentation/projection consumers. `GameManager` remains the speed proxy; `TimeManager` is not an autoload and exists only during a gameplay session.

| Owner | Responsibility | Must not own |
| --- | --- | --- |
| Session bootstrap/load coordinator | Explicit selection, dependency ordering, staging orchestration, ready/failure state, disposal. | Domain mutations, content mutation, save schema, projection Nodes. |
| Immutable content registry | Read-only lookup and validation of approved layout definitions and policy/catalog revisions by stable identity. | Session state, fallback selection, mutable candidate state, save writes. |
| `TimeManager` | Simulation/visual elapsed time, speed application, and calendar-boundary signals. | Recurring gameplay outcomes, balance, tenant state, UI state. |
| Domain authorities | Their own committed state, snapshots, transactions, and detached restore validation. | Other authorities' writes or generated presentation. |
| `SaveManager` | V2 parse/validation orchestration, staging, atomic commit, and sole post-commit `game_loaded`. | Recreating missing content or partial-session recovery. |
| Projection Coordinator and UI | Disposable read-only projections of committed snapshots and readiness/failure presentation. | Authoritative state, content, calendar, or save mutation. |

## Immutable content and layout selection

The registry is a typed, read-only catalog of approved static definitions/policies. Each entry is addressed by stable identity and its approved revision/provenance; a district layout also carries its definition version and H2 fingerprint. Shared Resources are definitions only and never hold session lifecycle or random-call-order state, consistent with Tenant H3.

New-session creation requires an explicit layout identity from an approved caller/configuration. The registry validates that identity before any authority or projection is created. Missing, retired, incompatible, or invalid layout/policy content returns a structured startup diagnostic and creates no partial session. There is no inferred default layout and no legacy-fixture fallback. The legacy fixture may be reached only through an explicitly approved fixture identity while its migration evidence permits it; production selection must never reach it by absence, alias, coordinates, Node names, or old save shape.

On V2 restore, `SaveManager` resolves `layout_ref.layout_id`, definition version, and fingerprint through the registry before staging authorities. Tenant policy references and all other approved content references validate during their owner’s detached restore validation. A missing or mismatched reference rejects the entire load before projection or live mutation; it is never silently remapped. Static registry content is excluded from saves.

## Calendar and recurrence contract

Decision 12 as amended by ADR 33 establishes the sole calendar owner; element 01 owns units and numbers. A scaled elapsed second is one real second at 1x. A calendar hour/day/week/month is 1/24/168/720 scaled elapsed seconds respectively; a visitor decision tick is 5 scaled elapsed seconds, not 5 calendar minutes. The visual day is 600 scaled elapsed seconds. Both clocks share pause/speed; `speed == 0` advances neither.

`TimeManager` accumulates `delta * speed` once per process frame. It must enumerate every crossed visitor-tick, hour, day, week, and month boundary, including when a single frame crosses multiple boundaries. Calendar identities are monotonic boundary ordinals derived from accumulated simulation time; consumers receive the boundary identity rather than reconstructing elapsed-time constants.

Emission is chronological. For boundaries sharing the same simulation instant, emit `visitor_tick`, `sim_hour_passed`, `sim_day_passed`, `sim_week_passed`, then `sim_month_passed`; each signal is emitted once for that crossed identity before advancing to the next instant. This only fixes delivery order, not gameplay values. Recurring consumers subscribe to these signals and persist their own consumed-period markers for idempotency across replay/load.

Within a day boundary, complete due Tenant lifecycle transitions before Economy captures Open-tenant rent. At a weekly boundary, capture and retain boundary employment before settlement as MVP H3 specifies. Registration/traversal order cannot choose these outcomes. These are coordinated existing-owner calls, not a second Time scheduler or EventBus query protocol.

Existing approved recurrence policy remains unchanged: Economy consumes daily tenant-rent input, weekly paid-staff input, and monthly loan schedules (Economy H1); Tenant H1 schedules/evolves its lifecycle on day/week identities. No owner may use an independent timer or raw elapsed-time counter for those recurrences.

## Ordered startup, load, and readiness flow

### New session

```text
explicit layout selection
  -> registry validation and immutable definition/policy capture
  -> resolve district snapshot
  -> create domain authorities in dependency order
  -> create TimeManager paused
  -> obtain committed immutable read snapshots
  -> build/validate detached projections
  -> atomically attach projection roots
  -> publish session-ready to UI
  -> accept speed/input and start calendar delivery
```

### Saved session

```text
parse -> require V2 -> validate envelope
  -> resolve/validate layout and content references
  -> detached authority validation and staging in owner dependency order
  -> build/validate staging projections
  -> atomic session commit
  -> SaveManager emits game_loaded once
  -> attach/refresh projections from committed snapshots
  -> publish session-ready to UI
  -> accept speed/input and resume calendar delivery
```

The V2 order preserves H9’s rule that `game_loaded` follows commit only. No staging authority, Node, UI action, calendar signal, player input, or save operation is externally available before the commit/ready gate. Projection failure before readiness destroys staging or retains the prior live projection/session as applicable; it never changes committed authority. UI may show loading or structured failure diagnostics, but must not present an interactive gameplay state until it has received session-ready after committed projections are valid.

## Data and event flow

```text
immutable registry -> validated definitions/policies -> authority snapshots
authority commits -> immutable committed snapshots/envelopes -> Projection Coordinator -> UI
TimeManager boundaries -> approved recurring authority inputs -> committed results -> projections/UI
SaveManager post-commit game_loaded -> projection refresh -> session-ready -> UI
```

Domain commit envelopes remain ordered by their owner contracts. `session-ready` is a presentation/lifecycle event, not a substitute for a domain commit or `game_loaded`, and it carries no mutable Node references.

## Persistence

- Persist only each authority’s approved committed snapshot inside H9’s V2 envelope, including `authorities.time`; exclude registry content, projections, UI state, timers, reservations/tokens, and readiness state.
- Time restore must preserve the simulation and visual elapsed values needed by Decision 12 and the calendar identity used by recurring idempotence; it must not emit retroactive boundaries during staging.
- V1 and every schema-absent payload reject before staging or live mutation, preserve the slot, and return H9’s structured incompatibility result. No converter, compatibility registry, baseline derivation, or legacy selection path is authorized.

## Acceptance criteria

- A new session cannot start without one explicit, registry-validated approved layout; unknown/retired/mismatched content creates no partial authority or projection.
- Each session contains exactly one session-scoped `TimeManager`; menu/no-session speed changes are harmless through the existing `GameManager` proxy contract.
- Pause, speed changes, multi-boundary frames, and simultaneous boundaries deliver every Decision 12 signal exactly once in the defined order.
- Daily, weekly, and monthly consumers use calendar identities and remain idempotent across V2 save/load; no consumer independently counts raw time.
- V2 load validates layout and content references before staging, commits atomically, emits one `game_loaded` only after commit, and never restores transient/presentation state.
- No legacy layout is selected by default, alias, absent configuration, or incompatible save; rejection preserves the previous live session/slot as H9 requires.
- UI accepts no gameplay input before a committed session has valid projections; projection failure cannot mutate authority or expose a half-ready UI.

## Risks

| Risk | Mitigation |
| --- | --- |
| A composition root becomes a hidden service locator or domain writer. | Keep it limited to lifecycle ordering and owner ports; audit writes to authority-owned state. |
| A frame skips or duplicates recurring settlement. | Enumerate all crossed identities in deterministic order; persist consumer-owned idempotence markers. |
| Static content is mutated or serialized as session state. | Use read-only registry entries and validate references on restore. |
| A missing layout falls back to fixed/legacy assumptions. | Require explicit stable identity and reject unresolved selection before creation. |
| UI or projections observe staged/partial state. | Keep staging private; gate input/UI readiness until post-commit projection validation. |

## Required implementation skills

Load `dependency-injection`, `scene-organization`, `resource-pattern`, `save-load`, `godot-testing`, and `godot-ui` before implementation.
