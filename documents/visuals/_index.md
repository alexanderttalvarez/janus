# Project Janus — Visual & Audio Asset Plan

This directory is the production contract for Janus visual and audio assets. It defines **what exists, why it exists, and the requirements it must satisfy**. It does not prescribe modelling, texturing, audio, or engine-integration workflows.

## Project Stage

**Game-design stage:** The current tracker is at Phase 3; Phase 4 is listed next (`game_design/_status.md`). The playable project already contains structural, surrounding-world, traffic, UI, and shader systems. Asset status in this directory is **planning readiness only**; it never reports production completion or integration completion.

## Authoritative Sources

1. `documents/game_design/` defines player-facing requirements and MVP/post-MVP scope.
2. `documents/architecture/` defines representation and technical constraints.
3. Confirmed human direction retained in [style_guide.md](style_guide.md) governs artistic coherence.
4. Where those sources conflict, the conflict is recorded as an open question rather than silently resolved.

## Core Contract

| Document | Purpose |
|---|---|
| [asset_catalog.md](asset_catalog.md) | Master inventory, asset IDs, priorities, status, sources, and handoff links. |
| [style_guide.md](style_guide.md) | Confirmed visual direction, reference hierarchy, anti-goals, and unresolved artistic decisions. |
| [scale_guide.md](scale_guide.md) | Grid-relative dimensions and confirmed working-scale facts. |
| [technical_guide.md](technical_guide.md) | Engine, rendering, localization, runtime, and unknown technical constraints. |

## Detailed Family Specifications

| Family | Specification |
|---|---|
| Civic perimeter and surrounding world | [environment/civic_perimeter.md](environment/civic_perimeter.md) |
| Floors, walls, vertical circulation, terraces, columns | [buildings/building_kit.md](buildings/building_kit.md) |
| Visitors and staff | [characters/agents.md](characters/agents.md) |
| Tenant frontages, operations, hygiene, prestige amenities | [props/tenant_amenities.md](props/tenant_amenities.md) |
| Reusable material and data-visualization families | [materials/material_system.md](materials/material_system.md) |
| HUD, tools, panels, graphs, world labels, and notifications | [ui/game_ui.md](ui/game_ui.md) |
| Zone, heatmap, construction, and contextual feedback overlays | [vfx/overlays.md](vfx/overlays.md) |
| Visitor, staff, elevator, construction, and UI motion | [animations/agent_animation.md](animations/agent_animation.md) |
| Music direction | [music/music_direction.md](music/music_direction.md) |
| Sound-effect direction | [sfx/sfx_direction.md](sfx/sfx_direction.md) |

## Planning Statuses

| Status | Meaning |
|---|---|
| `discovered` | The asset requirement is known but lacks a useful specification. |
| `specified` | The requirement is scoped, but a material decision still prevents a reliable production handoff. |
| `blocked` | A design, scope, or direction decision must be made first. |
| `ready_for_production` | A producer can start from the linked specification, including known non-blocking assumptions. |

## Current Material Open Decisions

- Confirm whether current road, pedestrian-ring, and traffic presentation is MVP scope; it is present in the live scene but multi-plot road ownership is post-MVP in game design.
- Resolve the escalator scope contradiction: the tech-tree document includes it in the MVP tree, while the circulation document calls it post-MVP.
- Resolve the Cutaway/Partial wall-strip height: the game-design wall specification says about 10% plus a cap plate, while the earlier wall-rendering decision says 5%.
- Define the bathroom facility footprint, unlock, and placement rules. The visitor and staff systems require it, but no building specification exists.
- Set target platform(s), interchange/audio formats, supported texture resolutions, mesh budgets, pivot/axis conventions, and LOD policy.
- Approve audio mood and SFX stylization before audio assets can become production-ready.
