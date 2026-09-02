# Handoff 09: Save/Load V2 and District Persistence

## Status

**Draft - implementation blocked by predecessors.** Requires implemented H1-H8 authority snapshots and MVP immediate realization. It is not blocked by future durable pending-cohort policy because MVP has no durable pending window.

## Purpose

Define Save V2 and detached, validated, atomic session replacement while preserving JSON monolithic slots, five slots, and `SaveManager` orchestration.

## Dependencies

- [H1](01_definition_schema_and_validation.md) semantic inclusion, [H2](02_resolved_district_model.md) canonical encoding/hash, H3-H8 state contracts.

## Source-of-truth documents

- [Decision 15](../../decisions/15_save_load_architecture.md)
- [Handoff index](./_index.md)

## Current-state findings

Current parsing emits `game_loaded`, schema follows application version, and managers deserialize sequentially into live state.

## Target state

Integer `save_schema_version`; layout/version/fingerprint identity; sparse authority snapshots; detached validation; staging projections; one atomic session commit; `game_loaded` only after commit. V2 is the first supported district-layout save schema.

## Scope

V2 envelope, V2 compatibility validation, staging, atomic commit, safe writes/backups, events, tests.

## Explicit non-goals

No generated data, V1 classification/conversion, runtime old-schema adapter, pending MVP records, gameplay policy, partial load, or guessed migration.

## System ownership

| Owner | Responsibility |
| --- | --- |
| `SaveManager` | I/O, schema validation, V2 compatibility policy, structured results, sole post-commit event. |
| H1 | Exact fingerprint semantic inclusion. |
| H2 | Exact canonical byte encoding and SHA-256. |
| Session owner | Candidate build and atomic swap. |

## Data contracts

### Exact V2 envelope

The V2 root has exactly `save_schema_version`, `meta`, `layout_ref`, and `authorities`; unknown or missing keys reject.

- `save_schema_version` is integer `2`.
- `meta` has exactly integer `slot`, integer UTC `timestamp`, and string `application_version`.
- `layout_ref` has exactly string `layout_id`, integer `layout_definition_version`, and lowercase 64-character hexadecimal SHA-256 `definition_fingerprint`.
- `authorities` has exactly the keys `district`, `zone_parcel`, `tenant`, `visitor`, `economy`, `progression`, `prestige`, `staff`, `synergy`, and `time`; no unknown or missing key is allowed.

Each authority value is a detached snapshot owned, versioned, and validated by that named authority. `authorities.district` is exactly H2's complete `DistrictState` schema and its identity values must equal `layout_ref`. Derived geometry, graphs, transforms, Nodes, indexes, presentation, reservations, pending cohorts, and caches are excluded.

### Schema absence and incompatibility result

Any payload lacking `save_schema_version`, including every current V1 save, is unsupported. Reject it before staging, projection work, or live-session mutation. Do not classify its shape, convert it, map legacy source or floor IDs, derive baselines, or route fields through compatibility code.

Rejection returns a structured incompatibility diagnostic/result suitable for presentation, including a stable reason code and whether the slot was preserved. User-facing incompatibility messaging is required, but its exact text and UI location remain presentation-owned. Rejection never silently deletes, overwrites, or otherwise changes the existing save slot.

### Future V2 compatibility

V2 payloads must match the exact envelope above and resolve a known layout whose definition version and fingerprint match `layout_ref`. Unknown, retired, or incompatible layouts and fingerprints reject safely before staging. Future V2 schema migrations are permitted only when explicitly approved and released; no converter, registry, compatibility adapter, baseline/derivation policy, or migration artifact is created in advance.

## Communication and event flow

`parse -> require V2 schema -> validate exact envelope -> resolve definition -> verify fingerprint -> validate all authorities/cross-refs detached -> build staging projections -> atomic session commit -> game_loaded once`.

Metadata reads, parsing, migration, staging, and failures emit no `game_loaded`.

## Persistence impact

V1 and other schema-absent payloads are rejected with no slot mutation. Save writes stage and validate the complete V2 envelope, flush a temporary file, then atomically replace the slot; failure preserves the prior slot. MVP persists no pending arrival records. Future durable cohorts must define persistence before shipping.

## Editor/runtime behavior

Editor can validate detached data without events or live mutation. Runtime exposes no staging Nodes/services before commit.

## V1 Save Support Decision (2026-08-31)

**Approved policy:** V2 is the first supported district-layout save schema. Current V1 saves and every payload without `save_schema_version` are incompatible and rejected before staging or live mutation. The old slot remains intact, and the returned structured diagnostic enables required presentation-owned incompatibility messaging. There is no V1 conversion, support window, compatibility adapter, fixture conversion, source/floor mapping, baseline/derivation policy, or migration registry.

## Expected affected files/systems

SaveManager, V2 DTOs, session staging, all authority snapshot boundaries, projection rebuild orchestration, presentation-owned incompatibility messaging.

## Acceptance criteria

Exact-key V2 sparse round trip; schema-absent/V1 rejection before staging with a structured incompatibility result and preserved slot; V2 malformed, unknown-layout, and fingerprint rejection; staged atomic save/load; all failures retain the old session; one post-commit `game_loaded`; generated data absent; no pending-MVP blocker.

## Required tests

V2 exact root/meta/layout/authority key and type tests; H2 district-schema invariants; schema-absent payload (including current V1) rejection before staging/live mutation with structured incompatibility diagnostic and unchanged slot; V2 missing/unknown keys, unknown layout IDs, definition-version mismatch, and fingerprint mismatch rejection; detached authority validation; fault injection at every staged load/save step; event order; safe temporary-file atomic replacement; round trip. Verify that no V1 shape classifier, converter, source/floor mapper, fixture conversion, baseline/derivation policy, compatibility adapter, or migration registry is reachable or required.

## Performance/scalability checks

Report parse/validate/rebuild/commit separately; size follows mutable state; repeated cycles leak nothing.

## Failure and rollback behavior

Any precommit failure destroys staging and preserves live session/slot. V2 never silently downgrades.

## Technical risks

JSON number coercion, accidental live singleton mutation, staging registration, unsupported definition retirement, and unclear presentation of incompatibility.

## FACTS

- `game_loaded` means successful atomic commit only.
- H1 owns inclusion; H2 owns bytes/hash.
- H9 is implementation-ready when H1-H8 authority snapshots and MVP immediate realization are implemented.

## ASSUMPTIONS

- Authorities expose detached snapshot validation/import.

## OPEN QUESTIONS

- Save support/backup window and concrete performance budgets.
- Future V2 schema migration rules remain open and require explicit approval and release before implementation.
- Future durable cohort policy before those cohorts ship.

## GodotPrompter skills required by implementation agents

- `save-load`, `resource-pattern`, `dependency-injection`, `scene-organization`, `godot-testing`.
