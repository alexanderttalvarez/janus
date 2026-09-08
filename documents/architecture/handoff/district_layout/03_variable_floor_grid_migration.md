# Handoff 03: Variable Floor Grid Migration

## Status

**Approved — 2026-09-03.** The H1 KEEP decision, frozen H1/H2 goldens, and Economy/Progression architecture dependencies are satisfied.

## Purpose

**Revision:** 2026-09-08 delegated consistency pass. ADR 33 supplies the one non-reentrant session gate, proof-only Fixture C ownership exception and superseding camera/traffic semantics. Element 08 and Progression H2/H3 replace all old U1-U3/higher-unavailable acceptance wording with exact current gates. Progression alone writes selected Plot IDs; District only consumes them. Read [Current MVP](../../../game_design/current_mvp.md) before implementing future expansion UI.

Own the session District Runtime lifecycle and migrate the fixed grid to sparse, explicit-address, transactional district state.

## Dependencies

- Frozen [H1](01_definition_schema_and_validation.md) and [H2](02_resolved_district_model.md) after KEEP.
- Existing zone/parcel rules; `ZoneManager` remains their sole writer.
- [Economy Handoff 01](../economy/01_transaction_authority_and_policy_boundary.md) and [Economy Handoff 02](../economy/02_expansion_pricing_and_refund_policy.md).
- [Progression Handoff 01](../progression/01_eligibility_policy_and_snapshot_boundary.md).

## Source-of-truth documents

- [Handoff index](./_index.md)
- [Decision 27](../../decisions/27_district_layout_templates.md)
- [Existing parcel/zone handoffs](../_index.md)

## Current-state findings

The current 25x25 `plot_0` grid conflates ownership and construction, preallocates full floors, defaults floor/plot scope, mutates tiles directly, and globally rebuilds consumers.

## Target state

One session-scoped, non-autoload District Runtime holds one immutable snapshot and sparse `DistrictState`, is the sole district writer, publishes one committed delta per atomic transaction, and never mutates definitions. Camera viewing never creates `FloorState`.

## Scope

- Session create/replace/dispose lifecycle; sparse state; explicit address migration; revisioned immutable reads.
- Plot Section acquisition and orthogonally adjacent Plot activation through designated entry-eligible sections.
- Sequential tile-by-tile vertical-space acquisition, construction and demolition transactions.
- Physical/progression cap checks, selected-Plot eligibility, elevation-adjacent 2-tile footprint limits only within acquired vertical rights, revision guards, detached candidates, Economy quote/reserve/guaranteed-capture/cancel, Progression policy snapshots, ZoneManager coordination, atomic commit, and one committed delta.

## Explicit non-goals

Prices/formulas, public-realm conversion (H5), generated Nodes (H4), or zone writes.

## System ownership

| Owner | Responsibility |
| --- | --- |
| District Runtime | Sole district writer, state lifecycle, district transactions/revisions/deltas. |
| `ZoneManager` | Sole zone/parcel writer; validates or rejects coordinated candidate changes. |
| Economy | H1 quote/reserve/guaranteed-capture/cancel, H2 immutable price-policy snapshots, and balances. |
| Progression | H1 immutable eligibility/cap snapshots, Plot Access selection state, and revisions. |
| H4 | Generated projection lifecycle. |
| H5 | Street conversion and public realm only. |

## Data contracts

### Explicit addresses and sparse state

`FloorAddress=(runtime_plot_id,elevation)`; cell/edge addresses add plot-local coordinates. Bare `Vector2i`, floor labels, default plot, Node paths, and world coordinates are invalid authority boundaries. `DistrictState` stores sparse section, floor, segment, and source records. `FloorState` exists only after an authoritative mutation needs it.

### Acquisition rules

