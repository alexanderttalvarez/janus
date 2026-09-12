## Isolated authority and projection state prepared before session publication.
class_name SessionRestoreCandidate
extends RefCounted

var layout_ref: Dictionary = {}
var layout_snapshot: ResolvedDistrictSnapshot
var authority_snapshots: Dictionary = {}
var authorities: Dictionary = {}
var projections: Dictionary = {}
var projection_manifests: Dictionary = {}
var context: Dictionary = {}
var prepared: bool = false
var published: bool = false
var disposed: bool = false


func initialize(resolved_layout: Dictionary) -> Dictionary:
	if not bool(resolved_layout.get("valid", false)):
		return _failure("CANDIDATE_LAYOUT_INVALID")
	layout_snapshot = resolved_layout.get("snapshot") as ResolvedDistrictSnapshot
	layout_ref = resolved_layout.get("layout_ref", {}).duplicate(true)
	if layout_snapshot == null or layout_ref.is_empty():
		return _failure("CANDIDATE_LAYOUT_INVALID")
	return {"valid": true, "diagnostics": []}


func import_authority_snapshot(key: String, snapshot: Dictionary) -> Dictionary:
	if disposed or prepared or key.is_empty() or authority_snapshots.has(key):
		return _failure("CANDIDATE_IMPORT_INVALID")
	authority_snapshots[key] = snapshot.duplicate(true)
	return {"valid": true, "diagnostics": []}


func set_authority(key: String, authority: Variant) -> Dictionary:
	if disposed or key.is_empty() or authority == null or authorities.has(key):
		return _failure("CANDIDATE_AUTHORITY_INVALID")
	authorities[key] = authority
	return {"valid": true, "diagnostics": []}


func set_projection(key: String, projection: Variant, manifest: Dictionary = {}) -> Dictionary:
	if disposed or key.is_empty() or projection == null or projections.has(key):
		return _failure("CANDIDATE_PROJECTION_INVALID")
	projections[key] = projection
	projection_manifests[key] = manifest.duplicate(true)
	return {"valid": true, "diagnostics": []}


func mark_prepared(expected_authorities: Array[String], expected_projections: Array[String]) -> Dictionary:
	if disposed or authority_snapshots.keys().size() != expected_authorities.size():
		return _failure("CANDIDATE_AUTHORITY_SET_INCOMPLETE")
	for key: String in expected_authorities:
		if not authority_snapshots.has(key):
			return _failure("CANDIDATE_AUTHORITY_SET_INCOMPLETE")
	for key: String in expected_projections:
		if not projection_manifests.has(key):
			return _failure("CANDIDATE_PROJECTION_SET_INCOMPLETE")
	prepared = true
	return {"valid": true, "diagnostics": []}


func mark_published() -> void:
	published = true


func dispose() -> void:
	if disposed:
		return
	disposed = true
	for value: Variant in projections.values():
		_dispose_value(value)
	for value: Variant in authorities.values():
		_dispose_value(value)
	projections.clear()
	authorities.clear()
	projection_manifests.clear()
	authority_snapshots.clear()
	context.clear()
	layout_snapshot = null
	layout_ref.clear()


func _dispose_value(value: Variant) -> void:
	if value == null or not is_instance_valid(value):
		return
	if value.has_method("dispose"):
		value.call("dispose")
	if value is Node:
		var node: Node = value
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


func _failure(code: String) -> Dictionary:
	return {"valid": false, "diagnostics": [{"code": code, "stage": "candidate"}]}
