# Handoff 07: Traffic Topology Migration

## Status

**Draft - implementation blocked by predecessors.** Requires [H5](05_street_and_pedestrian_generation.md) public-realm and conversion inputs.

## Purpose

Own immutable `RoadGraphSnapshot`, graph deltas, lane/control anchors, and the stable invalidation identifiers and instructions consumed by transient traffic systems. H7 does not own reservations.

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
| H5 | Public-realm/conversion inputs. |
| H7 TrafficTopology | Exclusive `RoadGraphSnapshot` and `RoadGraphDelta` authority. |
| TrafficManager | Ambient cars and transient reservations only. |

## Data contracts

`RoadGraphSnapshot` carries layout/resolver/district/graph revisions and stable lanes, segments, intersections, crosswalks, stops, route attachments, control anchors, and outer ring. `RoadGraphDelta` carries ordered added/changed/removed IDs, invalid routes/reservations, attachments, and reason. Control kinds replace Spawn/StopLine/Exit/SourceClear/IntersectionHold/IntersectionClear Node-name contracts without preserving scene identity.

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

Deterministic graph IDs; immutable ring; conversion connectivity never vetoes; stale routes/reservations clear; no Node-name/coordinate authority; H7 is sole road graph owner.

## Required tests

Profiles, graph goldens, conversion/deltas, route/reservation cleanup, missed-revision recovery, adapter exactness, save exclusion.

## Performance/scalability checks

Graph work scales with topology; route lookup is indexed; incremental rebuild is checked against full rebuild oracle.

## Failure and rollback behavior

Invalid graph retains last complete graph or disables initial ambient traffic. A valid district conversion is never rolled back for ambient failure.

## Technical risks

Dual graph authority, unstable IDs, stale reverse indexes, and confusing ring validity with internal connectivity.

## FACTS

- H7 alone owns `RoadGraphSnapshot`.

## ASSUMPTIONS

- Ambient cars may despawn without gameplay-state loss.

## OPEN QUESTIONS

- Ambient routing/presentation tuning and incremental strategy after profiling.

## GodotPrompter skills required by implementation agents

- `ai-navigation`, `resource-pattern`, `gdscript-advanced`, `godot-optimization`, `godot-testing`.
