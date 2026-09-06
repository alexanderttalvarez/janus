@tool
class_name ProjectionCoordinator
extends Node3D

## Owns generated projection roots. It consumes immutable H3 views and never
## writes district, zone, economy, progression, or persistence authority.

signal projection_committed(manifest: Dictionary)
signal projection_rejected(diagnostics: Array[Dictionary])
signal projection_cancelled(build_token: int)

const ALL_LAYERS: Array[String] = ["WallProjections", "DoorGapProjections", "OverlayProjections", "HeatmapProjections", "LabelProjections", "DebugProjections", "PickingProjections", "BoundsProjections"]

var _runtime: DistrictRuntime
var _metrics: ProjectionMetrics
var _builder: ProjectionDescriptorBuilder
var _active_root: Node3D
var _active_floor_index: Dictionary = {}
var _manifest: Dictionary = {}
var _generation: int = 0
var _build_token: int = 0
var _last_result: ProjectionResult
var _last_built_district_revision: int = -1


func configure(runtime: DistrictRuntime, metrics: ProjectionMetrics) -> Dictionary:
	if runtime == null:
		return _reject("RUNTIME_REQUIRED", "projection requires a District Runtime")
	if metrics == null:
		return _reject("METRICS_REQUIRED", "projection metrics are required")
	var validation: Dictionary = metrics.validate()
	if not bool(validation.get("valid", false)):
		return {"valid": false, "diagnostics": validation.get("diagnostics", [])}
	_runtime = runtime
	_metrics = metrics.duplicate(true) as ProjectionMetrics
	_builder = load("res://scripts/projection/projection_descriptor_builder.gd").new() as ProjectionDescriptorBuilder
	if not _runtime.district_delta_committed.is_connected(_on_district_delta_committed):
		_runtime.district_delta_committed.connect(_on_district_delta_committed)
	return {"valid": true, "diagnostics": []}


func rebuild() -> Dictionary:
	var request_result: Dictionary = _make_runtime_request()
	if not bool(request_result.get("valid", false)):
		return _reject_diagnostics(request_result.get("diagnostics", []))
	var result: ProjectionResult = build(request_result["request"] as ProjectionRequest)
	if not result.valid:
		return _reject_diagnostics(result.diagnostics)
	return _commit(result)


## Build a detached candidate using the same path for runtime and editor preview.
func build(request: ProjectionRequest) -> ProjectionResult:
	var result: ProjectionResult = ProjectionResult.new()
	if request == null:
		return _result_failure(result, "REQUEST_REQUIRED", "projection request is required")
	var request_validation: Dictionary = request.validate()
	if not bool(request_validation.get("valid", false)):
		return _result_failure_diagnostics(result, request_validation.get("diagnostics", []))
	if _metrics != null and not _metrics.matches(request.metrics):
		return _result_failure(result, "METRICS_MISMATCH", "request metrics do not match the configured metrics")
	if _metrics == null:
		_metrics = request.metrics.duplicate(true) as ProjectionMetrics
	if _builder == null:
		_builder = load("res://scripts/projection/projection_descriptor_builder.gd").new() as ProjectionDescriptorBuilder
	var token: int = _build_token
	var descriptor_result: Dictionary = _builder.build_floor_descriptors(request.snapshot, request.state, request.metrics)
	if not bool(descriptor_result.get("valid", false)):
		return _result_failure_diagnostics(result, descriptor_result.get("diagnostics", []))
	var descriptors: Array = _filter_descriptors(descriptor_result.get("descriptors", []), request.addresses)
	var candidate: Node3D = _materialize(descriptors, request.layers, request.editor_mode, request.descriptor_batches)
	if candidate == null:
		return _result_failure(result, "MATERIALIZATION_FAILED", "projection candidate could not be materialized")
	if token != _build_token:
		candidate.queue_free()
		return _result_failure(result, "PROJECTION_CANCELLED", "projection build was cancelled")
	if _runtime != null:
		var current: Dictionary = _runtime.get_state_read()
		var current_snapshot: ResolvedDistrictSnapshot = current.get("snapshot") as ResolvedDistrictSnapshot
		if int(current.get("district_revision", -1)) != request.district_revision or current_snapshot == null or current_snapshot.get_fingerprint() != request.definition_fingerprint:
			candidate.queue_free()
			return _result_failure(result, "STALE_PROJECTION", "district changed while projection was building")
	result.valid = true
	result.candidate_root = candidate
	result.source_mappings = _source_mappings(descriptors)
	result.transforms = _transforms(descriptors)
	result.bounds = _bounds(descriptors)
	result.budgets = {"floor_nodes": descriptors.size(), "node_budget": descriptors.size(), "layers": request.layers.duplicate(), "descriptor_primitive_count": _primitive_count(request.descriptor_batches)}
	result.descriptor_batches = request.descriptor_batches.duplicate()
	result.manifest = {
		"definition_fingerprint": request.definition_fingerprint,
		"district_revision": request.district_revision,
		"zone_revision": request.zone_revision,
		"metrics": request.metrics.value(),
		"affected_scope": request.affected_scope.duplicate(true),
		"layers": request.layers.duplicate(),
		"editor_mode": request.editor_mode,
		"floor_count": descriptors.size(),
		"node_budget": descriptors.size(),
	}
	return result


