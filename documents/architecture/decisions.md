# Architectural Decisions

## Decision 1: Scene Architecture — Single Game Scene with Sub-scene Instancing
**Date:** 2026-07-28
**Status:** Accepted

### Context
The game has many interconnected systems (economy, visitors, tenants, UI, grid). We needed to decide between few large scenes vs. many smaller scenes.

### Decision
Option A: One `main_game.tscn` that composes everything via instanced sub-scenes.

### Rationale
- No scene transitions during gameplay
- All systems coexist naturally
- Simpler state management
- Sub-scenes provide modularity without lifecycle complexity

### Consequences
- The main game scene tree will be large but well-organized
- Sub-scenes must have clean `@export` interfaces
- Cross-sub-scene communication goes through EventBus

---

## Decision 2: UI Rendering — SubViewport for Heatmap Overlay
**Date:** 2026-07-28
**Status:** Accepted

### Context
Heatmaps need to overlay the 3D world. We needed to decide between CanvasLayer and SubViewport.

### Decision
Heatmaps rendered via SubViewport overlaid on the 3D game view.

### Rationale
- Allows shader-driven tile coloring independent of 3D rendering
- Can toggle heatmap on/off without affecting 3D scene
- Clean separation between game world and data visualization

---

## Decision 3: Visitor Agents — Node3D with Centralized Tick + Floor-based Culling
**Date:** 2026-07-28
**Status:** Accepted

### Context
Visitors are individual agents with goals, budgets, needs, and pathfinding. We needed to decide between Node3D per visitor vs. pure data with pooled visuals.

### Decision
Each visible visitor is a Node3D. Invisible visitors exist as data only. Floor-based culling limits visible visitors to ~30-60 at any time.

### Rationale
- "What You See Is What Is Simulated" philosophy is maintained for visible visitors
- Floor-based culling reduces visible count from 200-500 to 30-60
- 30-60 `_process` calls doing simple `move_toward` is trivial for Godot 4
- Thought bubbles are trivial as Label3D children
- Full remote inspector debugging access

### Implementation Details
- **Logic:** Centralized tick in VisitorManager every 5 sim seconds (decisions, pathfinding, state changes)
- **Visual movement:** Each visitor Node3D has `_process` with `position.move_toward(target, speed * delta)` — simple interpolation only
- **Animation:** Set explicitly by VisitorManager on state change (`play("walk")`, `play("idle")`) — no polling
- **Culling rules:**
  - Same floor as camera → render
  - Skybridge/underground passage connected to current floor → render
  - Pedestrian areas → render only if viewing floor 1, 2, or 3
  - Other floors/buildings → data only, no visual
  - Zoomed out past threshold → hide all visitors
- **Draw calls:** Shared material across all visitor meshes → 1 draw call

### Consequences
- VisitorManager manages lifecycle: creates/destroys Node3Ds when floors change visibility
- Visitor data always exists in `all_visitors` array regardless of visibility
- When camera switches floor, Node3Ds are created at current data positions

---

## Decision 4: Wall Rendering — Shader-based Clipping
**Date:** 2026-07-28
**Status:** Accepted

### Context
Wall visualization has 3 modes: Cutaway (front walls 5%, back walls 100%), Partial (all walls 5%), Full (all walls 100%). We needed to decide between shader clipping vs. mesh swapping.

### Decision
A shader clips walls based on camera direction and current visualization mode.

### Rationale
- No mesh swapping needed — single wall mesh works for all modes
- Instant mode transitions (no loading)
- Camera-relative clipping is natural in a shader (dot product of wall normal vs. camera direction)

---

## Decision 5: Heatmap Implementation — Shader-driven Mesh
**Date:** 2026-07-28
**Status:** Accepted

### Context
Heatmaps overlay tile data (visitor density, zone viability) with color gradients. We needed to decide between per-tile overlays, shader-driven mesh, or post-processing.

### Decision
A single shader-driven mesh renders heatmap colors based on tile data passed as uniforms or textures.

### Rationale
- One draw call for the entire heatmap
- No per-tile MeshInstance3D overhead
- Color transitions are smooth and GPU-accelerated
- Easy to swap heatmap modes by changing the data texture

