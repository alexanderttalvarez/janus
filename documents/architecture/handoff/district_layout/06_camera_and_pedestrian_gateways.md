# Handoff 06: Camera Envelope and Pedestrian Gateways

## Status

**Approved — 2026-09-03.** Implementation remains blocked by implemented H3 selected/Active Plot views and [H5](05_street_and_pedestrian_generation.md) public topology/pedestrian graph. The camera-margin and legacy-rule design selections are recorded and architecture-validated.

## Purpose

Consume H2 source attachments/poses and H5's final pedestrian graph to own only camera bounds/viewing and `GatewayEligibilitySnapshot`. H8 owns allocation.

## Dependencies

- H2 exclusively resolved the authored selector to a static topology attachment ID and baseline `DistrictGridPose` from immutable definition/topology.
- [H3](03_variable_floor_grid_migration.md) Active Plots and view capabilities.
- [H5](05_street_and_pedestrian_generation.md) final pedestrian topology/graph.

## Source-of-truth documents

- [Decision 16](../../decisions/16_camera_system_architecture.md)
- [Decision 28](../../decisions/28_visitor_arrival_architecture.md)

## Current-state findings

Camera uses radial origin bounds and floor strings; `PlotData` stores corner spawn geometry; `PedestrianArea` assumes one 25x25 ring.

## Target state

The pan/focus region is the geometric union of each Active Plot rectangle and each Progression-selected/unlocked Plot rectangle, expanded by margin, not an enclosing AABB. Focus outside the union clamps to the nearest point in that union with deterministic tie-breaks. Gateway eligibility is derived only from H2 attachment/pose, H5's final graph, current source state, and matching revisions. Viewing and eligibility never mutate district state or create `FloorState`.

## Scope

Union-region camera clamp, signed-elevation viewing, pass-through H2 attachment/pose values, and structural gateway eligibility against H5's final graph and current source state.

## Explicit non-goals

Demand, source allocation/capacity/weight, visitor realization, road graph, state writes, or persisted identity migration.

## System ownership

| Owner | Responsibility |
| --- | --- |
| H2 | Exclusive selector resolution, static topology attachment ID, and baseline `DistrictGridPose`. |
| Design | Decision owner for camera infrastructure margin and the legacy 20-purchased-tile rule. |
| Architecture | Validates each selected policy against architecture invariants and acceptance evidence. |
| H6 | Camera region/viewing and `GatewayEligibilitySnapshot` only. |
| H8 | Source allocation/orchestration. |
| District Runtime | Source-state writes. |

## Data contracts

`CameraBoundsSnapshot` contains District and Progression revisions, sorted Active Plot IDs, sorted selected/unlocked Plot IDs, expanded rectangle union, margin, and empty status. `GatewayProjection` may package `arrival_source_id`, authored selector, H2 topology attachment ID, and H2 baseline `DistrictGridPose`, but labels attachment and pose owner as H2 and cannot alter or re-resolve either. `GatewayEligibilitySnapshot` reports current source state, structural eligibility, reason codes, and committed district/topology revisions only.

## Communication and event flow

`Active Plot + selected/unlocked Plot rectangles -> expanded union -> CameraManager`;  `H2 attachment/pose + H5 final graph + current source state -> eligibility snapshot -> H8`.

## Persistence impact

Bounds, H2 poses/attachments, eligibility, and camera viewing are unsaved unless a separate presentation setting is approved. Viewing never writes floor state.

## Editor/runtime behavior

Identical projections in editor/runtime. Empty union disables spatial pan/focus safely.

## Migration and compatibility requirements

- `LegacyCameraBoundsAdapter` bridges legacy bootstrap only.
- `LegacyCornerSpawnAdapter` is restricted to legacy gateway/layout compatibility. It never performs persisted corner-ID migration; schema-absent V1 saves are rejected by H9.
- Old floor-label listeners reuse `LegacyFloorIdAdapter`; no unnamed adapter is allowed.
- Historical migration seam only: the accepted decision removes the legacy radial rule. New work must not recreate its adapter or policy branch.

