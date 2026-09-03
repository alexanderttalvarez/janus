# Runtime Performance Baseline

This is an observation-only baseline. No H4/H10 performance policy or release
threshold has been selected.

Captured from the running `res://scenes/levels/main_game.tscn` through
GodotIQ after startup:

| Metric | Value |
| --- | ---: |
| FPS | 60 |
| Draw calls | 172 |
| Total nodes | 680 |
| Objects | 283 |
| Triangles | 9,440 |
| Buffer memory | 27,497,584 bytes |
| Texture memory | 68,452,384 bytes |
| Video memory | 114,633,104 bytes |
| Orphan nodes | 0 |

These values are not a pass against a release budget until Release and
Architecture select the required performance policy and target platform.
