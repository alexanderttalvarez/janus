# Construction Handoff 01 — MVP Circulation, Vertical Links, and Operations Rooms

**Status:** Approved — 2026-09-05 (delegated architecture authority)

**Prepared:** 2026-09-05

**Implementation order:** 1 of 1

## Purpose

**Revision:** 2026-09-08 delegated consistency pass. [Current MVP](../../../game_design/current_mvp.md), element 03 and ADR 33/MVP H3 govern scope, prices, paid-action cancellation and the common gate. Required geometry is approved below; absence of an authored record is a content error, not an unresolved design choice. No mechanical elevator trip/capacity system is included.

Define the smallest authoritative construction program for player-built circulation and Operations Rooms. It accepts typed player intents, provides non-mutating previews, and commits legal placements atomically on acquired, buildable District cells.

The MVP construction catalog is limited to corridors, adjacent-floor stairs, elevator shafts with per-floor lobbies, and Operations Rooms. A successful committed placement updates the owning District state, coordinates with Zone where required, captures an approved Economy charge where applicable, and publishes committed topology/vertical-link facts for Spatial H1. Presentation renders previews and results but never places elements itself.

## Authoritative sources

- [District Handoff 03 — Variable Floor Grid Migration](../district_layout/03_variable_floor_grid_migration.md)
- [Economy Handoff 01 — Transaction Authority and Policy Boundary](../economy/01_transaction_authority_and_policy_boundary.md)
- [Economy Handoff 02 — Expansion Pricing and Refund Policy](../economy/02_expansion_pricing_and_refund_policy.md)
- [Progression Handoff 02 — Vertical Expansion](../progression/02_vertical_expansion.md)
- [Spatial Evaluation Inputs Handoff 01 — Spatial Context and Rent Recommendation](../spatial_evaluation/01_spatial_context_and_rent_recommendation.md)
- [Staff Handoff 01 — Cleaning, Security, and Wages](../staff/01_cleaning_security_and_wages.md)
- [Presentation Handoff 01 — MVP Read Models, Intent Gateway, and Notifications](../presentation/01_mvp_read_models_intent_gateway_and_notifications.md)
- [Transit & Circulation design](../../../game_design/elements/11_transit_circulation.md)
- [Staff System design](../../../game_design/elements/15_staff_system.md)

## Scope

- Typed construction intents, shared preview/confirm resolution, structured diagnostics, and post-commit publication.
- Authoritative placement on explicit acquired/buildable `FloorAddress` cell identities.
- One element per tile, ownership, construction-state, and Zone coordination rules.
- Immutable, source-backed construction policy for the approved catalog costs.
- Corridors, stairs, elevators, and Operations Rooms only.
- Revisioned committed pedestrian topology and valid vertical-link publication required by Spatial H1.
- Detached construction facts needed by Staff H1 to validate Operations Room staffing references.
- Save V2 persistence and deterministic tests for committed construction facts.

## Explicit non-goals

- Escalators, plazas, terraces, skybridges, underground passages, amenities, bins, bathrooms, maintenance, decoration, or any other facility.
- New progression nodes, floors, elevation limits, capacity, speed, queueing, congestion, Prestige, satisfaction, rent, visitor behavior, navigation-agent behavior, or staffing consequences.
- Construction removal, demolition, post-commit cancellation, reversal, salvage, or refund policy.
- Player-facing UI layout, localized copy, world projection details, visual previews, or Node ownership.
- Mutable runtime price overrides, cost formulas, discounts, or fallback prices.

## Facts and immutable policy

`ConstructionPolicy` is versioned, immutable authored content. The transaction captures its identity/revision with the Economy and Progression snapshots. Missing, malformed, or unapproved policy rejects the intent; no caller may supply a substitute price or derive a price from the footprint.

| Construction kind | Approved cost | Source rule |
| --- | ---: | --- |
| Corridor | 0 Kreds | Free on purchased/acquired tiles. |
| Stairs | 500 Kreds per stair placement | One adjacent-floor stair placement. |
| Elevator shaft | 2,000 Kreds per shaft | One shaft identity, spanning its selected connected floors. |
| Elevator lobby | 500 Kreds per lobby tile | One lobby on each selected elevator stop floor. |
| Operations Room | 2,000 Kreds per room placement | One-time placement cost. |

The policy records only these approved integer values, stable charge categories, and policy revision. It does not authorize any unsupported construction type or infer a price for one.

