# H1-H9 Proof Test Results

All commands were run from the project root with Godot 4.7 stable. Results are
execution evidence, not approval signoff.

| Handoff | Command | Result |
| ---: | --- | --- |
| H1 | `godot --headless --path . -s tests/test_district_layout_definition.gd` | **PASS — 60 passed, 0 failed** |
| H2 | `godot --headless --path . -s tests/test_resolved_district_model.gd` | **PASS — 73 passed, 0 failed** |
| H3 | `godot --headless --path . -s tests/test_district_runtime_h3.gd` | **PASS — 32 passed, 0 failed** |
| H4 | `godot --headless --path . -s tests/test_world_projection_h4.gd` | **PASS — 22 passed, 0 failed** |
| H4 editor preview | `godot --headless --path . -s tests/test_projection_editor_preview.gd` | **PASS — 15 passed, 0 failed** |
| H5 | `godot --headless --path . -s tests/test_public_realm_h5.gd` | **PASS — 21 passed, 0 failed** |
| H6 | `godot --headless --path . -s tests/test_camera_h6.gd` | **PASS — 23 passed, 0 failed** |
| H7 | `godot --headless --path . -s tests/test_traffic_topology_h7.gd` | **PASS — 19 passed, 0 failed** |
| H8 | `godot --headless --path . -s tests/test_visitor_arrival_h8.gd` | **PASS — 31 passed, 0 failed**; process-exit ObjectDB/resource leak warnings remain. |
| H9 | `godot --headless --path . -s tests/test_save_load_h9.gd` | **PASS — 18 passed, 0 failed** |

## Additional regression status

`tests/test_zone_manager_split_commit.gd` was identified as a required H10
zone/parcel regression suite, but it is not directly executable with Godot's
`-s` option because it does not inherit `SceneTree` or `MainLoop`. Its runner
integration remains to be documented or corrected before H10 acceptance.

The frozen H1/H2 golden record also records the H1 decision as `KEEP`:
`documents/architecture/handoff/district_layout/frozen_h1_h2_goldens.md`.
