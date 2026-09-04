# H6 Policy Selection Record

**Status:** Design-selected and architecture-validated policy — 2026-09-03.

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

The H6 camera no longer applies the legacy radial purchased-tile rule. Camera movement is constrained exclusively by the expanded Active Plot plus Progression-selected/unlocked Plot rectangle union. The legacy adapter exposes canonical Active Plot records while H6 reads selected/unlocked Plot IDs from Progression; neither applies the removed rule.

These approved presentation policies may change only through a later architecture/design decision and never change H3 authority state.
