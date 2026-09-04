# Progression Handoff 01 — Eligibility Policy and Snapshot Boundary

**Status:** Approved — 2026-09-03
**Prepared:** 2026-09-03
**Implementation order:** 1 of 1

## Purpose

Define a single revisioned Progression authority that converts committed prestige tiers and approved Tech Tree state into immutable eligibility snapshots consumed by District Runtime and Economy. This handoff defines what is currently available; it does not price actions, mutate District state, or create new progression content.

## Dependencies

- Economy Handoff 01 supplies the quote/reserve/capture boundary and consumes immutable progression snapshots.
- Economy Handoff 02 supplies prices but never grants eligibility.
- Prestige remains the authoritative tier calculator; TechTreeManager remains the initial owner of unlocked-node and earned-point state.
- District Runtime remains the sole district writer and validates physical/layout rules independently.

## Approved policy

### Elevations

| Capability | Eligibility |
|---|---|
| Ground `G` | Initial Plot only; owned at game start. |
| `F1`, `F2` | Requires existing `Multi-Floor` node. Ground is the first building level, making these the second and third floors. |
| `U1`–`U3` | Requires existing `Underground` node, whose prerequisite remains `Multi-Floor`. |
| `F3`–`F9`, `U4`–`U5` | Explicitly unavailable pending a future progression extension. |

Physical caps/templates and District ownership/buildability remain separate validations.

### Plot Access

The initial Plot is owned at game start. At most eight additional Plots may be selected, for a total cap of nine.

| Mall Level reached | New permanent selections | Total selectable additional Plots |
|---|---:|---:|
| Small Market | 0 | 0 |
| Neighborhood Center | 2 | 2 |
| Regional Mall | 2 | 4 |
| City Destination | 2 | 6 |
| Megacity Mall | 2 | 8 |

A selection:
- chooses one unselected Plot orthogonally adjacent to an Active or already selected/unlocked Plot;
- permanently adds that stable Plot ID to progression state;
- grants camera access and permits later Plot Section purchase attempts;
- grants no ownership, construction, zone, or section state;
- does not make the Plot Active. Active remains derived only after the first section purchase.

A selector may not choose diagonally, a non-adjacent Plot, a non-player-capable slot, a retired/missing Plot, or a Plot after all eight additional selections are consumed.

### Street conversion and transport

- Street Segment conversion is progression-eligible at **Neighborhood Center** and above, subject to all District geometry/frontage/public-realm and Economy affordability checks.
- Non-pedestrian transport facilities are explicitly unavailable until a dedicated transport/progression handoff approves them.

## Boundaries and ownership

| Owner | Responsibility | Must not own |
|---|---|---|
| PrestigeManager | Computes and publishes committed tier changes. | Unlock state, Plot selections, District state. |
| Progression authority (initially TechTreeManager) | Sole writer of unlocked nodes, earned/spent points, Plot Access grants, selected Plot IDs, and progression revision. | Prestige calculation, prices/balance, District mutations. |
| District Runtime | Validates physical eligibility and commits selected Plot/section/floor/street state. | Spending/revoking progression grants or Tech state. |
| Economy | Prices and captures an otherwise eligible action. | Progression eligibility. |
| Camera/projection | Reads selected/unlocked and Active Plot state to build the envelope. | Progression/District writes. |

## Snapshot contract

The Progression authority exposes immutable, revisioned snapshots containing:

- current committed Mall Level/tier reference;
- unlocked Tech node IDs and available/earned point facts;
- Plot Access grants earned, consumed, and remaining;
- selected/unlocked stable Plot IDs in canonical order;
- elevation eligibility and Street-conversion eligibility;
- explicit unavailable capability identifiers;
- progression revision and content-policy revision.

Snapshots exclude Node references, camera bounds, prices, Economy state, District mutable state, previews, and UI state.

District Runtime captures the snapshot/revision while preparing an intent, revalidates it under its transaction gate, and rejects stale or unavailable requests before Economy capture. Economy uses the same snapshot only as an eligibility input to its quoted transaction.

## State and event flow

```text
Prestige committed tier change
  -> Progression authority grants exact Plot Access selections once
  -> progression revision increments; immutable snapshot publishes
  -> player submits a Plot selection against resolved District topology
  -> Progression authority validates and commits the selected stable Plot ID
  -> camera envelope projects Active + selected/unlocked Plot rectangles

District floor/section/street intent
  -> capture Progression snapshot
  -> District physical validation + Progression eligibility
  -> Economy quote/reservation/capture
  -> one coordinated committed envelope
```

The Plot Access grant and player Plot selection are separate transactions. Selecting a Plot never debits Economy and never purchases a section.

## Persistence

Persist only committed progression state: unlocked nodes/points, awarded milestone identities, Plot Access grant counts, selected stable Plot IDs, revisions, and required content/version references. Derive eligibility snapshots and camera bounds after load. Never persist previews, transaction tokens, or camera state as progression authority.

## Debug behavior

When `god_mode` is active in a non-release build, Progression is treated as fully unlocked: all Tech/progression eligibility is satisfied, F1–F9 and U1–U5 are eligible within their normal physical District limits, Street conversion is eligible regardless of Mall Level, and all eight additional Plot Access selections are immediately available without prestige tiers or Tech Points. The normal 9-Plot cap, valid stable IDs, orthogonal-adjacency selection, physical District rules, transaction revision checks, and Economy/District atomicity still apply. The debug snapshot must retain the normal snapshot/result topology.

## Explicit non-goals

- New Tech nodes, Tech Point values, prestige thresholds, or tier names.
- Progression for F3–F9/U4–U5, transport, maintenance, construction cancellation, or tenant eviction.
- Prices, refunds, loans, or balances.
- UI, camera implementation, localization, or selection presentation.

## Acceptance requirements

- Tier changes grant exactly the approved total of eight additional Plot selections across the five non-initial tiers; no duplicate grant occurs after load or recomputation.
- Selection cap is nine total Plots including the initial Plot.
- Selected Plot IDs are stable, unique, canonical, orthogonally reachable, and persist across save/load.
- An unlocked Plot is camera-eligible but is not Active until a first owned section commits.
- `Multi-Floor` enables only F1/F2; `Underground` enables only U1–U3; all higher listed elevations explicitly reject.
- Street conversion rejects below Neighborhood Center and may proceed only at/above it when all non-progression requirements succeed.
- Transport explicitly rejects as unavailable.
- Stale snapshots, invalid selections, or rejected eligibility produce no Economy debit or District mutation.
- God mode yields all progression eligibility and eight Plot Access selections immediately, but does not bypass the 9-Plot cap, adjacency, stable-ID, or physical-validity rules.

## Technical risks

- Confusing selected/unlocked availability with Active/owned state would break camera, ownership, and public-topology rules. Keep them distinct values.
- Awarding Plot Access from recomputed tier state can duplicate grants. Persist milestone-award identity, not only a numeric current tier.
- UI/camera writes must not create selection state; presentation reads committed Progression/District data only.
- Future tier or Tech Tree changes must migrate stable milestone/node IDs, not infer state from display text.

## Follow-ups

- Progression H2: F3–F9/U4–U5 extension and any new Tech nodes.
- Transport/progression handoff: non-pedestrian transport gates and content.
- District H3/H4/H5: consume this policy for transaction, camera, and Street conversion work.
