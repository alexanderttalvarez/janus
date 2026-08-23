# Material & Surface System

## Identity

**Asset IDs:** `mat_architecture_base`, `mat_zone_overlay`, `mat_wall_clipping`  
**Category:** Materials and shader-driven visual data  
**Family:** Soft low-noise architecture, gameplay overlays, and camera-aware walls

## Purpose

Materials provide a coherent visual identity while preserving the primacy of simulation data: zones, heatmaps, wall modes, construction, and contextual warnings must remain legible over environmental surfaces.

## Source

- Confirmed human direction in [style_guide.md](../style_guide.md).
- `04_zone_space_design.md`, `07_metrics_data_visualization.md`, `12_wall_system.md`.
- `04_wall_rendering.md`, `05_heatmap_implementation.md`, `10_zone_system_architecture.md`.

## Required Families

| Family | MVP representation | Production representation | Required states / variants |
|---|---|---|---|
| Architecture base | Warm cream/beige, low-noise floor/wall/civic palette | Visual-only selectable building material library | Concrete/windows, glass curtain, brick, metal panel, decorative when unlocked |
| Zone overlay | Five distinct functional colors with preview/paint/final opacity states | Refined overlay that remains clearly data-like | Retail purple, food green, entertainment orange, services blue, anchor red; tenant/decoration/transit |
| Wall clipping | Camera-aware full wall, low strip, and cap read | Every architecture finish honors the same clipping contract | Cutaway, Partial, Full; straight/corner/T junction |
| Heatmap color treatment | Density and viability gradients with a legend | Additional analytic gradients when systems ship | Density, viability; congestion, synergy, prestige contribution |
| Condition/construction states | Lifecycle color/overlay states | Integrated wear/grime/repair and construction finish states | Vacancy, construction phases, pristine→critical, repair |

## Dependencies & Reuse

- Zone overlay is one floor-level data-driven surface, not a unique material per tile or zone.
- Heatmaps use one shader-driven mesh and swap data/mode; color palettes must be shared with the legend UI.
- Wall appearance uses one clipping rule across all chosen future material styles.
- Base materials should reuse a limited palette and minimal surface noise, as confirmed in the style guide.

## Visual Requirements

- Prefer matte, clean, softly lit surfaces with restrained roughness variation and minimal texture dependence.
- Avoid grunge, heavy weathering by default, photoreal concrete noise, aggressive reflections, and material detail that cannot read at camera distance.
- Environmental hue must not reduce the contrast of zone, heatmap, warning, and tenant-state visualizations.
- Night materials must preserve the approved cool-environment/warm-interior relationship without turning the district into cyberpunk neon.

## Technical Requirements

- Wall clipping and zone/heatmap overlay representations are technical architecture decisions, not optional visual alternatives.
- Source control does not establish texture resolution, material-slot limits, texture formats, or rendering-platform targets. These remain open in [technical_guide.md](../technical_guide.md).
- Do not bake localized text or game-state values into materials.

## Acceptance Criteria

- Five zone colors are distinguishable over every approved base surface and in both day/night lighting.
- Each heatmap has an unambiguous low-to-high or bad-to-good gradient that matches its UI legend.
- The same wall finish reads correctly in Cutaway, Partial, and Full mode.
- Base materials support a clean coherent district without requiring high-frequency surface detail.

## Open Questions

1. Which post-MVP wall-material unlocks are first-release production scope?
2. What are the approved exact palette values and accessibility contrast targets?
3. What texture/material budgets apply to target platforms?
4. Which source controls the retained wall-strip height in Cutaway and Partial mode: 10% in game design or 5% in the earlier rendering decision?
