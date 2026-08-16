# Wall Materials

## Wall Base Material (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Default wall surface. |
| **Type** | ShaderMaterial (wall clipping shader) |
| **Color** | Warm neutral (light gray/white) |
| **Roughness** | 0.7 |
| **Metallic** | 0.0 |
| **MVP** | Flat color with clipping shader. |
| **Post-MVP** | Textured material (concrete, glass, brick, etc.). |

## Wall Clipping Shader (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Clips walls based on camera direction and visualization mode. |
| **Type** | ShaderMaterial |
| **Parameters** | `camera_direction` (global), `wall_mode` (global: cutaway/partial/full), `outward` + `front_threshold` (per material) |
| **Logic** | Dot product of the baked wall outward direction vs. camera direction determines front/back. Front walls clipped to 10% in cutaway mode. Corner cubes use a diagonal outward direction with a 0.5 front threshold, so only the camera-facing corner opens. |

### Shader Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `camera_direction` | vec2 (global) | Current camera look direction |
| `wall_mode` | int (global) | 0=Cutaway, 1=Partial, 2=Full |
| `outward` | vec2 (per material) | Baked wall outward direction (axis normal for walls, diagonal for corner cubes) |
| `front_threshold` | float (per material) | 0.0 for walls, 0.5 for corner cubes |
| `front_clip_height` | float | 0.10 for Cutaway/Partial, 1.0 for Full |
| `back_clip_height` | float | 1.0 for Cutaway, 0.10 for Partial, 1.0 for Full |

## Post-MVP Wall Materials

### Concrete + Windows (Default)

| Property | Value |
|----------|-------|
| **Style** | Standard commercial concrete with window cutouts |
| **Color** | Light gray |
| **Texture** | Concrete texture with window pattern |

### Glass Curtain

| Property | Value |
|----------|-------|
| **Style** | Modern, transparent |
| **Color** | Tinted blue/gray |
| **Transparency** | 70-80% |
| **Reflection** | High |

### Brick

| Property | Value |
|----------|-------|
| **Style** | Warm, traditional |
| **Color** | Red/brown brick |
| **Texture** | Brick pattern |

### Metal Panel

| Property | Value |
|----------|-------|
| **Style** | Industrial, sleek |
| **Color** | Silver/gray |
| **Metallic** | 0.8 |
| **Roughness** | 0.3 |

### Decorative

| Property | Value |
|----------|-------|
| **Style** | Ornamental, premium |
| **Color** | Variable |
| **Texture** | Decorative pattern |

## Reuse Opportunities

- All wall materials share the same base geometry
- Wall clipping shader is shared across all wall materials
- Post-MVP materials are variants of the base wall material with different textures