- A Plot becomes Active only when any section is owned. A Progression-selected/unlocked Plot is camera-accessible but is not Active and is not stored as mutable District state.
- The first acquired section of an inactive Plot requires a committed Progression Plot Access selection for that stable Plot ID. The selected Plot must already have passed Progression's orthogonal adjacency rule; District Runtime still validates resolved topology and the designated entry-eligible section. Diagonal/corner contact is insufficient.
- The production initial Plot is the sole initially owned Plot. Proof Fixture C's explicit entry-section set is the ADR-33 test-only exception. Production Progression permits at most eight additional selected Plots, for a maximum of nine total Plots.
- Later section acquisition follows resolved section adjacency and captured Economy/Progression policy results.
- Vertical space is acquired one tile at a time in sequential elevation order. No full-volume allocation is permitted. Normal Progression uses element 08/H2: Multi-Floor F1/F2, Underground U1/U2, explicit extension nodes for F3-F9/U3-U5; missing unlocks reject. Non-release god mode may make the full physical range eligible, but cannot bypass rights/caps. This does not expand current playable scope.
- Construction requires ownership/right, availability, buildability, acquired vertical space, no incompatible fixed occupancy, and current caps.
- Each constructed upper or underground floor footprint may extend by at most two orthogonal tile steps beyond the constructed footprint at the adjacent comparison elevation, and every cell of the extended footprint must remain inside owned/acquired vertical rights. For an upper elevation `n`, the immediately lower supporting elevation is `n-1`. Underground acquisition is sequential from `0` to `-1` to `-2` and onward; for elevation `-n`, the adjacent geometric comparison elevation is one step toward ground. This comparison defines only the two-tile geometric rule and does not invent underground structural-engineering semantics. Overhang grants no new rights.

### Transaction protocol

Preview and commit evaluate the same intent against the district snapshot/revision, zone revision, economy quote/reservation contract, and immutable progression/economy policy snapshots. District Runtime hosts the transaction coordinator but never writes `ZoneManager` or Economy authority directly. A cross-authority commit uses this externally atomic sequence:

1. Prepare immutable detached district and zone candidates and capture all required immutable policy snapshots and authority revisions.
2. Acquire the single cross-authority transaction gate and its notification/save/input barrier. No observer, player input handler, save operation, or authority publication may pass the barrier.
3. Ask Economy to reserve the required value and return a reservation token; rejection releases the gate with no state change.
4. Ask `ZoneManager` to validate and prepare its detached candidate and return a prepare token; rejection cancels the economy reservation and releases the gate with no state change.
5. Revalidate every captured district, zone, economy, and progression revision while the gate is held. Any mismatch cancels prepared tokens and releases the gate with no state change.
6. Ask Economy to convert the reservation token into a guaranteed-capture token. Final capture is contractually non-failing while the transaction gate and token remain valid. If the Economy port cannot provide that guarantee, reject and cancel before any authority state reference is swapped.
7. The coordinator constructs one complete ordered commit envelope and verifies before any swap that the in-memory commit journal/dispatcher can accept it. The append operation is contractually non-throwing and non-failing.
8. Under the transaction gate and notification/save/input barrier, `ZoneManager` and District Runtime swap their immutable state references, Economy completes its guaranteed capture, and each authority retains its prior-state undo reference. No authority publishes during these operations.
9. Any fault before append restores all prior authority references, cancels outstanding tokens where applicable, and publishes nothing. Otherwise append the complete envelope once. This append is the commit point; after append, no rollback or compensating authority mutation is permitted.
10. Release the barrier while the transaction gate remains held; release synchronously flushes that envelope through the dispatcher. Subscriber faults are isolated as diagnostics and cannot alter committed authority, suppress or reorder the remaining fan-out, or fail the flush.
11. Release the transaction gate only after the envelope flush completes. No intervening transaction, save, or input may observe between swaps, append, and flush.

Every rejection may publish diagnostics but publishes no gameplay signal, state delta, save-visible change, or observer-visible candidate. The only externally observable outcomes are unchanged pre-commit authority or one complete committed envelope. This protocol is closed: append is the commit point and there is no post-append compensating rollback path.

Demolition never clears zone state directly. Occupied zone/tenant dependencies reject until a post-MVP tenant policy exists. An otherwise eligible whole fixed-occupant demolition uses Economy H2's flat 20-Kred fee and creates no refund; partial demolition remains unsupported. District Runtime owns non-economic demolition eligibility and Economy owns the capture.