## Preview leaves the candidate detached for an editor/tool caller to inspect.
func preview(request: ProjectionRequest) -> ProjectionResult:
	return build(request)


func cancel_build() -> void:
	_build_token += 1
	projection_cancelled.emit(_build_token)


func commit_result(result: ProjectionResult) -> Dictionary:
	return _commit(result)


func _commit(result: ProjectionResult) -> Dictionary:
	if result == null or not result.valid or result.candidate_root == null:
		return _reject("RESULT_INVALID", "only a valid detached projection can be committed")
	if result.candidate_root.get_parent() != null:
		return _reject("RESULT_NOT_DETACHED", "projection candidate must remain detached until commit")
	var old_root: Node3D = _active_root
	_active_root = result.candidate_root
	add_child(_active_root)
	_rebuild_floor_index()
	if old_root != null and is_instance_valid(old_root):
		old_root.queue_free()
	_generation += 1
	_manifest = result.manifest.duplicate(true)
	_manifest["generation"] = _generation
	_last_result = result
	_last_built_district_revision = int(result.manifest.get("district_revision", -1))
	projection_committed.emit(get_manifest())
	return {"valid": true, "manifest": get_manifest(), "diagnostics": []}


func dispose() -> void:
	cancel_build()
	if _runtime != null and _runtime.district_delta_committed.is_connected(_on_district_delta_committed):
		_runtime.district_delta_committed.disconnect(_on_district_delta_committed)
	if _active_root != null and is_instance_valid(_active_root):
		_active_root.queue_free()
	_active_root = null
	_active_floor_index.clear()
	_runtime = null
	_metrics = null
	_builder = null
	_last_result = null
	_last_built_district_revision = -1
	_manifest = {}


func get_manifest() -> Dictionary:
	return _manifest.duplicate(true)


func get_active_root() -> Node3D:
	return _active_root


## Resolve a generated floor from the full H3/H4 floor address.
func get_projected_floor(address: Dictionary) -> Floor:
	var floor_id: String = String(address.get("floor_id", ""))
	if floor_id.is_empty():
		return null
	var floor: Floor = _active_floor_index.get(floor_id, null) as Floor
	if floor == null or not is_instance_valid(floor):
		return null
	var runtime_plot_id: String = String(address.get("runtime_plot_id", ""))
	if not runtime_plot_id.is_empty() and String(floor.get_meta("runtime_plot_id", "")) != runtime_plot_id:
		return null
	if address.has("elevation") and int(floor.get_meta("elevation", 0)) != int(address["elevation"]):
		return null
	return floor


