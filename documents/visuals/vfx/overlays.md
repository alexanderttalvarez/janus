# Gameplay Overlays & Contextual Feedback

## Identity

**Asset IDs:** `vfx_heatmap_family`, `vfx_contextual_feedback`, `vfx_construction_state`, `vfx_condition_degradation`, `vfx_water_feature`, `vfx_time_season_lighting`  
**Category:** Data visualization and visual feedback  
**Family:** Restrained spatial overlays and state communication

## Purpose

Overlays explain what the simulation is doing directly in the district: painted zones, heatmaps, tenant lifecycle, congestion, low viability, prestige previews, and future repair/season changes. They are gameplay communication, not decorative spectacle.

## Source

- `01_core_loop.md`, `04_zone_space_design.md`, `06_tenant_shop_system.md`, `07_metrics_data_visualization.md`, `16_maintenance_system.md`.
- `02_ui_rendering.md`, `05_heatmap_implementation.md`, `10_zone_system_architecture.md`.

## Gameplay Context

- Zone painting previews at 50% opacity and painted tiles at 100%; finished edit mode removes the zone overlay, while perimeter/name feedback remains.
- Only one heatmap is active at a time. MVP modes are Visitor Density and Zone Viability.
- Construction has foundation/scaffolding, framing, finishing/signage, and operational states.
- Localized warnings must point to the affected area rather than becoming global clutter.

## Required Assets & Variants

| Family | MVP representation | Production representation | Required variants |
|---|---|---|
| Zone / typology overlay | Five-color tile data treatment plus perimeter line/name | Refined data overlay with same functional clarity | Hover, paint, final; tenant, decoration, transit |
| Heatmaps | Density and viability color scales plus legend | Full analytical suite | Density, viability; congestion, synergy, prestige contribution post-MVP |
| Contextual feedback | Low-viability cue, congestion cue, tenant state icon, vacant timer, quality preview | Subtle motion/emphasis without visual noise | Healthy, concerned, critical, closing, vacant; congestion; prestige preview |
| Construction lifecycle | Distinct three-phase state + operational state | Foundation/framing/finishing visual family | Vacant, applicant/lock, phase 1–3, open, closing |
| Condition/repair | N/A | Wear, grime, damage, critical, under-repair visual states | 80–100, 50–79, 20–49, 0–19, repair |
| Water feature | Clear static water surface | Restrained fountain/pool water movement that supports a prestige focal point | Fountain, small pool |
| Day/season | N/A | Lighting and selected foliage/decoration changes | Morning/midday/lunch/afternoon/evening/night; four seasons |

## Dependencies & Reuse

- Zone overlay: one shader-driven mesh per floor; heatmaps: one shader-driven mesh per active mode. Do not require unique tile assets.
- Color definitions must be shared by world overlays, indicators, heatmap legends, and panel status components.
- Construction and condition states may reuse material/geometry states, but their player-visible threshold changes must remain distinct.
- Day/season presentation depends on systems deferred to post-MVP by `12_time_system_architecture.md`.

## Visual Requirements

- Overlay colors take precedence over environmental color accuracy when data is active.
- Feedback should be obvious enough to explain an issue yet quiet enough that building remains pleasant in a busy district.
- Avoid particle excess, full-screen flashes, or continuously pulsing decoration.
- At night, indicators and heatmaps retain full gameplay contrast against the approved cool ambient environment and warm interior lighting.

## Technical Requirements

- Heatmap and zone overlays have mandated shader-driven representations. Their production requirement is color/state art and a legend, not per-tile visual assets.
- Wall mode may hide major wall surfaces; critical feedback must remain visible from the current camera angle or have a panel equivalent.
- No player-facing text is baked into world feedback. Values/timers render through localized labels.

## Acceptance Criteria

- Players distinguish the five zone types during editing and the three tenant-health warning levels in normal gameplay.
- Density and viability heatmaps have clear legends and can be interpreted without remembering an arbitrary palette.
- Construction progress is understandable from world state alone.
- Contextual indicators identify affected space without covering the entire floor or obscuring major building decisions.

## Open Questions

1. What exact visual representation should distinguish application/exclusivity lock from construction phase one?
2. Do thought bubbles belong to this overlay family or remain only a world-label UI asset? The current catalog treats their presentation as UI while their placement is world-space.
3. Which seasonal decorations/events are in product scope once visual time is implemented?
