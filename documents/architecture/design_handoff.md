# District Layout and Visitor Arrival Architecture Blueprint

**Status:** Architecture approved
**Date:** 2026-08-30
**Authorities:** [Decision 27](decisions/27_district_layout_templates.md), [Decision 28](decisions/28_visitor_arrival_architecture.md)

## Purpose

This document is the central architecture handoff for data-driven district layouts, plot and vertical acquisition, street conversion, and visitor arrivals. It describes boundaries and contracts, not an implementation plan. Existing approved zone and parcel handoffs remain authoritative inside acquired, constructed floor space unless explicitly amended by Decisions 27 or 28.

## Architectural Invariants

- Immutable definitions describe layout capability and initial conditions; saves describe mutable state.
- Runtime code never mutates shared Resource definitions.
- Stable IDs, versions, fingerprints, and value snapshots cross boundaries; Node references do not.
- The same deterministic layout resolver serves editor preview and runtime.
- Authoritative runtime state precedes spatial generation; scenes and UI are projections.
- Preview and commit consume the same rules and differ only in whether validated state is committed.
- Economy and progression remain separate authoritative services queried by transactions.
- Generated geometry and topology are reproducible derived data and are not persisted.
- The permanent outer road ring is immutable.
- The existing 25x25 runtime is acknowledged as non-conforming legacy behavior requiring later migration.

## Domain Model

### Immutable definition layer

| Type | Identity | Content |
|---|---|---|
| `DistrictLayoutDefinition` | Stable layout ID + version | Shared row depths/column widths, pedestrian width 5-10, uniform road profile, complete outer ring, block slots. |
| `BlockSlotDefinition` | Stable slot ID within layout | Role, plot-template reference, constrained overrides. |
| `PlotTemplateDefinition` | Stable template ID + version | Dimensions, sections, designated first sections for orthogonally adjacent Plot activation, physical floor limits/overrides, fixed structures, future role capabilities. |

The provisional format combines `.tres` metadata with token-grid cell layers. A representative proof layout must test authoring clarity, validation, diffs, rotations/overrides, multi-floor fixed structures, and deterministic resolution before the format is finalized.

### Mutable runtime layer

| State | Owns |
|---|---|
| `DistrictState` | Layout identity, district-level mutation revision, plot/segment/source state collections. |
| `PlotState` | Slot/template identity and aggregate active/fully-owned status derived from sections. |
| `PlotSectionState` | Stable section identity, ownership, availability, and acquisition facts. |
| `FloorState` | Signed elevation identity, acquired space, construction, fixed occupancy, and floor-local mutable facts. |
| `StreetSegmentState` | Segment conversion/acquisition state and affected facility references. |
| `IntersectionState` | Derived ownership from all incident internal segments. |
| `ArrivalSourceState` | Enabled state, capacity/allocation state, and pending state subject to the unresolved persistence policy. |

Definitions are referenced, not copied into mutable state except where a compatibility snapshot/fingerprint is required. Aggregate flags such as Active Plot, Fully Owned, intersection ownership, and camera bounds should be derived rather than independently writable.

### Cell-state vocabulary

Every query and transaction must distinguish:

| Concept | Meaning |
|---|---|
| Ownership | Legal rights held by the player. |
| Availability | Whether policy currently permits acquisition or use. |
| Fixed occupancy | Authored or scenario structure occupying space independently of ownership. |
| Buildability | Whether construction rules permit a proposed use. |
| Acquired space | A purchased horizontal/vertical space right. |
| Constructed state | Whether player construction physically exists. |

No single character or boolean may stand for several of these concepts.

## Spatial Rules

### Rectilinear district

- Block slots are rectangular.
- Rows share authored depths; columns share authored widths.
- Every layout has a complete permanent outer road ring.
- One road profile applies throughout the district.
- Each lane is 3 tiles wide, with at least 2 total lanes and at least 1 lane per direction.
- Same-direction lanes are contiguous.
- Public Pedestrian Bands are 5-10 tiles wide as defined by the layout.
- A Street Corridor is the generated road band between blocks.
- Intersections divide corridors into stable Street Segments.
- The road graph is generated from resolved topology and supports ordinary road users; no bus-only lane type exists.

