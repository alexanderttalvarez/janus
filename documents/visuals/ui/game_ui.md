# Game UI & World Information

## Identity

**Asset IDs:** `ui_hud_control_set`, `ui_build_toolset`, `ui_information_panels`, `ui_tech_tree_graph`, `ui_notification_family`, `ui_world_label_family`  
**Category:** UI, icons, data display, and world-space information  
**Family:** Clean, on-demand simulation interface

## Purpose

The UI makes Janus's rules transparent without displacing the built world. It gives players building tools, readable metrics, contextual explanation, and non-interruptive notifications.

## Source

- `07_metrics_data_visualization.md`, `08_mall_levels_tech_tree.md`, `17_ui_hud_system.md`, `18_notifications_system.md`.
- `14_ui_architecture.md`, `17_notification_system_architecture.md`, `19_tech_tree_architecture.md`, `21_multi_language_architecture.md`.

## Gameplay Context

- HUD stays visible while building and observing: money, visitors, prestige, speed, visual clock, wall mode, and camera/floor context.
- Bottom tools change among Build, Observe, and Edit Zone modes.
- On-demand panels stack from the right; a maximum of three is open at once.
- World labels identify zones/businesses; up to three rotating thought bubbles explain visible visitor intent.
- Toasts appear bottom-right, with category, priority, optional action, and a persistent log/red dot for unresolved urgent issues.

## Required Asset Families

| Family | MVP representation | Production representation | Required variants |
|---|---|---|---|
| HUD controls | Compact information/control groups with explicit selected state | Polished soft-modern HUD that remains secondary to world | Money, visitors, prestige, speed, clock, wall mode, floor/camera context |
| Build/edit tools | Clearly named/icon-led tool states | Cohesive icon and tool-state library | Five zones; corridor; stairs; elevator; amenities; Operations Room; bulldozer; three tile typologies; walls; finish |
| Information panels | Shared frame, header, close action, lists and charts | Consistent data-panel system | Finances, prestige, tenants, visitors, metrics, tech tree, staff, notifications |
| Tech graph | Branch/node state + dependency links | Branch-specific visual character without losing legibility | Construction, circulation, amenities; locked, available, unlocked |
| Notifications | Toast, log row, category marker, red-dot indicator | Priority-aware notification language | Seven categories; high/medium/low; unread/read/resolved; optional action |
| World labels | Text-safe zone/business label and thought bubble | Icon-assisted label language that respects camera/zoom | Zone name, business name/subtype, visitor thought, contextual state |
| Analytics language | Chart and legend components | Refined graph/heatmap legend family | Lines, bars, tier distribution, 7/30/90 range, density and viability legends |

## Dependencies & Reuse

- Use a shared frame, button-state, and icon language across HUD, toolbar, panels, tooltips, toasts, and tech nodes.
- Tech icons are individual assets referenced by data and must contain no language-specific words.
- UI labels, business names, tech names, and notifications must accept translation keys; no player-facing text may be baked into a texture.
- Heatmap legends share exact color tokens with [material_system.md](../materials/material_system.md).

## Visual Requirements

- Compact, calm, clean, and soft-modern; world view is always primary.
- Panels may be semi-transparent but must preserve text/chart legibility above any day/night world state.
- Functional color has a reserved meaning: zone colors and green/yellow/red health states cannot be used decoratively in a way that obscures their gameplay meaning.
- Icons prioritize silhouette and recognizability over illustrative detail. Avoid ornamental chrome, extreme gradients, or a high-tech/cyberpunk treatment.

## Technical Requirements

- `game_ui.tscn` separates HUD, toolbar, panel, notification, and overlay layers. Assets must layer cleanly in their intended layer.
- The live scene is authored at 1920×1080 with a 32px HUD and 40px toolbar; this is a current implementation observation, **not** an approved responsive-layout target.
- Panels are separate runtime scenes and must work in a maximum-three stack.
- World labels must remain readable within the current orthographic camera and not present critical information only when a visitor is culled.

## Acceptance Criteria

- A new player can identify available versus locked build tools and understand the selected tool without relying on color alone.
- HUD and bottom toolbar leave the primary world view visually dominant.
- A panel stack remains clearly scannable at three panels without hiding urgent world feedback.
- A toast's category, priority, message, and optional action are distinguishable at a glance.
- Zone, business, and thought information can be localized without changing visual artwork.

## Open Questions

1. What are the target resolutions, scaling policy, minimum text size, controller focus requirements, and accessibility palette requirements?
2. Are custom cursors required or should the system cursor remain standard?
3. Which specific tech-node icon concepts are confirmed beyond their mechanical names?
