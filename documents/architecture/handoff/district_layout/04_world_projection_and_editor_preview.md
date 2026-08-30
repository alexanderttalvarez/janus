# Handoff 04: World Projection and Editor Preview

## Status

**Draft - implementation blocked by predecessors.** Requires implemented H3 state, explicit addresses, revisions, and lifecycle.

## Purpose

Own all generated Node/projection lifecycle in runtime and editor, including floor, wall, door, overlay, label, debug, and later public-realm visuals, plus `main_game` composition.

## Dependencies

- [H3](03_variable_floor_grid_migration.md) committed immutable views and affected scopes.
- [H1](01_definition_schema_and_validation.md) and [H2](02_resolved_district_model.md) frozen definitions/transforms.

## Source-of-truth documents

- [Handoff index](./_index.md)
- [Decision 1](../../decisions/01_scene_architecture.md) and [Decision 6](../../decisions/06_floor_representation.md)

## Current-state findings

The current floor assumes 25x25/625 per-tile mesh Nodes, zero-origin transforms, fixed floor lookup, and global wall rebuilds; `main_game` contains authored road visuals.

## Target state

One Projection Coordinator owns generated roots from detached descriptor build through validation, stale-revision check, atomic swap, and disposal. `main_game.tscn` remains composition root; `floor.tscn` is a reusable explicit plot/elevation container, never authority.

## Scope

Generated floor/ground, wall, door-gap, overlay, heatmap, label, debug, picking, bounds, runtime/editor preview, cancellation, swaps, disposal, and composition lifecycle.

## Explicit non-goals

No district/state writes, road semantics, street conversion, traffic graph, arrival policy, persistence, or renderer choice before profiling.

## System ownership

| Owner | Responsibility |
| --- | --- |
| Projection Coordinator | Every generated Node/root and lifecycle operation. |
| Descriptor builders | Pure geometry/presentation values. |
| H5 | Public-realm semantics/descriptors. |
| H7 | Road graph; H4 never owns it. |

## Data contracts

Requests carry fingerprint, district/zone revisions, explicit addresses, affected scope, layers, runtime/editor mode, H2 `DistrictGridPose`/`DistrictGridRect` values, and one immutable `ProjectionMetrics` value. Results carry immutable manifests, stable source mappings, projected transforms/bounds, budgets, diagnostics, and a detached candidate root only after materialization. Node references never enter domain APIs.

`ProjectionMetrics` has stable `identity`, `revision`, and immutable `value`. Its value contains positive finite `grid_unit_size`, positive finite `floor_height`, and a finite projection origin, with no inferred or fallback members. The same identity, revision, and value must be injected into editor preview and runtime for a district projection. Metrics are presentation configuration only: they do not enter district fingerprints, semantic IDs, saves, or gameplay authority, and are never inferred from current Nodes, imported visual dimensions, or an existing scene transform. A missing metric, invalid value, or identity/revision/value mismatch rejects preview/build before materialization and leaves the prior projection intact.

Projection converts H2 integer-quarter coordinates exactly once: grid `x4` maps to Godot `+X` as `origin.x + (x4/4)*grid_unit_size`, grid `z4` maps to Godot `+Z` as `origin.z + (z4/4)*grid_unit_size`, and signed `elevation` maps to Godot `+Y` as `origin.y + elevation*floor_height`. Bounds project their quarter-tile edges by the same rule. Facing maps without rotation ambiguity: grid `NORTH/EAST/SOUTH/WEST` points toward Godot `-Z/+X/+Z/-X`; `NONE` applies no directional rotation. Arithmetic uses the integer-quarter value as the source and performs one presentation conversion, never repeated float accumulation. No numeric grid size or floor height is fixed by this handoff.

## Communication and event flow

`committed views -> descriptors -> validate/budget -> detached Nodes -> stale check -> atomic swap -> dispose old root`.

## Persistence impact

Generated Nodes, meshes, walls, doors, overlays, labels, bounds, and manifests are never saved.

## Editor/runtime behavior

Editor and runtime use the same resolver, H2 grid poses/bounds, injected `ProjectionMetrics` identity/revision/value, projection function, descriptors, and lifecycle. Preview roots are marked generated and removed on close/disable. Opening a scene with different current Node transforms cannot silently redefine metrics.

## Migration and compatibility requirements

Replace the 625-Node path and hard floor lookup. Existing road scenes may later be visual pieces under H5 but never define semantics.

## Expected affected files/systems

Projection modules, `floor.tscn`, `main_game.tscn`, walls/doors, tools, overlays, labels, preview tooling.

## Acceptance criteria

Parity across fixtures with byte/equality-checked metrics identity/revision/value; variable/sparse/multi-elevation grid-pose projection; exact quarter-tile and elevation round trips; deterministic facing; mismatch rejection; bounded renderer; failed/stale builds retain prior projection; clean disposal; no road semantics or graph ownership.

## Required tests

Descriptor goldens; H2 grid-pose/bounds to Godot projection and inverse-picking round trips across positive/negative quarter coordinates and elevations; editor/runtime metrics parity; missing/invalid/mismatched metrics rejection; projection-origin translation; facing; wall/door/overlay alignment; swap fault injection; editor cleanup; no per-cell Node regression; rebuild-without-authority-change or district-fingerprint change when presentation metrics change.

## Performance/scalability checks

Profile viable chunked/`MultiMesh`/`ArrayMesh` approaches and record node, draw, memory, full-build, and targeted-rebuild budgets.

## Failure and rollback behavior

Projection failure never mutates or rolls back committed authority; retain old presentation and retry from authority.

## Technical risks

Shared material mutation, stale async results, temporary double memory, and Node metadata becoming identity.

## FACTS

- H4 owns generated visuals and `main_game` composition, not road semantics or traffic graphs.
- H4 consumes H2 dimensionless grid poses/bounds and is the sole owner of their physical projection through injected `ProjectionMetrics`.

## ASSUMPTIONS

- Renderer choice can remain behind stable descriptor contracts.

## OPEN QUESTIONS

- Renderer/profile budgets, safe worker-thread stages, and degraded-presentation input policy.

## GodotPrompter skills required by implementation agents

- `addon-development`, `scene-organization`, `3d-essentials`, `godot-optimization`, `godot-testing`.
