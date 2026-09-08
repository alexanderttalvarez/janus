# Tenant Handoff 01 — Occupancy and Daily Rent

**Status:** Approved — 2026-09-05
**Prepared:** 2026-09-05
**Implementation order:** 1 of 3

**Revision:** 2026-09-08 delegated consistency pass. [Current MVP](../../../game_design/current_mvp.md), elements 01/06/20 and ADR 33 apply. Tenant H2 supersedes automatic commercial acceptance; approved `tenant_interiors/H3` supersedes uniform/area-only selection in its detached stage, without live runtime or save cutover. Retain state-only unpaid fit-out cancellation and explicit coordinated retirement; no financial eviction penalty is introduced.

## Purpose

Create the smallest authoritative tenant loop: a valid vacant parcel waits for its scheduled evaluation, receives a legal seeded-random tenant candidate, becomes locked and constructed, opens, and then supplies immutable daily-rent input to Economy. This handoff deliberately makes no claim that visitors create revenue or that tenant performance affects prestige.

## Authoritative sources

- [Tenant & Shop System design](../../../game_design/elements/06_tenant_shop_system.md)
- [Economy design](../../../game_design/elements/03_economy.md)
- [Economy Handoff 01 — Transaction Authority and Policy Boundary](../economy/01_transaction_authority_and_policy_boundary.md)
- [Zone Handoff 02 — Immediate Debug Business Assignment](../zone_parcels/02_immediate_debug_business_assignment.md)
- [Zone Handoff 06 — Paint-First Zone Mutation and Preservation](../zone_parcels/06_paint_first_zone_mutation.md)
- [District Handoff 09 — Save/Load V2 and District Persistence](../district_layout/09_save_load_v2.md)
- [Decision 12 — Time System Architecture](../../decisions/12_time_system_architecture.md)
- [Decision 17 — Notification System Architecture](../../decisions/17_notification_system_architecture.md)

## Scope

- A `TenantManager` session authority and immutable tenant read snapshot.
- Explicit `DEBUG_IMMEDIATE` versus `TENANT_LIFECYCLE` assignment modes; the approved debug contract remains unchanged.
- Vacant-parcel scheduling, seeded-random legal candidate selection, automatic acceptance, exclusivity lock, construction, opening, and no-cost cancellation.
- Atomic parcel occupancy binding and atomic parcel-retirement handling with `ZoneManager`.
- Immutable active-tenant daily-rent snapshot supplied to Economy on authoritative day boundaries.
- Detached V2 `authorities.tenant` persistence, restore validation, diagnostics, and deterministic tests.

## Explicit non-goals

- Visitor purchases, store targeting, tenant revenue, operating costs, viability, closure, eviction, upgrades, or tenant competition beyond same-subtype edge adjacency.
- Tenant Quality or Tenant Satisfaction contributions to Prestige.
- Rent-setting UI, initial/default rent values, construction cost, deposits, cancellation charge/refund, compensation, notifications, labels, interiors, signage, or construction visuals.
- Recoloring/reassigning existing lifecycle tenants after a later zone edit; only parcel retirement is handled here.
- Altering the approved `DEBUG_IMMEDIATE` assignment behavior, legacy migration cleanup, or the debug catalog's content.

## FACTS

- `ZoneManager` is the sole writer of zone and parcel state. Stable parcel IDs, valid geometry, zone type, area, frontage, and committed revisions originate there.
- `ZoneBusinessAssigner` already defines subtype eligibility and the graph-color rule: edge-adjacent parcels cannot share a subtype; corner contact does not count.
- `DEBUG_IMMEDIATE` is an approved, deterministic, debug-only mode that must remain independently testable.
- `TimeManager` owns simulation calendar boundaries. A vacant parcel is evaluated one simulation day after vacancy; lock duration is one simulation week; construction duration is `0.3` simulation weeks per parcel tile.
- Economy is the only balance writer. Open tenants provide daily rent input; Economy credits it once per authoritative simulation day.
- Approved rent formula: current zone daily rate × parcel tile count, rounded down to integer Kreds; no rent before Open.
- Save/Load V2 owns the outer atomic envelope and reserves `authorities.tenant` for this authority.

## ASSUMPTIONS

- Historical H1-only behavior accepted legal candidates automatically. Tenant H2 and Spatial H1 now approve score inputs/evaluation and supersede that behavior; Selectivity participates in H2's threshold.
- A valid daily zone rate can be read from the committed zone configuration when settlement occurs. A missing/invalid rate is a diagnostic and creates no fallback rate.
- A single persisted session seed plus a stable per-parcel evaluation ordinal is sufficient randomness for H1. This is deterministic randomness, not a mutable call-order-dependent RNG stream.

## Resolved Inputs and Deferred Work

