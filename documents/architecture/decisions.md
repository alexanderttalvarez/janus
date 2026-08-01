# Architectural Decisions

This directory contains individual architectural decision records for the Janus project.

## Decisions

| # | Decision | File |
|---|----------|------|
| 1 | Scene Architecture — Single Game Scene with Sub-scene Instancing | [01_scene_architecture.md](01_scene_architecture.md) |
| 2 | UI Rendering — SubViewport for Heatmap Overlay | [02_ui_rendering.md](02_ui_rendering.md) |
| 3 | Visitor Agents — Node3D with Centralized Tick + Floor-based Culling | [03_visitor_agents.md](03_visitor_agents.md) |
| 4 | Wall Rendering — Shader-based Clipping | [04_wall_rendering.md](04_wall_rendering.md) |
| 5 | Heatmap Implementation — Shader-driven Mesh | [05_heatmap_implementation.md](05_heatmap_implementation.md) |
| 6 | Floor Representation — Instanced Sub-scene (floor.tscn) | [06_floor_representation.md](06_floor_representation.md) |
| 7 | Grid Data Structure — Per-Floor 2D Arrays Managed by GridManager | [07_grid_data_structure.md](07_grid_data_structure.md) |
| 8 | Plot Scalability — Multi-Plot Ready from Day One | [08_plot_scalability.md](08_plot_scalability.md) |
| 9 | Footprint Masks — Text Files for Plot/Floor Shapes | [09_footprint_masks.md](09_footprint_masks.md) |
| 10 | Zone System Architecture | [10_zone_system_architecture.md](10_zone_system_architecture.md) |
| 11 | Zone Splitting Algorithm — Full Recalculation with Tenant Preservation | [11_zone_splitting_algorithm.md](11_zone_splitting_algorithm.md) |
| 12 | Time System Architecture — Accumulated Time with EventBus Signals | [12_time_system_architecture.md](12_time_system_architecture.md) |
| 13 | Economy System Architecture | [13_economy_system_architecture.md](13_economy_system_architecture.md) |
| 14 | UI Architecture — Multi-CanvasLayer with game_ui.tscn Sub-scene | [14_ui_architecture.md](14_ui_architecture.md) |
| 15 | Save/Load Architecture — JSON with Manager Serialization | [15_save_load_architecture.md](15_save_load_architecture.md) |
| 16 | Camera System Architecture — Pivot-Based Rig with Floor Navigation | [16_camera_system_architecture.md](16_camera_system_architecture.md) |
| 17 | Notification System Architecture — Condition-Based with Toast Queue | [17_notification_system_architecture.md](17_notification_system_architecture.md) |
| 18 | Staff System Architecture — Centralized Management with Coverage Boundaries | [18_staff_system_architecture.md](18_staff_system_architecture.md) |
| 19 | Tech Tree Architecture — Dictionary Data with Visual Graph | [19_tech_tree_architecture.md](19_tech_tree_architecture.md) |
| 20 | Debug Mode Architecture — DebugManager Autoload | [20_debug_mode_architecture.md](20_debug_mode_architecture.md) |
| 21 | Multi-Language Architecture — Godot CSV/PO with tr() | [21_multi_language_architecture.md](21_multi_language_architecture.md) |
| 22 | Prestige Calculation Architecture — Aggregator with Snapshot Queries | [22_prestige_calculation_architecture.md](22_prestige_calculation_architecture.md) |
| 23 | State Machine Architecture — Resource-Based FSM Pattern | [23_state_machine_architecture.md](23_state_machine_architecture.md) |

## Pending Decisions
- Implementation planning (task breakdown, skill assignment)
- (More to come)
