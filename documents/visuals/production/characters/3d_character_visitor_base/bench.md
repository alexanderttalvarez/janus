# Bench — from `bench.png` reference to 3D model

**Asset:** `prop_bench` (stylized backless park bench, timber seat on blue steel frames)
**Source reference:** [bench.png](bench.png) — multi-view sheet, six panels
**Model:** [bench.blend](bench.blend) (editable) · [bench.glb](bench.glb) (game-ready, Y-up)
**Generator:** [bench_build.py](bench_build.py) · preview renders: [bench_preview.py](bench_preview.py)

## Reference reading

| Panel | View | Used for |
|---|---|---|
| A (top-left) | three-quarter from above | slat layout, 3 bolts per end, frame width, rail ends |
| B (top-right) | bench back | **ignored** — not modelled |
| C (mid-right) | front elevation | length : height, seat thickness, no lengthwise stretcher |
| D (bottom-left) | three-quarter front-left | posts splayed in depth, top rail protruding past posts |
| E (bottom-middle) | end elevation | seat depth, leg splay, top + bottom frame rails, feet |
| F (bottom-right) | three-quarter front-right | post cross-section, plinth foot pads |

## Dimensions (metres, Z up, origin at footprint centre on the ground)

| Part | Size |
|---|---|
| Overall | 1.80 × 0.562 × 0.48 (0.493 including bolt domes) |
| Seat | 3 planks, 1.80 × 0.18 × 0.10, 0.011 gaps, top at 0.48 |
| Bolts | 6 blue domes, ⌀0.05, 0.08 in from each plank end |
| Frames | 2 trestles at x = ±0.80: splayed posts 0.12×0.075 (top) → 0.135×0.10 (foot), outer span 0.36 (top) → 0.53 (foot) |
| Frame rails | top rail under the seat (0.055 tall, ends proud of the posts), bottom rail 0.057 tall above the feet |
| Feet | 0.165 × 0.19 plinth pads, 0.055 tall, chamfered |

Wood/orange `bench_wood_orange` `#E58950` (roughness 0.45) and painted steel
`bench_metal_blue` `#42638F` (roughness 0.42, metallic 0.15). 1 836 triangles, flat-shaded
with hard chamfers to match the reference's low-poly faceting.

## Rebuild

```bash
blender -b -P bench_build.py                                   # bench.blend + bench.glb
blender -b bench.blend -P bench_preview.py -- /tmp/bench_shots # comparison renders
python3 reference_contact_sheet.py bench /tmp/bench_shots .freebuff/bench_preview/index.html
```

All geometry comes from the parameter block at the top of `bench_build.py`; the script is
deterministic, so tuning proportions there is the intended way to iterate.

## Open items

- The reference is not a true orthographic turnaround: the end view implies a deeper/lower
  bench than the front view. The front view was treated as authoritative for height and seat
  thickness and the end view for depth and leg splay.
- Destination in the game project is `assets/models/props/` once the bench is tied to the
  amenity/green-space catalogue; palette vs. zone colours (orange = entertainment,
  blue = services) is worth a readability check before it ships.
