# Heatmap Overlay Assets

## Heatmap Overlay (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Shader-driven color overlay showing spatial data. |
| **Type** | SubViewport with shader-driven mesh |
| **Rendering** | Single draw call for entire heatmap |
| **Data input** | Uniform array or texture with per-tile values |
| **Position** | Overlaid on 3D game view |

### MVP Heatmap Modes

| Mode | Data Source | Color Scale |
|------|-------------|-------------|
| **Visitor Density** | Visitor count per tile | Hot (red/orange) → Medium (yellow) → Cold (blue/dim) |
| **Zone Viability** | Zone health status | Healthy (green) → At Risk (yellow) → Vacant (gray) |

### Post-MVP Heatmap Modes

| Mode | Data Source | Color Scale |
|------|-------------|-------------|
| **Congestion** | Visitors per corridor tile | Blocked (red) → Busy (orange) → Free (green) |
| **Synergy** | Zone adjacency scores | Positive (green) → Neutral (gray) → Negative (red) |
| **Prestige Contribution** | Per-tile prestige contribution | High (gold) → Medium (white) → Low (dim) |

## Weather Particles (Post-MVP)

| Effect | Season | Description |
|--------|--------|-------------|
| **Rain** | Any | GPUParticles2D/3D rain drops |
| **Snow** | Winter | GPUParticles2D/3D snowflakes |
| **Falling leaves** | Autumn | GPUParticles2D/3D leaf sprites |
| **Blossom petals** | Spring | GPUParticles2D/3D petal sprites |

## Water Fountain VFX (Post-MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Water particle effect for fountains. |
| **Type** | GPUParticles3D |
| **Style** | Low-poly water spray |

## Reuse Opportunities

- Single heatmap shader with different color scales per mode
- Weather particles use the same particle system with different textures
- All heatmap modes share the same mesh and rendering pipeline
