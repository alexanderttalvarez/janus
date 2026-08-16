## Decision 8: Plot Scalability — Multi-Plot Ready from Day One
**Date:** 2026-07-28
**Status:** Accepted

### Context
MVP has a single 25×25 plot. Post-MVP adds multiple plots with roads, skybridges, and underground passages. We needed to decide whether to hardcode single-plot or design for multi-plot from the start.

### Decision
GridManager manages a `Dictionary` of `PlotData` objects. Each `PlotData` contains its own `Dictionary` of `FloorGrid` objects. MVP uses exactly one plot (`plot_0`). Convenience methods default to `DEFAULT_PLOT` so existing code doesn't need to change.

### Rationale
- Avoids a 5+ system refactor when adding multi-plot
- Extra indirection is one dictionary lookup — negligible cost
- Pathfinding graph already supports inter-plot edges
- Synergy system already supports cross-plot distance calculations

### Structure
```
GridManager
├── plots: Dictionary[String, PlotData]
│   └── "plot_0" (PlotData)
│       ├── floors: Dictionary[String, FloorGrid]
│       ├── boundary: Rect2i
│       ├── pedestrian_boundary: Rect2i
│       ├── spawn_points: Array[SpawnPointData]  # four derived corner anchors
│       └── connections: Array[PlotConnection]  # empty in MVP
```

### Visitor Spawn Points

Each plot derives four stable spawn points from its building and pedestrian boundaries:

- `plot_id_corner_nw`
- `plot_id_corner_ne`
- `plot_id_corner_se`
- `plot_id_corner_sw`

The points are positioned at the four pedestrian-ring corners using the plot
geometry and a configurable pedestrian margin. They are data owned by
`PlotData`; `PedestrianArea` only provides traversal geometry, and
`VisitorManager` consumes the points for spawning and voluntary exits.

The MVP attempts one spawn per visitor tick until the active visitor count
reaches 20. This policy is population-based and remains valid when additional
plots are introduced.

### Consequences
- `PlotData` class added to `scripts/grid/plot_data.gd`
- `DEFAULT_PLOT` constant in GridManager
- Convenience methods (`get_tile_at()`, `get_floor_grid()`) default to `DEFAULT_PLOT`
- Full methods (`get_tile(plot_id, ...)`) available for cross-plot operations