### Plot sections and vertical rights

- Sections are arbitrary 4-neighbor-contiguous masks with stable IDs and no overlap.
- Acquisition commits an entire section atomically.
- Entry eligibility applies to Plot activation: an orthogonally adjacent Plot is activated through one of its designated first sections.
- A plot is Active when any section is owned and Fully Owned when every acquirable section is owned.
- Vertical rights at an elevation equal the union of owned section masks.
- Individual spaces are acquired sequentially.
- Elevation is a signed integer: `0`, `+1` to `+9`, and `-1` to `-5`.
- Default caps are 10 levels including ground and 5 underground; template, slot, or progression policy may be stricter.
- A 2-tile overhang is allowed only within vertical rights.
- Fixed structures may span elevations and survive acquisition until a distinct authorized demolition.

### Street and public-realm rights

- Internal Street Segment eligibility requires at least 50% owned frontage on each side, evaluated separately.
- Conversion includes both Pedestrian Bands and carriageway.
- Conversion removes road-graph edges and attached curbside facilities only after preview and confirmation.
- Connectivity is disclosed but does not veto conversion.
- An intersection is owned only after every incident internal segment is converted.
- Outer-ring segments and intersections remain immutable.
- Pedestrian Bands remain city-owned. Adjacent owned frontage grants player-funded facility-placement rights, not ownership.

### Camera envelope

The pan/focus envelope is the union of Active Plot rectangles plus a configurable margin. It is recomputed from committed state and does not use purchased-tile radial distance as the target rule.

## System Boundaries

### Dependency direction

```text
definitions
  -> resolver
  -> authoritative runtime state
  -> spatial consumers
  -> projection and UI
```

Reverse writes are prohibited. UI submits intents and renders results. Spatial consumers derive geometry, path graphs, camera bounds, and source positions from committed state.

### Initial service shape

The simplest viable boundaries are preferred:

| Boundary | Initial shape | Split trigger |
|---|---|---|
| Layout resolution + district state | One District Runtime service is acceptable. | Resolver lifecycle, caching, editor tooling, or state ownership becomes independently complex. |
| Acquisition + floor construction | Modules of one Construction/Acquisition authority are acceptable. | Transaction rules, permissions, rollback, or construction lifecycle require separate authorities. |
| Economy | Separate authoritative service. | Remains separate; queried for affordability and charged only by committed transactions. |
| Progression | Separate authoritative service. | Remains separate; queried for eligibility and limits. |

These are logical ownership boundaries, not a requirement for one Node or file per row.

### Transaction communication

Acquisition and conversion follow one conceptual contract:

1. Accept an intent containing stable target IDs.
2. Resolve current definition and runtime snapshots.
3. Query progression for eligibility and limits.
4. Query economy for affordability without duplicating balance state.
5. Produce a preview containing costs, state changes, removals, and diagnostics.
6. On confirmation, defensively validate the same rules and atomically commit authoritative state and payment.
7. Publish committed facts for spatial and UI projections.

Exact gates, prices, rollback protocol, and transaction API shape remain open. The required outcome is no partial district mutation or charge.

## Visitor Architecture

### Demand, allocation, realization

Visitor flow has three separate stages:

| Stage | Responsibility |
|---|---|
| Demand | Decide desired visitor count/profile without choosing transport or coordinates. |
| Arrival allocation | Select eligible source IDs and reserve source capacity. |
| Realization | Create visitor data/presentation at positions derived from resolved topology. |

Pedestrian is the MVP arrival mode. The common source contract reserves pedestrian, bus, parking, taxi, and metro modes. New modes extend source policy rather than own demand.

### Arrival source contract

A source is addressed by stable ID and exposes mode, topology anchors, enabled/eligibility state, capacity/allocation limits, realization policy, and presentation metadata. `ArrivalSourceState` owns mutable source facts; coordinates and route attachment are derived.