MVP geometry policy is explicit: stairs occupy one contiguous 2×2 footprint and connect exactly two adjacent acquired floors; an elevator shaft occupies one fixed 1×1 local cell across a contiguous selected run of acquired floors that includes G, with one 1×1 lobby tile on each selected stop floor; an Operations Room occupies one contiguous 2×2 footprint on a single acquired buildable floor. All cells must be otherwise empty and preserve the one-element-per-tile rule. Wider stairs, non-contiguous elevator stops, alternate room footprints, and other geometry remain unsupported and reject rather than infer a layout.

## Ownership and dependency direction

| Owner | Owns | Must not own |
| --- | --- | --- |
| District Runtime / construction authority | Construction intent resolution, detached candidates, sole District writes, construction identities, committed construction revision/delta, and coordinated transaction gate. | Zone writes, balance writes, mutable price/progression policy, UI state, or live navigation. |
| `ZoneManager` | Sole zone/parcel writes and validation/preparation of prospective element changes affecting zone facts. | District construction state, Economy capture, or topology policy. |
| `EconomyManager` | Quotes, reservations, guaranteed capture, committed balance/result, and debug-free-cost behavior. | Construction validity, geometry, or policy mutation. |
| Progression authority | Immutable eligibility snapshot/revision, including required tech eligibility. | Prices, placement state, reservations, or balance. |
| Construction policy content | Approved catalog costs and only approved geometry metadata. | Session state, reservations, player selections, or policy mutation. |
| Circulation/topology projection | Detached pedestrian topology and valid vertical-link facts derived only from committed construction/District state. | Construction commits, zone writes, or tenant evaluation. |
| Staff authority | Staffing records and validation against committed Operations Room facts. | Room placement, geometry, construction pricing, or District writes. |
| Presentation | Preview rendering, typed request routing, and committed-result display. | Authoritative validation, placement, reservations, or local state prediction. |

```text
player construction intent
  -> UIIntentGateway
  -> District construction preview or confirm
  -> immutable District / Zone / Economy / Progression / ConstructionPolicy snapshots
  -> validated detached candidate + Economy reserve/guaranteed capture
  -> atomic District/Zone/Economy commit envelope
  -> committed construction delta
  -> topology/vertical-link projection + Staff room-reference projection + presentation
```

## Player intent, preview, and confirm

Every intent has a stable request ID, construction kind, explicit stable target identities, selected orientation/connection metadata where the catalog supports it, and expected authority/policy revisions. Bare world coordinates, Node paths, default plot/floor selection, or a UI-local element enum are invalid authority inputs.

The construction authority exposes one pure resolution path used by both operations:

1. Capture detached committed District, Zone, Economy, Progression, and ConstructionPolicy snapshots/revisions.
2. Normalize and canonically order the requested cell and link identities.
3. Validate type, policy availability, ownership/acquired-space/buildability, construction state, one-element-per-tile, geometry availability, required progression eligibility, and prospective Zone compatibility.
4. Build a detached candidate, prospective immutable charge lines, affected stable IDs, and prospective topology/link changes.
5. Return preview facts, or execute the District H3 coordinated commit protocol after all required revalidation.

Preview has no committed effect: it creates no persistent identities/counters, Economy reservation, capture token, state delta, event, notification, or save-visible state. Its result contains the normalized targets, captured revisions, policy revision, prospective cost/charge lines, supported prospective topology facts, affected stable IDs, expiry/revalidation requirements, and stable diagnostics. A free corridor still returns a normal zero-cost quote context; callers may not skip the policy/transaction path because its price is zero.

Confirm is a new intent, not conversion of UI-local preview state. It includes expected revisions and the preview/quote reference when required. The authority resolves and validates again, then follows the complete District H3 transaction protocol: reserve, Zone detached-candidate preparation, all-revision revalidation, guaranteed capture, silent authority swaps, one non-failing commit-envelope append, ordered publication, and gate release. A stale or rejected confirm leaves District, Zone, Economy, topology, Staff references, and presentation read models at their committed values.

The Economy reservation may be cancelled before the envelope append when preview/confirm validation fails or the player abandons an in-flight confirmation. This only releases an uncommitted claim. It is not construction cancellation and creates no balance mutation or refund.

## Placement invariants

### Common cell rules

- Every requested cell uses an explicit `FloorAddress` plus plot-local cell identity.
- Each cell must be in an acquired/owned District footprint, have acquired vertical space at its elevation, be currently buildable, and be available for construction under District H3. Owning a plot or selecting a plot/floor does not imply those facts.
- Exactly one committed construction element occupies a tile. A new element cannot overlap a corridor, stair, shaft, lobby, Operations Room, fixed occupant, or any incompatible existing element.
- Construction never silently replaces, clears, moves, or converts a committed element. Unsupported replacement/removal rejects.
- Zone membership and typology remain `ZoneManager` facts. A construction candidate that changes or conflicts with Zone/parcel constraints must be prepared and accepted by `ZoneManager` in the same atomic transaction; District Runtime must not write zone data directly.
- A rejection at any common or type-specific check commits no authority state and publishes no gameplay topology delta.