## Project a fractional local grid coordinate through the generated floor.
func project_grid_coordinate(address: Dictionary, grid_coordinate: Vector2) -> Vector3:
	var floor: Floor = get_projected_floor(address)
	if floor == null:
		return Vector3.INF
	return floor.to_global(floor.grid_coordinate_to_local(grid_coordinate))


## Project the canonical center of one local grid cell.
func project_cell_center(address: Dictionary, cell: Vector2i) -> Vector3:
	return project_grid_coordinate(address, Vector2(cell) + Vector2(0.5, 0.5))


## Return the projected local cell under a world-space camera ray.
func pick_cell(address: Dictionary, ray_origin: Vector3, ray_direction: Vector3) -> Dictionary:
	var floor: Floor = get_projected_floor(address)
	if floor == null or ray_direction.length_squared() <= 0.000001:
		return {"valid": false, "cell": Vector2i(-1, -1)}
	var local_origin: Vector3 = floor.to_local(ray_origin)
	var local_direction: Vector3 = floor.global_transform.basis.inverse() * ray_direction.normalized()
	var grid_origin: Marker3D = floor.get_grid_origin()
	var plane_y: float = grid_origin.position.y if grid_origin != null else 0.0
	if absf(local_direction.y) < 0.000001:
		return {"valid": false, "cell": Vector2i(-1, -1)}
	var distance: float = (plane_y - local_origin.y) / local_direction.y
	if distance < 0.0:
		return {"valid": false, "cell": Vector2i(-1, -1)}
	var local_hit: Vector3 = local_origin + local_direction * distance
	var origin_position: Vector3 = grid_origin.position if grid_origin != null else Vector3.ZERO
	var cell_position := Vector2i(
		floori((local_hit.x - origin_position.x) / floor.tile_size),
		floori((local_hit.z - origin_position.z) / floor.tile_size)
	)
	if cell_position.x < 0 or cell_position.y < 0 or cell_position.x >= floor.grid_width or cell_position.y >= floor.grid_height:
		return {"valid": false, "cell": cell_position, "world_position": floor.to_global(local_hit)}
	return {"valid": true, "cell": cell_position, "world_position": floor.to_global(local_hit)}


func get_projected_tile_size(address: Dictionary) -> float:
	var floor: Floor = get_projected_floor(address)
	return floor.tile_size if floor != null else 0.0


func _rebuild_floor_index() -> void:
	_active_floor_index.clear()
	if _active_root == null:
		return
	for child: Node in _active_root.get_children():
		var floor: Floor = child as Floor
		if floor == null:
			continue
		var floor_id: String = String(floor.get_meta("runtime_floor_id", ""))
		if not floor_id.is_empty():
			_active_floor_index[floor_id] = floor


func _materialize(
	descriptors: Array,
	requested_layers: Array[String] = [],
	editor_mode: bool = false,
	batches: Array[ProjectionDescriptorBatch] = []
) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "GeneratedProjection_%d" % (_generation + 1)
	root.set_meta("generated_projection", true)
	root.set_meta("projection_mode", "editor" if editor_mode else "runtime")
	var layer_names: Array[String] = ALL_LAYERS if requested_layers.is_empty() else requested_layers
	for layer_name: String in layer_names:
		var layer: Node3D = Node3D.new()
		layer.name = layer_name
		layer.set_meta("generated_projection", true)
		root.add_child(layer)
	var floor_scene: PackedScene = load("res://scenes/world/floor.tscn") as PackedScene
	if floor_scene == null:
		root.queue_free()
		return null
	for descriptor: Dictionary in descriptors:
		var floor_node: Floor = floor_scene.instantiate() as Floor
		if floor_node == null:
			root.queue_free()
			return null
		var elevation: int = int(descriptor.get("elevation", 0))
		var floor_label: String = "G" if elevation == 0 else ("F%d" % elevation if elevation > 0 else "B%d" % absi(elevation))
		var plot_id: String = String(descriptor.get("plot_id", ""))
		floor_node.name = "floor_%s_%s" % [plot_id, floor_label]
		floor_node.plot_id = plot_id
		floor_node.floor_level = floor_label
		floor_node.position = descriptor.get("position", Vector3.ZERO)
		floor_node.rotation.y = float(descriptor.get("rotation_y", 0.0))
		floor_node.set_meta("generated_projection", true)
		floor_node.set_meta("runtime_floor_id", descriptor.get("floor_id", ""))
		floor_node.set_meta("runtime_plot_id", descriptor.get("plot_id", ""))
		floor_node.set_meta("elevation", elevation)
		floor_node.apply_projection(descriptor, _metrics)
		root.add_child(floor_node)
	_materialize_batches(root, batches)
	return root


