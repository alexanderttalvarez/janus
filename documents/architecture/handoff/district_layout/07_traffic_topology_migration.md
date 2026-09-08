# District Layout Handoff 07: Traffic Topology

## Status

Approved 2026-09-03; revised 2026-09-08 under delegated documentation authority and ADR 33. The connected-Plot-union assertion, 5T-offset/red-at-zero pair, absent pedestrian clearance and mandatory turn-extension hooks are superseded. Prior engineering evidence does not verify this revision.

## Purpose

Supply deterministic road topology and safe straight-through ambient traffic/midpoint crossings without creating a transport simulation or duplicating public pedestrian topology.

## In-Scope Behavior

Road graphs/deltas; stable lanes, intersections, controls and anchors; straight-through intersection reservations; phase/clearance control at segment midpoint crosswalks; invalidation after construction/conversion/load. Use active-slot components, not a filled geometric bounding box.

## Out-of-Scope Behavior

Intersection lights/crosswalks, turns or turn-framework hooks, bus facilities/economics/capacities, street purchase policy, persistent cars/reservations, pedestrian graph ownership, future transport cohorts, or authored Node-name topology.

## Authorities

[Element 19](../../../game_design/elements/19_district_layout_land_expansion.md) owns road dimensions, active-slot perimeter and exact crossing phase/clearance/speed rules. [ADR 27](../../decisions/27_district_layout_templates.md), [ADR 33](../../decisions/33_documentation_consistency_and_minimum_contracts.md), H2 resolution, H3 state, H5 public realm and element 01's clock apply. No duplicate timing table is authored here.

## Inputs and Outputs

Inputs: H2 resolved lane/segment/intersection descriptors; committed H3 Active Plot and segment state; H5 conversion/public-realm inputs; Time's scaled elapsed seconds for control evaluation. Progression-selected but unowned Plots do not count.

Outputs: complete immutable `RoadGraphSnapshot` with source revisions and stable IDs for lanes, segments, intersections, crosswalks, stops, anchors and the permanent outer ring; `RoadGraphDelta` with canonically ordered added/changed/removed IDs, invalid routes/reservations and reason. Control identities are semantic, never Spawn/StopLine/Exit Node names. Runtime public-crossing consumers receive phase and occupancy admission facts, not a second graph.

## State Ownership

TrafficTopology alone publishes road topology/deltas and control descriptors. TrafficManager owns transient cars and vehicle/pedestrian crossing reservations, including occupancy holds; it reads the shared Time clock and never saves/restarts an independent timer. Visitor owns the crossing visitor's logical lifecycle/movement and releases its crossing reservation after clearing. H5 alone owns pedestrian links; H8 arrival allocation is independent of traffic, though actual later crossing traversal observes these controls. No observer writes another owner's state.

## Invariants

- Intersections are reservation-controlled and straight-through only, never traffic-light controlled. Midpoint crosswalks are the only pedestrian crossings.
- Active-slot adjacency defines one or more valid components; Fixture C retains its exact three initial entry sections without inventing connecting ownership. Each component's bordering resolved roads supply its perimeter. Shared lane/control anchors deduplicate by stable identity; canonical order removes traversal-order dependence.
- Selected/unowned Plots cannot extend controlled boundaries. Converted/inactive roads have no active anchors; the permanent outer ring is never removed.
- Element 19's phase epoch, east-west offset, final-T clearance and mutual occupancy hold are exact. A vehicle and pedestrian cannot acquire conflicting crossing occupancy. Coarse visitor decision ticks do not delay safety release/hold checks.
- Outer-ring midpoint lights remain vehicle-functional but never create H5 pedestrian links or permit visitor entry.
- Rebuild replaces the whole graph atomically. Cars/reservations are transient; stale handles cannot cross revisions. Conversion never fails because ambient traffic would disconnect.

## Failure and Edge Cases

Missing/invalid initial graph disables ambient cars. A failed update retains the previous complete graph for diagnosis but closes controls affected by a newer District revision; never traverse stale converted roads. Stop new entries, release/invalidate affected reservations and remove ambient cars safely without rolling back valid District state. A pedestrian already crossing clears before conflicting movement resumes; if topology removes its route, use the approved Visitor topology recovery at a valid public anchor, never drop the visitor. At load, derive phases from restored Time and start with no transient reservations; no retroactive traffic work runs.

## Dependencies

Implemented H2/H3/H5 source ports. H6 is not needed for road topology; H8 is not needed for graph construction. Integration with public visitor traversal requires its existing movement lifecycle and the crossing admission facts above. No bus/runtime interior contract is a prerequisite.

## Ordered Implementation Outcomes

1. Produce complete deterministic graphs from resolved roads and active-slot components.
2. Derive perimeter anchors, excluding selected/unowned and converted/inactive roads.
3. Publish deltas and invalidate transient routes/reservations in stable order.
4. Apply element-19 timing/occupancy holds to ambient cars and public crossing traversal using shared Time.
5. Rebuild after load and demonstrate runtime/editor graph parity without persisted topology.

## Acceptance Criteria

- Same inputs produce identical stable graphs/deltas; input order cannot change anchors or routes.
- Single Plot, adjacent Plots, disconnected Fixture C components, selected-only Plots and conversion splits obey perimeter/ownership rules with no duplicate anchors or inferred connecting Plot.
- Boundary tests at phases 0, 5, 6, 9 and 10 prove signal states; east-west is red at epoch zero. Pause/speed and restore preserve phase derivation.
- Entry just before pedestrian cutoff clears before vehicle entry; a stalled pedestrian or late clearing car keeps the conflicting hold. No crossing conflict occurs during a large frame or skipped visitor-decision interval.
- Outer midpoint controls remain traffic-functional but pedestrian-inaccessible. No intersection light/crosswalk or turn path exists.
- Conversion, stale graph, missed delta and failed rebuild never restore obsolete traffic access or veto valid District state.
- Graphs, routes, cars, controls and reservation state are absent from durable saves; post-load topology comes from committed authority.
