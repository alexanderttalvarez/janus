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

## Decision 10: Zone System Architecture
**Date:** 2026-07-28
**Status:** Accepted

### Context
Zones are the player's primary creative tool. They require data management, a complex splitting algorithm, input handling for painting/editing, and visual rendering. We needed to decide on ownership, algorithm structure, visual approach, and tool architecture.

### Decision
- **ZoneManager** owns zone data (separate from GridManager)
- **ZoneSplitter** and **ZoneBusinessAssigner** are pure static classes
- **ZoneTool** handles input and preview (separate from data management)
- **Zone visuals** use a shader-driven overlay (one MeshInstance3D per floor)
- **Wall mode** is a global visualization setting (not per-zone), managed by GameManager

### Zone System Structure
```
ZoneManager (Node)                    ← Zone data ownership, lifecycle, synergy
├── zones: Dictionary[String, ZoneData]
├── create_zone()
├── modify_zone()
├── delete_zone()
├── recalculate_synergy()
└── get_zone_at_tile()

ZoneSplitter (static class)           ← Pure function: zone → parcels
└── split(zone, grid) → Array[Parcel]

ZoneBusinessAssigner (static class)   ← Pure function: parcels → business assignments
└── assign(parcels, zone_type) → void

ZoneTool (Node, in UI layer)          ← Input handling, painting, preview
├── handle_input()
├── update_preview()
└── Signals: zone_created, zone_modified, zone_deleted

ZoneData (Resource)                   ← Zone data container
├── id: String
├── type: String
├── subtype: String (assigned after splitting)
├── floor: String
├── tiles: Array[Vector2i]
├── typologies: Dictionary[Vector2i, TileTypology]
├── wall_mode: bool
├── name: String
└── parcels: Array[Parcel]
```

### Communication Flow
1. Player clicks to paint → `ZoneTool` captures input, shows preview
2. Player clicks "Finish Zone" → `ZoneTool` emits `zone_created(type, tiles, floor)`
3. `ZoneManager` receives signal → creates `ZoneData`, marks tiles in `GridManager`
4. `ZoneManager` calls `ZoneSplitter.split()` → gets parcels
5. `ZoneManager` calls `ZoneBusinessAssigner.assign()` → assigns subtypes
6. `ZoneManager` emits `zone_created` on EventBus → UI updates, synergy recalculates

### Zone Visuals
- One `MeshInstance3D` per floor covers the entire grid
- Shader reads zone ID from a texture (zone_id_texture) and colors each tile
- Hover preview: set shader uniform for hover zone ID
- Painting: update zone_id_texture pixel values
- One draw call per floor for all zone overlays

### Rationale
- Clean separation: GridManager (tiles/pathfinding) vs ZoneManager (zones/splitting)
- Splitting is a pure function → easy to unit test, easy to iterate
- ZoneTool handles input → doesn't pollute ZoneManager with UI concerns
- Shader overlay → one draw call per floor, scalable to large zones
- Wall mode is global → GameManager tracks it, shader reads it

### Consequences
- `ZoneSplitter` and `ZoneBusinessAssigner` have no Godot dependencies (pure GDScript)
- Zone texture updates require careful synchronization (update texture when zone changes)
- ZoneTool must coordinate with GridManager for tile validation during painting

---

## Decision 11: Zone Splitting Algorithm — Full Recalculation with Tenant Preservation
**Date:** 2026-07-28
**Status:** Accepted

### Context
When a zone is edited (tiles added/removed, typologies changed), the frontage-based splitting algorithm must re-run. We needed to decide between incremental updates vs. full recalculation, and how to handle tenant preservation.

### Decision
- **Full recalculation** on every zone edit. The splitting algorithm is fast (pure GDScript on small arrays, milliseconds).
- **Tenant preservation** by spatial matching: after recalculation, existing parcels are matched to new parcels by overlap. If a parcel still meets minimum size, its tenant is preserved.
- **Eviction** only when a parcel falls below its minimum tile requirement after tile removal.
- **ZoneSplitter** and **ZoneBusinessAssigner** are pure static classes with no Godot dependencies.

### Algorithm Phases
1. **Detect Frontage:** Find zone tiles bordering walkable areas (corridors, transit)
2. **Reserve Frontages:** Group contiguous frontage tiles into segments, distribute to target store count
3. **Grow Rectangles:** Each frontage seed grows inward until target area or boundary
4. **Validate and Repair:** Merge undersized parcels, fill gaps, ensure frontage connectivity
5. **Assign Businesses:** Graph coloring to prevent adjacent same-subtype parcels