- Tenant H2/Spatial H1 define Zone-owned rates, recommendations and commercial evaluation; H3 defines foundation candidates. Element 20 and staged interior H3 amend size/weights/provenance.
- Presentation H1/MVP H3 expose rent and state-only fit-out cancellation; element 01 fixes deadlines. Existing cancellation/retirement below is the complete current consequence, not permission to invent eviction costs or new locks on ordinary edits.
- Revenue/viability/financial closure, upgrades, tenant-derived Prestige and richer construction visuals remain future scope. Interior default visuals/capacity/cutover follow their explicitly gated program.

## System boundaries and ownership

| Owner | Owns | Must not own |
|---|---|---|
| `TenantManager` | Tenant records, lifecycle deadlines, tenant session seed, per-parcel evaluation ordinal, candidate selection, active-rent snapshot, tenant revision. | Zone/parcel geometry or direct parcel writes, balances, Time progression, UI, outer save envelope. |
| `ZoneManager` | Parcel/zone geometry, committed revision, lifecycle occupancy binding (`occupying_tenant_id`), and `assigned_subtype_id` once a lifecycle candidate is bound. | Tenant timers/state, candidate RNG, balances, rent credits. |
| `ZoneBusinessAssigner` / subtype catalog | Pure eligibility and adjacency-color selection from immutable parcel/catalog snapshots. | Tenant records, mutable zone state, random seed ownership. |
| `TimeManager` | Day/week/calendar boundary signals and calendar identity. | Tenant timers, selection, construction state, financial writes. |
| `EconomyManager` | Balance mutation and idempotent daily settlement markers. | Tenant lifecycle, rate calculation inputs, parcel reads. |
| `SaveManager` | Whole-session atomic staging/restoration. | Reconstructing tenant candidates, lifecycle inference, outer authority semantics. |
| UI / notification / debug projections | Read-only presentation and diagnostics. | Any tenant, parcel, or financial mutation. |

Dependency direction:

```text
Zone committed snapshot + immutable subtype catalog + Tenant seed
  -> TenantManager candidate/lifecycle candidate
  -> ZoneManager occupancy-bind commit
  -> Tenant committed snapshot
  -> Economy daily-rent settlement / SaveManager / UI
```

No consumer may inspect mutable tenant Nodes to settle money, and no tenant flow may write Economy balance directly.

## Assignment modes and subtype selection

### `DEBUG_IMMEDIATE`

This is exactly the Handoff 02 contract: `ZoneManager` invokes the deterministic complete-parcel-set assignment, commits only parcel metadata, and does not notify `TenantManager`. Existing debug saves/fixtures remain governed by that handoff.

### `TENANT_LIFECYCLE`

This new runtime mode leaves newly valid parcels vacant and schedules their first evaluation for the next authoritative simulation day. It must never invoke the debug all-parcel assignment. A parcel can have at most one lifecycle binding.

At a scheduled evaluation, `TenantManager` obtains a detached committed parcel neighborhood snapshot and immutable subtype catalog. It builds the same eligibility domain and edge-adjacency constraints defined by Handoff 02. It then selects from **only legal colors** using a deterministic random value derived from:

```text
persisted tenant session seed + stable parcel ID + persisted evaluation ordinal
```

The random choice is made after type/size filtering and neighbor-color exclusion. If no legal subtype remains, no candidate is created; the parcel stays vacant with a structured diagnostic and a newly scheduled later evaluation. It must never assign a conflicting subtype, force a wrong-size subtype, mutate neighbor tenants, or use random call order as state.

H1 does not run the debug mode's global recoloring/repair pass against live lifecycle tenants. A later content/lifecycle handoff may define a broader reassignment policy. The prospective candidate must simply be legal against committed bound neighbors at its own commit point.

## Lifecycle and atomicity

### State model

```text
Vacant
  -- first/scheduled sim-day evaluation --> ExclusivityLocked
  -- one sim week --> Constructing
  -- 0.3 sim weeks × tile count --> Open

ExclusivityLocked or Constructing
  -- player cancellation --> Vacant (re-evaluation delayed one sim week)

any lifecycle-bound state
  -- committed parcel retirement --> Retired
```

`Retired` is terminal historical state retained only as necessary for current-session diagnostics; it is not an active tenant, does not receive rent, and must not preserve a binding to a non-existent parcel after the commit. Persisted H1 state contains only live tenant records; retired records are excluded.

Element 01 fixes daily deadline rounding and first-rent order: the exact construction delay is `21 * tile_count / 10` days, completed on the first day boundary at or after its deadline. Apply all due lifecycle transitions before Economy captures that boundary's Open tenants. An opening at that boundary is rent-eligible then; missed boundaries process chronologically, not by subscriber order.

A candidate is automatically accepted on successful scheduled evaluation. There is no H1 player accept/reject UI, score threshold, or applicant queue.

### Parcel binding protocol

`ZoneManager` remains the only parcel writer. Before a tenant becomes `ExclusivityLocked`, `TenantManager` prepares a detached tenant record and requests a zone-side bind candidate containing parcel ID, zone ID, subtype ID, expected parcel/zone revision, and new stable tenant ID. `ZoneManager` validates that the parcel still exists, is valid and vacant, matches the candidate's type/size snapshot, and has no conflicting committed neighbor subtype.

