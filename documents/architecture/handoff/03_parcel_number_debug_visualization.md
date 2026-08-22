# Handoff 03 — Parcel Number Debug Visualization

**Status:** Approved
**Approved:** 2026-08-22
**Implementation order:** 3 of 3 — after Handoffs 01 and 02

## Purpose

Render a numeric debug readout for every committed parcel tile. All tiles in one parcel show the same number; a larger parcel name appears at the parcel's calculated center. This replaces finalized colored tenant-tile fills and makes parcel ownership visible without creating tenant interiors or gameplay state.

## Dependencies

- [Handoff 01 — Deterministic Parcel Splitting](01_parcel_splitting.md) provides valid parcel geometry, stable parcel IDs, and atomic rejection.
- [Handoff 02 — Immediate Debug Business Assignment](02_immediate_debug_business_assignment.md) provides parcel subtype metadata and display names.

Neither handoff may expose partial state to this renderer.

## Scope

- Render one semi-transparent tile-number `Label3D` per committed parcel tile.
- Render one larger semi-transparent parcel-name `Label3D` at the geometric center of each committed parcel.
- Render transient `0` tile labels for a rejected finalization attempt's proposed Tenant tiles.
- Control committed labels through a reusable `DebugManager` visibility flag.
- Remove finalized colored tenant-tile fills while retaining ZoneTool hover/paint preview feedback.

## Explicit non-goals

- Tenant entities, applications, lifecycle, construction, economy, or notifications.
- Tenant interiors, business signage, door/wall visuals, collisions, input, ray-picking, or pathfinding.
- Subtype display names beyond Handoff 02 catalog data.
- Player-facing debug settings UI or a debug-overlay control.
- Persisting visual nodes, label containers, or preview-label state.

## Data ownership

| Owner | Responsibility |
|---|---|
| `ZoneManager` | Owns committed parcel data and allocates/preserves parcel display numbers as part of an accepted atomic commit. |
| `Parcel` | Owns stable `display_number`, persistent parcel ID, tile geometry, and assigned subtype ID. |
| `ParcelLabelRenderer` | Floor-scoped, read-only projection of committed parcel data into `Label3D` nodes. It never mutates game data. |
| `ZoneTool` | Owns rejection-preview lifetime and proposed tile data. It does not create committed parcel data. |
| `DebugManager` | Owns the reusable `show_parcel_labels` debug flag and emits a change signal. |
| Subtype catalog | Resolves `assigned_subtype_id` to a display name. |

## Display-number contract

- `Parcel.display_number` is a globally unique, positive, monotonically allocated integer.
- `ZoneManager` allocates it only during a successful atomic commit, beginning at `1`.
- Handoff 01 overlap-preservation also preserves the display number for a matched parcel.
- New parcels receive new numbers; retired numbers are never reused.
- `0` is reserved exclusively for transient rejected-finalization feedback and is never committed to a parcel.
- `display_number` is persistent parcel state. It must be serialized with parcel identity/geometry when parcel save/load integration is implemented; visual nodes are always rebuilt after load.

The display number is not a zone ID, subtype ID, tenant ID, tile coordinate, or array index.

## Scene ownership and visual structure

Each instantiated floor gains a dedicated runtime container separate from zone overlays:

```text
Floor (Node3D)
├── ZoneContainer                     # Existing overlays / ZoneTool previews
├── ParcelLabelContainer (Node3D)     # Committed runtime debug labels
│   └── <parcel persistent ID> (Node3D)
│       ├── Tile_<coordinate> (Label3D)
│       └── Name (Label3D)
└── ZoneToolRejectedPreviewContainer   # Transient, active-edit feedback only
```

`ParcelLabelRenderer` owns `ParcelLabelContainer` and its committed children. `ZoneTool` owns the content lifetime of the rejected-preview container, which is hosted on the active floor so world transforms remain correct.

## Label content, positioning, and opacity

### Committed parcel tiles

- One `Label3D` per parcel tile.
- Text is the parcel's decimal `display_number`.
- Position is the canonical center of that instantiated floor tile.
- Opacity is **20%** (`alpha = 0.2`) at all times.

### Committed parcel center label