## Communication and event flow

`intent -> immutable candidates/policy snapshots -> transaction gate + barrier -> economy reservation -> ZoneManager prepare -> all-revision revalidation -> guaranteed-capture token -> append-capability preflight -> authority swaps -> guaranteed economy capture -> non-failing envelope append/commit point -> synchronous barrier-release flush -> gate release -> projections`.

## Persistence impact

Persist sparse District authority only. Explicit migration maps `G->0`, `F<n>->+n`, `B<n>->-n`; malformed values reject. Progression persists selected/unlocked Plot IDs and grant state under its own authority; District reads those committed values but does not duplicate them. Full arrays, indexes, transforms, graphs, reservations, and Nodes are excluded.

## Editor/runtime behavior

Runtime and editor inspect the same immutable values. Active plot/elevation selection is presentation context and never an authority default.

## Migration and compatibility requirements

Exactly five H3 adapters: `LegacyLayoutBootstrapAdapter`, `LegacyFloorIdAdapter`, `LegacyGridProjectionAdapter`, `LegacyDefaultPlotSelectionAdapter`, and `LegacyExteriorAccessAdapter`. The exterior adapter continues through H5 until the approved zero-corner-frontage and topology-backed public-band access rules are implemented and migrated. All are removed by H10. Reuse `LegacyFloorIdAdapter` for old listeners; no unnamed floor adapter is allowed.

## Expected affected files/systems

District Runtime/state/transactions, legacy grid/floor boundaries, zone coordination, economy/progression ports, and save snapshots.

## Acceptance criteria

- Sole-writer and sparse-state invariants hold across all fixtures.
- Selected-Plot-gated section activation, sequential vertical acquisition, direction-correct upper/underground cap and adjacent-footprint rules, construction/demolition, revision rejection, Economy guaranteed-capture protocol, Progression snapshot revalidation, and zone coordination are externally atomic.
- An unlocked Plot becomes camera-accessible without becoming Active; only a successful first-section purchase changes District Active state.
- Camera viewing allocates no state; every success emits one delta and every rejection emits none.

## Required tests

Lifecycle/isolation; explicit addresses; Progression-only selected Plot IDs, cap, adjacency and unlocked-versus-Active separation; section adjacency; exact element-08/Progression H2 elevation gates including rejection without the required extension; physical caps and two-step footprint/rights limits; detached candidates; stale revisions; Economy quote/reserve/capture/cancel; Zone prepare/swap/undo; ADR-33 shared-gate exclusion; append preflight and non-failing commit point; protected ordered fan-out with isolated subscriber faults. Inject every pre-append fault and attempted callback reentrancy; prove unchanged authority with no envelope or one complete envelope with no rollback/reordering. Temporary-adapter checks are historical H10 evidence, not new production dependencies.

## Performance/scalability checks

Mutable memory follows changed state, and affected-scope invalidation replaces global rebuilds.

## Failure and rollback behavior

Any policy, revision, economy, zone, candidate, append-preflight, swap, or other pre-append failure restores all prior immutable references, cancels outstanding tokens, releases barrier/gate safely, and emits no gameplay delta. Economy capture and journal append cannot fail under their valid contracts; an implementation unable to guarantee either is rejected before state swap. Append commits authority permanently; later subscriber faults are isolated diagnostics and never trigger rollback.

## Technical risks

Mutable legacy tile references, partial cross-authority commits, dense caches, and implicit scope leaking through old APIs.

## FACTS

- District Runtime is the sole district writer; `ZoneManager` is the sole zone writer.
- H5 owns only street conversion/public realm, not plot/floor transactions.

## ASSUMPTIONS

- Economy can expose reservation-to-guaranteed-capture tokens without moving balance authority; otherwise coordinated commits reject before state swap.

## OPEN QUESTIONS

- Demolition/tenant consequence policy, owned by later gameplay design; rejection is the safe current contract.
- Derived index representation after profiling.

## GodotPrompter skills required by implementation agents

- `resource-pattern`, `gdscript-advanced`, `dependency-injection`, `save-load`, `godot-testing`.
