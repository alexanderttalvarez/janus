## H4 editor-preview tests for source parity, isolation, stale-safe swaps, and cleanup.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_source_uses_h1_h2_contracts()
	_test_preview_lifecycle_and_isolation()
	print("Projection editor preview H4 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _make_metrics() -> ProjectionMetrics:
	var metrics: ProjectionMetrics = load("res://scripts/projection/projection_metrics.gd").new() as ProjectionMetrics
	metrics.identity = "editor_preview_test_metrics"
	metrics.revision = 3
	metrics.grid_unit_size = 2.0
	metrics.floor_height = 3.5
	metrics.origin = Vector3(4.0, 1.0, -2.0)
	return metrics


func _test_source_uses_h1_h2_contracts() -> void:
	var source: ProjectionEditorSource = load("res://scripts/projection/projection_editor_source.gd").new() as ProjectionEditorSource
	var loaded: Dictionary = source.load_fixture("A")
	_assert(bool(loaded.get("valid", false)), "editor source validates the selected H1 fixture")
	var snapshot: ResolvedDistrictSnapshot = source.get_snapshot()
	_assert(snapshot != null and source.get_fingerprint() == snapshot.get_fingerprint(), "editor source exposes the resolved H2 fingerprint")
	var request_result: Dictionary = source.build_request(_make_metrics())
	var request: ProjectionRequest = request_result.get("request") as ProjectionRequest
	_assert(bool(request_result.get("valid", false)) and request != null and request.editor_mode, "editor request is built from the shared immutable snapshot")
	_assert(request.definition_fingerprint == snapshot.get_fingerprint() and request.district_revision == source.get_revision(), "editor request carries source revision and H2 fingerprint")
	var missing: Dictionary = source.load_file("res://does_not_exist.json")
	_assert(not bool(missing.get("valid", false)) and not source.get_diagnostics().is_empty(), "invalid editor source exposes diagnostics")


func _test_preview_lifecycle_and_isolation() -> void:
	var source: ProjectionEditorSource = load("res://scripts/projection/projection_editor_source.gd").new() as ProjectionEditorSource
	source.load_fixture("A")
	var request_result: Dictionary = source.build_request(_make_metrics(), ["BoundsProjections"])
	var request: ProjectionRequest = request_result.get("request") as ProjectionRequest
	var host: Node3D = Node3D.new()
	root.add_child(host)
	var controller: ProjectionPreviewController = load("res://scripts/projection/projection_preview_controller.gd").new() as ProjectionPreviewController
	host.add_child(controller)
	var attached: Dictionary = controller.attach_to_scene(host)
	_assert(bool(attached.get("valid", false)) and controller.owner == null, "preview controller attaches as an ownerless transient node")
	var revision: int = source.get_revision()
	var committed: Dictionary = controller.rebuild(request, revision, revision)
	var prior_root: Node3D = controller.get_preview_root()
	_assert(bool(committed.get("valid", false)) and prior_root != null, "valid detached preview commits through the controller")
	_assert(prior_root.get_meta("generated_projection", false) == true and prior_root.get_parent() != null, "committed root is marked generated and remains under preview ownership")
	_assert(prior_root.owner == null, "generated preview root cannot be saved as authored scene content")
	var stale: Dictionary = controller.rebuild(request, revision, revision + 1)
	_assert(not bool(stale.get("valid", false)) and stale.get("diagnostics", [])[0].get("code", "") == "STALE_EDITOR_PREVIEW", "stale editor builds are rejected")
	_assert(controller.get_preview_root() == prior_root, "stale rebuild retains the prior valid preview")
	var invalid_metrics: ProjectionMetrics = _make_metrics()
	invalid_metrics.grid_unit_size = 0.0
	var invalid_request_result: Dictionary = source.build_request(invalid_metrics)
	_assert(not bool(invalid_request_result.get("valid", false)), "invalid metrics are rejected before materialization")
	_assert(controller.get_preview_root() == prior_root, "invalid rebuild preparation does not clear the prior preview")
	controller.cleanup()
	_assert(controller.get_preview_root() == null, "explicit cleanup removes generated roots")
	controller.detach_from_scene()
	_assert(controller.get_parent() == null, "detaching removes the controller from the edited scene")
	controller.free()
	host.free()
