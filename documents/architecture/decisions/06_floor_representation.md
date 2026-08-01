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
