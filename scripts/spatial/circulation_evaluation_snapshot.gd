class_name CirculationEvaluationSnapshot
extends RefCounted

const SCHEMA_VERSION: int = 1
const FIELDS: Array[String] = [
	"schema_version", "target_parcel_id", "target_zone_id", "elevation",
	"public_route_reaches_frontage", "valid_stair_count", "valid_elevator_count",
	"topology_revision", "source_identity", "accessibility_band",
]
var _data: Dictionary = {}


func configure(values: Dictionary) -> void:
	_data = values.duplicate(true)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


func validate() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	for field: String in FIELDS:
		if not _data.has(field):
			diagnostics.append({"code": "CIRCULATION_CONTEXT_UNAVAILABLE", "path": "$.%s" % field})
	for key: Variant in _data.keys():
		if not FIELDS.has(String(key)):
			diagnostics.append({"code": "CIRCULATION_CONTEXT_UNAVAILABLE", "path": "$.%s" % String(key)})
	if int(_data.get("schema_version", -1)) != SCHEMA_VERSION or int(_data.get("topology_revision", -1)) < 0:
		diagnostics.append({"code": "CIRCULATION_CONTEXT_UNAVAILABLE", "path": "$.schema_version"})
	if int(_data.get("elevation", 0)) < -100 or int(_data.get("elevation", 0)) > 100:
		diagnostics.append({"code": "CIRCULATION_CONTEXT_UNAVAILABLE", "path": "$.elevation"})
	if int(_data.get("valid_stair_count", -1)) < 0 or int(_data.get("valid_elevator_count", -1)) < 0:
		diagnostics.append({"code": "CIRCULATION_CONTEXT_UNAVAILABLE", "path": "$.valid_links"})
	if not ["poor", "average", "good", "excellent"].has(String(_data.get("accessibility_band", ""))):
		diagnostics.append({"code": "CIRCULATION_CONTEXT_UNAVAILABLE", "path": "$.accessibility_band"})
	if String(_data.get("source_identity", "")).is_empty():
		diagnostics.append({"code": "CIRCULATION_CONTEXT_UNAVAILABLE", "path": "$.source_identity"})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


static func create(parcel_id: String, zone_id: String, elevation: int, route_exists: bool, stairs: int, elevators: int, topology_revision: int, source_identity: String) -> CirculationEvaluationSnapshot:
	var band := "poor"
	if route_exists:
		if elevation == 0:
			band = "average"
		elif stairs > 0 and elevators > 0:
			band = "excellent"
		elif stairs > 0 or elevators > 0:
			band = "good"
		else:
			band = "average"
	var snapshot := CirculationEvaluationSnapshot.new()
	snapshot.configure({
		"schema_version": SCHEMA_VERSION,
		"target_parcel_id": parcel_id,
		"target_zone_id": zone_id,
		"elevation": elevation,
		"public_route_reaches_frontage": route_exists,
		"valid_stair_count": stairs,
		"valid_elevator_count": elevators,
		"topology_revision": topology_revision,
		"source_identity": source_identity,
		"accessibility_band": band,
	})
	return snapshot
