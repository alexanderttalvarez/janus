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

## Decision 13: Economy System Architecture
**Date:** 2026-07-28
**Status:** Accepted

### Context
The economy drives tension between creative ambition and financial reality. It handles money balance, rent collection, loans, and expenses. We needed to decide on money ownership, transaction scheduling, and loan management.

### Decision
- **EconomyManager owns the money balance** (single financial authority)
- **Recurring transactions driven by TimeManager events** (`sim_day_passed`, `sim_month_passed`)
- **Rent collected weekly** (not daily)
- **Loans managed as `LoanData` objects** within EconomyManager
- **Maintenance cost is post-MVP** — no recurring maintenance expense in MVP
- **EconomyManager is NOT an autoload** — child of `main_game.tscn`

### EconomyManager Structure
```
EconomyManager (Node, child of main_game.tscn)
├── balance: int = 500_000
├── loans: Dictionary[String, LoanData]
├── add(amount, reason)
├── subtract(amount, reason) → bool
├── take_loan(amount, term) → String
├── repay_loan(loan_id)
├── _on_sim_day_passed(day)
│   └── _accrue_staff_wages(day)
├── _on_sim_week_passed(week)
│   └── _collect_rent()
├── _on_sim_month_passed(month)
│   └── _process_loan_payments()
└── Signals:
    └── balance_changed(new_balance, delta)
```

### LoanData Structure
```
class LoanData:
    id: String
    principal: int
    remaining: int
    interest_rate: float
    monthly_payment: int
    term_months: int
    months_paid: int
    failed_payments: int
    is_active: bool
    calculate_monthly_payment() → int
    process_payment() → bool
```

### Rent Collection Flow
```
_on_sim_week_passed(week):
    for zone in ZoneManager.zones:
        if zone.has_active_tenants():
            rent = zone.calculate_weekly_rent()
            EconomyManager.add(rent, "Rent from " + zone.name)
```

### Rationale
- Single financial authority prevents balance inconsistencies
- Time-driven transactions are predictable and easy to debug
- Weekly rent matches the design doc's pacing (daily was too frequent)
- Loan objects have clear lifecycle and are easy to serialize
- Not an autoload because economy only exists during gameplay

### Consequences
- EconomyManager depends on TimeManager signals and ZoneManager data
- Balance changes emit signals for HUD updates
- Negative balance triggers high-priority notification
- Post-MVP: maintenance costs, transportation fees, event income added to monthly processing

---

## Decision 14: UI Architecture — Multi-CanvasLayer with game_ui.tscn Sub-scene
**Date:** 2026-07-28
**Status:** Accepted

### Context
Janus has a layered UI system: HUD bar, bottom toolbar, informational panels, notifications, and thought bubbles. We needed to decide on scene structure, panel lifecycle, and data flow.

### Decision
- **UI lives in `game_ui.tscn`** — a sub-scene instanced into `main_game.tscn`
- **Multiple CanvasLayers** (5 layers: HUD, Toolbar, Panel, Notification, Overlay)
- **PanelManager controls panel lifecycle** — opens/closes/stacks panels (max 3 simultaneously)
- **Hybrid data flow** — direct access for initial state, EventBus signals for reactive updates
- **Each panel is a separate `.tscn` file**, instanced by PanelManager at runtime

### Scene Structure
```
main_game.tscn (Node3D)
├── World (Node3D)
├── Simulation (Node)
└── GameUI (game_ui.tscn instanced)
    ├── HUDLayer (CanvasLayer, layer 1)
    │   └── HUDBar (Control)
    ├── ToolbarLayer (CanvasLayer, layer 2)
    │   └── BottomToolbar (Control)
    ├── PanelLayer (CanvasLayer, layer 3)
    │   └── PanelContainer (Control) ← PanelManager script
    ├── NotificationLayer (CanvasLayer, layer 4)
    │   └── NotificationSystem (Control)
    └── OverlayLayer (CanvasLayer, layer 5)
        └── ThoughtBubbleContainer (Control)
```

### Panel Lifecycle
1. Player clicks toolbar button → `PanelManager.open_panel("finances")`
2. PanelManager instantiates `finances_panel.tscn`, adds to PanelContainer
3. Panel reads initial state from managers, connects to EventBus signals
4. Player clicks X or Escape → `PanelManager.close_panel("finances")`
5. Panel disconnects signals, queues free, PanelManager repositions remaining panels

