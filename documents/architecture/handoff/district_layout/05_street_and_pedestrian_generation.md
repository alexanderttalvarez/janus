# Handoff 05: Street and Pedestrian Generation

## Status

**Approved — 2026-09-03.** Implementation requires implemented H3 transactions and H4 runtime projection lifecycle. The former corner-frontage/public-band access blockers and the required Economy/Progression policies are approved.

## Purpose

Own public-realm descriptors, generated pedestrian/road/intersection geometry, frontage, street conversion/state impacts, and final `PedestrianGraphSnapshot` authority.

## Dependencies

- [H3](03_variable_floor_grid_migration.md) state/transaction coordination.
- [H4](04_world_projection_and_editor_preview.md) generated Node lifecycle.
- H3 floor/circulation/door/vertical-link inputs.
- [Economy Handoff 01](../economy/01_transaction_authority_and_policy_boundary.md) and [Economy Handoff 02](../economy/02_expansion_pricing_and_refund_policy.md).
- [Progression Handoff 01](../progression/01_eligibility_policy_and_snapshot_boundary.md) and [Progression Handoff 03](../progression/03_bus_stop_eligibility.md).

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

No road graph, traffic reservations, price/formula ownership, ownership transfer of public bands, curbside facility state, or tenant-door allocation algorithm beyond the approved physical access-edge contract. H5 supplies geometry/count inputs; Economy H2 owns Street conversion pricing.

## System ownership

| Owner | Responsibility |
| --- | --- |
| Architecture | Validates each selected design contract against architecture invariants and acceptance evidence. |
| H5 public-realm projection | Descriptors, geometry, frontage, conversion rules/impacts, pedestrian graph, and public-band access edges. |
| District Runtime | Sole `StreetSegmentState` writer and atomic commit. |
| Economy | Quotes/reserves/captures the H2 Street conversion cost from H5's complete Corridor tile count. |
| Progression | Supplies immutable Street-conversion eligibility snapshot; Neighborhood Center is the normal-play gate. |
| H4 | Generated Nodes and projection lifecycle only; no public-realm or traffic semantics. |
| H7 | Exclusive road graph authority. |

## Data contracts

Each corridor has two 5-10-tile public bands and a carriageway with 2-6 total 3-tile lanes, at least one lane per direction, and contiguous same-direction groups. Outer ring is immutable. Internal conversion requires at least 50% owned frontage independently on both sides, includes both bands plus carriageway spatially, discloses connectivity without veto, and derives intersection transfer from all incident internal segments.

Only positive-length collinear contact from **Active/owned** Plot geometry contributes frontage; corner-only contact contributes zero. A Progression-selected/unlocked Plot is camera-accessible but has no owned section, adds no conversion frontage, creates no player floor/circulation input, and does not change `PedestrianGraphSnapshot`. An adjacent active public Pedestrian Band may provide a topology-backed physical door/access edge for a Plot Section or tenant parcel without ownership transfer. That edge must have stable public-topology identity and appear under the same connector ID in the post-commit pedestrian graph. H5 does not define tenant-door allocation beyond this access contract.

Under [ADR 35](../../decisions/35_public_band_access_snapshot_and_zone_injection.md), H5 owns pure derivation of the exact immutable `PublicBandAccessSnapshot` from one resolved layout and one committed or prospective District candidate. It contains exact H9 `layout_ref`, the represented nonnegative `district_revision`, and stable `jid1` access edges sorted by ID. Each edge identifies one ground-level `FloorCellAddress`, outward cardinal direction, and H2 Pedestrian Band ID for positive-length orthogonal Active/owned Plot-to-active-band adjacency. Corner-only, selected/unowned, inactive, virtual, implicit, and transform-derived entries are absent. The snapshot contains no Nodes, transforms, graph handles, Zone/parcel IDs, or mutable collections.

Generated public-realm geometry is descriptor-driven: carriageways use dark-gray asphalt sized from Street Segment length and lane count. Flat marking overlays sit epsilon above asphalt and batch per segment/chunk; they are not hand-authored decal Nodes or raised geometry. Ordinary markings are 0.25 tile thick and stop lines are 0.50 tile thick. Use solid edge lines against both Pedestrian Bands, a solid divider between opposing direction groups, and 1-tile white/1-tile gap dashed dividers within a direction group. Each active Street Segment has exactly one centered crosswalk, 5 tiles along-road wide, with alternating 0.5-tile white stripes and 0.5-tile exposed asphalt, spanning the full carriageway. Apply stop lines only to approaching lanes, 2 full tiles before the approached midpoint crosswalk or intersection boundary. Curbs are continuous on both carriageway edges, 0.10 tile high and 0.15 tile wide, except flush interruptions at midpoint crosswalks; intersections use simple square 90-degree corners.