### Historical Camera Alternatives (Resolved)

**Resolved 2026-09-03:** Road-profile-relative B is selected and validated in [H6 Policy Acceptance](h6_policy_acceptance.md). Its exact margin formula is authoritative. The alternatives below are retained decision history, not current blockers.

| Alternative | Contract |
| --- | --- |
| A fixed authored tile margin | One authored tile margin applies according to the approved camera policy. |
| B road-profile-relative margin | The margin derives deterministically from the selected road profile. |
| C per-layout authored margin | Each layout authors its own validated margin. |

A, B, and C are neutral alternatives. Selection must assess design intent for the camera union, player legibility, editor/runtime parity, variable road widths, and migration. The selected contract becomes an input to Projection/Camera policy and must be recorded in acceptance evidence before H6 acceptance.

### Legacy 20-purchased-tile rule

**Resolved 2026-09-03:** Alternative A removes the legacy 20-purchased-tile rule. ADR 33 explicitly amends ADR 16 to match. The following alternatives are historical, not open choices.

| Alternative | Contract |
| --- | --- |
| A remove at district migration | The legacy rule ends as part of the district-layout migration. |
| B explicit target policy | The rule remains as an explicit target camera policy. |

A and B are neutral alternatives. Selection must assess conflict with the Active Plot union fact, state-mutation risk, and player expectation. The selected contract must be recorded in acceptance evidence before `LegacyCameraBoundsAdapter` removal or H10 acceptance. Implementation agents do not choose.

## Expected affected files/systems

Camera manager, composition wiring, gateway projections, old listener boundaries, tests.

## Acceptance criteria

Exact expanded-rectangle union and nearest-point clamp; viewing/activity independence; no FloorState allocation; H2 attachment/pose pass-through without resolution or mutation; revision-matched structural eligibility; H8 exclusively allocates. Acceptance evidence records one camera-margin alternative and one legacy-rule alternative, Design approval, Architecture validation, and evidence against every listed criterion; the margin contract is recorded before H6 acceptance, and the legacy-rule contract is recorded before `LegacyCameraBoundsAdapter` removal or H10.

## Required tests

Empty/overlap/disjoint union, holes and nearest-point ties, pan/focus, signed elevations, H2 pass-through invariance, current-state structural eligibility, stale district/topology revisions, missing static attachment, adapter isolation, and viewing-no-mutation. Test the selected camera-margin contract across variable road widths and editor/runtime contexts and reject the unselected contracts. Test the selected legacy-rule target/removal behavior, including its no-state-mutation invariant, and reject the unselected contract. A missing attachment or attachment absent from the committed graph is ineligible and never falls back to nearest topology.

## Performance/scalability checks

Region updates scale with Active Plots and eligibility uses graph indexes, not world-distance scans.

## Failure and rollback behavior

Invalid revisions retain last valid camera projection; blocked view changes nothing. Stale or missing static attachments are ineligible with reason codes and never trigger selector re-resolution or nearest-topology fallback.

## Technical risks

Accidentally replacing the union with an AABB, H6 re-resolving H2 identity/pose, corner migration leaking into runtime, and observation creating sparse state.

## FACTS

- H2 owns attachment/pose resolution; H6 owns structural eligibility and camera only; H8 owns allocation.

## ASSUMPTIONS

- Plot rectangles are axis-aligned in district space.

## OPEN QUESTIONS

- **Resolved:** Design selected road-profile-relative camera margin (B); Architecture validates it as deterministic, presentation-only, and compatible with variable road widths and editor/runtime parity.
- **Resolved:** Design selected removal of the legacy 20-purchased-tile rule (A); camera uses the expanded Active plus selected/unlocked Plot union without mutating District state.

## GodotPrompter skills required by implementation agents

- `camera-system`, `math-essentials`, `ai-navigation`, `godot-testing`.