### Update Flow
```
Player edits zone (add/remove tiles, change typology)
    ↓
ZoneManager identifies affected parcels
    ↓
For each affected parcel:
    if new_tile_count < min_area → mark for eviction
    else → preserve tenant
    ↓
Evicted tenants trigger:
    - 1-week exclusivity lock
    - EventBus.tenant_closed
    - Prestige recalculation
    ↓
ZoneSplitter.split() re-runs on updated zone
    ↓
Existing tenants matched to new parcels by spatial overlap
    ↓
ZoneBusinessAssigner.assign() for new unassigned parcels
    ↓
New tenant applications begin (after 1-day delay)
```

### Rationale
- Incremental updates are exponentially more complex (split parcels, new frontage distribution, edge cases)
- Full recalculation is fast enough (milliseconds on 25×25 grid)
- Tenant preservation is the critical concern, not geometry recalculation
- Design doc says "AI recalculates" — full recalculation is the intended behavior

### Consequences
- `ZoneSplitter` and `ZoneBusinessAssigner` are easily unit-testable
- Zone edits are atomic: either the full recalculation succeeds, or it fails and the zone reverts
- Eviction logic is simple: tile count vs. minimum area

---

## Decision 12: Time System Architecture — Accumulated Time with EventBus Signals
**Date:** 2026-07-28
**Status:** Accepted

### Context
Janus has three independent timers (simulation clock, visual clock, visitor tick) that scale together with speed controls. We needed to decide on timer implementation, event subscription, and speed change handling.

### Decision
- **Single `_process`** accumulates `sim_time` and `visual_time` as floats
- **Speed is a multiplier** on delta — instant changes, no timer recalculation
- **Events emitted via signals** from TimeManager (not EventBus directly, but TimeManager can emit on EventBus if needed)
- **TimeManager is NOT an autoload** — it's a child of `main_game.tscn`, created/destroyed with the game session
- **GameManager proxies speed control** — `GameManager.set_speed()` forwards to `TimeManager.speed`
- **Time-of-day and seasons are post-MVP** — calculations are left as commented code for future implementation

### TimeManager Structure
```
TimeManager (Node, child of main_game.tscn)
├── sim_time: float           # Accumulated sim seconds
├── visual_time: float        # Accumulated visual seconds
├── speed: int                # 0=pause, 1=1x, 2=2x, 3=3x
├── _process(delta)           # Accumulates time, emits events
└── Signals:
    ├── visitor_tick          # Every 5 sim seconds
    ├── sim_hour_passed(hour)
    ├── sim_day_passed(day)
    ├── sim_month_passed(month)
    └── [POST-MVP] visual_phase_changed(phase), season_changed(season)
```

### Constants
```
SIM_SECONDS_PER_DAY = 86400       # 24 sim hours
VISUAL_SECONDS_PER_DAY = 600      # 10 real minutes at 1x
VISITOR_TICK_INTERVAL = 5         # 5 sim seconds
VISUAL_TO_SIM_RATIO = VISUAL_SECONDS_PER_DAY / SIM_SECONDS_PER_DAY
```

### Event Emission Logic
```
_process(delta):
    if speed == 0: return
    sim_time += delta * speed
    visual_time += delta * speed * VISUAL_TO_SIM_RATIO
    
    if int(sim_time / VISITOR_TICK_INTERVAL) > last_visitor_tick:
        emit visitor_tick
    if int(sim_time / SIM_SECONDS_PER_DAY) > last_sim_day:
        emit sim_day_passed
    if int(sim_time / (SIM_SECONDS_PER_DAY * 30)) > last_sim_month:
        emit sim_month_passed
```

### Rationale
- Accumulated time has no drift (unlike multiple Timer nodes)
- Speed multiplier is instant — no state reset needed
- Signals decouple TimeManager from listeners
- Not an autoload because time only matters during gameplay
- GameManager as proxy keeps speed control accessible from menus

### Consequences
- TimeManager must be instantiated when main_game.tscn loads
- GameManager checks `if TimeManager` before forwarding speed (handles menu state)
- Post-MVP time-of-day and season calculations are pure functions of `visual_time`

---

## Pending Decisions
- Economy system architecture (money tracking, rent, loans)
- UI panel architecture (stacking, lifecycle, communication)
- Save/load architecture (what to save, serialization format)
- Undo/redo system architecture
- (More to come)