---

## Decision 6: Floor Representation — Instanced Sub-scene (floor.tscn)
**Date:** 2026-07-28
**Status:** Accepted

### Context
Each floor needs structural nodes (floor plane, wall mesh, grid origin) and runtime containers (tiles, circulation, visitors). We needed to decide between instanced sub-scene vs. fully procedural creation.

### Decision
Each floor is an instance of `floor.tscn`. The scene template contains authored structural nodes. Runtime content (tiles, zones, visitors) is added programmatically to container nodes.

### Rationale
- Structural properties (floor plane material, wall shader params, grid origin, floor height) benefit from Inspector editing
- Consistent node structure across all floors — no risk of missing nodes
- Easy to iterate on visuals without code changes
- Natural fit with Godot's scene composition philosophy
- Scales to post-MVP features (terrace containers, column containers, skybridge connection points)

### Floor Scene Structure
```
floor.tscn (Node3D)
├── FloorPlane (MeshInstance3D)       # Ground surface
├── WallMesh (MeshInstance3D)         # All walls, rendered with clipping shader
├── GridOrigin (Marker3D)             # World position of tile (0, 0)
├── TileContainer (Node3D)            # Runtime: tile visuals
├── CirculationContainer (Node3D)     # Runtime: stairs, elevators
├── ZoneContainer (Node3D)            # Runtime: zone overlays
├── VisitorContainer (Node3D)         # Runtime: visitor Node3Ds
├── IndicatorContainer (Node3D)       # Runtime: contextual indicators
└── script: floor.gd
```

### Consequences
- Tiles, zones, and elements are always created at runtime (625 per floor is too many to author)
- GridManager creates and manages floor instances at game start / on floor unlock
- Each floor instance is positioned at the correct Y height by GridManager

---

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

---

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
│       └── connections: Array[PlotConnection]  # empty in MVP
```

### Consequences
- `PlotData` class added to `scripts/grid/plot_data.gd`
- `DEFAULT_PLOT` constant in GridManager
- Convenience methods (`get_tile_at()`, `get_floor_grid()`) default to `DEFAULT_PLOT`
- Full methods (`get_tile(plot_id, ...)`) available for cross-plot operations

---

## Decision 9: Footprint Masks — Text Files for Plot/Floor Shapes
**Date:** 2026-07-28
**Status:** Accepted

### Context
Post-MVP scenarios need irregular plot shapes, pre-occupied tiles, and varying floor footprints. We needed a data-driven way to define which tiles exist on each floor.

### Decision
Footprint masks are plain text files. Each character represents one tile. Lines represent rows (Y axis). Comments start with `#`.

### Character Legend
| Char | Meaning |
|---|---|
| `.` | Valid tile (can be purchased and built on) |
| `x` | Invalid tile (no tile exists here) |
| `o` | Pre-occupied tile (exists, owned, can't be purchased) |
| `#` | Comment line (ignored) |

### Rationale
- Editable in any text editor (no image editor needed)
- 1 char = 1 tile — obvious and precise
- Text diff in version control (clear change history)
- Self-documenting (can add header comments)
- Trivial to parse (~20 lines of GDScript)

### File Location
`resources/plots/footprints/` — one `.txt` file per floor shape.

### Loading
`FootprintLoader` static class parses text files into `Array[Array[bool]]` (footprint) and `Array[Vector2i]` (pre-occupied positions). `FloorDefinition` loads its footprint at runtime from `footprint_path`.

### Consequences
- `FootprintLoader` class in `scripts/grid/footprint_loader.gd`
- `FloorDefinition.footprint_path` replaces `footprint_mask: Texture2D`
- Pathfinding checks `is_valid_tile(x, y)` before adding neighbors
- MVP uses `25x25_full.txt` (all dots)

---

## Pending Decisions
- Zone system architecture (storage, validation, frontage-based splitting)
- Time system architecture (dual timer: simulation clock + visual clock)
- Economy system architecture (money tracking, rent, loans)
- UI panel architecture (stacking, lifecycle, communication)
- Save/load architecture (what to save, serialization format)
- Undo/redo system architecture
- (More to come)
