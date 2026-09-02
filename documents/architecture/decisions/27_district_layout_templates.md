# Decision 27: District Layout Templates and Runtime State

**Date:** 2026-08-30
**Status:** Accepted

## Context

The current runtime assumes one 25x25 plot and represents ownership, construction, and occupancy through closely coupled tile data. The approved game direction requires multiple rectangular plots, permanent streets, section-by-section horizontal and vertical acquisition, fixed structures, and data-driven layouts that can be previewed and saved safely. Shared authored definitions must not become mutable save state.

## Decision

District geometry is resolved from immutable, versioned definitions into authoritative runtime state. Generated scenes, meshes, road graphs, intersections, and UI are projections of that state and are not authorities.

The provisional authoring format is a hybrid of `.tres` metadata and token-grid cell layers. This choice must be validated with a representative proof layout before the final authoring format is fixed.

### Immutable definitions

| Definition | Required content |
|---|---|
| `DistrictLayoutDefinition` | Stable layout ID and version, row depths, column widths, pedestrian-band width, uniform road profile, permanent outer ring, and block slots. |
| `BlockSlotDefinition` | Stable slot ID, role, `PlotTemplateDefinition` reference, and constrained per-slot overrides. |
| `PlotTemplateDefinition` | Stable template ID/version, dimensions, section masks, entry-eligible sections, physical floor limits, per-floor overrides, fixed structures, and reserved future role capabilities. |

Definitions express capabilities and initial conditions. Runtime systems never mutate shared Resources.

### Runtime state

Mutable state is stored separately with stable IDs:

- `DistrictState`
- `PlotState`
- `PlotSectionState`
- `FloorState`
- `StreetSegmentState`
- derived `IntersectionState`
- `ArrivalSourceState`

`IntersectionState` is derived because intersection ownership follows incident segment state. `ArrivalSourceState` is included here as district state but its behavior is governed by Decision 28.

### District geometry

- Districts are rectilinear.
- Block slots are rectangular and use shared row depths and column widths.
- Every district has a complete, permanent outer road ring.
- The pedestrian-band width is authored in the inclusive range 5-10 tiles.
- A district uses one uniform road profile.
- Each traffic lane is 3 tiles wide.
- A road has at least 2 lanes total and at least 1 lane in each direction.
- Lanes moving in the same direction are contiguous.
- A **Street Corridor** is generated road space between blocks.
- A **Street Segment** is the portion of a corridor bounded by intersections and is the unit of street acquisition.
- The traffic road graph is generated from resolved topology. There are no bus-only lanes.

### Plot sections and acquisition

- A Plot Section is an arbitrary, non-overlapping, 4-neighbor-contiguous mask with a stable ID.
- Horizontal acquisition is atomic per section.
- Entry eligibility applies to Plot activation: an orthogonally adjacent Plot is activated through one of its designated first sections. Exact economic and progression gates remain policy inputs.
- An **Active Plot** owns at least one section.
- A **Fully Owned Plot** owns every acquirable section.
- Vertical rights on each elevation are the union of owned section masks.
- Individual spaces are acquired sequentially rather than in bulk.
- Elevation IDs are signed integers: ground `0`, above ground `+1` through `+9`, and underground `-1` through `-5`.
- Default physical caps are 10 levels including ground and 5 underground levels. Template, slot, and progression limits may be stricter.
- A 2-tile overhang is permitted only when it remains within the player's vertical-rights mask.

### State distinctions

The model keeps these concepts independent:

- ownership;
- availability;
- fixed occupancy;
- buildability;
- acquired space; and
- constructed state.

Fixed structures can occupy multiple floors. Acquisition does not remove them; they remain until an authorized demolition transaction succeeds.

### Street acquisition

- An internal Street Segment is eligible only when the player owns at least 50% of the adjacent frontage, evaluated independently on each side.
- Conversion includes both Pedestrian Bands and the carriageway.
- Preview must disclose removal of road edges and attached curbside facilities; mutation occurs only after confirmation.
- Connectivity does not veto an otherwise eligible conversion.
- An intersection becomes owned only when all incident internal Street Segments are converted.
- The outer road ring, including its Street Segments and intersections, is immutable and cannot be acquired or converted.
- Public Pedestrian Bands remain city-owned. The player receives player-funded facility-placement rights where a band is adjacent to owned frontage; this does not transfer land ownership.

### Resolution and dependencies

The dependency direction is:

```text
immutable definitions
  -> layout resolver
  -> authoritative district runtime state
  -> spatial consumers
  -> scene and UI projections
```

All boundaries exchange stable IDs and value data, never scene-node references. The same resolver contract is used by editor preview and runtime. The game scene remains the composition root, and an editor preview scene does not need to be empty.

The camera movement envelope is derived from the union of Active Plot rectangles plus a configurable margin.

### Service boundaries

Keep the initial authority boundaries small:

- Layout Resolver and District State may initially be one `District Runtime` service.
- Acquisition and Floor Construction may initially be modules of one `Construction/Acquisition` authority.
- Split either boundary only when state ownership, testing, or lifecycle complexity warrants it.
- Economy and progression remain separate authoritative services. Transactions query them for affordability and eligibility; district/construction state does not duplicate their balances or unlock state.

## Persistence

A save records the layout ID, definition version or fingerprint, stable runtime IDs, and mutable district state. Generated geometry, intersections, road graphs, and other topology projections are derived and are not saved.

V2 save loading validates layout identity and definition compatibility before commit. A payload lacking `save_schema_version`, including current V1 saves, is unsupported and rejects safely without partially mutating runtime state or changing the save slot. Future V2 migrations require explicit approval and release.

## Consequences

- Decision 6 remains valid for floor scene composition but not as the floor-state authority.
- Decision 7's `GridManager`/tile arrays are no longer the complete district authority.
- Decision 8's `PlotData` model and single 25x25 default are superseded as the target district architecture.
- Decision 9's character mask is superseded as a complete format because it conflates ownership and occupancy; it may remain as a parser for simple boolean cell layers.
- Decision 15 is amended with layout compatibility, future-V2 migration, and derived-data rules.
- The existing 25x25 runtime is a non-conforming legacy implementation that requires a later migration. This decision does not define that implementation plan.

## Open Questions

- Exact prices, affordability rules, progression gates, and unlock timing.
- Final authoring format after the proof layout validates or rejects the provisional hybrid.
- Exact facility types and placement policy for public Pedestrian Bands.
- Definition fingerprint algorithm and policy for removed stable IDs. Future V2 migration rules require explicit approval and release.
