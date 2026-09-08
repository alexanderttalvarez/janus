# Handoff 05: Automatic Parcel Doors

## Status

Approved — 2026-08-24

**Revision:** 2026-09-08 delegated consistency pass. [Element 12](../../../game_design/elements/12_wall_system.md), element 19, ADRs 30/31/33 and Current MVP apply. Topology-backed active Pedestrian Band edges are legal real access under the district amendment; virtual/implicit/unzoned/inter-zone automatic access remains prohibited. Manual door records are District-owned through ADRs 30/31, not a restored legacy grid authority.

## Goal

Every committed parcel receives deterministic physical doors to its eligible internal Transit or external CIRCULATION frontage. The generated wall geometry leaves a matching gap at each selected edge.

## Door allocation

- A physical eligible position is a distinct parcel Tenant tile with at least one directed frontage edge to either:
  - same-zone internal Transit; or
  - owned, built, external `TileElement.CIRCULATION`.
- Frontage to a different committed zone is never automatic parcel-door access.
- Exclude virtual exterior and implicit-unzoned circulation from physical door allocation.
- The required door count is `ceil(physical_eligible_position_count / 10.0)`.
- Select at most one edge per eligible parcel tile position.
- Preserve all still-legal prior selected edges first, capped to the required count. Existing legal selections are never displaced by the preference policy.
- Fill remaining door slots deterministically using this slot-aware preference:
  - first unfilled slot: prefer internal Transit, with external circulation as fallback;
  - second unfilled slot: prefer external circulation; if unavailable, prefer a different connected internal Transit area;
  - later slots: prefer an as-yet-uncovered connected internal Transit area, then remaining external circulation, then canonical fallback candidates.
- When a one-door parcel has an **unfilled** slot, prefer internal Transit and use external circulation as fallback. A still-legal previously selected external door is retained even if internal Transit later appears; preference never displaces preservation.
- “Different Transit area” means a distinct connected component of same-zone Transit tiles, identified by a stable key derived from that component’s minimum tile coordinate.
- Sort ties canonically by parcel tile `y`, parcel tile `x`, then edge direction.
- Persist selected edges in `Parcel.selected_door_edges` and restore them through parcel serialization. Transit-area keys are derived candidate metadata and are not separately serialized.
- A parcel without a physical eligible position rejects atomically with `NO_PHYSICAL_DOOR_FRONTAGE`.

## Existing-door preservation invariant

- A committed zone transaction must not invalidate a retained parcel's existing automatic door or an affected manual door. Explicit authorized parcel retirement is the exception for that parcel's own automatic doors: remove them atomically with parcel/tenant retirement, with no replacement-door requirement for a nonexistent parcel. Manual doors remain separately protected except H6's explicit obsolete same-zone merge-boundary removal.
- If zone creation, modification, an affected-zone split, or clearing tiles makes an existing door edge illegal, the entire transaction rejects atomically with `EXISTING_DOOR_INVALIDATED`.
- Automatic parcel-door legality requires the old physical edge to remain legal on the matched persistent parcel. Replacement frontage does not compensate for a blocked automatic door.
- Manual-door legality uses the prospective equivalent of manual placement rules: exterior zone doors require Transit; zone-to-circulation doors require Transit plus explicit CIRCULATION; different-zone doors require Transit on both sides; same-zone manual doors remain prohibited.
- Unrelated legacy manual doors do not block a transaction unless the prospective transaction changes an endpoint’s zone, typology, or element.
- Manual doors are identified by their canonical unordered grid edge. Automatic door identity includes parcel tile, direction, access tile, and `access_kind`; derived Transit-area keys do not affect legality.
- Rejected transactions do not commit zones, grid markings, parcel changes, manual door flags, counters, or events.

## Ownership and rendering

- `ZoneSplitter` remains pure and produces all frontage candidates only, including deterministic connected Transit-area metadata.
- `ZoneManager` derives selected edges after stable parcel-ID matching and before commit.
- ZoneTool preview uses the same prospective layout seed, occupancy overlay, affected-zone checks, physical-door eligibility, and existing-door preservation checks as finalization, without mutating persistent state.
- A blocked existing door reports a diagnostic beginning with `EXISTING_DOOR_INVALIDATED` and disables Finish with an actionable status.
- Repainting a pending tile between Tenant and Transit immediately revalidates the preview.
- Selected Parcel ↔ same-zone internal Transit edges create a centered gap in the thin parcel wall.
- Selected Parcel ↔ external CIRCULATION edges create a centered gap in the existing structural zone-perimeter wall.
- Manual grid-door placement may connect a zone Transit tile to explicit external CIRCULATION, or connect Transit tiles across two different zones. It cannot connect a zone tile to a different zone’s non-Transit tile.
- Manual grid-door flags retain their existing behavior otherwise; automatic parcel doors do not set grid-door flags or emit `EventBus.door_changed`.
- The existing Cutaway, Partial, and Full wall modes apply to door jambs, lintels, caps, and all wall profiles.

## Explicit exclusions

- Door collisions, navigation/pathfinding edges, interaction, or tenant lifecycle.
- Automatic physical doors for virtual exterior, implicit-unzoned, or inter-zone frontage.
- Manual doors between a zone tile and a different zone’s non-Transit tile.
- Door meshes separate from the wall geometry.

## Validation requirements

- 1–10, 11–20, and 21–30 physical eligible positions select 1, 2, and 3 doors respectively.
- No two selected doors originate on the same parcel tile.
- A new/unfilled one-door allocation prefers internal Transit; a legal prior external selection survives new internal frontage.
- Two-door allocation prefers internal Transit first, then external circulation, then a different Transit area when external is unavailable.
- Zone-to-zone frontage never produces an automatic door candidate.
- Manual doors reject different-zone connections unless both tiles are Transit, and allow zone Transit to explicit external circulation.
- A zone that blocks an existing automatic or changed-endpoint manual door rejects atomically; preview and finalization report the same status and preserve committed state.
- Selection is deterministic, survives serialization, and preserves legal selections across parcel edits.
- Internal-Transit selections create thin-wall gaps; external-CIRCULATION selections create structural-wall gaps.
- Zero physical eligible positions reject without committing a zone mutation.
- Existing tests pass; runtime zones produce the expected selected-door count and gap geometry with no debugger errors.
