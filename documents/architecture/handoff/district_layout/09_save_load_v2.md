# Handoff 09: Save/Load V2 and District Persistence

## Status

**Draft - implementation blocked by predecessors and migration data.** Requires implemented H1-H8 authority snapshots and a complete owner-versioned V1 converter registry. It is not blocked by future durable pending-cohort policy because MVP has no durable pending window.

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

Integer `save_schema_version`; layout/version/fingerprint identity; sparse authority snapshots; detached migration/validation; staging projections; one atomic session commit; `game_loaded` only after commit.

## Scope

V2 envelope, migration registry, exact V1 recognition/conversion, source-ID migration, staging, atomic commit, safe writes/backups, events, tests.

## Explicit non-goals

No generated data, runtime old-schema adapter, pending MVP records, gameplay policy, partial load, or guessed migration.

## System ownership

| Owner | Responsibility |
| --- | --- |
| `SaveManager` | I/O, schema dispatch, migration orchestration, result, sole post-commit event. |
| H9 offline converter | Detached V1-to-V2 values only. |
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

### Exact V1 classification

A payload is V1 only when the root lacks `save_schema_version`, has exactly `meta`, `economy`, `grid`, `zones`, `tenants`, `visitors`, `time`, `prestige`, `staff`, and `synergy`, and every value is a dictionary. Unknown or missing keys reject. `meta` has exactly integer `slot`, UTC `timestamp`, and string `version`; `timestamp` accepts a finite, nonnegative JSON number whose mathematical value is integral because the current Time API serializes a float-valued Unix second. The converter range-checks that value and converts it exactly to the V2 integer timestamp; fractional, negative, or non-finite values reject. The actual application version must appear in the approved legacy-version converter registry or classification rejects.

`grid` has exactly `plots`, a dictionary containing only `plot_0`. The plot record has exactly `plot_id`, `floors`, `boundary`, `pedestrian_boundary`, `pedestrian_margin`, and `spawn_points`: `plot_id="plot_0"`; `boundary={x:0,y:0,w:25,h:25}`; `pedestrian_boundary={x:-5,y:-5,w:35,h:35}`; and integer `pedestrian_margin=5`.

`floors` contains only keys from `G`, `F1` through `F9`, and `B1` through `B5`, and must contain `G`. Each floor record has exactly `width`, `height`, `tiles`, and `footprint`: integer width/height are both `25`; `footprint` is exactly 25 row-major arrays of 25 boolean `true` values; and `tiles` is exactly 25 x-major columns of 25 records. Each tile record has exactly boolean `owned`, boolean `floor_built`, boolean `walls_built`, string `zone_id`, integer `element` in `0..5`, integer `typology` in `0..2`, integer `condition` in `0..100`, and integer `door_sides` in `0..15` with no bits outside `NORTH=1|SOUTH=2|EAST=4|WEST=8`.

`spawn_points` is exactly four records, in serializer order, with exact keys `id`, `position`, and `direction`; each vector has exactly numeric finite `x,y,z`. Values are:

| ID | Position | Direction |
| --- | --- | --- |
| `plot_0_corner_nw` | `{x:-5,y:0,z:-5}` | `{x:1,y:0,z:1}` |
| `plot_0_corner_ne` | `{x:30,y:0,z:-5}` | `{x:-1,y:0,z:1}` |
| `plot_0_corner_se` | `{x:30,y:0,z:30}` | `{x:-1,y:0,z:-1}` |
| `plot_0_corner_sw` | `{x:-5,y:0,z:30}` | `{x:1,y:0,z:-1}` |

This geometry is validated only to classify the exact current serializer and is then discarded as authority.

### Exact V1 conversion

Floor labels map only as `G -> 0`, `F1..F9 -> +1..+9`, and `B1..B5 -> -1..-5`; no aliases exist. Source corners map only as `NW` (`plot_0_corner_nw`) `-> gateway_north`, `NE` (`plot_0_corner_ne`) `-> gateway_east`, `SE` (`plot_0_corner_se`) `-> gateway_south`, and `SW` (`plot_0_corner_sw`) `-> gateway_west`. Visitor `spawn_point_id` uses this mapping. Empty is accepted only when the visitor owner confirms that the record's state does not reference a source; an unknown nonempty value rejects.

District conversion targets `fixture.legacy_25_single`. `whole_plot` remains owned from the immutable fixture initial condition: legacy per-tile `owned` conflated section land with acquired floor space and cannot revoke atomic target section ownership. On every recognized floor, including `G`, each tile with `owned=true` maps to an `acquired_cells` cell and each tile with `floor_built=true` maps to a `constructed_cells` cell; constructed without owned rejects. Partial `G` ownership is therefore representable as partial elevation-0 floor-space acquisition while section rights remain separately derived. This is the explicit V1 compatibility interpretation. Tile fields other than district-owned `owned`/`floor_built` route through the `zone_parcel` or other named owner converter and are never silently discarded. Validated plot/floor geometry and spawn coordinates are discarded after conversion.

### Converter registry blocker

Cross-authority conversion is a closed registry keyed by exact V1 `meta.version`. A V1 application version is supported only when that version has a complete owner-approved converter entry for every exact authority key plus the omitted progression baseline. Each entry must enumerate every serialized V1-to-V2 field mapping and every target authority field absent from V1. For each absent target field, the entry must prescribe exactly one of: (a) the exact versioned legacy-deserializer baseline value, (b) a deterministic derivation from enumerated serialized fields, or (c) a rejection predicate. Generic current defaults, empty fallbacks, unspecified omission, and silent loss are forbidden.

