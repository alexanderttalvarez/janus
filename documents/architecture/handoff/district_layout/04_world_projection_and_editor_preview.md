# Handoff 04: World Projection and Editor Preview

## Status

**Draft - implementation blocked by predecessors.** Requires implemented H3 state, explicit addresses, revisions, and lifecycle.

## Purpose

Own all generated Node/projection lifecycle in runtime and editor, including floor, wall, door, overlay, label, debug, and later public-realm visuals, plus `main_game` composition. Editor preview is delivered only through the opt-in tooling contract in the 2026-08-31 addendum below.

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
| Projection Coordinator | Every generated runtime Node/root and lifecycle operation. |
| Descriptor builders | Pure geometry/presentation values. |
| Opt-in editor plugin and its `@tool` preview controller | Editor-only selection, validation, diagnostics, and disposable preview-root lifecycle; never domain or runtime authority. |
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

Editor and runtime use the same H1 validation, H2 resolver/grid poses/bounds, injected `ProjectionMetrics` identity/revision/value, projection function, and descriptors. Opening a scene with different current Node transforms cannot silently redefine metrics. The editor-preview implementation is non-authoritative and is constrained by the 2026-08-31 addendum below.

## Migration and compatibility requirements

Replace the 625-Node path and hard floor lookup. Existing road scenes may later be visual pieces under H5 but never define semantics.

## Expected affected files/systems

Projection modules, `floor.tscn`, `main_game.tscn`, walls/doors, tools, overlays, labels, preview tooling.

## Acceptance criteria

Parity across fixtures with byte/equality-checked metrics identity/revision/value; variable/sparse/multi-elevation grid-pose projection; exact quarter-tile and elevation round trips; deterministic facing; mismatch rejection; bounded renderer; failed/stale builds retain prior projection; clean disposal; no road semantics or graph ownership.

## Required tests

Descriptor goldens; H2 grid-pose/bounds to Godot projection and inverse-picking round trips across positive/negative quarter coordinates and elevations; editor/runtime metrics parity; missing/invalid/mismatched metrics rejection; projection-origin translation; facing; wall/door/overlay alignment; swap fault injection; editor cleanup; no per-cell Node regression; rebuild-without-authority-change or district-fingerprint change when presentation metrics change. The editor-plugin-specific coverage is defined in the 2026-08-31 addendum below.

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

## 2026-08-31 Editor Preview Addendum

**Status: new H4 completion requirement.** H4 runtime projection work may be complete independently, but H4 editor-preview acceptance remains pending until the optional editor-plugin capability and its tests exist. This addendum does not change H5 or H7 ownership.

### Editor tooling boundary

- District layout must be visible and inspectable in the Godot editor, not only while the game runs.
- Provide this only through a dedicated opt-in `EditorPlugin` plus an `@tool` preview controller. Do not put `@tool` behavior in District Runtime, the resolver, or any production game-authority class.
- The plugin provides layout selection and validation controls, manual explicit preview rebuild and cleanup actions, and optional diagnostic display. Implementation paths, dock placement, custom types, controller names, and UI design remain open.
- The preview controller materializes a disposable generated preview root from the existing H1, H2, and H4 contracts. H1 validation, H2 resolution, and H4 descriptor/projection behavior are shared with runtime; the plugin must not introduce alternate semantics, identity, geometry, or transforms.

### Authority and lifecycle

- Preview is non-authoritative: it never mutates immutable Resources/definitions, `DistrictState`, `SaveManager` data, economy/progression, scenes, or gameplay/runtime authority, and it never writes authoritative content into the live `main_game` scene.
- Preview roots are plugin-owned, marked generated, isolated from authored nodes, and removed on explicit cleanup, plugin disable, scene close/change, and failed or stale rebuild. `_exit_tree` unregisters/frees plugin UI and preview roots.
- The safe lifecycle is `validate -> build detached candidate -> stale/revision check -> swap -> dispose old preview`. Invalid definitions expose validation diagnostics instead of a partial preview. A failed or stale rebuild keeps the prior valid preview.
- All editor-only scripts use `@tool` and guard editor-only behavior. Runtime does not rely on `Engine.is_editor_hint()` for domain semantics.
- Editor and runtime receive the same immutable `ProjectionMetrics` identity, revision, and value. Metrics are injected, never inferred from current Nodes or transforms; parity is required.

### Acceptance and tests

- Acceptance requires editor visibility/inspection, explicit rebuild and cleanup, generated-root isolation, invalid-definition diagnostics without partial preview, detached-candidate stale-safe swapping, prior-preview retention on failure, and cleanup on every listed lifecycle exit.
- Tests must prove H1/H2/H4 parity, metrics identity/revision/value parity, no authority or authored-scene mutation, generated-root ownership/isolation, all cleanup paths, invalid/stale/failure behavior, and `_exit_tree` teardown.
- The implementation agent requires `addon-development` and `godot-testing` skills in addition to the existing H4 skills.

## GodotPrompter skills required by implementation agents

- `addon-development`, `scene-organization`, `3d-essentials`, `godot-optimization`, `godot-testing`.
