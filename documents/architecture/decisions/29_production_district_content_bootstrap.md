# Decision 29: Production District Content and Session Bootstrap

**Date:** 2026-09-05  
**Status:** Accepted — resolves the H10 production-source blocker.

## Context

Decision 27 makes immutable definitions the source of district capability and initial conditions, while H1 defines three proof fixtures only. H10 now requires proof fixtures and legacy `GridManager` support to be Archive-Policy-B test-pack content, zero production `GridManager` reachability, and no fallback layout selection. The old `main_game` boot path violates all three by directly selecting `fixture.legacy_25_single` and hosting `GridManager`.

A production game still requires an explicit layout source for a new session. Treating a fixture as that source would make test data a production gameplay dependency; removing it without replacement would leave boot undefined.

## Decision

Production new-game sessions load a **production-owned immutable district definition** through a production layout catalog and explicit bootstrap configuration. They never load a proof fixture, fixture factory, legacy grid, or inferred default.

### Production content contract

| Concern | Decision |
| --- | --- |
| Production layout identity | The initial release layout is `district.initial`; it is not a `fixture.*` identity. |
| Definition content | `district.initial` is a fully validated H1 `DistrictLayoutDefinition` and uses H1/H2 semantics, validation, resolver, version, and fingerprint contracts. It preserves the approved initial single 25x25, initially-owned Plot only as authored initial content; it is not the legacy runtime or Fixture A. It includes the required permanent outer ring and generated topology. |
| Content owner | Content authors own the definition resource(s), including initial facts. The definition pipeline validates and publishes immutable values; it never creates mutable session state. |
| Catalog | A production layout catalog contains the explicit allow-list of shippable layout IDs and their definition resources. `district.initial` must be present. The catalog is immutable content, not an autoload and not save state. |
| Bootstrap configuration | A composition-owned immutable bootstrap configuration explicitly names `district.initial` for **new game only**. It is injected into the session bootstrap/District Runtime gateway; no system supplies an implicit layout ID. |
| Saved game | H9 load uses the V2 `layout_ref` (ID, version, fingerprint) against the production catalog. The new-game bootstrap configuration is not consulted during V2 load. |
| Missing/incompatible content | Missing catalog/configuration, unknown ID, failed validation/resolution, or V2 mismatch returns a structured bootstrap/load failure before state, projections, or UI gameplay activation. It must not select a fixture, `plot_0`, first catalog entry, or any other fallback. |

`district.initial` is a technical content identity, not a new gameplay layout, price, unlock, or expansion rule. Future production districts extend the catalog with distinct stable IDs and explicit user/session-selection policy; they do not alter the new-game default by inference.

## Runtime boundaries and data flow

```text
Production layout catalog + new-game bootstrap configuration
  -> validate selected DistrictLayoutDefinition
  -> H2 resolver
  -> session-scoped District Runtime creates DistrictState
  -> committed immutable views/deltas
  -> H4/H5/H6/H7/H8 projections and presentation
```

`main_game.tscn` remains the composition root but contains no `GridManager`, fixture factory, fixture resource, or authored district authority. Its bootstrap role is limited to wiring the production catalog/configuration to the session owner and hosting disposable presentation roots.

Consumers use the target contracts already owned by H3-H8:

| Consumer family | Production dependency after migration |
| --- | --- |
| Zone/parcel, wall, door, labels, heatmap | Explicit H3 floor/address read views and committed deltas; H4 projection handles/manifests for presentation. |
| Visitor, staff, synergy | District Runtime stable IDs/read views and their own authorities; arrival locations derive from H5/H6/H8 topology contracts. |
| Camera | H6 derived camera envelope and selected/Active Plot views. |
| Traffic | H7 generated `RoadGraphSnapshot` and stable anchors. |
| SaveManager | H9 detached V2 authority snapshots and production catalog compatibility lookup. |

No consumer may retain a `GridManager`, `PlotData`, `FloorGrid`, `GridTile`, fixture identity, scene-node identity, default plot/floor parameter, or authored coordinate as a production authority boundary. Existing zone/parcel behavior is preserved by adapting consumers to these explicit views, not by retaining a compatibility authority.

## Archive Policy B boundary

The following are test-pack-only content: all `fixture.*` definitions and fixture factories, proof goldens, legacy `GridManager`, legacy grid/floor data types where a named regression harness still needs them, and test runners/scenes. They may exist in the repository source tree but must be excluded from the production export and have zero production manifest, registration, dependency, preload/load, autoload, and scene reachability.

H10 acceptance still runs all three fixtures, but it runs them from the separate test pack. They prove contracts; they are not production boot content. The production package is exercised separately by booting `district.initial` and performing the production smoke/save/load evidence specified by H10.

## Migration requirements

1. Author, validate, fingerprint, and register `district.initial` before removing the legacy production bootstrap.
2. Replace `main_game` fixture selection with the explicit new-game bootstrap configuration; remove `World/GridManager` from the production scene.
3. Migrate every listed consumer to its owning H3-H8 contract. A consumer without a target contract is a migration failure, not justification for a new default or adapter.
4. Relocate/archive fixture factories and legacy grid support into the test-pack boundary; update test-only imports and runners.
5. Build the production export and test pack independently. Record the manifest/reachability proof required by the H10 release evidence contract.
6. Add production bootstrap failure tests, `district.initial` resolver/session/save-load smoke tests, and negative tests proving no fixture/legacy fallback on missing or unknown configuration.

## Persistence

A new game persists the resolved `district.initial` layout reference through the normal V2 save envelope. Production catalog content is immutable and is not serialized into saves. Generated topology/projections and bootstrap configuration are not saved.

## Consequences and tradeoffs

This is the smallest architecture that preserves Decision 27: one catalog and one explicit new-game selection are sufficient. It avoids a separate content service/autoload, runtime fixture conversion, or a generalized campaign-selection system before design requires one. The cost is one required authored production definition plus export-boundary tooling; that cost is necessary because a test fixture cannot be both excluded from production and used as production content.

## Testing and release evidence

- Validate that `district.initial` is H1/H2-valid, has a reviewed fingerprint, resolves identically in editor/runtime, creates a session without `GridManager`, and supports H9 V2 round trip.
- Verify failure on absent/unknown/mismatched bootstrap/catalog content with no state, projection, save-slot, or fixture fallback.
- Verify every target consumer boot path is free of `GridManager` and omitted identity calls.
- Run Fixture A/B/C only through the test pack; prove neither their IDs nor legacy support appears in the production export manifest or dependency graph.

## FACTS

- The existing production boot path selects `fixture.legacy_25_single` and hosts `GridManager`; it is non-conforming.
- H1 fixtures are proof artifacts, and H1 explicitly excludes production gameplay layouts from its scope.
- The approved design calls for an initially owned 25x25 Plot and requires a permanent outer ring.

## ASSUMPTIONS

- `district.initial` can be authored with the already frozen H1/H2 schema without changing approved gameplay semantics.

## OPEN QUESTIONS

- The authoring location/format details and exact reviewed fingerprint for `district.initial`; content implementation supplies these under H1 validation.
- Future player-facing layout selection. Until designed, new games always use explicit `district.initial`.
