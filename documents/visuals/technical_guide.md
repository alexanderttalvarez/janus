# Technical Guide

This document records only production constraints established by the project. Unspecified budgets and formats are intentionally not invented.

## Confirmed Runtime & Representation Constraints

| Area | Requirement | Source |
|---|---|---|
| Engine / presentation | Godot 4, 3D project, orthographic isometric camera | Project summary; `16_camera_system_architecture.md` |
| Floor construction | Each level instantiates `floor.tscn`; structural nodes are authored, while tiles, zones, circulation, visitors, and indicators are runtime content | `06_floor_representation.md` |
| Floor assets | Floor Plane and Wall Mesh are reusable structural assets; tile and zone visuals cannot require hand-authored instances for all 625 tiles | `06_floor_representation.md` |
| Zone visuals | One shader-driven overlay mesh per floor reads tile/zone data; previews and finalized zones must work through that shared overlay | `10_zone_system_architecture.md` |
| Heatmaps | One shader-driven mesh renders each heatmap; modes swap data and color treatment rather than needing per-tile art assets | `02_ui_rendering.md`, `05_heatmap_implementation.md` |
| Walls | A single wall mesh/shader system supports Cutaway, Partial, and Full camera-relative modes | `04_wall_rendering.md`, `12_wall_system.md` |
| Visitor visuals | Visible visitors are Node3D instances; current population cap is 20; shared material is required for batching | `03_visitor_agents.md`, `05_visitor_simulation.md` |
| Staff visuals | Staff are Node3D instances; architecture expects roughly 16 maximum | `18_staff_system_architecture.md` |
| UI | `game_ui.tscn` uses five CanvasLayers; panels are separate scenes; three panels maximum at once | `14_ui_architecture.md` |
| Localization | UI strings and data labels use translation keys; do not bake player-facing text into visual assets | `21_multi_language_architecture.md` |
| Tech icons | Tech-node entries preload individual icon assets; icons belong in `assets/textures/ui/tech/` | `19_tech_tree_architecture.md` |

## Asset Naming

Use stable catalog IDs in planning and a compatible lowercase underscore file stem in production:

`<category>_<family>_<name>[_<variant>]`

Examples: `3d_arch_wall_standard`, `ui_icon_tech_stairs`, `vfx_heatmap_density`, `sfx_ui_confirm`.

Do not derive file names from translated display text.

## Required Asset Behaviour

- **World assets:** must remain tile-aligned and support the camera/wall visibility rules in [scale_guide.md](scale_guide.md).
- **Text assets:** must remain replaceable by localization; provide a text-safe sign plate, icon, or layout region rather than baked words.
- **Color-critical overlays:** zone colors and heatmap colors must remain distinguishable from environmental materials and retain legibility at night.
- **Characters:** shared base resources must not require editing shared materials to vary per-instance opacity or appearance; visitor spawning already uses per-instance transparency.

## Unresolved Technical Constraints

The following are **OPEN QUESTIONS** and must be approved before final high-fidelity asset delivery:

1. Target platform(s), screen-resolution targets, and performance budget.
2. Supported 3D interchange formats, texture formats, and audio formats.
3. Forward/up axis, object pivot convention, unit-to-metre convention, and collision-delivery expectations.
4. Triangle, material-slot, texture-resolution, memory, and draw-call budgets.
5. LOD, impostor, texture-atlas, and compression policy.
6. Audio buses, loudness targets, and accessibility requirements.

These unknowns do not block visual planning, but they prevent declaring most geometry and audio families fully ready for production.
