# Style Guide — Project Janus

## Confirmed Direction (from Game Design Documents)

### Visual Identity

| Aspect | Direction | Source |
|--------|-----------|--------|
| **Art style** | Low-poly 3D with clean, modern aesthetics | concept.md |
| **Color palette** | Warm neutrals with accent colors for zones and services | concept.md |
| **Lighting** | Soft, natural. Atriums and gardens should feel luminous | concept.md |
| **Camera** | Isometric, rotatable in 90° increments, zoomable | concept.md |
| **Tone** | Serene, professional, aspirational. Architectural visualization meets playful simulation | concept.md |
| **Reference games** | Cities: Skylines, Two Point Hospital, Dorfromantik, Mini Metro, Project Highrise, Townscaper, Planet Coaster | concept.md |

### Zone Colors (Confirmed)

| Zone Type | Color | Purpose |
|-----------|-------|---------|
| **Retail** | Purple | Zone overlay, perimeter lines, UI |
| **Food & Beverage** | Green | Zone overlay, perimeter lines, UI |
| **Entertainment** | Orange | Zone overlay, perimeter lines, UI |
| **Services** | Blue | Zone overlay, perimeter lines, UI |
| **Anchor** | Red | Zone overlay, perimeter lines, UI |

### Heatmap Colors (Confirmed)

| Heatmap Mode | Hot | Medium | Cold |
|-------------|-----|--------|------|
| **Visitor Density** | Red/Orange | Yellow | Blue/Dim |
| **Zone Viability** | Green (healthy) | Yellow (at risk) | Gray (vacant) |

### UI Philosophy (Confirmed)

- The build view should feel clean. The world is the focus, not panels and numbers.
- Informational windows are toggled on demand.
- Contextual indicators appear near relevant elements, not as global alerts.
- HUD is compact and non-intrusive.

---

## Open Questions — Need Human Input

### Visual Identity

1. **Low-poly detail level**: How low? Think *Townscaper* (very abstract, almost blocky) or *Two Point Hospital* (recognizable shapes, simplified details) or somewhere in between?

2. **Color palette specifics**: "Warm neutrals" is a direction. Do you have specific hex values or a reference palette? Should the warm neutrals lean more toward beige/cream or toward gray/stone?

3. **Accent colors**: The zone colors (purple, green, orange, blue, red) are confirmed. Should these be saturated/bright (game-y) or muted/sophisticated (architectural)?

4. **Sky / background**: What should the sky look behind the building? Solid color? Gradient? Simple clouds? Full skybox?

5. **Surrounding context**: The plot sits in a "neighborhood." Should the area outside the plot be visible? If so, what level of detail? Simple ground plane? Surrounding buildings as backdrop? Trees and streets?

6. **Day/night cycle visuals**: The visual clock drives a day/night cycle. How dramatic should the lighting change be? Subtle warm/cool shift? Full dark at night with interior lights?

7. **Seasonal visuals**: Seasons affect foliage and decorations. What visual changes per season? (Spring: blossoms, Summer: lush green, Autumn: orange/brown, Winter: bare/snow?)

### Audio Identity

8. **Music genre**: What style of background music? Ambient electronic? Lo-fi? Acoustic? Orchestral? Minimal piano?

9. **Music mood**: Relaxing and meditative? Upbeat and productive? Neutral background?

10. **SFX style**: Realistic (actual mall sounds)? Minimal/abstract (soft clicks and whooshes)? Cartoonish? Retro?

11. **Ambient sound**: Should there be background mall ambience (murmuring crowd, distant music, HVAC hum)? Or keep it silent except for UI/interaction sounds?

### Consistency Rules

12. **Target platform**: Desktop only? Or mobile consideration? (Affects texture resolution, polygon count, UI sizing)

13. **Texture resolution**: Standard 512×512 for props? 1024×1024 for larger surfaces? Or keep everything at a single resolution?

14. **Polygon budget**: Any target triangle count per visitor mesh? Per prop? Per floor segment?

15. **File format preferences**: GLB for 3D models? PNG for textures? OGG for audio? Or different preferences?

---

## MVP Visual Priorities

For MVP gameplay testing, the following visual elements are **essential**:

1. **Floor plane** — visible grid surface
2. **Walls** — with cutaway/partial/full modes
3. **Zone color overlays** — purple/green/orange/blue/red per tile
4. **Visitor mesh** — simple capsule or low-poly humanoid
5. **Staff meshes** — 2 types (Cleaner, Security) with color-coded uniforms
6. **Stairs model** — basic stair geometry
7. **Elevator model** — shaft + lobby + cab
8. **Basic UI** — HUD bar, toolbar, panel frames
9. **Heatmap overlay** — shader-driven color gradient
10. **Construction phase visuals** — 3 stages (scaffolding → framing → finishing)
11. **Garbage sprite** — small floor decal
12. **Thought bubble** — Label3D above visitors

Everything else can be placeholder geometry (colored boxes, cylinders) until post-MVP.
