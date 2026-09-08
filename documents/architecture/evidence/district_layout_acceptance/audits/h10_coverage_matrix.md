# H10 Coverage Matrix

This matrix records the current non-hardware evidence for each H10 coverage
row. It is an implementation/evidence record, not the final release approval.

| Coverage row | Static/dependency evidence | Behavioral evidence | Status |
| --- | --- | --- | --- |
| Ten canonical adapters and eight stale aliases | `build/h10/production_manifest.json`; `tests/test_h10_legacy_removal.gd` | H10 legacy-removal suite: 16 passed, 0 failed | PASS |
| `25x25_full`, semantic `25`, `24`, `12`, `12.5`, `625` | H1/H2 fixture and canonical-resolution code; [static audit](h10_static_audit.md) | `tests/test_district_layout_definition.gd`; `tests/test_resolved_district_model.gd` | PASS |
| `DEFAULT_PLOT`, `plot_0`, `GROUND_FLOOR`, floor labels, `floor_levels`, `floor_plot_0_G` | Production manifest excludes retired grid files; [static audit](h10_static_audit.md) classifies remaining presentation/archive terms | `tests/test_session_h1.gd`; `tests/test_district_runtime_h3.gd`; `tests/test_world_projection_h4.gd`; `tests/test_camera_h6.gd`; `tests/test_save_load_h9.gd` | PASS |
| `PlotData.pedestrian_boundary`, spawn points, virtual exterior, fixed exterior doors, corner frontage | H5/H6/H8 source and topology owners; production manifest excludes archive grid authority | `tests/test_public_realm_h5.gd`; `tests/test_camera_h6.gd`; `tests/test_visitor_arrival_h8.gd` | PASS |
| Authored roads, lanes, markers, corner/source authority | H5 generated public-realm descriptors and H7 graph ownership | `tests/test_traffic_topology_h7.gd`; `tests/test_visitor_arrival_h8.gd` | PASS |
| Direct mutable grid writes, ownership/construction conflation, full-volume allocation, global rebuilds, bare coordinate boundaries | H3 transaction ownership, H4 detached projection, H5 conversion, and explicit-address contracts | `tests/test_district_runtime_h3.gd`; `tests/test_world_projection_h4.gd`; `tests/test_public_realm_h5.gd`; `tests/test_district_traversal_topology_h3.gd` | PASS |
| Schema-absent/V1 mutation | V2 schema contract and H9 SaveManager boundary | `tests/test_save_load_h9.gd`: 18 passed, 0 failed | PASS |

## Supporting suites

- H1 definition: 60 passed, 0 failed.
- H2 resolved district: 74 passed, 0 failed.
- H3 runtime: 42 passed, 0 failed.
- H3 traversal topology: 7 passed, 0 failed.
- H4 runtime projection: 22 passed, 0 failed.
- H4 editor preview: 15 passed, 0 failed.
- H5 public realm: 21 passed, 0 failed.
- H6 camera/gateways: 28 passed, 0 failed.
- H7 traffic topology: 38 passed, 0 failed.
- H8 visitor arrival: 46 passed, 0 failed.
- H9 Save/Load V2: 18 passed, 0 failed.
- Zone/parcel and wall scenes: 191 and 23 passed, respectively; 0 failures.
- Zone tool and label scenes: 9 and 22 passed, respectively; 0 failures.

## Still required for acceptance

- Three qualifying release-export RVR-1 samples on the specified reference
  hardware, including FPS, frame-time, draw calls, nodes, VRAM, and leak gate.
- Production/test-pack exports, checksums, manifests, forbidden-content and
  reachability proof, CI job URLs, and retained raw logs.
- Independent Architecture, Design, QA, and Release approvals against the
  final candidate commit and evidence-manifest checksum.
