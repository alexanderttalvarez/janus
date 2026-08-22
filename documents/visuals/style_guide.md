```markdown
# Style Guide — Project Janus

## Confirmed Direction

### Visual Identity

| Aspect | Direction | Status |
|--------|-----------|--------|
| **Art style** | Stylized low-poly 3D with simple geometry, clean silhouettes, flat or nearly-flat materials, and minimal texture dependence | Confirmed |
| **Detail level** | Simplified but recognizable. More detailed than highly abstract/blocky low-poly, but substantially simpler than realistic 3D. Comparable in production philosophy to *Parkitect* and *Pocket City 2* | Confirmed |
| **Primary visual references** | *Parkitect*, *Pocket City 2* | Confirmed |
| **Secondary aesthetic influence** | Japanese City Pop illustration — primarily for palette, lighting, atmosphere, and graphic character | Confirmed |
| **Architecture** | Contemporary Japanese commercial and urban architecture, simplified into readable low-poly forms | Confirmed |
| **Color philosophy** | Soft but vibrant colors, strong color blocking, restrained saturation, minimal surface noise | Confirmed |
| **Lighting** | Soft and stylized during the day; blue ambient environment with warm interiors and restrained colorful commercial lighting at night | Confirmed |
| **Camera** | Isometric / elevated 3D view, rotatable in 90° increments, zoomable | Confirmed |
| **Tone** | Cheerful, clean, inviting, slightly nostalgic, playful but not childish | Confirmed |
| **Visual priority** | Gameplay readability and asset consistency over realism or individual asset detail | Confirmed |

---

## Visual Reference Hierarchy

Visual references should not all be interpreted in the same way.

### Primary Style Reference

The selected visual direction is based primarily on the second generated Janus visual reference.

It defines:

- overall softness of the palette,
- amount of saturation,
- geometric simplification,
- clean low-poly construction,
- material simplicity,
- approximate environmental detail,
- vegetation language,
- commercial signage density,
- balance between playful and architectural forms.

It should be treated as the main visual benchmark when evaluating newly generated assets.

### Night Lighting Reference

The approved nighttime variation defines the intended nighttime atmosphere.

It establishes:

- dark blue / deep blue ambient illumination,
- warm yellow-orange light from interiors,
- restrained pink/coral commercial signage,
- occasional cyan/turquoise accents,
- high readability despite darkness,
- localized illumination rather than excessive global neon.

Nighttime Janus should feel lively and atmospheric without becoming cyberpunk, synthwave, or neon-heavy.

### Other Generated References

Other Janus style experiments may be used as secondary references for:

- alternative shapes,
- architecture,
- signage,
- composition,
- vegetation,
- individual ideas.

They should not override the primary style reference.

---

# Shape Language

## General Geometry

Assets should generally use:

- simple geometric masses,
- clean silhouettes,
- large readable shapes,
- limited beveling,
- restrained curvature,
- slightly exaggerated proportions where this improves readability.

Visual interest should come primarily from:

1. silhouette,
2. proportions,
3. color blocking,
4. modular details,
5. signage,
6. lighting.

Not from:

- complex textures,
- surface damage,
- tiny geometry,
- realistic material imperfections.

---

## Low-Poly Detail Level

The target is approximately:

**Pocket City 2 / Parkitect-like simplification**

rather than:

- ultra-abstract block geometry,
- voxel art,
- realistic architectural visualization,
- highly detailed stylized 3D.

Objects should be recognizable from the normal gameplay camera without requiring small texture details.

A useful rule:

> If a detail cannot be read from the normal gameplay camera and does not affect silhouette, gameplay, or identity, it probably does not need geometry.

---

# Materials

## General Material Philosophy

Prefer:

1. flat color,
2. subtle roughness variation,
3. simple reusable materials,
4. textures only where necessary.

Materials should generally be:

- matte,
- clean,
- slightly soft,
- low-noise,
- non-photorealistic.

Avoid:

- grunge,
- dirt-heavy surfaces,
- realistic concrete noise,
- scratches,
- weathering as a default,
- highly reflective materials,
- complex PBR detail.

---

## Texture Philosophy

Unique textures should not carry the visual identity of most assets.

Whenever possible, prefer:

- reusable material palettes,
- trim sheets,
- atlases,
- decals,
- procedural color variation,
- geometry-based detail.

Textures should support the geometry rather than compensate for weak geometry.

---

# Color Direction

## Core Palette Philosophy

Janus uses a palette inspired by Japanese City Pop aesthetics but softened for continuous gameplay use.

The palette should feel:

- colorful,
- optimistic,
- harmonious,
- slightly nostalgic,
- clean.

City Pop is an **influence**, not a strict theme.

The game should not visually become:

- vaporwave,
- synthwave,
- cyberpunk,
- neon Tokyo,
- retro-futurist.

---

## Core Color Families

Exact production hex values should eventually be stored in a dedicated palette file.

Current target families:

| Family | Typical Use |
|--------|-------------|
| **Cream / warm off-white** | Walls, neutral architecture, floors |
| **Soft beige / sand** | Architecture, interiors, secondary surfaces |
| **Sky blue** | Exterior accents, environmental elements |
| **Cyan / turquoise** | Commercial accents, awnings, selected architecture |
| **Coral / salmon** | Shop accents, signage, decorative elements |
| **Soft pink** | Selected retail elements, vegetation, signage |
| **Warm yellow** | Highlights, lighting, selected accents |
| **Muted green** | Vegetation, landscaping |
| **Deep blue** | Shadows, roofs, nighttime environment |
| **Blue-purple** | Night ambience and selected accent surfaces |

Avoid making every asset contain the entire palette.

Most individual objects should use:

- 1 dominant color,
- 1 secondary color,
- 1 accent color,
- optional neutral.

---

# Zone Colors

Zone colors communicate gameplay information and are separate from the environmental palette.

| Zone Type | Color | Purpose |
|-----------|-------|---------|
| **Retail** | Purple | Zone overlay, perimeter lines, UI |
| **Food & Beverage** | Green | Zone overlay, perimeter lines, UI |
| **Entertainment** | Orange | Zone overlay, perimeter lines, UI |
| **Services** | Blue | Zone overlay, perimeter lines, UI |
| **Anchor** | Red | Zone overlay, perimeter lines, UI |

These colors should remain immediately distinguishable even when displayed over colorful environments.

Environmental objects should avoid using zone colors in ways that create gameplay ambiguity.

---

# Heatmap Colors

| Heatmap Mode | Hot | Medium | Cold |
|-------------|-----|--------|------|
| **Visitor Density** | Red / Orange | Yellow | Blue / Dim |
| **Zone Viability** | Green | Yellow | Gray |

Heatmap visualization has priority over environmental color accuracy while active.

The underlying environment may be desaturated or dimmed if necessary to improve heatmap readability.

---

# Day Lighting

Daytime environments should feel:

- bright,
- soft,
- clean,
- colorful,
- welcoming.

Target characteristics:

- soft directional sunlight,
- gentle shadows,
- restrained contrast,
- readable shaded areas,
- no physically harsh exposure extremes,
- slightly warm neutral light.

Atriums, gardens, plazas, and large interior spaces should feel luminous.

---

# Night Lighting

Nighttime is an important part of Janus's visual identity.

The goal is not simple darkness.

Instead use:

### Environment

- deep blue ambient light,
- blue-purple shadows,
- readable silhouettes,
- reduced but preserved environmental color.

### Interiors

- warm yellow / amber lighting,
- visible shop interiors,
- bright windows,
- inviting commercial spaces.

### Commercial Lighting

Use selectively:

- coral,
- pink,
- warm red,
- cyan,
- turquoise.

Avoid turning every sign or building edge into neon.

### Contrast Principle

Nighttime should create a visual relationship between:

**cool environment**
+
**warm interiors**
+
**restrained colorful commercial accents**

This contrast is a major component of the intended Janus identity.

Gameplay information must remain easy to read at night.

---

# Japanese Visual Identity

Japanese identity should primarily emerge from environmental design rather than stereotypes or decorative overload.

Useful visual elements include:

- compact storefronts,
- vertical signage,
- awnings,
- vending machines,
- exterior AC units,
- bicycles,
- small planted areas,
- rooftop equipment,
- utility boxes,
- convenience-store-like glazing,
- restaurant lanterns,
- commercial signs,
- transit infrastructure,
- narrow service elements,
- rooftop gardens,
- pedestrian-oriented details.

These elements should be simplified according to the Janus low-poly language.

Avoid excessive use of Japanese text solely as decoration.

---

# Architecture

Architectural forms should feel believable while remaining stylized.

Prefer:

- clear structural volumes,
- modular façades,
- readable floor divisions,
- large windows,
- simplified frames,
- flat roofs,
- rooftop utility elements,
- awnings,
- external signs,
- terraces,
- occasional vegetation.

Avoid overly complex façade topology.

Where gameplay construction systems are involved, modularity takes priority over unique architectural detail.

---

# Vegetation

Vegetation should use the same simplified geometric language.

Prefer:

- stylized tree crowns,
- clearly separated foliage masses,
- simple trunks,
- low-detail shrubs,
- geometric planters,
- clean silhouettes.

Seasonal variants may modify:

- foliage color,
- foliage density,
- blossoms,
- ground decoration.

Potential seasonal direction:

| Season | Visual Direction |
|--------|------------------|
| **Spring** | Fresh greens, selective pink blossoms |
| **Summer** | Full green vegetation |
| **Autumn** | Warm ochre / orange / muted red accents |
| **Winter** | Reduced foliage, cooler palette; snow only if gameplay/design explicitly requires it |

---

# Characters

Characters should remain readable at small gameplay scale.

Target direction:

- stylized low-poly,
- simplified proportions,
- strong silhouettes,
- restrained facial detail,
- simple clothing color blocking.

Avoid:

- realistic humans,
- highly detailed faces,
- extreme chibi proportions unless later explicitly approved.

Character complexity should reflect their small on-screen size.

---

# UI Philosophy

- The world is the primary visual focus.
- HUD should remain compact and non-intrusive.
- Informational windows appear on demand.
- Contextual indicators should appear near relevant world elements where practical.
- UI should use the game's palette without competing with gameplay overlays.
- Icons should prioritize silhouette and meaning over decoration.
- UI should visually belong to the same clean, soft, modern world as the 3D environment.

---

# Asset Production Principles

Every visual asset should satisfy these rules:

1. **Readable at gameplay distance**
2. **Clear silhouette**
3. **Simple geometry**
4. **Limited material count**
5. **Minimal texture dependence**
6. **Compatible with day and night lighting**
7. **Consistent with the approved visual references**
8. **Reusable or modular where reasonable**
9. **Reasonable for AI-assisted production**
10. **Easy to modify and regenerate**

Asset consistency is more important than maximizing the visual quality of a single asset.

---

# AI-Assisted Asset Generation

AI-generated assets should not automatically be treated as game-ready.

For generated 3D assets, expect potential cleanup involving:

- topology,
- scale,
- pivot,
- normals,
- UVs,
- materials,
- disconnected geometry,
- excess polygons,
- collision,
- naming.

Reference images intended for image-to-3D generation should preferably use:

- isolated object,
- neutral background,
- clear silhouette,
- even lighting,
- minimal cast shadows,
- no depth of field,
- full object visible,
- consistent proportions.

Presentation artwork and 3D reconstruction references are different deliverables and should not be confused.

---

# MVP Visual Priorities

For MVP gameplay testing, the following visual elements are essential:

1. **Floor plane** — visible grid surface
2. **Walls** — with cutaway / partial / full modes
3. **Zone color overlays**
4. **Visitor mesh**
5. **Staff meshes** — Cleaner and Security
6. **Stairs model**
7. **Elevator model**
8. **Basic UI**
9. **Heatmap overlay**
10. **Construction phase visuals**
11. **Garbage sprite / decal**
12. **Thought bubble / world-space indicator**

Everything else may use placeholder geometry until production quality is necessary.

---

# Open Questions

## Technical Art

1. What polygon budgets should be used for:
   - visitors,
   - small props,
   - furniture,
   - large props,
   - architectural modules?

2. What texture resolutions should be standard?

3. Should assets rely primarily on:
   - material colors,
   - shared palettes,
   - texture atlases,
   - trim sheets,
   - individual textures?

4. What is the standard 3D interchange format?
   - GLB recommended unless pipeline requirements suggest otherwise.

5. What conventions should be used for:
   - pivots,
   - forward axis,
   - up axis,
   - object naming,
   - material naming?

6. Are LODs required?

7. What are the target hardware requirements?

---

## Audio Identity

The visual City Pop influence does not automatically determine the musical style.

Still to decide:

1. Background music genre
2. Music energy level
3. Degree of City Pop influence, if any
4. SFX realism vs stylization
5. Mall ambient sound philosophy
6. Day/night audio differences
7. Music layering / dynamic music strategy

---

# Visual Validation Checklist

Before accepting a visual asset, verify:

- Does it read correctly from gameplay distance?
- Does its silhouette communicate its purpose?
- Is it appropriately simplified?
- Does it use Janus's material language?
- Does it fit the approved palette?
- Does it work during both day and night?
- Does it contain unnecessary detail?
- Does it resemble the approved references rather than generic AI low-poly art?
- Can similar assets be produced consistently?
- Does it introduce visual noise into crowded scenes?
- Is its production complexity justified by its gameplay importance?
```