- One larger `Label3D` per parcel.
- Text is the Handoff 02 subtype catalog display name, for example `Fashion`.
- If no subtype is assigned, text is `Unassigned Parcel`.
- Position is the exact geometric center of the rectangular parcel, including centers between tiles when applicable.
- It has a higher local vertical offset than tile-number labels to avoid overlap.
- Opacity is **20%** (`alpha = 0.2`) at all times.

### Rejected-finalization preview

- When Handoff 01 returns a rejected split result, render text `0` only over proposed **Tenant** tiles.
- Do not render center names, labels for Transit/Decoration tiles, or any committed parcel group.
- Rejection labels are temporary. Clear them when the player changes the painted geometry/typology, cancels editing, switches floor, disables the debug flag, or successfully finalizes.

Label positions must use the active instantiated `Floor`'s canonical tile-center conversion, including `GridOrigin`, tile spacing, and parent/floor transforms. Do not hard-code tile size, floor height, or call any diverging grid-to-world helper until its scale contract is reconciled.

## Visibility, lifecycle, and performance

- `DebugManager.show_parcel_labels` defaults enabled in debug builds and disabled in release builds. No player-facing toggle is included here.
- Committed labels are visible only when the flag is enabled and their floor is active.
- On flag enable, hydrate labels from committed ZoneManager parcel data; on disable, clear or hide all label groups.
- Inactive-floor committed label nodes are released and rebuilt lazily when their floor becomes active.
- Refresh labels only after successful committed zone create/modify/delete events, a floor change, a debug-flag change, or load restoration. Never regenerate them every frame.
- The current 25×25 floor limit caps an active floor at 625 tile-number labels plus one name label per parcel. No inactive floor retains live labels.
- All labels are non-interactive and do not participate in collision, input, navigation, or gameplay systems.

## Event and update flow

```text
Successful Handoff 01 + 02 atomic commit
    → existing committed zone create/modify/delete event
    → ParcelLabelRenderer refreshes only the affected active floor/zone

Rejected Handoff 01 finalization
    → no committed zone event or data mutation
    → ZoneTool shows transient Tenant-tile 0 labels
```

On an edit preview, hide the affected committed parcel-label group while the preview is active. Restore it on cancellation/rejection, or replace it after a successful commit. This prevents stale committed numbers overlapping preview zeroes.

## Finalized color behavior

- Remove the finalized colored tenant-tile visual path.
- Keep ZoneTool hover and unfinished-paint previews separate; they remain edit feedback and are not parcel labels.
- Committed parcel labels are the sole finalized tile-ownership visualization in this handoff.

## Acceptance requirements

- Every tile in every committed valid parcel on the active floor shows exactly that parcel's positive display number.
- Distinct committed parcels never share a display number; a matched parcel retains its number through an accepted overlap-preserving edit.
- Every committed parcel has one larger center label with its subtype display name or `Unassigned Parcel`.
- All committed and rejected-preview labels render at 20% opacity.
- Rejected finalization shows `0` only on proposed Tenant tiles, mutates no committed zone/grid/parcel data, and creates no center name.
- Rejected-preview zeroes clear on paint mutation, cancellation, successful finalization, floor switch, and debug disable.
- Rejected finalization leaves committed labels unchanged once the transient preview is cleared.
- Creation, modification, deletion, debug enable/disable, active-floor changes, and post-load hydration leave no stale or duplicate label groups.
- Corner and interior labels use transformed floor tile centers correctly for non-origin `GridOrigin` transforms.
- Finalized colored tenant fills are absent; ZoneTool previews remain functional.
- Label changes create no tenant, door, wall, input, pathfinding, or other gameplay side effect.

## Risks and prerequisites

- Current zone/parcel code does not yet satisfy Handoff 01/02 atomic commits, stable IDs, or serialization. Handoff 03 cannot begin until those contracts are verified.
- Runtime floor/grid scale values diverge from visual documentation. Correct labels require one authoritative floor-local tile-center conversion before implementation.
- Per-tile transparent `Label3D` nodes are intentionally debug-only; active-floor gating and lazy lifecycle are required to contain draw/sorting cost.

## Implementation guidance

Implement only after Handoffs 01 and 02 pass their acceptance requirements. Use a dedicated floor-scoped renderer, not ad-hoc label creation inside `ZoneManager`, `ZoneBusinessAssigner`, or tenant systems.

Required implementation skills: `godot-prompter:3d-essentials`, `godot-prompter:event-bus`, and `godot-prompter:godot-testing`.