The coordinator atomically swaps both candidates:

```text
capture Zone/Tenant revisions
  -> prepare tenant candidate + zone occupancy-bind candidate
  -> revalidate both revisions and legal subtype neighborhood
  -> commit Zone parcel binding and Tenant record together
  -> increment both revisions
  -> publish one post-commit lifecycle envelope
```

Failure or staleness commits neither candidate. `occupying_tenant_id` and `assigned_subtype_id` are cleared by `ZoneManager` only when the corresponding tenant transition/cancellation/retirement candidate commits. A tenant reference alone is not proof of occupancy; the committed two-authority binding is.

### Cancellation and parcel retirement

Cancellation during `ExclusivityLocked` or `Constructing` is a state-only atomic unbind: no Economy transaction, charge, refund, compensation, or notification. The parcel returns to vacant and cannot be evaluated again for one simulation week.

A zone mutation that would retire a lifecycle-bound parcel must include its tenant ID in the mutation's prospective-retirement set. `TenantManager` validates the set and prepares tenant retirements before Zone's final commit. The same shared transaction gate commits parcel retirement/unbinding and tenant retirement together. H1 produces no eviction consequence, financial result, or replacement assignment.

## Economy contract

On each `TimeManager.sim_day_passed`, Economy requests one immutable `ActiveTenantRentSnapshot` from `TenantManager`. The snapshot is revisioned, detached, sorted canonically by tenant ID, and includes only tenants whose committed state is `Open` at that boundary:

- tenant ID, parcel ID, zone ID, subtype ID;
- parcel tile count captured from committed parcel state;
- current validated zone daily rate and calculated integer rent amount;
- tenant and zone/parcel revisions; and
- authoritative simulation-day identity.

Economy validates the snapshot's day identity and settles each tenant once using its own persisted idempotence markers. TenantManager never marks money settled or mutates balance. Rent changes affect the next day boundary only; no retroactive adjustment occurs. Empty zones and non-Open tenants contribute no entry.

## Persistence and restoration

`authorities.tenant` is a detached, exact-key, versioned authority snapshot. H1 persistable live records include:

- tenant schema/revision and persisted session seed;
- canonical stable tenant ID, parcel ID, zone ID, subtype ID, and candidate profile reference;
- lifecycle state; source evaluation ordinal; and calendar deadline/next-evaluation identities;
- construction tile-count basis captured at construction start; and
- any required diagnostic/retry scheduling state.

It excludes Node references, UI state, pending transactions, transient candidate objects, financial results, debug mode UI, retired records, notifications, and recomputable presentation state.

Restore order is: zone/parcel authority first; Tenant validates every tenant's zone/parcel reference, matching `occupying_tenant_id`, matching `assigned_subtype_id`, legal zone type/area, and legal committed adjacency; then Tenant stages its snapshot; Economy restores before future day settlement; SaveManager atomically exposes the restored session only after all authorities accept. A mismatch rejects the complete load—no tenant is silently dropped, recreated, or rebound.

## Events and diagnostics

Tenant emits typed, post-commit envelopes for: scheduled evaluation failure, bound/locked, construction begun, opened, cancelled, and retired-by-parcel-mutation. The envelope carries stable tenant/parcel IDs, old/new lifecycle states, source revisions, calendar identity, and structured diagnostic code. It carries no mutable Node references or direct UI instructions.

Minimum diagnostics: `PARCEL_MISSING_OR_RETIRED`, `PARCEL_STALE`, `PARCEL_ALREADY_BOUND`, `NO_ELIGIBLE_SUBTYPE`, `NO_LEGAL_SUBTYPE`, `ZONE_RATE_INVALID`, `TENANT_SNAPSHOT_INVALID`, and `TENANT_BIND_CONFLICT`. Notifications remain a later consumer decision.

## Acceptance requirements

- Debug mode continues to match Handoff 02 and never creates a tenant record.
- Lifecycle mode evaluates each valid vacant parcel no earlier than one authoritative day after vacancy.
- Candidate randomness is stable across save/load and independent of event/input ordering for a given seed, parcel ID, and evaluation ordinal.
- Every bound subtype is eligible and never duplicates an edge-adjacent committed subtype; corner-only contact is permitted.
- Stale/invalid bind, cancellation, or parcel-retirement attempts expose no partial parcel/tenant state.
- Lock, construction, opening, cancellation cooldown, and rent eligibility occur on the specified authoritative calendar boundaries.
- Economy receives only immutable Open-tenant entries and cannot credit one tenant twice for one simulation day, including across save/load.
- V2 rejects every broken tenant-to-zone/parcel binding and leaves the prior live session intact.
- No H1 event, state, or snapshot asserts visitor revenue, tenant viability, Prestige, notifications, construction pricing, or refunds.

## Required implementation skills

Before implementation, load `resource-pattern`, `state-machine`, `event-bus`, `save-load`, `godot-testing`, and `dependency-injection`. Use the approved Zone/District transaction and revision patterns rather than independently inventing a second atomicity mechanism.
