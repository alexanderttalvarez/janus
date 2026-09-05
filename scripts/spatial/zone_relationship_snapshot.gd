class_name ZoneRelationshipSnapshot
extends RefCounted

const SCHEMA_VERSION: int = 1
const FIELDS: Array[String] = [
	"schema_version", "target_zone_id", "application_adjacency", "selected_zone_id",
	"selected_relation_distance", "nearest_same_type_distance", "competition_band",
	"policy_revision", "geometry_revision", "provenance",
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
			diagnostics.append({"code": "RELATIONSHIP_CONTEXT_UNAVAILABLE", "path": "$.%s" % field})
	for key: Variant in _data.keys():
		if not FIELDS.has(String(key)):
			diagnostics.append({"code": "RELATIONSHIP_CONTEXT_UNAVAILABLE", "path": "$.%s" % String(key)})
	if int(_data.get("schema_version", -1)) != SCHEMA_VERSION or int(_data.get("policy_revision", -1)) < 1 or int(_data.get("geometry_revision", -1)) < 0:
		diagnostics.append({"code": "RELATIONSHIP_CONTEXT_UNAVAILABLE", "path": "$.revision"})
	if not ["negative", "neutral", "positive"].has(String(_data.get("application_adjacency", ""))):
		diagnostics.append({"code": "RELATIONSHIP_CONTEXT_UNAVAILABLE", "path": "$.application_adjacency"})
	if not ["none", "within_10", "within_20"].has(String(_data.get("competition_band", ""))):
		diagnostics.append({"code": "RELATIONSHIP_CONTEXT_UNAVAILABLE", "path": "$.competition_band"})
	if String(_data.get("provenance", "")).is_empty():
		diagnostics.append({"code": "RELATIONSHIP_CONTEXT_UNAVAILABLE", "path": "$.provenance"})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}
