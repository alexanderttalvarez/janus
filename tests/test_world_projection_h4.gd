## H4 projection tests for metrics, exact quarter conversion, bounded roots, and swaps.
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _factory: RefCounted
var _resolver: RefCounted
var _runtime: DistrictRuntime
var _coordinator: ProjectionCoordinator
var _metrics: ProjectionMetrics


func _init() -> void:
	_factory = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	_resolver = load("res://scripts/resources/district_layout_resolver.gd").new()
	_test_metrics_and_exact_projection()
	_test_invalid_metrics_rejection()
	_test_bounded_runtime_projection()
	print("WorldProjection H4 tests: %d passed, %d failed" % [_passed, _failed])
	if _coordinator != null:
		_coordinator.dispose()
		_coordinator.free()
	if _runtime != null:
		_runtime.free()
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
	metrics.identity = "h4_test_metrics"
	metrics.revision = 7
	metrics.grid_unit_size = 2.0
	metrics.floor_height = 3.5
	metrics.origin = Vector3(10.0, 4.0, -6.0)
	return metrics


func _test_metrics_and_exact_projection() -> void:
	_metrics = _make_metrics()
	var validation: Dictionary = _metrics.validate()
	_assert(bool(validation.get("valid", false)), "valid projection metrics are accepted")
	var builder: ProjectionDescriptorBuilder = load("res://scripts/projection/projection_descriptor_builder.gd").new() as ProjectionDescriptorBuilder
	var pose: Dictionary = builder.project_pose({"x4": -3, "z4": 7, "elevation": -2, "facing": "EAST"}, _metrics)
	_assert(bool(pose.get("valid", false)), "quarter-coordinate pose projects")
	_assert(pose["position"] == Vector3(8.5, -3.0, -2.5) and is_equal_approx(float(pose["rotation_y"]), -PI / 2.0), "quarter coordinates and signed elevation project exactly")
	var bounds: Dictionary = builder.project_bounds({"minimum_x4": -4, "minimum_z4": 8, "maximum_x4": 8, "maximum_z4": 20}, -2, _metrics)
	var projected_bounds: AABB = bounds["bounds"]
	_assert(projected_bounds.position.is_equal_approx(Vector3(8.0, -3.0, -2.0)) and projected_bounds.size.is_equal_approx(Vector3(6.0, 0.0, 6.0)), "quarter bounds project exactly")
	var directions: Dictionary = {}
	for facing: String in ["NORTH", "EAST", "SOUTH", "WEST", "NONE"]:
		directions[facing] = builder.project_pose({"x4": 0, "z4": 0, "elevation": 0, "facing": facing}, _metrics)["rotation_y"]
	_assert(directions["NORTH"] == 0.0 and directions["EAST"] == -PI / 2.0 and directions["SOUTH"] == PI and directions["WEST"] == PI / 2.0 and directions["NONE"] == 0.0, "facing projection is deterministic")


func _test_invalid_metrics_rejection() -> void:
	var invalid: ProjectionMetrics = _make_metrics()
	invalid.grid_unit_size = 0.0
	var builder: ProjectionDescriptorBuilder = load("res://scripts/projection/projection_descriptor_builder.gd").new() as ProjectionDescriptorBuilder
	var result: Dictionary = builder.project_pose({"x4": 0, "z4": 0, "elevation": 0, "facing": "NONE"}, invalid)
	_assert(bool(invalid.validate().get("valid", false)) == false and not bool(result.get("valid", false)), "invalid metrics reject projection before materialization")


