# Project Janus — Asset Index

Master index of all visual and audio assets required for the game.

## Game Overview

Janus is a **low-poly 3D isometric** commercial district building simulation. The player designs multi-floor buildings, places zones (Retail, Food & Beverage, Entertainment, Services, Anchor), adds circulation (corridors, stairs, elevators), and watches visitors flow through the space. The art direction is **clean, modern, serene** — architectural visualization meets playful simulation.

## Asset Categories

| Category | Document | MVP Assets | Post-MVP Assets |
|----------|----------|-----------|-----------------|
| **Scale Reference** | [scale.md](scale.md) | Tile grid, floor height, camera | — |
| **Style Guide** | [style_guide.md](style_guide.md) | Color palette, art direction | — |
| **Characters** | [characters/](characters/) | Visitor mesh, staff meshes | Visitor variations, named staff |
| **Environment** | [environment/](environment/) | Plot ground, road/pedestrian tiles | Multiple plots, skybridges |
| **Buildings** | [buildings/](buildings/) | Floor plane, walls, stairs, elevators, columns, terraces | Escalators, skybridges, underground passages |
| **Props** | [props/](props/) | Zone interior placeholders, basic amenities, garbage, signage | Detailed shop interiors, furniture, water features, art |
| **Materials** | [materials/](materials/) | Floor material, wall material, zone color overlays | Concrete, glass, brick, metal, decorative materials |
| **UI** | [ui/](ui/) | HUD bar, toolbar, panel frames, icons, heatmap legend | Advanced panel skins, custom cursors |
| **Animations** | [animations/](animations/) | Visitor walk/idle, staff walk, construction phases | Visitor browse/queue, staff clean/patrol, door open/close |
| **VFX** | [vfx/](vfx/) | Heatmap overlay, contextual indicators | Particle effects, weather |
| **Music** | [music/](music/) | 1 ambient loop | Seasonal tracks, time-of-day variations |
| **SFX** | [sfx/](sfx/) | UI click, generic confirm, generic error | Category-specific UI, world ambience, interaction feedback |

## MVP Asset Count Summary

| Category | Unique Assets | Reusable Variants |
|----------|--------------|-------------------|
| 3D Models | ~25 | ~15 |
| Materials | ~8 | ~5 |
| UI Elements | ~30 | ~10 |
| Animations | ~10 | ~5 |
| VFX | ~5 | ~3 |
| Music Tracks | 1 | — |
| SFX | ~8 | ~4 |

## Key Scale Decisions

- **1 tile = 2m × 2m** in world units
- **Floor height = 4m** (2 tiles tall)
- **Wall height = 4m** (full floor)
- **Visitor height = ~1.7m** (slightly under half a floor)
- **Camera**: Orthographic, zoom range 5.0–50.0

## Asset Reuse Strategy

- **Single visitor mesh** with color variations for different visitor types
- **Single staff mesh** per type (Cleaner, Security) with uniform color coding
- **Shared floor plane material** with color overlays for zone types
- **Modular wall segments** generated procedurally from tile data
- **Reusable amenity props** (plants, benches, trash cans) placed across zones
- **Shared UI icon set** with consistent stroke/fill style

## File Naming Convention

```
<category>_<name>_<variant>.<ext>
```

Examples:
- `mesh_visitor_base.glb`
- `mat_wall_concrete.tres`
- `tex_zone_retile.png`
- `sfx_ui_click.wav`
- `anim_visitor_walk.res`

## Status Legend

| Status | Meaning |
|--------|---------|
| 🔴 Not Started | Asset not yet produced |
| 🟡 In Progress | Asset being produced |
| 🟢 Complete | Asset ready for use |
| ⚪ MVP Placeholder | Temporary asset for gameplay testing |
