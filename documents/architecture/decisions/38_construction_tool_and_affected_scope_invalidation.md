# ADR 38: Construction Tool and Affected-Scope District Invalidation

**Status:** Accepted — 2026-09-11; amended 2026-09-12 by explicit user approval

## Context

Product P03 requires build and zone actions through non-debug controls. Construction H1 already provides authoritative preview/confirm behavior, but production presentation exposed only zone and door tools. Because production District state is sparse, zone painting correctly remains unavailable until the player separately acquires floor space and constructs it.

Exposing `ACQUIRE_SPACE` also revealed that every `district_delta_committed` subscriber rebuilt from the global District revision. A single acquired cell consequently caused repeated full H4/H5 projection replacement plus unrelated H6/H7 and wall work while the shared mutation gate remained held. This violates the approved affected-scope invalidation requirement and can prevent synchronous commit fan-out from completing in bounded time.

## Decision

### Normal-play construction presentation

- Add one scene-owned `ConstructionTool`; do not extend `ZoneTool` or add a gameplay authority.
- The Build toolbar exposes `Acquire Ground Space` and `Build Corridor` before the existing zone and door controls.
- This increment targets a canonical rectangle of explicit cells on the production initial Plot at G only.
- Ground-space acquisition and corridor construction are separate preview/confirm transactions. A drag produces one atomic operation; there is no automatic compound commit.
- Both actions route through the existing single `UIIntentGateway` to a narrow `ConstructionIntentGateway` owner adapter. District Runtime remains the sole writer and Economy remains the price/balance owner.
- Owning the initial Plot section does not densely populate `acquired_cells` or `constructed_cells`. `ACQUIRE_SPACE` adds sparse acquired membership at the source-backed G price; corridor construction then adds constructed and explicit-circulation membership through Construction H1's zero-Kred policy path.
- `ConstructionTool`, `ZoneTool`, and `DoorTool` are mutually exclusive. The tool owns only picking, transient rectangle selection, preview rendering, confirm/cancel interaction, and immediate diagnostics.
- A rectangle is canonicalized, deduplicated, and validated as a complete set. One invalid, stale, occupied, zoned, or unaffordable cell rejects the complete operation without partial mutation.
- After a successful commit, the tool retains a non-confirmable green marker over the committed rectangle until the next selection, mode change, or deactivation. This is transient confirmation, not persistent authority or an H4 acquired-cell projection.
- Acquisition quotes the existing source-backed G price per cell, summed into one atomic settlement. Corridor construction remains zero Kreds per cell.
- While god mode is enabled, a presentation/debug overlay may show one low-opacity status label at the geometric center of each connected committed status component. It reads detached committed District state, shows only `unacquired` or `acquired`, is not saved, and is removed when god mode is disabled or its source is stale.

### Affected-scope invalidation

Committed fan-out remains synchronous and the session mutation gate remains held until protected publication completes. The fix removes irrelevant subscriber work; it does not defer publication or release the gate early.

| Consumer | Invalidating District operations |
| --- | --- |
| Base `ProjectionCoordinator` root | Initial build and explicit session restore/replacement only; no current state-only delta directly rebuilds the base root. |
| H5 public-realm geometry | `ACQUIRE_SECTION`, `CONVERT_STREET`. |
| H5 traversal graph without geometry replacement | `CONSTRUCT`, `DEMOLISH_CONSTRUCTION`, `DEMOLISH_FIXED_OCCUPANT`, `PAINT_ZONE`, `SET_MANUAL_DOOR`. |
| H6 camera/gateway projection | `ACQUIRE_SECTION`, `SET_SOURCE_ENABLED`, `CONVERT_STREET`, and the listed topology operations only after H5 publishes a matching current graph. |
| H7 traffic topology | `ACQUIRE_SECTION`, `CONVERT_STREET`. |
| Ground-floor `WallManager` | `CONSTRUCT`, `DEMOLISH_CONSTRUCTION`, `DEMOLISH_FIXED_OCCUPANT`, `PAINT_ZONE`, `SET_MANUAL_DOOR`. |

`ACQUIRE_SPACE` invalidates none of those consumers. It changes sparse rights and Economy only, regardless of rectangle size. H5 topology refresh reuses committed public-realm geometry, derives the graph from the new committed traversal view, and publishes a graph delta without calling H4 materialization or replacing the projection root.

Zone participation is an explicit no-op for `ACQUIRE_SPACE` and one-cell corridor construction. Acquisition cannot overlap Zone state, and a legal new corridor targets acquired, unconstructed space that cannot already belong to a Zone. Other construction kinds retain coordinated Zone preparation where their prospective geometry can conflict with Zone facts.

## Consequences

- The player can establish the legal `Acquire -> Construct corridor -> Paint zone` chain without seeded cells or debug mutation, using atomic rectangles for the first two steps.
- One-cell acquisition no longer amplifies into unrelated projection, traffic, camera, or wall rebuilds.
- Corridor commits update traversal and ground-floor walls while preserving the H4 root and traffic graph.
- Persistent production visualization remains a later H4 presentation concern; the god-mode status overlay is debug-only bounded P03 feedback and is not persisted.
- Future District operations must declare affected scopes and extend the filter matrix rather than relying on global revision changes alone.

## Required evidence

- Preview is non-mutating and exposes the source-backed per-cell G quote summed for the rectangle; confirm revalidates using a new request ID and the captured preview revision.
- Acquisition changes all acquired membership and balance once, leaves constructed/circulation membership unchanged, performs no listed rebuild, and returns with the gate released.
- Corridor construction requires acquisition for every cell, uses the zero-Kred policy path, adds constructed/explicit-circulation membership for every cell, refreshes H5 traversal and walls only, and returns with the gate released.
- Any invalid cell rejects the entire rectangle with no District, Economy, Zone, revision, journal, or projection mutation.
- God-mode overlay visibility, component count, status labels, centering, opacity, and non-persistence are covered.
- Tool mutual exclusion, diagnostics, duplicate-confirm prevention, and the retained non-confirmable success marker are covered.
- An operation-filter regression test locks the matrix above.

## Non-goals

Multi-cell Zone painting, non-G floors, Plot-section purchase UI, demolition controls, stairs, elevators, Operations Room placement, production acquired-cell overlays, asynchronous commit fan-out, and H4 partial-root architecture are unchanged or deferred.
