## Decision 7: Grid Data Structure — Per-Floor 2D Arrays Managed by GridManager
**Date:** 2026-07-28
**Status:** Accepted

### Context
Tile data must be stored, queried, and updated efficiently. The grid supports pathfinding, zone placement, wall generation, heatmaps, and synergy calculation. We needed to decide between 3D array, dictionary, flat array, or per-floor grids.

### Decision
GridManager owns a `Dictionary` mapping floor level strings (e.g., "F1", "U1") to `FloorGrid` objects. Each `FloorGrid` contains a 2D array `tiles[x][y]` of `TileData` objects.

### Rationale
- Mirrors the floor-as-scene architecture: one FloorGrid per floor.tscn instance
- Each floor can have different dimensions (design doc allows upper floors to be smaller)
- Dynamic floor addition/removal is natural (add/remove dictionary entries)
- FloorGrid can own its own pathfinding sub-graph
- Zone operations are floor-local (player paints zones on one floor at a time)
- TileData is lightweight (~8 fields), 625 per floor is negligible memory

### TileData Structure
```
class TileData:
    owned: bool
    floor_built: bool
    walls_built: bool
    zone_id: String
    element: TileElement (enum: None, Shop, Decoration, Column, Circulation, Amenity)
    typology: TileTypology (enum: Tenant, Decoration, Transit)
    condition: int (0-100, for maintenance post-MVP)
```

### Pathfinding
GridManager maintains a unified layered pathfinding graph:
- Each FloorGrid contributes internal edges (adjacent walkable tiles)
- Circulation elements (stairs, elevators) contribute cross-floor edges
- Visitors query the graph, not the tile arrays directly
- A* runs on the combined graph

### Consequences
- Cross-floor queries require iterating multiple FloorGrids (acceptable — rare operation)
- Save/load serializes each FloorGrid independently
- GridManager is the single authority for tile data and pathfinding