### Traffic and presentation

- Traffic road graphs are generated from district topology.
- Ambient cars are presentation-focused and do not establish authoritative off-district simulation.
- Buses are arrival events with pending cohorts, not continuously simulated distant agents.
- Bus events reserve a source, present arrival, and realize cohort members.
- Bus stops are capped at `ceil(number of Active Plots / 3)`.
- Buses use ordinary road lanes; no bus-only lane exists.
- Decision 3 remains authoritative for visible visitor Nodes, centralized behavioral ticks, and culling after realization.

## Major Feature Analysis

### District definition and resolution

**Requirement:** Author multiple deterministic districts without embedding mutable gameplay state in templates.

**Systems:** Definition registry, resolver, validation, District Runtime, preview projection.

**Ownership:** Definitions own authored facts; District Runtime owns the resolved definition reference and mutable state; projections own no gameplay truth.

**Communication:** Stable IDs and immutable resolver output. Editor and runtime call the same resolver contract.

**Persistence:** Save layout ID/version/fingerprint and mutable state only.

**Scalability:** Shared row/column dimensions avoid arbitrary road seams; stable IDs permit sparse state and targeted regeneration.

**Testing:** Golden proof-layout resolution, malformed definition rejection, deterministic fingerprints, slot override constraints, editor/runtime parity.

**Risks:** Hybrid format may be cumbersome; Resource mutation could leak between sessions; definition edits can invalidate saves.

### Section and vertical acquisition

**Requirement:** Buy contiguous plot sections and then individual above/underground spaces within owned rights.

**Systems:** Construction/Acquisition authority, District Runtime, economy, progression, spatial validation.

**Ownership:** Section and floor state are authoritative; economy owns funds; progression owns gates/caps.

**Communication:** Stable-ID transaction intents, read-only policy queries, previews, atomic commit results.

**Persistence:** Section ownership, acquired elevations/spaces, constructed state, fixed-structure demolition state, stable IDs.

**Scalability:** Sparse floor state avoids allocating every possible cell/elevation; rights derive from section masks.

**Testing:** Contiguity/non-overlap validation, orthogonally adjacent Plot activation through a designated first section, sequential acquisition, signed elevation boundaries, stricter cap precedence, overhang containment, fixed-structure survival.

**Risks:** Conflating ownership and construction causes destructive bugs; simultaneous economy/state commit may partially fail; per-floor overrides may become ambiguous.

### Street conversion and public realm

**Requirement:** Acquire eligible internal streets while keeping the outer ring and city-owned pedestrian realm rules intact.

**Systems:** Construction/Acquisition authority, frontage evaluator, District Runtime, traffic topology, facility projection, confirmation UI.

**Ownership:** Segment state is authoritative; intersection ownership is derived; public bands remain city-owned; facility placement rights are conditional capability.

**Communication:** Preview reports each side's frontage ratio, removed graph edges, and attached facilities before confirmation.

**Persistence:** Converted internal segment state and mutable facility state; intersections and road graph are derived.

**Scalability:** Segment-level mutation bounds graph regeneration and avoids cell-by-cell street ownership.

**Testing:** Exactly-below/at/above 50% per side, immutable outer ring, both bands plus carriageway conversion, no connectivity veto, all-incident intersection rule, facility cleanup.

**Risks:** Frontage measurement ambiguity at corners; topology regeneration can leave stale route references; users may not understand non-vetoed disconnection without clear preview.

### Visitor arrivals

**Requirement:** Support pedestrian arrivals now and transport modes later without coupling demand to map geometry or off-district simulation.

**Systems:** Demand authority, arrival authority, District Runtime, traffic topology, visitor authority, presentation.

**Ownership:** Demand owns desired arrivals; arrival state owns allocation/pending cohorts; visitor authority owns realized visitors; presentation owns transient visuals only.

**Communication:** Stable source IDs, capacity reservations, committed arrival events, and resolved topology snapshots.

