# Handoff 05: Street and Pedestrian Generation

## Status

**Draft - implementation blocked by predecessors and two design approvals.** Requires H3 transactions and H4 projection lifecycle. Corner-frontage attribution and public-band physical parcel-door access are separate DESIGN BLOCKERS.

## Purpose

Own public-realm descriptors, generated pedestrian/road/intersection geometry, frontage, street conversion/state impacts, and final `PedestrianGraphSnapshot` authority.

## Dependencies

- [H3](03_variable_floor_grid_migration.md) state/transaction coordination.
- [H4](04_world_projection_and_editor_preview.md) generated Node lifecycle.
- H3 floor/circulation/door/vertical-link inputs.

## Source-of-truth documents

- [Decision 27](../../decisions/27_district_layout_templates.md)
- [Existing parcel/door handoffs](../_index.md)

## Current-state findings

Current `pedestrian_boundary`, outside-grid `virtual_exterior`, and authored roads/crosswalks conflate access geometry with public topology. Existing splitter frontage and physical-door rules conflict.

## Target state

Deterministic descriptors and generated geometry represent corridors, two public Pedestrian Bands, carriageways, intersections, outer ring, segment sides, and frontage. H5 combines public bands with H3 committed floor circulation, doors, and vertical links into the final immutable `PedestrianGraphSnapshot`. H7 alone owns `RoadGraphSnapshot`.

## Scope

Public-realm descriptors/geometry; independent-side frontage; street conversion preview/state impacts through H3 commit protocol; derived intersections; final pedestrian graph and deltas; access conflict decision boundary.

## Explicit non-goals

No road graph, traffic reservations, prices/formulas, ownership transfer of public bands, or speculative physical-door rule.

## System ownership

| Owner | Responsibility |
| --- | --- |
| Design | Decision owner for corner-frontage attribution and public-band physical parcel-door access. |
| Architecture | Validates each selected design contract against architecture invariants and acceptance evidence. |
| H5 public-realm projection | Descriptors, geometry, frontage, conversion rules/impacts, pedestrian graph. |
| District Runtime | Sole `StreetSegmentState` writer and atomic commit. |
| H4 | Generated Nodes only. |
| H7 | Exclusive road graph authority. |

## Data contracts

Each corridor has two 5-10-tile public bands and a carriageway of 3-tile lanes. Outer ring is immutable. Internal conversion requires at least 50% owned frontage independently on both sides, includes both bands plus carriageway spatially, discloses connectivity without veto, and derives intersection transfer from all incident internal segments.

Positive-length collinear frontage is measured deterministically and remains decided. Corner-only frontage is unresolved and cannot contribute to conversion eligibility until the blocker below is approved.

`PedestrianGraphSnapshot` combines public-band edges with H3 floor/circulation/door/vertical-link values at explicit revisions. It is immutable, derived, unsaved, and rebuilt/delta-published after commit.

## Communication and event flow

`resolved public realm + H3 circulation/doors/vertical links -> pedestrian graph`; `conversion intent -> H3 transaction protocol -> one commit -> H5 graph/geometry rebuild`.

## Persistence impact

Persist only sparse converted `StreetSegmentState` through `DistrictState`; never persist public geometry, intersections, or pedestrian graph. Curbside facility state is future, has no current `DistrictState` field, and requires an approved future authority and persistence contract before shipping.

## Editor/runtime behavior

Same descriptors/graphs in editor and runtime. H4 owns all materialized Nodes.

## Migration and compatibility requirements

`LegacyExteriorAccessAdapter` remains compatibility-only until both blockers below are approved, then is removed by H10. Authored road/crosswalk assets may be reusable visuals only after dimension-independence proof.

### Corner-frontage attribution

**DESIGN BLOCKER:** the blueprint leaves corner-only frontage open. Design is the decision owner and Architecture is the validator. H5 conversion implementation and H10 removal are blocked until the selected alternative is recorded under acceptance evidence with both approvals.

| Alternative | Effect |
| --- | --- |
| A zero-length contact | A zero-length point contact contributes zero frontage. |
| B deterministic attribution | An approved deterministic corner-attribution rule assigns contribution. |
| C fixed-structure edge | An approved fixed-structure-edge-specific rule determines contribution. |

A, B, and C are neutral alternatives. Selection must assess mathematical determinism for both positive-length and point contacts, prevention of corner double counting, player-preview legibility at the exact 50% threshold, behavior for unusual fixed-structure edges, and compatibility evidence. The selected rule becomes the sole valid rule; unselected alternatives must reject. This handoff makes no recommendation.

### Public-band physical parcel-door access conflict

**DESIGN BLOCKER:** existing parcel splitting accepts public frontage while automatic doors require physical internal/explicit circulation.

| Alternative | Effect |
| --- | --- |
| A geometry-only | Public frontage cannot itself supply a physical door. |
| B topology-backed access | A stable adjacent band/edge can be a physical access candidate without band ownership transfer. |
| C internal-only | Public bands never satisfy parcel access. |

A, B, and C remain neutral alternatives. Design must choose among them based on physical-door semantics, ownership/capability separation, player legibility, and migration cost. No alternative is approved. H10 acceptance requires both H5 design approvals, implemented migration/tests, and removal of `LegacyExteriorAccessAdapter`.

## Expected affected files/systems

Public-realm resolver values, conversion integration, graph builder, H4 builders, access context, pathfinding, road visual assets.

## Acceptance criteria

Complete deterministic outer/internal topology; approved corner rule; conversion invariants; final pedestrian graph includes all inputs; H7 remains sole road graph owner; neither blocked alternative ships without approval. Before H5 conversion implementation or H10 acceptance, acceptance evidence records the selected corner-frontage alternative `A`, `B`, or `C`, Design approval, Architecture validation, and evidence against every listed selection criterion.

## Required tests

Profile/outer ring, topology incidence, positive-length collinear frontage, and the selected approved corner rule at below/exact/above threshold; unselected corner alternatives reject. Separately test conversion atomicity, pedestrian graph input/delta, save exclusion, the selected physical-door rule, and rejection of its unselected alternatives.

## Performance/scalability checks

Topology/graphs scale with elements, targeted conversion rebuilds are measured, and frontage uses indexed spans.

## Failure and rollback behavior

Invalid topology blocks publication. Conversion rejection changes nothing. Projection failure after commit retains authority and prior visuals.

## Technical risks

Double-counted corners, ownership/capability conflation, stale path references, and access without a physical door.

## FACTS

- H5 owns final pedestrian graph; H7 alone owns road graph.
- Positive-length collinear frontage measurement is decided.

## ASSUMPTIONS

- Rectilinear spans can represent approved topology.

## OPEN QUESTIONS

- **DESIGN BLOCKER:** Design selects corner-frontage alternative A, B, or C and Architecture validates it; record the selection and criterion evidence before H5 conversion implementation or H10.
- **DESIGN BLOCKER:** separately approve A, B, or C for public-band physical doors.
- Curbside facility authority, persistence, catalog, and active-agent response are later policies and cannot ship without that future contract.

## GodotPrompter skills required by implementation agents

- `procedural-generation`, `ai-navigation`, `math-essentials`, `3d-essentials`, `godot-testing`.
