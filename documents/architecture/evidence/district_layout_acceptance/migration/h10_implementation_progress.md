# H10 Implementation Progress

This record captures the implementation phase only. It is not the H10
acceptance or release signoff.

## Completed boundary removals

- Deleted the remaining executable H10 adapters:
  - `scripts/district/legacy_layout_bootstrap_adapter.gd`
  - `scripts/district/legacy_floor_id_adapter.gd`
  - `scripts/district/legacy_grid_projection_adapter.gd`
  - `scripts/district/legacy_default_plot_selection_adapter.gd`
  - `scripts/district/legacy_exterior_access_adapter.gd`
  - `scripts/traffic/legacy_authored_traffic_layout_adapter.gd`
  - `scripts/simulation/legacy_visitor_spawn_adapter.gd`
- Removed the arrival coordinator's runtime visitor adapter dependency and
  preserved direct explicit arrival-source identity.
- Removed the unused Economy zero-cost reservation compatibility wrapper and
  the no-op monthly payroll compatibility hook.
- Removed the tracked `wall_manager.gd.bak` file containing a stale hard-coded
  `floor_plot_0_G` lookup.
- Removed adapter-only H7/H8 runtime test helpers.
- Renamed the projection's presentation-only floor label local and removed
  stale camera fallback wording; signed elevation remains the authority.

## Validation

- H1 layout-definition suite: 60 passed, 0 failed.
- H2 resolved-district suite: 74 passed, 0 failed.
- H3 District Runtime: 42 passed, 0 failed.
- H3 traversal topology: 7 passed, 0 failed.
- H4 world projection: 22 passed, 0 failed.
- H4 editor preview: 15 passed, 0 failed.
- H5 public realm: 21 passed, 0 failed.
- H6 camera/gateway: 28 passed, 0 failed.
- H7 traffic topology: 38 passed, 0 failed.
- H8 visitor arrival: 46 passed, 0 failed.
- H9 Save/Load V2: 18 passed, 0 failed.
- H10 legacy-removal test: 16 passed, 0 failed.
- Properly launched zone/parcel and wall scene suites: 191 and 23 passed,
  respectively, with 0 failures.
- Main scene started through GodotIQ; `GameManager.session_ready` was true,
  FPS was 60, draw calls were 128, and runtime/debug-console errors were 0.
- GodotIQ validation reported 0 convention issues; signal audit reported 0
  orphan signals; asset audit reported 0 unused assets.
- The RVR-1 headless authority workload completed with 200 immutable visitor
  records, 30 rebuild cycles, 20 V2 restore cycles, `valid=true`, a latest
  targeted rebuild maximum of 91 ms, a latest save/load maximum of 136 ms,
  serialized state of 417 bytes, and no application-owned warning/error/leak
  lines.
- The local Archive Policy B manifest rerun produced valid production and
  test-pack manifests with 324 and 614 files respectively and zero forbidden
  production-content violations.

## Remaining acceptance work

- Complete the H10 coverage matrix with named static/dependency/behavioral
  evidence for every row and record archive/package/CI evidence.
- Record the required Architecture, Design, QA, and Release signoffs.
- The GodotIQ project-wide checker still reports nine low-confidence
  `Script reload failed (error 22)` entries with no line information. Direct
  headless `--check-only` checks pass for all nine scripts, and the running
  main scene has no runtime or debugger errors.
- The H8, H3 traversal, staff, tenant, visitor-proxy, rent-settlement,
  zone-tool, and state-machine suites were rerun after explicit lifecycle and
  diagnostic cleanup; they now exit warning/leak-free.