### Corridors

A corridor is a one-tile construction request on a legal cell. Its price is the immutable zero-Kred corridor charge. The construction authority must not treat a corridor as authorization to paint a zone, fabricate a public route, or bypass Zone's explicit circulation/typology rules. A committed corridor contributes horizontal traversability only through the committed topology projection; it provides no vertical access.

### Stairs

A stair request identifies the complete approved footprint on two adjacent explicit elevations and its connection direction. It requires the approved Stairs progression eligibility and legal cells on both served elevations. The minimum 2×2 footprint must be validated against immutable catalog geometry; wider stairs remain unavailable until geometry policy approves them. A committed stair produces one stable vertical-link identity connecting exactly its adjacent elevations. It must not connect skipped floors or create elevator-style all-floor service.

### Elevators

An elevator request identifies one 1×1 shaft column, its selected connected floors, and one 1×1 lobby tile for every selected stop floor. It requires approved Elevators progression eligibility. The shaft and every lobby must independently satisfy common placement rules; each lobby is charged as its own immutable 500-Kred line, while the shaft is charged once at 2,000 Kreds. The resulting quote is the canonical sum of those approved lines, with no inferred per-floor shaft cost.

The committed elevator has one stable shaft identity and an explicit canonical stop set. Its valid vertical-link publication connects only those committed stops. It may not claim service to an unselected floor, create a lobby implicitly, overlap another element, or infer queue/capacity/travel behavior.

### Operations Rooms

An Operations Room request requires the approved immutable **2x2** catalog geometry record. Missing/malformed content rejects as policy unavailable; the footprint itself is settled. Its legal cells follow the common rules and it costs one immutable 2,000-Kred line per placement.

On commit, the construction authority publishes a detached room fact containing stable `operations_room_id`, stable building ID, canonical floor identity, committed construction revision, and `committed_valid_for_staffing=true`. This is the sole construction input Staff H1 consumes. Staff independently owns staffing capacity, coverage, task, and payroll facts. Removing or invalidating a committed room is not authorized in this MVP; no room-reference mutation path is implied.

## Topology and vertical-link publication

After the commit envelope is appended, the circulation/topology projection rebuilds or incrementally derives detached, revisioned facts from committed District construction state. It does not inspect preview state, generated Nodes, transforms, live visitor positions, NavigationServer probes, or legacy navigation.

The publication must provide the committed vertical-link facts required by Spatial H1 for a target elevation: canonical floor identity, valid public-route result where H5 data exists, presence/count of valid stairs, presence/count of valid elevators, source construction/topology revision, and commit identity. A stair counts only on the two elevations it actually connects. An elevator counts only on its committed stop floors. A rejected/stale/unavailable topology state is unavailable, not a guessed accessibility value.

Topology/projection consumers observe only the complete post-commit envelope. They may invalidate/rebuild derived data after it, but cannot delay, mutate, roll back, or publish a construction commit.

## Diagnostics and publication

The construction authority returns detached structured diagnostics. At minimum it distinguishes `CONSTRUCTION_POLICY_UNAVAILABLE`, `CONSTRUCTION_GEOMETRY_UNAVAILABLE`, `CONSTRUCTION_TYPE_INVALID`, `CELL_NOT_OWNED`, `VERTICAL_SPACE_UNAVAILABLE`, `CELL_NOT_BUILDABLE`, `CELL_ALREADY_OCCUPIED`, `ELEMENT_CONFLICT`, `ZONE_CONSTRUCTION_REJECTED`, `PROGRESSION_ELIGIBILITY_REJECTED`, `STALE_CONSTRUCTION_INTENT`, and the Economy H1 diagnostics.

On success, one post-commit construction result/delta includes stable construction and affected-cell/link/room IDs, prior/new construction revision, captured policy/authority revisions, committed Economy result reference, and topology invalidation scope. It contains no Node references, UI instructions, live path result, staff record, or mutable collection. Preview and rejected diagnostics are immediate presentation feedback only, not durable notification entries unless a separately approved committed condition requests one.

## Persistence and restoration