### Data Flow Pattern (Hybrid)
```gdscript
func _ready() -> void:
    # Initial state — direct access
    $BalanceLabel.text = "%,d K" % EconomyManager.balance
    # Future updates — signals
    EventBus.money_changed.connect(_on_money_changed)

func _on_money_changed(balance: int, delta: int) -> void:
    $BalanceLabel.text = "%,d K" % balance

func _exit_tree() -> void:
    EventBus.money_changed.disconnect(_on_money_changed)
```

### Rationale
- `game_ui.tscn` keeps `main_game.tscn` clean and allows independent UI iteration
- Multiple CanvasLayers give explicit layer ordering and independent visibility control
- PanelManager enforces max-3 rule and handles stacking logic centrally
- Hybrid data flow ensures panels show correct data immediately on open (signals alone would cause blank panels)

### Consequences
- Each panel must implement the hybrid pattern (read state + connect signals + disconnect on exit)
- PanelManager needs a registry mapping panel names to `.tscn` paths
- CanvasLayer ordering must be maintained (HUD always on top, panels below, etc.)

---

## Decision 15: Save/Load Architecture — JSON with Manager Serialization
**Date:** 2026-07-28
**Status:** Accepted

### Context
The game needs to persist economy, grid, zones, tenants, visitors, time, tech tree, prestige, and staff state. Settings (volume, keybindings) also need persistence. We needed to decide on serialization format, save structure, and responsibility.

### Decision
- **JSON serialization** — human-readable, easy to debug, fast enough for this game
- **Single monolithic file per save slot** — atomic saves, simple management
- **SaveManager orchestrates** — each manager implements `serialize()` and `deserialize()`
- **Settings use ConfigFile** — separate file at `user://settings.cfg`
- **Save format versioning** — `meta.version` field enables migration between versions

### SaveManager Structure
```
SaveManager (Node, autoload)
├── save_game(slot) → Error
├── load_game(slot) → Error
├── delete_save(slot) → Error
├── has_save(slot) → bool
├── get_save_meta(slot) → Dictionary
├── save_setting(section, key, value)
├── load_setting(section, key, default) → Variant
├── SAVE_DIR = "user://saves/"
├── MAX_SLOTS = 5
└── SETTINGS_PATH = "user://settings.cfg"
```

### Save File Structure
```json
{
  "meta": { "slot": 1, "timestamp": 1722182400, "version": "0.1.0" },
  "economy": { "balance": 500000, "loans": [...] },
  "grid": { "plots": { "plot_0": { "floors": {...} } } },
  "zones": [...],
  "tenants": [...],
  "visitors": [...],
  "time": { "sim_time": 86400.0, "visual_time": 600.0 },
  "tech_tree": { "unlocked_nodes": [...], "tech_points": 5 },
  "prestige": { "scale": 42, "quality": 68 },
  "staff": { "operations_rooms": [...] }
}
```

### Manager Interface
```gdscript
# Each manager implements:
func serialize() -> Dictionary:
    return { "balance": balance, "loans": loans.map(func(l): return l.serialize()) }

func deserialize(data: Dictionary) -> void:
    balance = data["balance"]
    for loan_data in data["loans"]:
        loans.append(LoanData.deserialize(loan_data))
```

### Rationale
- JSON is human-readable — saves can be inspected and debugged
- Single file is atomic — no partial saves
- Manager-owned serialization keeps data ownership clear
- ConfigFile for settings is Godot's built-in solution for key-value persistence
- Version field enables forward-compatible save migration

### Consequences
- Each manager must implement serialize/deserialize
- SaveManager needs references to all managers (or they register themselves)
- Migration functions needed when save format changes between versions
- Settings are loaded at game start, saved immediately when changed

---

## Decision 16: Camera System Architecture — Pivot-Based Rig with Floor Navigation
**Date:** 2026-07-28
**Status:** Accepted

### Context
The game requires an isometric camera with 90° rotation, zoom, pan, and focus. Floor navigation allows moving between floors. Camera state affects wall rendering and visitor culling.

