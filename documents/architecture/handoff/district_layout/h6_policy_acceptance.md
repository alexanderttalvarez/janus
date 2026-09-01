# H6 Policy Selection Record

**Status:** Provisional implementation policy, approved for implementation by Design direction.

## Camera infrastructure margin

Selected alternative: **B — road-profile-relative**.

The implementation derives the margin from the committed H5 road profile:

```
margin_quarter = max(all pedestrian_band_cross_depth + carriageway_cross_depth / 2)
margin_world = margin_quarter * grid_unit_size / 4
```

The calculation is deterministic, uses all committed segment profiles, and rejects an empty or non-positive profile. The margin is presentation-only and never mutates District Runtime state.

## Legacy 20-purchased-tile rule

Selected alternative: **A — remove at migration**.

The H6 camera no longer applies the legacy radial purchased-tile rule. Camera movement is constrained exclusively by the expanded Active Plot rectangle union. The legacy adapter only exposes canonical Active Plot records and does not apply the removed rule.

These values are intentionally provisional and may be revised by a later architecture/design decision without changing H3 authority state.
