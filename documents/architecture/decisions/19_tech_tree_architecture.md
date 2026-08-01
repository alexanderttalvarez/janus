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
