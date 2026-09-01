@tool
class_name ProjectionEditorSource
extends RefCounted

## Read-only editor source adapter. It validates and resolves the same H1/H2
## records used by runtime, then creates a defensive baseline state for preview.

var _factory: RefCounted
var _loader: DistrictLayoutDefinitionLoader
var _resolver: DistrictLayoutResolver
var _state_records: DistrictStateRecords
var _public_realm_builder: PublicRealmDescriptorBuilder
var _snapshot: ResolvedDistrictSnapshot
var _state: Dictionary = {}
var _diagnostics: Array[Dictionary] = []
var _revision: int = 0


func _init() -> void:
	_factory = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	_loader = load("res://scripts/resources/district_layout_definition_loader.gd").new() as DistrictLayoutDefinitionLoader
	_resolver = load("res://scripts/resources/district_layout_resolver.gd").new() as DistrictLayoutResolver
	_state_records = load("res://scripts/resources/district_state_records.gd").new() as DistrictStateRecords
	_public_realm_builder = load("res://scripts/public_realm/public_realm_descriptor_builder.gd").new() as PublicRealmDescriptorBuilder


func load_fixture(fixture_id: String) -> Dictionary:
	var record: Dictionary = _factory.build_fixture(fixture_id)
	if record.is_empty():
		return _reject("FIXTURE_NOT_FOUND", "the selected proof fixture does not exist")
	return _load_record(record)


func load_file(path: String) -> Dictionary:
	var loaded: Dictionary = _loader.load_file(path)
	if not bool(loaded.get("valid", false)):
		_diagnostics = _copy_diagnostics(loaded.get("diagnostics", []))
		return {"valid": false, "diagnostics": get_diagnostics()}
	var definition: DistrictLayoutDefinition = loaded.get("definition") as DistrictLayoutDefinition
	if definition == null or not definition.is_published():
		return _reject_diagnostics(loaded.get("diagnostics", []))
	return _load_record(definition.get_semantic_record())


func build_request(metrics: ProjectionMetrics, layers: Array[String] = [], addresses: Array[Dictionary] = []) -> Dictionary:
	if _snapshot == null:
		return {"valid": false, "request": null, "diagnostics": [{"code": "EDITOR_SOURCE_EMPTY", "message": "validate a district layout before rebuilding the preview"}]}
	var request: ProjectionRequest = load("res://scripts/projection/projection_request.gd").new() as ProjectionRequest
	request.definition_fingerprint = _snapshot.get_fingerprint()
	request.district_revision = _revision
	request.zone_revision = 0
	request.addresses = addresses.duplicate(true)
	request.affected_scope = {"editor_source_revision": _revision}
	request.layers = layers.duplicate()
	request.editor_mode = true
	request.metrics = metrics.duplicate(true) as ProjectionMetrics if metrics != null else null
	request.snapshot = _snapshot
	request.state = _state.duplicate(true)
	if _public_realm_builder == null:
		_public_realm_builder = load("res://scripts/public_realm/public_realm_descriptor_builder.gd").new() as PublicRealmDescriptorBuilder
	if _public_realm_builder == null:
		return {"valid": false, "request": null, "diagnostics": [{"code": "PUBLIC_REALM_BUILDER_REQUIRED", "message": "public-realm preview builder could not be loaded"}]}
	var editor_state: Dictionary = request.state.duplicate(true)
	editor_state["district_revision"] = _revision
	var traversal: DistrictTraversalReadView = load("res://scripts/district/district_traversal_read_view.gd").new() as DistrictTraversalReadView
	traversal.initialize(_snapshot.get_fingerprint(), _revision, 0, [], [], [])
	var public_realm: Dictionary = _public_realm_builder.build(_snapshot, editor_state, traversal, request.metrics)
	if not bool(public_realm.get("valid", false)):
		return {"valid": false, "request": null, "diagnostics": public_realm.get("diagnostics", [])}
	request.descriptor_batches = [public_realm.get("batch") as ProjectionDescriptorBatch]
	var validation: Dictionary = request.validate()
	if not bool(validation.get("valid", false)):
		return {"valid": false, "request": null, "diagnostics": validation.get("diagnostics", [])}
	return {"valid": true, "request": request, "diagnostics": []}


func get_revision() -> int:
	return _revision


func get_snapshot() -> ResolvedDistrictSnapshot:
	return _snapshot


func get_diagnostics() -> Array[Dictionary]:
	return _diagnostics.duplicate(true)


func get_fingerprint() -> String:
	return "" if _snapshot == null else _snapshot.get_fingerprint()


func _load_record(record: Dictionary) -> Dictionary:
	var resolution: Dictionary = _resolver.resolve(record)
	if not bool(resolution.get("valid", false)):
		_snapshot = null
		_state.clear()
		_diagnostics = _copy_diagnostics(resolution.get("diagnostics", []))
		return {"valid": false, "diagnostics": get_diagnostics()}
	var candidate: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	if candidate == null:
		return _reject("SNAPSHOT_REQUIRED", "the resolved editor source did not produce a snapshot")
	_snapshot = candidate
	_state = _state_records.create_baseline(_snapshot)
	_diagnostics.clear()
	_revision += 1
	return {"valid": true, "fingerprint": _snapshot.get_fingerprint(), "revision": _revision, "diagnostics": []}


func _reject(code: String, message: String) -> Dictionary:
	return _reject_diagnostics([{"code": code, "message": message}])


func _reject_diagnostics(diagnostics: Array) -> Dictionary:
	_diagnostics = _copy_diagnostics(diagnostics)
	return {"valid": false, "diagnostics": get_diagnostics()}


func _copy_diagnostics(diagnostics: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary:
			typed.append(diagnostic.duplicate(true))
	return typed