Intersections are plain dark-gray `C x C` surfaces with no internal lane-direction markings and only approach stop lines. Pedestrian Bands connect around intersection exteriors but do not create pedestrian intersection crossings. Midpoint crosswalks are the only pedestrian crossings; outer-ring midpoint crosswalks remain traffic-functional but create neither pedestrian graph links nor visitor crossings. A converted Street Segment removes its carriageway, markings, curbs, midpoint crosswalk, traffic lights, and stop lines; its whole space becomes unrestricted pedestrian topology using ordinary Pedestrian Band paving.

`PedestrianGraphSnapshot` combines public-band edges with H3 floor/circulation/door/vertical-link values at explicit revisions. It is immutable, derived, unsaved, and rebuilt/delta-published after commit.

`PublicBandAccessSnapshot` is also transient and unsaved, but precedes Zone preparation and graph rebuild. Preview and commit derive it from the same prospective District candidate and layout identity; the District coordinator injects it explicitly into Zone preparation. Zone never queries a global H5 value or live graph. District changes that may affect public access include Zone as a transaction participant so retained stable edge IDs validate before swaps. The post-commit pedestrian graph rebuild uses committed facts and must reproduce those connector IDs.

## Communication and event flow

`resolved layout + prospective District candidate -> public-band access snapshot -> District-coordinated Zone prepare`; `resolved public realm + committed H3 circulation/doors/vertical links -> pedestrian graph`; `conversion intent + H5 complete Corridor tile count + Economy H2 policy snapshot + Progression eligibility snapshot -> H3 transaction protocol -> one commit -> H5 graph/geometry rebuild`.

## Persistence impact

Persist only sparse converted `StreetSegmentState` through `DistrictState`; never persist public geometry, intersections, `PublicBandAccessSnapshot`, pedestrian graph, price quotes, reservations, or policy snapshots. Curbside facility state is future, has no current `DistrictState` field, and requires an approved future authority and persistence contract before shipping.

## Editor/runtime behavior

Same descriptors/graphs in editor and runtime. H4 owns all materialized Nodes.

## Migration and compatibility requirements

`LegacyExteriorAccessAdapter` remains compatibility-only until implementation and migration evidence covers the approved rules, then is removed by H10. Authored road/crosswalk assets may be reusable visuals only after dimension-independence proof.

## Expected affected files/systems

Public-realm resolver values, conversion integration, graph builder, H4 builders, access context, pathfinding, road visual assets.

## Acceptance criteria

Complete deterministic outer/internal topology; deterministic exact public-band snapshot derivation; zero corner-only or selected-unowned-Plot frontage; conversion invariants; a complete Corridor tile count supplied to Economy H2; normal-play Neighborhood Center Progression eligibility; prospective District-to-Zone injection has preview/commit parity and fails closed on layout/revision/malformed input; final pedestrian graph includes all inputs and the same stable public-band connector IDs; H7 remains sole road graph owner; no global query, new owner, persisted snapshot, or persisted graph exists; and generated geometry follows the approved road/crosswalk/curb contract. God mode may bypass only the Progression gate and Economy cost; it never bypasses H3/H5 physical/frontage/revision/atomicity rules. H4 remains projection lifecycle only, so these descriptors require no retroactive semantic change to completed H4 work.

## Required tests

Profile/outer ring, topology incidence, positive-length collinear frontage, zero corner-only frontage at below/exact/above threshold, conversion atomicity, pedestrian graph input/delta, save exclusion, and stable active public-band access-edge validation. Test the full generated road contract: lane markings, curbs, midpoint-crosswalk dimensions and stripes, approach-only stop lines, plain intersections, outer-crosswalk pedestrian exclusion, and complete conversion removal.

## Performance/scalability checks

Topology/graphs scale with elements, targeted conversion rebuilds are measured, and frontage uses indexed spans.

## Failure and rollback behavior

Invalid topology blocks publication. Conversion rejection changes nothing. Projection failure after commit retains authority and prior visuals.

## Technical risks

Double-counted corners, ownership/capability conflation, stale path references, and access without a physical door.

## FACTS

- H5 owns final pedestrian graph; H7 alone owns road graph.
- Positive-length collinear frontage measurement is decided.
- **2026-08-31 Road & Intersection Addendum:** Corner-only contact is zero frontage. Active adjacent public-band graph edges may provide physical parcel access without ownership transfer. H5 owns public-realm descriptors; H4 remains projection lifecycle only.

## ASSUMPTIONS

- Rectilinear spans can represent approved topology.

## OPEN QUESTIONS

- Curbside facility authority, persistence, catalog, price/fee, removal/refund, and active-agent response are later policies and cannot ship without that future contract.

## GodotPrompter skills required by implementation agents

- `procedural-generation`, `ai-navigation`, `math-essentials`, `3d-essentials`, `godot-testing`.
