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
