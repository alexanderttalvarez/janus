# Economy Handoff 02 — Expansion Pricing and Refund Policy

**Status:** Draft — ready for architecture approval
**Prepared:** 2026-09-03
**Implementation order:** 2 of 2 — after Economy Handoff 01

## Purpose

Provide the approved, centrally tunable Economy policy values needed to price plot-section acquisition, vertical floor-space acquisition, Street Segment conversion, and eligible demolition. Define the no-refund and no-reversal rules that apply once those transactions commit.

This handoff supplies immutable policy data to Economy H1. It does not change Economy's balance ownership, transaction protocol, District Runtime's sole district-writer role, or the separate future ownership of progression gates and tenant consequences.

## Dependencies

- [Economy Handoff 01 — Transaction Authority and Policy Boundary](01_transaction_authority_and_policy_boundary.md) is approved and remains authoritative for quote/reserve/guaranteed-capture/cancel, debug bypass, persistence, and result publication.
- [District Layout Handoff 03](../district_layout/03_variable_floor_grid_migration.md) remains authoritative for district transaction order, sparse state, and occupied-dependency rejection.
- [District Layout Handoff 05](../district_layout/05_street_and_pedestrian_generation.md) remains authoritative for Street Corridor geometry and conversion projection.

## FACTS

- Currency is integer Kreds; starting balance is 500,000 Kreds.
- Ground land is acquired only as atomic Plot Sections. A purchased section grants vertical rights but does not demolish fixed occupancy.
- Vertical floor-space acquisition is tile-by-tile and sequentially constrained by District policy.
- A Street Segment includes the complete Street Corridor: both Pedestrian Bands and the carriageway.
- A demolition transaction addresses one whole stable fixed-occupant identity across all of its elevations. Partial demolition is unsupported.
- Occupied zone/tenant dependencies reject demolition in MVP; their eviction/consequence policy is deferred until after MVP.
- Debug cost bypass produces a zero-cost Economy quote/capture while preserving all other validity and atomicity checks.

## Scope

- One centralized, tunable economy-policy configuration for approved monetary constants.
- Immutable per-transaction policy snapshots and stable policy revisioning for H1 quote validation.
- Approved price schedules for Plot Sections and vertical floor-space.
- Street Segment conversion pricing.
- Eligible demolition fee and no-refund policy.
- Explicit classification of construction cancellation, progression gates, transport, and maintenance as outside this handoff.
- Deterministic tests for policy lookup, integer arithmetic, transaction snapshot isolation, and no-refund behavior.

## Explicit non-goals

- Progression gates for plots, elevations, street conversion, or transport. A future Progression handoff owns them.
- Tenant eviction, compensation, closure, relocation, or demolition of occupied zone/tenant dependencies.
- Construction price catalogs or construction-cancellation refund policy.
- Transport, maintenance, repair, parking, event-income, or future operating-cost policies.
- Street conversion reversal in MVP.
- A mutable global price variable, UI-side prices, random discounts, sales, or dynamic market pricing.

## Canonical policy ownership

Economy policy content owns tunable approved values. `EconomyManager` receives an immutable snapshot/revision of that content at quote time. The session never reads a mutable global value during reserve, guaranteed capture, or final capture.

```text
Economy policy configuration (authoring/tuning)
  -> immutable EconomyPolicySnapshot + revision
  -> Economy H1 quote/reservation/capture
  -> District/Zone transaction coordinator
```

Tuning a value creates a new policy revision for later transactions. It cannot alter an already quoted/reserved transaction; that transaction rejects as stale if its captured policy revision no longer matches.

## Approved price policy

### Plot Sections

```text
plot_section_cost = section_tile_count × 1,000 Kreds
```

- The tile count is the complete valid section mask from the resolved district definition.
- The price includes ground ownership and the resulting vertical rights only.
- It excludes demolition, construction, fixed-occupant removal, and a separate vertical-rights surcharge.
- The whole section is quoted and captured atomically; partial section purchase is invalid.

### Vertical floor-space tiles

| Elevation | Cost per acquired tile |
|---|---:|
| G | 1,000 Kreds |
| F1 | 1,200 Kreds |
| F2 | 1,400 Kreds |
| F3 | 1,600 Kreds |
| F4 | 1,800 Kreds |
| F5 | 2,000 Kreds |
| F6 | 2,200 Kreds |
| F7 | 2,400 Kreds |
| F8 | 2,600 Kreds |
| F9 | 2,800 Kreds |
| U1 | 1,200 Kreds |
| U2 | 1,400 Kreds |
| U3 | 1,600 Kreds |
| U4 | 1,800 Kreds |
| U5 | 2,000 Kreds |

This table is authoritative. It must not be extrapolated beyond the approved physical elevation range. Economy prices a requested valid tile set from its explicit signed elevation; District Runtime owns whether the tile set is physically/legal/progression eligible.

### Street Segment conversion

```text
street_conversion_cost = complete_street_corridor_tile_count × 3,000 Kreds
```

