# Floor & Environment Materials

## Floor Base Material (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Default floor surface for purchased tiles. |
| **Type** | StandardMaterial3D |
| **Color** | Warm neutral (light gray/beige) |
| **Roughness** | 0.8 |
| **Metallic** | 0.0 |
| **MVP** | Flat color, no texture. |
| **Post-MVP** | Subtle tile texture (concrete, tile pattern). |

## Zone Color Overlay Material (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Colored overlay on floor tiles showing zone type. |
| **Type** | StandardMaterial3D with transparency |
| **Colors** | Retail=purple, Food&Bev=green, Entertainment=orange, Services=blue, Anchor=red |
| **Opacity** | Variable (0-100% based on edit mode state) |
| **Blend mode** | Alpha blend |

## Corridor Material (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Visual distinction for corridor/transit tiles. |
| **Type** | StandardMaterial3D |
| **Color** | Slightly different from floor base (darker or lighter neutral) |
| **MVP** | Flat color, no texture. |
| **Post-MVP** | Subtle corridor texture (smooth flooring pattern). |

## Terrace Material (Post-MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Outdoor floor material for terrace tiles. |
| **Type** | StandardMaterial3D |
| **Color** | Outdoor tone (stone, wood deck, or concrete) |
| **Texture** | Outdoor-appropriate texture |

## Ground Material (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Ground plane visible through unbought tiles and floor holes. |
| **Type** | StandardMaterial3D |
| **Color** | Warm neutral (slightly darker than floor) |
| **MVP** | Flat color. |
| **Post-MVP** | Subtle ground texture (grass, dirt, or asphalt). |

## Sky Material (MVP)

| Property | Value |
|----------|-------|
| **Purpose** | Background sky. |
| **Type** | Procedural sky or solid color |
| **Color** | Light blue (day), dark blue (night, post-MVP) |
| **MVP** | Solid color or simple gradient. |
| **Post-MVP** | Procedural sky with time-of-day changes. |

## Reuse Opportunities

- Floor base material is shared across all floors
- Zone overlay material is the same material with different color parameters
- Corridor material is a variant of floor base material
- Ground material is shared across the entire scene
