# H1-H9 Proof Test Results

All commands were run from the project root with Godot 4.7 stable. Results are
execution evidence, not approval signoff.

| Handoff | Command | Result |
| ---: | --- | --- |
| H1 | `godot --headless --path . -s tests/test_district_layout_definition.gd` | **PASS — 60 passed, 0 failed** |
| H2 | `godot --headless --path . -s tests/test_resolved_district_model.gd` | **PASS — 74 passed, 0 failed** |
| H3 | `godot --headless --path . -s tests/test_district_runtime_h3.gd` | **PASS — 42 passed, 0 failed** |
| H3 traversal | `godot --headless --path . -s tests/test_district_traversal_topology_h3.gd` | **PASS — 7 passed, 0 failed** |
| H4 | `godot --headless --path . -s tests/test_world_projection_h4.gd` | **PASS — 22 passed, 0 failed** |
| H4 editor preview | `godot --headless --path . -s tests/test_projection_editor_preview.gd` | **PASS — 15 passed, 0 failed** |
| H5 | `godot --headless --path . -s tests/test_public_realm_h5.gd` | **PASS — 21 passed, 0 failed** |
| H6 | `godot --headless --path . -s tests/test_camera_h6.gd` | **PASS — 28 passed, 0 failed** |
| H7 | `godot --headless --path . -s tests/test_traffic_topology_h7.gd` | **PASS — 38 passed, 0 failed** |
| H8 | `godot --headless --path . -s tests/test_visitor_arrival_h8.gd` | **PASS — 46 passed, 0 failed**, warning/leak-free after lifecycle cleanup. |
| H9 | `godot --headless --path . -s tests/test_save_load_h9.gd` | **PASS — 18 passed, 0 failed** |
| H10 removal | `godot --headless --path . -s tests/test_h10_legacy_removal.gd` | **PASS — 16 passed, 0 failed** |

## Additional regression status

Proper scene launches also pass:

- `tests/test_zone_label_renderer.tscn`: 22 passed, 0 failed.
- `tests/test_zone_tool.tscn`: 9 passed, 0 failed, warning/leak-free.
- `tests/test_zone_manager_split_commit.tscn`: 191 passed, 0 failed.
- `tests/test_wall_manager.tscn`: 23 passed, 0 failed.

The `.gd` files for those scene suites are not direct `-s` entry points because
some are `Node` scripts rather than `SceneTree`/`MainLoop` scripts.
