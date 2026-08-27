# Handoff 07 — Zone Debug Visualization

**Status:** Approved
**Approved:** 2026-08-27
**Implementation order:** 7 — after Handoff 06

## Purpose

Render one larger debug label at the mathematical center of each committed zone, alongside the existing parcel labels. Zone labels are a read-only visualization of committed `ZoneData`; they are not gameplay signage or tenant state.

## Player-facing and debug rules

- Zone labels are debug-only for now.
- `DebugManager.show_zone_labels` defaults enabled in debug builds and disabled in release builds.
- Each committed zone on the active floor has exactly one label while the flag is enabled.
- Text uses committed `ZoneData.zone_name`; when empty, it falls back to the committed zone type.
- Zone labels use a larger font than parcel center-name labels and a higher vertical label tier.
- Labels are non-interactive and do not participate in collision, input, navigation, or gameplay systems.
- No title-menu, settings UI, localization, tenant, or save-schema work is included.

## Ownership and scene structure

`ZoneManager` remains the committed zone-data owner. `ZoneLabelRenderer` is a floor-scoped, read-only projection. `ZoneTool` owns input and pending preview state only and never creates zone labels.

Each active instantiated floor gains a separate runtime container:

```text
Floor (Node3D)
├── ZoneContainer
├── ParcelLabelContainer
└── ZoneLabelContainer
    └── <zone persistent ID> (Node3D)
        └── Name (Label3D)
```

The renderer is created by `MainGame` under `World`, separately from `ParcelLabelRenderer`.

## Placement

For a committed zone, calculate the mathematical centroid by averaging the geometric centers of every tile in `ZoneData.tiles`:

```text
centroid = average(Vector2(tile) + Vector2(0.5, 0.5))
```

Convert the fractional coordinate with the active floor's canonical `grid_coordinate_to_local()` method. Do not hard-code tile size, grid origin, floor height, or a second grid conversion path. Place the label above the parcel-name label tier.

## Lifecycle

- Render only zones on the active floor and active plot.
- Refresh only after successful `zone_created`, `zone_modified`, `zone_deleted`, active-floor changes, debug visibility changes, or load restoration.
- A merge refreshes the surviving zone and removes retired zone groups through normal committed events.
- Rejected plans emit no committed event and must not change labels.
- Pending paint/removal previews must not create or mutate committed zone labels. Cancellation must leave the committed projection intact.
- Visibility disable clears/hides the runtime zone label groups; enable hydrates the active floor.

## Required files

- `scripts/zones/zone_label_renderer.gd`
- `scripts/levels/main_game.gd`
- `scripts/autoloads/debug_manager.gd`
- Tests covering centroid placement, transformed floor conversion, text fallback, active-floor and visibility lifecycle, create/modify/delete refresh, merge/removal cleanup, and rejected transactions.

## Acceptance requirements

- Every committed active-floor zone has exactly one larger center label when debug visibility is enabled.
- Label text is `zone_name` or the zone type when the name is empty.
- The label uses the mathematical tile-footprint centroid and the canonical floor transform.
- Labels refresh without duplicates after create, extension, merge, removal, and deletion.
- Invalid or cancelled pending operations do not alter committed labels.
- Parcel labels continue to be owned and rendered independently.
- Release builds default zone labels off.

## Explicit non-goals

- Player-facing zone signage.
- Localization or translation-key semantics for `zone_name`.
- Tenant interiors, tenant lifecycle, economy, notifications, or construction.
- Changes to zone identity, parcel solving, doors, walls, input, or pathfinding.
