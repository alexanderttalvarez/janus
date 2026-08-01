# Terrain & Environment

## Plot Ground Plane

| Property | Value |
|----------|-------|
| **Purpose** | Visible ground surface beneath the building. Shows through unbought tiles and floor holes. |
| **Size** | 50m × 50m minimum (covers single plot). Expandable for multi-plot. |
| **Material** | Simple ground texture or flat color. Warm neutral tone. |
| **MVP** | Flat colored plane (warm gray/beige). |
| **Post-MVP** | Textured ground with subtle variation, grass patches, sidewalk edges. |

## Sky / Background

| Property | Value |
|----------|-------|
| **Purpose** | Background behind the building. Sets atmosphere. |
| **MVP** | Solid color or simple gradient (light blue sky). |
| **Post-MVP** | Gradient sky with subtle clouds, or simple skybox. Changes with time-of-day and season. |

### Day/Night Sky Variations (Post-MVP)

| Time | Sky Color | Lighting |
|------|-----------|----------|
| **Morning (6–9)** | Warm orange/pink gradient | Soft warm light |
| **Midday (9–12)** | Light blue | Bright neutral |
| **Lunch (12–14)** | Bright blue | Strong neutral |
| **Afternoon (14–18)** | Blue with warm tint | Warm golden |
| **Evening (18–21)** | Orange/purple gradient | Warm dim |
| **Night (21–6)** | Dark blue/black | Cool dim, interior lights visible |

## Ground Texture (Post-MVP)

| Property | Value |
|----------|-------|
| **Resolution** | 512×512 or 1024×1024 (tileable) |
| **Style** | Low-poly, subtle variation |
| **Content** | Asphalt/concrete for roads, grass/dirt for open areas |

## Surrounding Context (Post-MVP)

| Element | Description | Detail Level |
|---------|-------------|-------------|
| **Adjacent buildings** | Simple low-poly blocks on neighboring plots | Very low detail, no interiors |
| **Trees** | Scattered around roads and pedestrian areas | Low-poly, 2-3 variations |
| **Street lamps** | Along roads | Simple geometry |
| **Cars** | Parked or moving on roads | Very low-poly, 2-3 variations |

## Seasonal Foliage (Post-MVP)

| Season | Visual Changes |
|--------|---------------|
| **Spring** | Light green foliage, possible blossom particles |
| **Summer** | Full dark green foliage |
| **Autumn** | Orange/brown/red foliage, falling leaf particles |
| **Winter** | Bare branches, possible snow on ground |

## Reuse Opportunities

- Single ground plane mesh, scaled as needed
- Sky is a shader or skybox, not a mesh
- Surrounding buildings can be 2-3 reusable low-poly block shapes with different heights
- Trees: 3 variations reused across the scene
