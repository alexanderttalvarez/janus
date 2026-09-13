# Boy (hoodie visitor) — from `reference_02_3_figures_second_boy.png` to 3D model

**Asset:** `char_boy_hoodie` (stylized low-poly child: blue open hoodie over a white tee,
tan cargo shorts, blue-and-white sneakers)
**Source reference:** [reference_02_3_figures_second_boy.png](reference_02_3_figures_second_boy.png) — front / three-quarter / back
**Model:** [boy.blend](boy.blend) (editable) · [boy.glb](boy.glb) (game-ready, Y-up)
**Generator:** [boy_build.py](boy_build.py) · preview renders: [boy_preview.py](boy_preview.py)

## Reference reading

| View | Used for |
|---|---|
| Front | proportions, open jacket over the tee, cargo shorts, socks, sneakers, face layout |
| Three-quarter | head depth, jacket bulk, cheek/ear shaping, pocket placement |
| Back | hood hanging on the back, hair mass covering the nape |

The reference has a real alpha channel, so the front figure's silhouette (976 px tall
including hair tips) was measured directly and the landmark table below is taken from it as
fractions of total height.

## Dimensions (metres; Z up; origin between the feet on the ground; faces +Y)

| Landmark | Fraction of H | Metres |
|---|---|---|
| Total height (sole → hair tips) | 1.000 | 1.25 |
| Chin / head top | 0.730 / 0.962 | 0.91 / 1.20 |
| Eye line | 0.786 | 0.98 |
| Shoulder / jacket hem | 0.700 / 0.405 | 0.88 / 0.51 |
| Shorts hem / knee | 0.284 / 0.235 | 0.36 / 0.29 |
| Ankle / shoe top | 0.150 / 0.115 | 0.19 / 0.14 |

| Width | Fraction of H | Metres |
|---|---|---|
| Head (skin, with ears) | 0.222 | 0.28 |
| Head + hair (widest) | 0.285 | 0.36 |
| Shoulders / jacket hem | 0.226 / 0.225 | 0.28 |
| Body + sleeves at the elbow line | 0.398 | 0.50 |
| Hips (shorts) | 0.236 | 0.30 |
| Shoe pair outer span | 0.346 | 0.43 |

Six materials — `boy_skin`, `boy_hair_brown`, `boy_jacket_blue`, `boy_cloth_white`,
`boy_shorts_tan`, `boy_eye_dark` — and 2 690 triangles, flat shaded to keep the reference's
faceted low-poly look. The jacket and the white tee are one loft: the front columns are
recessed and re-assigned to the cloth material so the open jacket edge reads in geometry.

## Rebuild

```bash
blender -b -P boy_build.py                                    # boy.blend + boy.glb
blender -b boy.blend -P boy_preview.py -- /tmp/boy_shots      # turnaround renders
python3 reference_contact_sheet.py boy /tmp/boy_shots .freebuff/boy_preview/index.html
```

Every dimension lives in the parameter block at the top of `boy_build.py` (fractions of H
plus a few widths); the script is deterministic, so tuning means editing numbers and
re-running rather than sculpting.

## Open items

- Static mesh only: no armature, no UVs, no LOD. A walk cycle would need a skeleton and
  hand-placed weights, or a re-topology pass first.
- The reference is ~3.7 heads tall, which sits at the stylized end of the style guide's
  "avoid extreme chibi proportions" note. Worth a review if this boy is the family baseline.
- Interchangeable parts (hair, jacket colour) are separate objects, but nothing yet shares
  geometry with the other two figures on the reference sheet.