### Decision
- **Pivot-based camera rig**: CameraRig (pivot) → CameraMount (zoom) → Camera3D (orthographic) + FocusTarget
- **Smooth rotation via Tween**: 0.15s duration, cubic ease-out
- **Zoom**: Changes `Camera3D.size`, range 5.0–50.0
- **Pan**: Moves CameraRig position in XZ plane
- **Focus**: Moves FocusTarget to element position, tweens camera
- **Position limit**: 20 tiles radial distance from any purchased tile
- **Floor navigation**: UI buttons + keyboard (Page Up/Down, +/-)
- **Floor visibility modes**: FULL (current), EXTERIOR (below), HIDDEN (above)
- **Unbought tiles = no mesh**: Natural transparency through holes to floors below

### Camera Rig Structure
```
CameraManager (Node, child of main_game.tscn)
├── camera_rig (Node3D)              ← Pivot for rotation
│   ├── camera_mount (Node3D)        ← Zoom distance
│   │   └── Camera3D (orthographic)
│   └── focus_target (Marker3D)      ← Look-at point
├── min_zoom: float = 5.0
├── max_zoom: float = 50.0
├── current_floor_index: int = 0
├── floor_levels: Array[String]
├── rotate_camera(direction: int)    ← -1=left, 1=right
├── zoom_camera(delta: float)
├── pan_camera(delta: Vector2)
├── focus_on(position: Vector3)
├── go_up() / go_down()              ← Floor navigation
├── can_go_up() / can_go_down()      ← Navigation guards
└── Signals:
    ├── rotated(direction)
    ├── zoomed(level)
    ├── focused(element_type, element_id)
    └── floor_changed(floor_level)
```

### Floor Visibility Modes
| Mode | Floor Plane | Walls | Tiles | Zones | Visitors | Circulation | Indicators |
|---|---|---|---|---|---|---|---|
| **FULL** (current) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **EXTERIOR** (below) | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| **HIDDEN** (above) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

### Floor Navigation Rules
- Can navigate to any acquired floor
- Can navigate one floor above highest acquired IF floor below has ≥20 purchased tiles
- New floor starts empty, player buys tiles on it
- Visitor culling: only visitors on current floor are visible
- Zoom threshold (>35.0): hide all visitors regardless of floor

### Wall Shader Integration
Camera direction passed as global shader parameter:
```gdscript
RenderingServer.global_shader_parameter_set("camera_direction", direction)
```

### Rationale
- Pivot-based rig makes orbit rotation, zoom, and focus all trivial
- Tween provides smooth, interruptible transitions with minimal code
- Orthographic projection eliminates perspective distortion for grid-based gameplay
- Floor visibility modes are per-floor, not global — each floor knows how to show/hide itself
- Unbought tiles = no mesh = natural transparency, no special see-through logic needed

### Consequences
- CameraManager must enforce position limits on pan and zoom
- Floor navigation creates new floor scenes dynamically when going above highest acquired
- Wall shader reads global `camera_direction` parameter for front/back wall clipping
- VisitorManager listens to `floor_changed` and `zoomed` signals for culling

---

## Decision 17: Notification System Architecture — Condition-Based with Toast Queue
**Date:** 2026-07-28
**Status:** Accepted

### Context
The game needs toast notifications (auto-dismiss, max 3 visible, queued), a notification panel (log with filtering), and a red dot indicator for unresolved high-priority items.

### Decision
- **NotificationManager controls toast queue** — max 3 visible, excess queued, auto-dismiss by priority duration
- **Condition-based resolution** — each notification stores a Callable checked once per sim day
- **Red dot owned by NotificationManager** — visible when any high-priority notification is unresolved
- **Toast lifecycle**: create → show → wait (duration) → dismiss → next from queue
- **Panel is a separate scene** — filters by category/status, clear read only

### NotificationManager Structure
```
NotificationManager (Node, child of game_ui.tscn)
├── visible_toasts: Array[Toast]
├── queue: Array[NotificationData]
├── log: Array[NotificationEntry]
├── MAX_VISIBLE = 3
├── DURATIONS = {"high": 10.0, "medium": 7.0, "low": 5.0}
├── notify(text, category, priority, action_target)
├── _show_toast(data)
├── _dismiss_toast(toast)
├── _on_sim_day_passed(day)  ← Checks resolution conditions
├── open_panel()
├── clear_read()
└── Signals:
    └── red_dot_changed(visible: bool)
```

### NotificationEntry Structure
```
class NotificationEntry:
    data: NotificationData
    status: String  # unread, read, resolved
    condition: Callable  # Optional: returns true when issue is fixed
    check_resolution() → bool
```

