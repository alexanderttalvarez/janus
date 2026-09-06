# H10 Static Legacy Audit

## Scope

Audit performed after the H10 executable adapter deletion pass. Runtime file
scan covers GDScript, scenes, resources, project settings, import/export
configuration, and tracked backup source files. Architecture handoff and
acceptance documents are evidence records and are not executable runtime
inputs.

## Adapter ledger

| Search | Result |
| --- | --- |
| Ten canonical adapter class names | Absent from runtime files. |
| Eight stale adapter aliases | Absent from runtime files. |
| Ten adapter file paths | Absent; verified by `tests/test_h10_legacy_removal.gd`. |
| `floor_plot_0_G` hard lookup | Removed with `scripts/walls/wall_manager.gd.bak`. |
| Arrival adapter runtime dependency | Removed from `ArrivalCoordinator`; direct source identity is used. |
| Traffic authored-layout adapter dependency | Removed; H7 graph is generated from committed topology. |

## Classified remaining terms

- `fixture.legacy_25_single` is an explicit approved fixture identity, not a
  default or fallback selection. Missing/unknown selection is rejected by H1.
- `G`, `F<n>`, and `B<n>` in projection and presentation code are display
  labels. Authority records use signed elevations and stable IDs.
- Optional TimeManager EventBus projections are presentation notifications;
  they do not create or migrate authority state.
- `plot_0` and `G` constants remain in the pre-existing GridManager/zone
  convenience API and presentation fixtures. H1/H3 explicit-address tests
  reject missing identity at the authoritative registry/runtime boundaries.
  These are follow-up audit items for the final coverage matrix, not executable
  H10 adapter implementations.

## GodotIQ audits

- Project convention validation: 0 issues.
- Signal orphan audit: 0 orphan signals.
- Asset registry: 50 assets, 0 unused.
- Main-scene runtime: session ready, 60 FPS, 128 draw calls, 0 runtime/debug
  console errors, 0 orphan nodes.

## Outstanding evidence

The final H10 matrix still needs named evidence for every numeric/default/API
row, archive/package exclusion, performance thresholds, CI invocation, and the
four required release signoff roles.