Committed construction belongs in the District V2 authority snapshot. Persist canonical stable construction IDs, kind, explicit cell/floor identities, link/shaft-stop membership, Operations Room identity/building/floor reference, construction schema, and revisions needed for validation. Persist only committed facts.

Exclude previews, quotes, reservations, capture tokens, transaction gates, temporary detached candidates, topology caches/graphs, generated Nodes/transforms, UI selection, diagnostics, and Staff records. `ConstructionPolicy` is versioned content, not mutable save data.

During atomic V2 staging, validate identity uniqueness, canonical ordering, one-element-per-tile, acquired/buildable ownership dependencies, stair adjacency, elevator shaft/lobby/stop consistency, and Operations Room references. A broken candidate rejects the full staged session; load never drops, relocates, recreates, or partially repairs construction. After successful atomic publication, topology and Staff room-reference projections rebuild from restored committed state without replaying construction or Economy events.

## Acceptance requirements

- Preview and confirm resolve the same canonical intent under the same policy; preview has no committed side effect.
- No construction commits outside explicit acquired, vertically acquired, buildable District cells.
- One committed element occupies each tile; construction never silently replaces an element or a Zone fact.
- Corridors are free only through the immutable policy and normal validation/transaction topology.
- Stairs charge 500 Kreds per placement and connect exactly adjacent floors through approved footprint geometry.
- Elevators charge 2,000 Kreds once per shaft plus 500 Kreds for every committed lobby, and publish only their selected stops.
- Operations Rooms charge 2,000 Kreds and publish only the detached stable room facts Staff H1 requires; staffing remains external.
- Missing geometry or policy rejects rather than using a fallback footprint, price, unlock, or rule.
- Economy, Progression, District, and Zone revisions revalidate before the commit point; every pre-append failure leaves all committed state unchanged.
- Spatial H1 receives revisioned committed link facts only, never previews, Node-derived state, live congestion, or inferred links.
- Save V2 round-trips committed construction only; invalid construction snapshots fail atomically.
- There is no committed construction cancellation, removal, demolition, reversal, or refund path in this MVP.

## Required tests

- Canonical intent ordering, request correlation, preview non-mutation, confirm revalidation, stale-preview rejection, and double-confirm suppression through the presentation gateway.
- Ownership, vertical-space, buildability, fixed-occupancy, one-element-per-tile, and Zone prepare/rejection paths, each proving no partial authority mutation.
- Immutable policy determinism, exact approved cost lines, missing/malformed policy rejection, and debug-free-cost behavior without bypassing non-economic checks.
- Corridor zero-cost placement on a legal cell and rejection on every illegal/conflicting cell state.
- Stair progression, exact 500-Kred charge, two-adjacent-floor identity, minimum approved 2×2 geometry, unresolved wider geometry rejection, and no skipped-floor link.
- Elevator progression, shaft-once/lobby-per-stop pricing, canonical stop ordering, missing lobby rejection, overlap rejection, and topology presence only at committed stops.
- Operations Room exact 2,000-Kred charge, unresolved geometry rejection, detached Staff-compatible room-fact publication, and proof that construction does not create staff/payroll/coverage state.
- Full District H3/Economy H1 transaction fault injection at every pre-append stage, including reservation cancellation and policy/revision staleness; prove either no mutation or one complete ordered envelope.
- Spatial H1 topology contract tests proving stairs/elevators appear only after commit, on the correct elevations, with revisions, and never from preview/live agents/Nodes.
- Save V2 exact round-trip, malformed/duplicate/overlapping construction rejection, invalid ownership/link/room-reference rejection, no transient token persistence, and topology/room-reference rebuild only after atomic restore.

## Risks and follow-up

| Risk | Required mitigation |
| --- | --- |
| A UI preview becomes a shadow construction state. | Preview remains detached and non-mutating; confirm always re-resolves at the authority. |
| Free corridors bypass validation or coordinated commit. | Use the same policy and transaction path with a zero-Kred quote. |
| Construction mutates Zone or Economy directly. | District coordinates detached candidates; Zone and Economy retain their sole-write boundaries. |
| Missing Operations Room footprint causes an arbitrary implementation. | Reject until immutable geometry content is approved. |
| Spatial evaluation consumes visual or live navigation data. | Publish only committed revisioned topology/link facts. |
| Pre-commit reservation cancellation is misread as demolition/refund. | Limit it to uncommitted token release; no post-commit path exists. |

Later handoffs must separately approve escalators, plazas/terraces, amenities, all removal/demolition/cancellation/refund behavior, expanded geometry, elevator operation/queueing, visitor navigation effects, and any Operations Room effects beyond Staff H1's reference contract.