func _materialize_batches(root: Node3D, batches: Array[ProjectionDescriptorBatch]) -> void:
	for batch: ProjectionDescriptorBatch in batches:
		for primitive: Dictionary in batch.primitives:
			var layer_name: String = String(primitive.get("layer", "ProjectionPrimitives"))
			var layer: Node3D = root.get_node_or_null(layer_name) as Node3D
			if layer == null:
				layer = Node3D.new()
				layer.name = layer_name
				layer.set_meta("generated_projection", true)
				root.add_child(layer)
			var node: MeshInstance3D = _materialize_primitive(primitive, batch)
			if node != null:
				layer.add_child(node)


func _materialize_primitive(primitive: Dictionary, batch: ProjectionDescriptorBatch) -> MeshInstance3D:
	var payload: Dictionary = primitive.get("presentation_payload", {})
	var rect: Dictionary = primitive.get("rect_quarter", payload.get("rect_quarter", {}))
	var position: Vector3 = payload.get("position", Vector3.ZERO)
	var size: Vector3 = payload.get("size", Vector3.ONE)
	var elevation: int = int(primitive.get("elevation", payload.get("elevation", 0)))
	if rect.has("minimum_x4") and rect.has("minimum_z4") and rect.has("maximum_x4") and rect.has("maximum_z4"):
		var minimum_x4: int = int(rect["minimum_x4"])
		var minimum_z4: int = int(rect["minimum_z4"])
		var maximum_x4: int = int(rect["maximum_x4"])
		var maximum_z4: int = int(rect["maximum_z4"])
		var minimum: Vector3 = _metrics.origin + Vector3(float(minimum_x4) / 4.0 * _metrics.grid_unit_size, float(elevation) * _metrics.floor_height, float(minimum_z4) / 4.0 * _metrics.grid_unit_size)
		var maximum: Vector3 = _metrics.origin + Vector3(float(maximum_x4) / 4.0 * _metrics.grid_unit_size, float(elevation) * _metrics.floor_height, float(maximum_z4) / 4.0 * _metrics.grid_unit_size)
		size = Vector3(maximum.x - minimum.x, float(payload.get("thickness", 0.05)), maximum.z - minimum.z)
		position = Vector3((minimum.x + maximum.x) * 0.5, minimum.y + size.y * 0.5, (minimum.z + maximum.z) * 0.5)
	else:
		size.y = float(payload.get("thickness", size.y))
	if size.x <= 0.0 or size.z <= 0.0 or size.y <= 0.0:
		return null
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = String(primitive.get("primitive_id", "ProjectionPrimitive"))
	node.mesh = mesh
	node.position = position
	node.rotation.y = float(payload.get("rotation_y", 0.0))
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var color: Variant = payload.get("color", Color.WHITE)
	material.albedo_color = color if color is Color else Color.WHITE
	node.material_override = material
	node.set_meta("generated_projection", true)
	node.set_meta("projection_channel_id", batch.channel_id)
	node.set_meta("projection_owner_id", batch.owner_id)
	node.set_meta("projection_source_id", primitive.get("source_id", ""))
	node.set_meta("projection_primitive_kind", primitive.get("primitive_kind", ""))
	return node