The currently known lossy omissions include staff individual records because V1 serialized only counts; tenant revenue, rent, end-day, and viability fields; visitor needs, patience, goals, and spawn-time fields; and the entire progression authority. Exact owner-approved rules for each of these omissions, and for every other absent target field discovered by the complete field inventory, are mandatory before that exact application version becomes supported. Unsupported versions and versions with any missing, incomplete, or unapproved mapping/baseline/derivation/rejection rule reject before staging.

H9 implementation remains blocked until owners supply this complete versioned registry for the exact V1 authority keys `economy`, `grid`, `zones`, `tenants`, `visitors`, `time`, `prestige`, `staff`, and `synergy`, with each entry naming its exact V2 authority output, plus the omitted progression baseline. This is the already-declared migration-data blocker, not an implementation choice.

## Communication and event flow

`parse -> classify schema -> migrate detached -> resolve definition -> verify fingerprint -> migrate IDs/source mapping detached -> validate all authorities/cross-refs -> build staging projections -> atomic session commit -> game_loaded once`.

Metadata reads, parsing, migration, staging, and failures emit no `game_loaded`.

## Persistence impact

The offline V1-to-V2 converter may remain for the approved support window. It is not named Adapter and is unreachable from new-game/runtime gameplay paths. Save writes stage and validate the complete envelope, flush a temporary file, then atomically replace the slot; failure preserves the prior slot. MVP persists no pending arrival records. Future durable cohorts must define persistence before shipping.

## Editor/runtime behavior

Editor can validate detached data without events or live mutation. Runtime exposes no staging Nodes/services before commit.

## Migration and compatibility requirements

- Convert only the exact recognized V1 shape and registered application version to `fixture.legacy_25_single`, accepting only range-valid integral mathematical timestamp values.
- Apply only the exact floor/source maps above; mapping remains here, never in H6/H8 adapters.
- Every owner converter is registered by exact `meta.version`, owner-approved, deterministic, complete, cross-reference-reporting, and side-effect-free; it enumerates every serialized field mapping and assigns every V1-absent target field an exact versioned legacy-deserializer baseline, deterministic derivation, or rejection predicate. Unsupported or incomplete versions reject before staging and block implementation and acceptance.
- Support window remains release policy; the offline converter may remain accordingly.

## Expected affected files/systems

SaveManager, DTOs, migration registry/converter, session staging, all authority snapshot boundaries, projection rebuild orchestration.

## Acceptance criteria

Exact V1 classification and rejection; complete owner-approved exact-`meta.version` converter registry with exhaustive serialized and absent-target-field rules; exact fixture conversion including partial-G floor-space, floor/source, and district mappings; preservation of remaining tile fields through owner converters; exact-key V2 sparse round trip; unsupported or incomplete V1 rejection before staging; staged atomic save/load; all failures retain old session; one post-commit `game_loaded`; generated data absent; no pending-MVP blocker.

## Required tests

V2 exact root/meta/layout/authority key and type tests; H2 district-schema invariants; V1 absent-schema and exact root/meta/grid/plot/floor/tile/spawn shape tests; supported/unsupported application versions; missing/unknown keys; integral integer-valued and float-valued timestamps plus fractional, negative, non-finite, and out-of-range rejection; exact floor/source maps and alias rejection; empty visitor source state validation; acquired/constructed truth tables on every recognized floor including partial `G`; constructed-without-owned rejection; immutable `whole_plot` ownership; routing and preservation of every other tile field through owner converters; geometry discard; registry completeness/versioning/cross-reference reports; exhaustive serialized-field and absent-target-field inventory; exact versioned baseline, deterministic derivation, and rejection-predicate behavior; fingerprint ownership; fault injection at every staged load/save step; event order; safe atomic file replacement; round trip. For each supported `meta.version`, delete each registry mapping, absent-field rule, owner approval, and progression-baseline rule one at a time and assert rejection before staging; include separate deletion cases for staff individual records, each tenant revenue/rent/end-day/viability field, each visitor needs/patience/goals/spawn-time field, and progression.

## Performance/scalability checks

Report parse/migrate/validate/rebuild/commit separately; size follows mutable state; repeated cycles leak nothing.

## Failure and rollback behavior

Any precommit failure destroys staging and preserves live session/slot. V2 never silently downgrades.

## Technical risks

JSON number coercion, accidental live singleton mutation, incomplete owner conversion data, staging registration, and unsupported definition retirement.

## FACTS

- `game_loaded` means successful atomic commit only.
- H1 owns inclusion; H2 owns bytes/hash.
- H9 is not implementation-ready until the owner-versioned converter registry is complete.

## ASSUMPTIONS

- Authorities expose detached snapshot validation/import and supply approved legacy converter versions.

## OPEN QUESTIONS

- **MIGRATION-DATA BLOCKER:** complete owner-approved exact-`meta.version` mappings and absent-target-field rules, including the mandatory known lossy omissions and progression baseline, for each supported legacy application version.
- Save support/backup window and concrete performance budgets.
- Future durable cohort policy before those cohorts ship.

## GodotPrompter skills required by implementation agents

- `save-load`, `resource-pattern`, `dependency-injection`, `scene-organization`, `godot-testing`.