### Resolution Flow
```
Sim day passes → NotificationManager checks all entries
    → If condition.call() returns true → status = "resolved"
    → If high-priority and unresolved → red dot visible
    → If all high-priority resolved → red dot hidden
```

### Rationale
- Condition-based resolution means notifications auto-dismiss when issues are fixed (no manual resolve calls)
- Toast queue prevents screen clutter during busy simulation periods
- Centralized management enforces max 3 and handles queuing cleanly
- Red dot tied to actual unresolved state, not just unread notifications

### Consequences
- Condition Callables must be side-effect-free
- Each system creating notifications must provide a resolution condition
- Toast scene must support optional action button
- Panel scene must support filtering by category and status

---

## Decision 18: Staff System Architecture — Centralized Management with Coverage Boundaries
**Date:** 2026-07-28
**Status:** Accepted

### Context
Staff (Cleaners and Security) are hired through Operations Rooms. Cleaners handle garbage and bathroom cleaning via task queues. Security provides passive coverage. Bins reduce garbage spawn rate.

### Decision
- **Dedicated StaffManager** owns all staff logic
- **Centralized task queue** with coverage-filtered assignment (cleaners only work on their coverage floors)
- **Node3D per staff member** (~16 max, negligible overhead)
- **Operations Room is 2×2 tiles** — all 4 must be purchased and empty
- **Bins reduce garbage** — 10% per bin per floor, max 80% reduction
- **Cleanliness and insecurity** calculated periodically from game state

### StaffManager Structure
```
StaffManager (Node, child of main_game.tscn)
├── operations_rooms: Dictionary[String, OperationsRoomData]
├── all_staff: Dictionary[String, StaffData]
├── garbage_queue: Array[GarbageTask]
├── bathroom_queue: Array[BathroomTask]
├── bins_per_floor: Dictionary[String, int]
├── place_operations_room(floor, position) → String
├── place_bin(floor, position)
├── hire_staff(room_id, staff_type) → String
├── fire_staff(staff_id)
├── _on_visitor_tick()  ← Spawns garbage (with bin reduction), assigns tasks
├── _assign_cleaner_tasks()  ← Filters by coverage floors
├── calculate_cleanliness() → int
├── calculate_insecurity() → float
└── get_garbage_reduction(floor) → float
```

### OperationsRoomData Structure
```
class OperationsRoomData:
    id: String
    floor: String
    position: Vector2i  # Top-left corner of 2×2
    size: Vector2i = Vector2i(2, 2)
    cleaners: Array[String]  # max 2
    security: Array[String]  # max 2
    coverage_floors: Array[String]  # floor + 1 above + 1 below
```

### Cleaner Assignment Flow
```
Visitor tick → Garbage spawns (reduced by bins)
    ↓
Garbage added to centralized queue
    ↓
For each FREE cleaner:
    → Filter queue to coverage floors only
    → Find nearest eligible task
    → Assign task → cleaner state = WORKING
    ↓
Cleaner pathfinds → cleans → state = FREE
```

### Bin Mechanics
- 1 tile amenity, placed via build palette
- Each bin = -10% garbage spawn on that floor
- Max 80% reduction (8 bins)
- Formula: `actual_garbage = int(base_garbage * (1.0 - min(0.8, bin_count * 0.1)))`

### Rationale
- Centralized queue enables optimal nearest-cleaner assignment while respecting coverage boundaries
- Node3D per staff is trivial at ~16 max
- Bin reduction creates meaningful player choice (place bins vs hire more cleaners)
- Coverage filtering prevents cross-floor contamination

### Consequences
- Operations Room placement validates 2×2 area (all tiles owned and empty)
- Cleaner task assignment filters by coverage floors before finding nearest
- Bin count tracked per floor for garbage reduction calculation
- Cleanliness and insecurity scores feed into Prestige (Visitor Experience factor)

---

## Decision 19: Tech Tree Architecture — Dictionary Data with Visual Graph
**Date:** 2026-07-28
**Status:** Accepted

### Context
Tech tree drives progression via Mall Levels. Three branches (Construction, Circulation, Amenities) with dependencies, costs, and unlock effects.

