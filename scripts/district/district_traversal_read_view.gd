class_name DistrictTraversalReadView
extends RefCounted

## Immutable H3 traversal input view consumed by H5. It is a derived read
## contract and never contains Node references or presentation geometry.

var definition_fingerprint: String = ""
var district_revision: int = -1
var zone_revision: int = -1
var floor_circulation_edges: Array[Dictionary] = []
var door_access_edges: Array[Dictionary] = []
var vertical_links: Array[Dictionary] = []


func initialize(
	p_definition_fingerprint: String,
	p_district_revision: int,
	p_zone_revision: int,
	p_floor_circulation_edges: Array,
	p_door_access_edges: Array,
	p_vertical_links: Array
) -> void:
	definition_fingerprint = p_definition_fingerprint
	district_revision = p_district_revision
	zone_revision = p_zone_revision
	floor_circulation_edges = _typed_copy(p_floor_circulation_edges)
	door_access_edges = _typed_copy(p_door_access_edges)
	vertical_links = _typed_copy(p_vertical_links)


func validate(snapshot: ResolvedDistrictSnapshot) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if snapshot == null:
		diagnostics.append({"code": "SNAPSHOT_REQUIRED", "message": "traversal view requires an immutable district snapshot"})
	elif definition_fingerprint != snapshot.get_fingerprint():
		diagnostics.append({"code": "TRAVERSAL_FINGERPRINT_MISMATCH", "message": "traversal view fingerprint must match the district snapshot"})
	if district_revision < 0:
		diagnostics.append({"code": "TRAVERSAL_DISTRICT_REVISION_INVALID", "message": "traversal district revision cannot be negative"})
	if zone_revision < 0:
		diagnostics.append({"code": "TRAVERSAL_ZONE_REVISION_INVALID", "message": "traversal zone revision cannot be negative"})
	_validate_records(floor_circulation_edges, ["edge_id", "from_cell_id", "to_cell_id", "kind"], "floor_circulation_edges", diagnostics)
	_validate_records(door_access_edges, ["door_edge_id", "floor_id", "interior_cell_id", "external_ref", "access_kind", "source_kind"], "door_access_edges", diagnostics)
	_validate_records(vertical_links, ["link_id", "from_floor_id", "from_cell_id", "to_floor_id", "to_cell_id", "kind"], "vertical_links", diagnostics)
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func duplicate_value() -> DistrictTraversalReadView:
	var copy: DistrictTraversalReadView = load("res://scripts/district/district_traversal_read_view.gd").new() as DistrictTraversalReadView
	copy.initialize(definition_fingerprint, district_revision, zone_revision, floor_circulation_edges, door_access_edges, vertical_links)
	return copy


func value() -> Dictionary:
	return {
		"definition_fingerprint": definition_fingerprint,
		"district_revision": district_revision,
		"zone_revision": zone_revision,
		"floor_circulation_edges": floor_circulation_edges.duplicate(true),
		"door_access_edges": door_access_edges.duplicate(true),
		"vertical_links": vertical_links.duplicate(true),
	}


func _typed_copy(records: Array) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for record: Variant in records:
		if record is Dictionary:
			copied.append(record.duplicate(true))
	return copied


func _validate_records(records: Array[Dictionary], fields: Array[String], label: String, diagnostics: Array[Dictionary]) -> void:
	var previous_id: String = ""
	for index: int in range(records.size()):
		var record: Dictionary = records[index]
		for field: String in fields:
			if not record.has(field):
				diagnostics.append({"code": "TRAVERSAL_FIELD_MISSING", "path": "$.%s[%d].%s" % [label, index, field], "message": "traversal record field is required"})
		var record_id: String = String(record.get(fields[0], ""))
		if record_id.is_empty():
			diagnostics.append({"code": "TRAVERSAL_ID_INVALID", "path": "$.%s[%d]" % [label, index], "message": "traversal record ID is required"})
		if index > 0 and record_id <= previous_id:
			diagnostics.append({"code": "TRAVERSAL_ORDER_INVALID", "path": "$.%s[%d]" % [label, index], "message": "traversal records must be stable-ID ascending"})
		previous_id = record_id