- Count every tile in the Street Segment's complete Street Corridor, including both Pedestrian Bands and carriageway.
- Economy does not price a partial conversion because District policy permits only whole Street Segment conversion.
- The price is intentionally high because conversion obtains a public street area for player-funded conversion.
- Completed conversion is irreversible in MVP. It creates no refund, reverse transaction, or compensating Economy mutation.

### Demolition

```text
demolition_cost = 20 Kreds per eligible whole fixed structure
```

- One stable fixed-occupant identity is one demolition transaction, regardless of its number of tiles/elevations.
- Demolition is quoted only after District Runtime confirms the target is an eligible whole fixed structure and all non-economic rules pass.
- Demolition with an occupied zone/tenant dependency rejects before Economy capture and therefore costs nothing.
- A completed demolition creates no refund.

## Refund and cancellation policy

| Action state | Policy |
|---|---|
| Quote/reservation cancelled before capture | Free; no committed debit. |
| Failed/stale/rejected transaction | Free; no committed debit. |
| Completed Plot Section or vertical-space purchase | No refund policy; reversal is unsupported until separately approved. |
| Completed Street Segment conversion | Irreversible in MVP; no reversal or refund. |
| Completed eligible fixed-structure demolition | No refund. |
| Construction cancellation | Outside H2; refund/penalty policy remains unapproved. |
| Occupied zone/tenant demolition | Reject in MVP; future tenant lifecycle owns consequences. |

No post-append rollback, compensating refund, or refund-by-direct-balance-write is permitted.

## Progression separation

Price and eligibility are separate inputs:

```text
District intent
  -> District validates geometry / ownership / construction state
  -> Progression snapshot determines eligibility
  -> Economy H2 policy snapshot determines price
  -> Economy H1 determines affordability and transaction safety
  -> coordinator commits or rejects atomically
```

H2 defines price even where a future Progression handoff has not yet approved access gates. A missing or rejecting progression snapshot prevents the transaction before capture; Economy must not infer that a price implies eligibility.

## Event, debug, and save behavior

- H2 adds no new runtime event owner. H1's committed financial result identifies the stable charge category and captured policy revision.
- Debug cost bypass returns a zero-cost quote for every H2 category while still validating section masks, tile/elevation rules, conversion eligibility, demolition eligibility, revisions, and transaction atomicity.
- The centralized policy configuration is authored content, not player save state. Saves persist committed purchases/demolitions through their owning district state and committed Economy balance; they do not persist transient quotes/reservations or mutable policy overrides.

## Acceptance requirements

- The same policy snapshot and valid intent always produce the same integer quote.
- Plot Section price equals exact valid section tile count × 1,000 Kreds.
- Every listed F1–F9 and U1–U5 tile resolves to its explicit table value.
- A Street Segment quote counts its complete Corridor exactly once and uses 3,000 Kreds per counted tile.
- An eligible whole fixed structure costs exactly 20 Kreds once, independent of its tile/elevation count.
- Invalid, occupied, stale, or rejected demolition never captures the 20-Kred fee.
- Completed Street conversion and demolition issue no refund; unsupported reversal requests reject without direct balance mutation.
- Policy revision changes invalidate old quotes/reservations rather than changing their amount in place.
- Debug bypass makes every H2 charge zero without bypassing non-economic validation.
- H2 introduces no progression gate, tenant consequence, construction-cancellation rule, or mutable global runtime price.

## Required tests

- Explicit table coverage for every approved elevation and invalid-elevation rejection.
- Plot Section masks: exact count, irregular masks, whole-section atomicity, and integer overflow/domain rejection.
- Street Corridor count including both Pedestrian Bands and carriageway; no partial Segment price path.
- Whole fixed-occupant demolition across multiple elevations; occupied dependency rejection with no charge.
- Reservation/capture behavior using H2 policy snapshots, policy-revision staleness, and debug zero-cost capture.
- No-refund/no-reversal rejection after committed conversion/demolition and save/load persistence of committed outcomes only.

## Technical risks

| Risk | Mitigation |
|---|---|
| “Global variable” tuning becomes mutable runtime authority. | Centralize values in authored policy content and capture immutable revisions per transaction. |
| Public-band tiles are omitted from Street pricing. | Price from the resolved complete Street Corridor descriptor, not a projection Node or selected sub-area. |
| Fixed-structure demolition is confused with zone/tenant eviction. | Require a stable fixed-occupant target; reject occupied dependencies until post-MVP policy. |
| Price is mistaken for permission. | Progression/District eligibility remains a separate pre-capture validation input. |
| Later refunds undermine atomic commit. | H2 allows no post-commit refund/reversal; future policy requires a new approved transaction type. |

## Follow-up handoffs

- **Progression Handoff:** gates for additional plots, elevations, Street conversion, and transport.
- **Tenant lifecycle:** rent inputs, tenant occupancy, eviction/compensation, and post-MVP demolition consequences.
- **Construction policy:** price catalog and cancellation/refund/penalty decisions.
- **Transport and maintenance:** post-MVP capital and operating costs.