### Decision
- **Tech tree data stored as a Dictionary** in `TechTreeData` class — easy to maintain, single source of truth
- **Preloaded icons** (`preload("res://...")`) stored directly in dictionary entries
- **Translation keys** (`name_key`, `description_key`) instead of raw strings — supports multi-language
- **`grid_pos: Vector2i`** for each node — UI builds visual graph from grid positions and prerequisites
- **Dependency visualization** — UI draws lines between nodes using `grid_pos` and `prerequisites`
- **Unlock effects checked by relevant systems** — `TechTreeManager.is_unlocked()` called by ZoneTool, CirculationTool, etc.

### TechTreeData Structure
```gdscript
const NODES := {
    "basic_zoning": {
        "name_key": "tech_basic_zoning",
        "description_key": "tech_basic_zoning_desc",
        "icon": preload("res://assets/textures/ui/tech/basic_zoning.png"),
        "branch": "construction",
        "cost": 0,
        "prerequisites": [],
        "grid_pos": Vector2i(0, 0),
        "unlocks": ["zone_retail", "zone_food"]
    },
    ...
}
```

### TechTreeManager Structure
```
TechTreeManager (Node, child of main_game.tscn)
├── unlocked_nodes: Array[String]
├── available_points: int
├── total_earned: int
├── can_unlock(node_id) → bool
├── unlock_node(node_id) → bool
├── is_unlocked(node_id) → bool
├── get_available_nodes() → Array
└── Signals:
    ├── tech_point_spent(node_id)
    └── tech_points_changed(available, total_earned)
```

### Rationale
- Dictionary is easier to maintain than many `.tres` files
- Preloaded icons avoid path management issues
- Translation keys enable multi-language without data restructuring
- `grid_pos` enables clean visual graph layout without complex auto-layout algorithms

### Consequences
- All tech tree strings must be translation keys
- Icons must be placed in `assets/textures/ui/tech/`
- UI panel draws dependency lines from `grid_pos` data
- Systems check `TechTreeManager.is_unlocked()` before allowing actions

---

## Decision 20: Debug Mode Architecture — DebugManager Autoload
**Date:** 2026-07-28
**Status:** Accepted

### Context
Development requires a debug mode to bypass unlocks, costs, and time constraints for testing.

### Decision
- **DebugManager is an autoload** — available globally during development
- **Auto-disabled in release builds** — `queue_free()` if `OS.has_feature("release")`
- **Toggle flags**: `god_mode` (unlocks everything), `infinite_money`, `instant_construction`, `time_warp`
- **Debug UI overlay** — toggle with F12, shows toggles and quick-action buttons

### Integration Points
- `TechTreeManager.can_unlock()`: returns `true` if `DebugManager.god_mode`
- `EconomyManager.subtract()`: returns `true` if `DebugManager.infinite_money`
- `TenantManager.start_construction()`: sets duration to 0 if `DebugManager.instant_construction`
- `TimeManager`: sets speed to 100 if `DebugManager.time_warp`

### Rationale
- Autoload ensures debug flags are accessible from any system
- Auto-disabled in release prevents accidental shipping
- Simple boolean flags are easy to toggle and test

### Consequences
- Every system with cost/unlock/time checks must integrate with DebugManager
- Debug UI overlay is a separate scene instanced only in debug builds

---

## Decision 21: Multi-Language Architecture — Godot CSV/PO with tr()
**Date:** 2026-07-28
**Status:** Accepted

### Context
Game must support multiple languages. English is primary, but translations should be easy to add.

### Decision
- **Godot's built-in translation system** — CSV or PO files in `translations/` directory
- **All UI text uses `tr("key")`** — no hardcoded strings in code or scenes
- **Data stores translation keys** — TechTreeData uses `name_key`, `description_key` instead of raw strings
- **TranslationServer handles loading/switching** — no custom translation logic needed

### File Structure
```
translations/
├── en.csv
├── es.csv
├── fr.csv
└── ja.csv
```

### Rationale
- Godot's translation system is mature and well-integrated
- CSV files are easy to edit and version control
- `tr()` is the standard Godot pattern — no custom infrastructure needed

### Consequences
- All UI labels must use `tr()` or be marked for translation in Inspector
- Data dictionaries store keys, not raw strings
- New languages require adding a CSV file and registering it in Project Settings

---

## Pending Decisions
- Prestige calculation architecture (Scale and Quality computation)
- (More to come)
