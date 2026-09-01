# Handoff 07: Traffic Topology Migration

## Status

**Draft - implementation blocked by predecessors.** Requires [H5](05_street_and_pedestrian_generation.md) public-realm and conversion inputs.

## Purpose

Own immutable `RoadGraphSnapshot`, graph deltas, lane/control anchors, traffic-control descriptors, and the stable invalidation identifiers and instructions consumed by transient traffic systems. H7 does not own reservations.

## Dependencies

- H2 resolved road descriptors, H3 committed segment state, and [H5](05_street_and_pedestrian_generation.md) conversion/public-realm inputs.

## Source-of-truth documents

- [Decision 27](../../decisions/27_district_layout_templates.md)
- [Handoff index](./_index.md)

## Current-state findings

`TrafficManager` discovers `World/TrafficLayout/Lanes`, eight exact `Lane_*` names, six marker families, and NW/NE/SW/SE reservation zones from authored Nodes.

## Target state

TrafficTopology alone publishes complete immutable road graphs and ordered deltas. `TrafficManager` owns transient cars/reservations against one graph revision and cannot write topology or veto street conversion.

## Scope

Road graph generation, lane/intersection/crosswalk/route/control attachments, deltas, transient reservation invalidation, and authored-layout migration.

## Explicit non-goals

Public-realm geometry, pedestrian graph, conversion eligibility/state writes, persistence, traffic prices/rates/capacities, or bus-only lanes.

## System ownership

| Owner | Responsibility |
| --- | --- |
| H5 | Public-realm/conversion inputs and pedestrian graph authority. |
| H7 TrafficTopology | Exclusive `RoadGraphSnapshot` and `RoadGraphDelta` authority. |
| TrafficManager | Ambient cars plus fade/spawn/despawn presentation and transient reservations only. |

## Data contracts

`RoadGraphSnapshot` carries layout/resolver/district/graph revisions and stable lanes, segments, intersections, crosswalks, stops, route attachments, control anchors, traffic-control descriptors, and outer ring. `RoadGraphDelta` carries ordered added/changed/removed IDs, invalid routes/reservations, attachments, and reason. Control kinds replace Spawn/StopLine/Exit/SourceClear/IntersectionHold/IntersectionClear Node-name contracts without preserving scene identity.

Initial routes are straight-through only. Turn-capable extension points remain in the contract, but no turn route is active. Existing intersection reservation behavior remains authoritative for straight crossings; intersections have no traffic lights or pedestrian crossings. The controlled area is the connected union of Active Plot rectangles. District acquisition rules guarantee this invariant; any proof fixture with disconnected initially-active Plots must be corrected before use.

Every outward-facing lane at the controlled-area road perimeter has paired spawn and despawn anchors just outside the boundary intersection, oriented by lane direction. As the controlled area expands, topology moves active anchors outward. Converted or inactive roads have no active anchors. TrafficTopology owns anchors and graph state; TrafficManager owns only presentation and transient cars.

Each midpoint crosswalk has two traffic-light poles, one centered in each Pedestrian Band opposite the other. Poles are compact dark-charcoal/black metal with rectangular heads and a signal center 2.5 tiles high; each provides vehicle green/yellow/red and pedestrian red/green faces. The shared traffic clock uses simulation-time scaling and pauses with simulation. Its 10T cycle is cars green for 5T, yellow for 1T, and red for 4T; pedestrians are red for 6T and green for 4T. North-south road crosswalks use offset 0; east-west use a 5T half-cycle offset. At shared-clock zero, north-south vehicle lights are green and east-west vehicle lights are red. During yellow, cars past their crosswalk stop line clear; cars not past it stop. Pedestrians enter only on green and otherwise wait. Canonical crossing time `T` is full carriageway crossing distance divided by canonical crosswalk speed, and every visitor uses that same canonical speed regardless of status. H7 distinguishes traffic-functional outer-crosswalk lights from H5 pedestrian-graph crossings.

## Communication and event flow

`H5 inputs + committed segment state -> complete graph -> delta -> release invalid reservations -> deterministic transient response`.

## Persistence impact

Graphs, deltas, anchors, routes, reservations, and cars are unsaved. Rebuild after H9 commit.

## Editor/runtime behavior

Atomic complete snapshot replacement; editor and runtime use identical graph generation.

## Migration and compatibility requirements

`LegacyAuthoredTrafficLayoutAdapter` validates/adapts exactly the current eight lanes, six marker families, and four reservation zones for the legacy fixture only; H10 removes it and all authored topology authority.

## Expected affected files/systems

Traffic manager, graph modules, composition, authored traffic Nodes, conversion subscribers, tests.

## Acceptance criteria

Deterministic graph IDs; immutable ring; conversion connectivity never vetoes; stale routes/reservations clear; no Node-name/coordinate authority; H7 is sole road graph owner; straight-only initial routes; connected controlled-area invariant; perimeter anchors; and the shared-clock control contract. H4 remains projection lifecycle only, so H7 traffic semantics do not retroactively change completed H4 work.

## Required tests

Profiles, graph goldens, straight-only routes with inactive turn extensions, conversion/deltas, route/reservation cleanup, missed-revision recovery, adapter exactness, save exclusion, connected controlled-area fixtures, active-anchor migration, converted/inactive anchor exclusion, traffic-control placement, clock offsets/phases/pause/time-scale behavior, yellow clearing, and canonical pedestrian crossing speed. Prove that outer midpoint crosswalk controls are traffic-functional without becoming H5 pedestrian graph crossings.

## Performance/scalability checks

Graph work scales with topology; route lookup is indexed; incremental rebuild is checked against full rebuild oracle.

## Failure and rollback behavior

Invalid graph retains last complete graph or disables initial ambient traffic. A valid district conversion is never rolled back for ambient failure.

## Technical risks

Dual graph authority, unstable IDs, stale reverse indexes, and confusing ring validity with internal connectivity.

## FACTS

- H7 alone owns `RoadGraphSnapshot`.
- **2026-08-31 Road & Intersection Addendum:** H7 owns traffic anchors, straight-through road routes, shared-clock traffic controls, and traffic-functional crosswalk semantics. H5 owns pedestrian crossings and public-realm descriptors; H4 remains projection lifecycle only.

## ASSUMPTIONS

- Ambient cars may despawn without gameplay-state loss.

## OPEN QUESTIONS

- Ambient routing/presentation tuning and incremental strategy after profiling.

## GodotPrompter skills required by implementation agents

- `ai-navigation`, `resource-pattern`, `gdscript-advanced`, `godot-optimization`, `godot-testing`.