**Persistence:** Source mutable state; pending arrival policy is open; geometry/routes are derived.

**Scalability:** Allocation can aggregate cohorts and realize only visible agents; modes share one source contract.

**Testing:** Demand independent of source count, deterministic eligible allocation, unavailable/full source behavior, topology changes, pedestrian realization, bus-stop cap across Active Plot counts, no authoritative ambient-car state.

**Risks:** Undefined pending-save behavior can duplicate/drop visitors; source invalidation during topology mutation; visual events can be mistaken for simulation truth.

### Save/load and compatibility

**Requirement:** Restore mutable district and arrival state against the correct immutable layout without serializing generated geometry.

**Systems:** SaveManager, definition registry, migration registry, District Runtime, projection rebuild.

**Ownership:** SaveManager orchestrates; each authority serializes its mutable state; definition registry establishes compatibility.

**Communication:** Versioned payloads keyed by stable IDs; load validates and migrates before commit.

**Persistence:** Layout ID, definition version/fingerprint, runtime mutable state, and stable IDs. Generated geometry/topology is excluded.

**Scalability:** Sparse mutable data scales with acquisitions rather than total theoretical district volume.

**Testing:** Round trips, migrations, unknown IDs, changed fingerprints, safe incompatible-layout rejection, no partial load, deterministic projection rebuild.

**Risks:** Definition drift, retired IDs, migration gaps, and unresolved pending-arrival semantics.

## Verification Strategy

Architecture acceptance should be demonstrated with deterministic domain tests and a proof layout, not by treating the legacy 25x25 scene as conforming evidence.

- Definition validation covers dimensions, road profile, outer ring, section masks, stable-ID uniqueness, floor limits, and fixed structures.
- Resolver tests prove identical input produces identical topology, source anchors, segments, and fingerprints in editor and runtime contexts.
- State tests prove shared Resources remain unchanged across multiple district sessions.
- Transaction tests prove preview/commit parity and atomic economy/progression/state behavior.
- Projection tests prove geometry and graphs can be discarded and rebuilt from definitions plus runtime state.
- Save tests prove migration and safe rejection occur before live-state mutation.
- Arrival tests separate demand counts from source selection and realization.
- Scale tests use many slots, sparse floors, and repeated topology changes to detect accidental full-volume state or stale references.

## FACTS

- The current runtime uses a single 25x25 plot and is non-conforming with this target architecture.
- Existing zone/parcel handoffs already use stable plot/floor IDs and preview-before-commit patterns that can remain inside acquired floor space.
- Economy is an authoritative balance owner under Decision 13.
- Progression currently exposes unlock checks under Decision 19.
- The game scene remains the composition root under Decision 1.
- Decision 3's visible visitor representation remains accepted.

## ASSUMPTIONS

- One tile unit is shared by plots, roads, pedestrian bands, section masks, and floor rights.
- Rectilinear layouts and rectangular slots are sufficient for the approved district set.
- Stable IDs are authored or deterministically derived and remain stable across compatible definition revisions.
- Fixed structures can be represented as immutable definitions plus mutable demolition/state records.
- Connectivity loss from street conversion is intentional gameplay and can be adequately communicated by preview.
- The common arrival-source contract can accommodate future modes without changing demand ownership.

## OPEN QUESTIONS

- Exact acquisition prices, progression gates, prerequisites, refunds, and failure messaging.
- Final definition/cell-layer authoring format after proof-layout validation.
- Definition fingerprint algorithm, migration support window, and policy for removed stable IDs.
- Pending arrival/cohort save policy: persist, cancel/refund, replay, or re-allocate.
- Arrival weighting, source capacities, schedules, retries, and non-pedestrian operating costs.
- Exact public Pedestrian Band facility catalog, costs, conflicts, and removal/refund rules.
- Frontage measurement treatment at corner-only contact and unusual fixed-structure edges.
- Whether initial combined services need separation after the proof layout and transaction model are validated.
