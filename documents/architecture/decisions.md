# Architectural Decisions

This directory contains individual architectural decision records for the Janus project.

The cross-system district and arrival blueprint is [design_handoff.md](design_handoff.md).

## Decisions

| # | Decision | File |
|---|----------|------|
| 1 | Scene Architecture — Single Game Scene with Sub-scene Instancing | [01_scene_architecture.md](decisions/01_scene_architecture.md) |
| 2 | UI Rendering — SubViewport for Heatmap Overlay | [02_ui_rendering.md](decisions/02_ui_rendering.md) |
| 3 | Visitor Agents — Node3D with Centralized Tick + Floor-based Culling | [03_visitor_agents.md](decisions/03_visitor_agents.md) |
| 4 | Wall Rendering — Shader-based Clipping | [04_wall_rendering.md](decisions/04_wall_rendering.md) |
| 5 | Heatmap Implementation — Shader-driven Mesh | [05_heatmap_implementation.md](decisions/05_heatmap_implementation.md) |
| 6 | Floor Representation — Instanced Sub-scene (floor.tscn) | [06_floor_representation.md](decisions/06_floor_representation.md) |
| 7 | Grid Data Structure — Per-Floor 2D Arrays Managed by GridManager | [07_grid_data_structure.md](decisions/07_grid_data_structure.md) |
| 8 | Plot Scalability — Multi-Plot Ready from Day One | [08_plot_scalability.md](decisions/08_plot_scalability.md) |
| 9 | Footprint Masks — Text Files for Plot/Floor Shapes | [09_footprint_masks.md](decisions/09_footprint_masks.md) |
| 10 | Zone System Architecture | [10_zone_system_architecture.md](decisions/10_zone_system_architecture.md) |
| 11 | Zone Splitting Algorithm — Full Recalculation with Tenant Preservation | [11_zone_splitting_algorithm.md](decisions/11_zone_splitting_algorithm.md) |
| 12 | Time System Architecture — Accumulated Time with EventBus Signals | [12_time_system_architecture.md](decisions/12_time_system_architecture.md) |
| 13 | Economy System Architecture | [13_economy_system_architecture.md](decisions/13_economy_system_architecture.md) |
| 14 | UI Architecture — Multi-CanvasLayer with game_ui.tscn Sub-scene | [14_ui_architecture.md](decisions/14_ui_architecture.md) |
| 15 | Save/Load Architecture — JSON with Manager Serialization | [15_save_load_architecture.md](decisions/15_save_load_architecture.md) |
| 16 | Camera System Architecture — Pivot-Based Rig with Floor Navigation | [16_camera_system_architecture.md](decisions/16_camera_system_architecture.md) |
| 17 | Notification System — Condition-Based with Toast Queue | [17_notification_system_architecture.md](decisions/17_notification_system_architecture.md) |
| 18 | Staff System — Centralized Management with Coverage Boundaries | [18_staff_system_architecture.md](decisions/18_staff_system_architecture.md) |
| 19 | Tech Tree — Dictionary Data with Visual Graph | [19_tech_tree_architecture.md](decisions/19_tech_tree_architecture.md) |
| 20 | Debug Mode — DebugManager Autoload | [20_debug_mode_architecture.md](decisions/20_debug_mode_architecture.md) |
| 21 | Multi-Language — Godot CSV/PO with tr() | [21_multi_language_architecture.md](decisions/21_multi_language_architecture.md) |
| 22 | Prestige Calculation — Aggregator with Snapshot Queries | [22_prestige_calculation_architecture.md](decisions/22_prestige_calculation_architecture.md) |
| 23 | State Machine — Resource-Based FSM Pattern | [23_state_machine_architecture.md](decisions/23_state_machine_architecture.md) |
| 24 | Paint-First Zone Mutation with Preservation-First Parcels | [24_paint_first_zone_mutation.md](decisions/24_paint_first_zone_mutation.md) |
| 25 | Remove-Mode Toolbar Clarification | [25_remove_mode_toolbar.md](decisions/25_remove_mode_toolbar.md) |
| 26 | Zone Paint Cancel Destination | [26_zone_paint_cancel.md](decisions/26_zone_paint_cancel.md) |
| 27 | District Layout Templates and Runtime State | [27_district_layout_templates.md](decisions/27_district_layout_templates.md) |
| 28 | Visitor Demand and Arrival Architecture | [28_visitor_arrival_architecture.md](decisions/28_visitor_arrival_architecture.md) |
| 29 | Production District Content and Session Bootstrap | [29_production_district_content_bootstrap.md](decisions/29_production_district_content_bootstrap.md) |
| 30 | Production Manual-Door Authority | [30_manual_door_authority.md](decisions/30_manual_door_authority.md) |
| 31 | Door Endpoint Semantics Views | [31_door_endpoint_semantics_views.md](decisions/31_door_endpoint_semantics_views.md) |
| 32 | H10 Engineering Completion and External Release Acceptance | [32_h10_engineering_completion_and_release_acceptance.md](decisions/32_h10_engineering_completion_and_release_acceptance.md) |

## Pending Decisions
- Future player-facing production-layout selection policy is intentionally deferred; Decision 29 fixes only the explicit initial layout bootstrap.
- (More to come)