func _test_bounded_runtime_projection() -> void:
	var resolution: Dictionary = _resolver.resolve(_factory.build_fixture("A"))
	var snapshot: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	_runtime = load("res://scripts/district/district_runtime.gd").new() as DistrictRuntime
	var created: Dictionary = _runtime.create_session(snapshot)
	_assert(bool(created.get("valid", false)), "projection test runtime session creates")
	_coordinator = load("res://scripts/projection/projection_coordinator.gd").new() as ProjectionCoordinator
	var configured: Dictionary = _coordinator.configure(_runtime, _metrics)
	_assert(bool(configured.get("valid", false)), "coordinator accepts the injected metrics")
	var built: Dictionary = _coordinator.rebuild()
	_assert(bool(built.get("valid", false)), "coordinator builds a detached projection")
	var request: ProjectionRequest = load("res://scripts/projection/projection_request.gd").new() as ProjectionRequest
	request.definition_fingerprint = snapshot.get_fingerprint()
	request.district_revision = _runtime.get_revision()
	request.zone_revision = 0
	request.metrics = _metrics.duplicate(true) as ProjectionMetrics
	request.snapshot = snapshot
	request.state = _runtime.get_state()
	request.layers = ["BoundsProjections"]
	var ground_floor_id: String = ""
	for floor: Dictionary in snapshot.get_data().get("floors", []):
		if int(floor.get("elevation", 999)) == 0:
			ground_floor_id = String(floor.get("id", ""))
			break
	request.addresses = [{"floor_id": ground_floor_id}]
	var preview_result: ProjectionResult = _coordinator.preview(request)
	_assert(preview_result.valid and preview_result.candidate_root != null and preview_result.candidate_root.get_parent() == null, "editor/runtime preview returns a detached candidate")
	_assert(preview_result.candidate_root.get_child_count() == 2 and preview_result.manifest["floor_count"] == 1, "request layers and explicit floor address scope are honored")
	preview_result.candidate_root.queue_free()
	var preview_shell: ProjectionPreview = load("res://scripts/projection/projection_preview.gd").new() as ProjectionPreview
	var shown: Dictionary = preview_shell.show_preview(request)
	_assert(bool(shown.get("valid", false)) and preview_shell.get_preview_root() != null, "preview shell commits the shared detached build")
	preview_shell.set_preview_enabled(false)
	_assert(preview_shell.get_preview_root() == null, "disabling preview disposes generated roots")
	preview_shell.free()
	var mismatch: ProjectionRequest = request
	mismatch.metrics = _make_metrics()
	mismatch.metrics.revision = 8
	var mismatch_result: ProjectionResult = _coordinator.preview(mismatch)
	_assert(not mismatch_result.valid and mismatch_result.diagnostics[0]["code"] == "METRICS_MISMATCH", "metrics identity/revision/value mismatch rejects before commit")
	var manifest: Dictionary = _coordinator.get_manifest()
	_assert(int(manifest.get("floor_count", 0)) == 15 and int(manifest.get("node_budget", 0)) == 15, "projection manifest records bounded one-root-per-floor budget")
	var root: Node3D = _coordinator.get_active_root()
	_assert(root != null and root.get_child_count() == 23, "generated root contains layers plus one floor node per descriptor")
	var ground: Floor
	for child: Node in root.get_children():
		if child is Floor:
			ground = child as Floor
			break
	_assert(ground != null and ground.get_child_count() == 17, "floor container has no per-cell visual nodes")
	_assert(root.get_meta("generated_projection", false) == true, "generated metadata is kept on the projection root")
	var old_root: Node3D = root
	var rebuilt: Dictionary = _coordinator.rebuild()
	_assert(bool(rebuilt.get("valid", false)) and _coordinator.get_active_root() != old_root, "rebuild atomically swaps the prior projection root")
	var stale: ProjectionRequest = load("res://scripts/projection/projection_request.gd").new() as ProjectionRequest
	stale.definition_fingerprint = snapshot.get_fingerprint()
	stale.district_revision = _runtime.get_revision() + 1
	stale.zone_revision = 0
	stale.metrics = _make_metrics()
	stale.snapshot = snapshot
	stale.state = _runtime.get_state()
	var retained_root: Node3D = _coordinator.get_active_root()
	var stale_result: ProjectionResult = _coordinator.preview(stale)
	_assert(not stale_result.valid and stale_result.diagnostics[0]["code"] == "STALE_PROJECTION" and _coordinator.get_active_root() == retained_root, "stale builds retain the prior projection")
	var changed_metrics: ProjectionMetrics = _make_metrics()
	changed_metrics.revision = 8
	var reconfigured: Dictionary = _coordinator.configure(_runtime, changed_metrics)
	var metrics_rebuild: Dictionary = _coordinator.rebuild()
	_assert(bool(reconfigured.get("valid", false)) and bool(metrics_rebuild.get("valid", false)) and int(_coordinator.get_manifest()["district_revision"]) == 0 and int(_coordinator.get_manifest()["metrics"]["revision"]) == 8, "presentation metric changes rebuild without authority mutation")
	_coordinator.dispose()
	_assert(_coordinator.get_active_root() == null and _coordinator.get_manifest().is_empty(), "coordinator disposal removes generated presentation")
