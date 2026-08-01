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