func _primitive_count(batches: Array[ProjectionDescriptorBatch]) -> int:
	var count: int = 0
	for batch: ProjectionDescriptorBatch in batches:
		count += batch.primitives.size()
	return count


func _on_district_delta_committed(_envelope: Dictionary) -> void:
	rebuild()


func _make_runtime_request() -> Dictionary:
	if _runtime == null or _metrics == null or _builder == null:
		return {"valid": false, "diagnostics": [{"code": "COORDINATOR_UNCONFIGURED", "message": "projection coordinator is not configured"}]}
	var captured: Dictionary = _runtime.get_state_read()
	var snapshot: ResolvedDistrictSnapshot = captured.get("snapshot") as ResolvedDistrictSnapshot
	if snapshot == null:
		return {"valid": false, "diagnostics": [{"code": "SNAPSHOT_REQUIRED", "message": "projection requires an active runtime snapshot"}]}
	var request: ProjectionRequest = load("res://scripts/projection/projection_request.gd").new() as ProjectionRequest
	request.definition_fingerprint = snapshot.get_fingerprint()
	request.district_revision = int(captured.get("district_revision", -1))
	request.zone_revision = 0
	request.layers = ALL_LAYERS.duplicate()
	request.metrics = _metrics.duplicate(true) as ProjectionMetrics
	request.snapshot = snapshot
	request.state = captured.get("state", {}).duplicate(true)
	return {"valid": true, "request": request, "diagnostics": []}


func _filter_descriptors(descriptors: Array, addresses: Array[Dictionary]) -> Array:
	if addresses.is_empty():
		return descriptors
	var filtered: Array = []
	for descriptor: Dictionary in descriptors:
		for address: Dictionary in addresses:
			var floor_match: bool = not address.has("floor_id") or String(address["floor_id"]) == String(descriptor.get("floor_id", ""))
			var plot_match: bool = not address.has("runtime_plot_id") or String(address["runtime_plot_id"]) == String(descriptor.get("plot_id", ""))
			var elevation_match: bool = not address.has("elevation") or int(address["elevation"]) == int(descriptor.get("elevation", 0))
			if floor_match and plot_match and elevation_match:
				filtered.append(descriptor)
				break
	return filtered


func _source_mappings(descriptors: Array) -> Array[Dictionary]:
	var mappings: Array[Dictionary] = []
	for descriptor: Dictionary in descriptors:
		mappings.append({"source_id": descriptor.get("floor_id", ""), "node_name": "floor_%s" % descriptor.get("floor_id", "")})
	return mappings


func _transforms(descriptors: Array) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for descriptor: Dictionary in descriptors:
		values.append({"source_id": descriptor.get("floor_id", ""), "position": descriptor.get("position", Vector3.ZERO), "rotation_y": descriptor.get("rotation_y", 0.0)})
	return values


func _bounds(descriptors: Array) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for descriptor: Dictionary in descriptors:
		values.append({"source_id": descriptor.get("floor_id", ""), "bounds": descriptor.get("bounds", AABB())})
	return values


func _result_failure(result: ProjectionResult, code: String, message: String) -> ProjectionResult:
	return _result_failure_diagnostics(result, [{"code": code, "message": message}])


func _result_failure_diagnostics(result: ProjectionResult, diagnostics: Array) -> ProjectionResult:
	result.valid = false
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary:
			result.diagnostics.append(diagnostic)
	return result


func _reject(code: String, message: String) -> Dictionary:
	return _reject_diagnostics([{"code": code, "message": message}])


func _reject_diagnostics(diagnostics: Array) -> Dictionary:
	var typed: Array[Dictionary] = []
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary:
			typed.append(diagnostic)
	projection_rejected.emit(typed)
	return {"valid": false, "diagnostics": typed}
