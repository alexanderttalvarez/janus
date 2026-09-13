# Litter bin — from `bin.png` reference to 3D model

**Asset:** `prop_bin` (stylized square composite litter bin: chamfered plinth, four corner
posts, cream shell panels, cyan roof slab, pictogram plate)
**Source reference:** [bin.png](bin.png) — big three-quarter view on the left, eight smaller panels on the right
**Model:** [bin.blend](bin.blend) (editable) · [bin.glb](bin.glb) (game-ready, Y-up)
**Generator:** [bin_build.py](bin_build.py) · preview renders: [bin_preview.py](bin_preview.py)

## Reference reading

| Panel | View | Used for |
|---|---|---|
| left (large) | three-quarter hero | stacking order, plinth corner cut, panel bevels, pictogram |
| top row #1 | front elevation with pictogram | plate size/position, pictogram size, bolt row |
| top row #2 | front elevation, plain panel | bolt placement, top-opening read, shell width |
| top row #4 | roof plan | square slab, mitred top bevel, corner facets |
| bottom row 1–4 | three-quarter views | corner posts, rim thickness, liner rim below the shell rim |

## Dimensions (metres, Z up, origin at footprint centre on the ground)

| Part | Size |
|---|---|
| Overall | 0.601 × 0.601 × 1.100 (roof overhangs the shell by 36.5 mm per side) |
| Roof | 0.601 square slab, 0.166 thick, top face inset 0.066 by a 45° bevel, mitred corners |
| Plinth | 0.608 square × 0.115 tall, 0.045 corner cuts in plan, 0.022 × 0.032 top chamfer |
| Corner posts | 4 navy columns 0.070 square, 0.819 tall (plinth top → roof underside) |
| Shell | 4 cream walls 0.388 × 0.030 × 0.633 between the posts, flush with the post faces |
| Liner | navy inner box, 0.018 walls, rim 8 mm below the shell rim |
| Bolts | 16 navy domes (4 per wall face), ⌀0.035, inset 0.046 from the wall edges (0.069 below the rim) |
| Pictogram plate | 0.326 × 0.416 blue plate, 0.010 proud, bottom 0.179 above the ground |
| Pictogram | white relief parts, 0.213 × 0.289, stepped 0.25 mm in depth so overlaps never z-fight |

Palette: navy `bin_frame_navy` `#33567C` (roughness 0.44, metallic 0.10), cream
`bin_shell_cream` `#F3D8B2`, cyan `bin_roof_cyan` `#31B3CE`, sign blue `bin_sign_blue`
`#0E79AD`, pictogram `bin_mark_white` `#F2EFE6`. 2 540 triangles across 43 named meshes
under a `prop_bin` empty, flat-shaded with hard chamfers to match the reference's faceting.

Colour and proportion reference: the front elevation is 344 px tall and is taken as 1.10 m,
so 1 px ≈ 3.2 mm. Measured model-vs-reference ratios agree within 1%: roof width 0.541 vs
0.547 of height, shell width 0.473 vs 0.480, plinth width 0.548 vs 0.544, plate 0.296 × 0.378
vs 0.297 × 0.378.

## Orientation

The pictogram faces **+Y in Blender**, which exports as Godot's **-Z forward**. `bin_preview.py
front` therefore renders from +Y. The pictogram is built from its own viewer-space coordinates
and mirrored into place, so it reads the right way round for anyone standing in front of the
bin.

## Rebuild

```bash
blender -b -P bin_build.py                                     # bin.blend + bin.glb
blender -b bin.blend -P bin_preview.py -- /tmp/bin_shots       # comparison renders
blender -b bin.blend -P bin_preview.py -- /tmp/bin_alpha front,end alpha   # transparent film
python3 reference_contact_sheet.py bin /tmp/bin_shots .freebuff/bin_preview/index.html
```

All geometry comes from the parameter block at the top of `bin_build.py`; the script is
deterministic, so tuning proportions there is the intended way to iterate. The `alpha` third
argument renders with a transparent film, which is what the reference-vs-model proportion
diff uses (bin.png carries a usable alpha channel too).

## Open items

- The roof-plan panel shows two navy tabs protruding past the slab's left and right edges,
  which cannot be the posts: the front elevation has the roof 0.0365 wider than the post span
  on every side. The front elevation was treated as authoritative and the tabs left unmatched.
- The front elevation's dark band at the top of the shell is read as the navy liner seen
  through the open top (the camera sits above roof height in the reference), not as a separate
  front slot; the same dark band appears in every three-quarter panel, which this reading explains.
- No UVs, LODs or collision: it is a static mesh. The pictogram is geometry rather than a
  texture, so nothing needs importing alongside the GLB and it stays crisp at any zoom.
- `bin.fbx` (already in this folder, imported by Godot since 12 Sep) is unrelated to this
  reference: a single unnamed `Mesh_0` at 50 000 triangles, 0.91 × 0.79 × 0.49 m with no
  materials. Nothing here overwrites it, but the two now share a name stem, so whichever the
  game actually uses should be the one that survives.
- The sheet lives in the *character* production folder (like `bench.png` and the boy sheet).
  The natural home is `assets/models/props/`, referenced from the amenity catalogue, which is
  also where a footprint/collision shape and a bin-versus-recycling variant would be defined.
