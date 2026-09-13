## Closed immutable detached facts used to resolve legal exterior queue positions.
class_name QueueResolutionSnapshot
extends RefCounted

const SCHEMA_ID: String = "queue_resolution_snapshot"
const SCHEMA_VERSION: int = 1
const KEYS: Array[String] = ["schema_id", "schema_version", "layout_ref", "district_revision", "zone_revision", "floor_scope", "public_queue_tiles", "nonpublic_quarter_cells", "intersection_quarter_cells", "crosswalk_quarter_cells", "source_anchor_quarter_cells", "vertical_link_quarter_cells", "structural_approach_quarter_cells", "fixed_occupancy_quarter_cells"]
const CELL_COLLECTIONS: Array[String] = ["public_queue_tiles"]
const QUARTER_COLLECTIONS: Array[String] = ["nonpublic_quarter_cells", "intersection_quarter_cells", "crosswalk_quarter_cells", "source_anchor_quarter_cells", "vertical_link_quarter_cells", "structural_approach_quarter_cells", "fixed_occupancy_quarter_cells"]

var _value: Dictionary = {}


func configure(value: Dictionary) -> Dictionary:
	var diagnostics: Array[Dictionary] = validate_value(value)
	if not diagnostics.is_empty():
		return {"valid": false, "diagnostics": diagnostics}
	_value = value.duplicate(true)
	return {"valid": true, "diagnostics": []}


func duplicate_value() -> Dictionary:
	return _value.duplicate(true)


static func validate_value(value: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if not _exact_keys(value, KEYS) or value.get("schema_id") != SCHEMA_ID or value.get("schema_version") != SCHEMA_VERSION:
		return [_diagnostic("QUEUE_INPUT_SCHEMA_INVALID", "$", {})]
	if not _valid_layout_ref(value.get("layout_ref")) or not value.get("district_revision") is int or int(value["district_revision"]) < 0 or not value.get("zone_revision") is int or int(value["zone_revision"]) < 0:
		diagnostics.append(_diagnostic("QUEUE_INPUT_PROVENANCE_INVALID", "$", {}))
	var scope: Variant = value.get("floor_scope")
	if not scope is Dictionary or not _exact_keys(scope, ["floor_id", "runtime_plot_id", "signed_elevation"]) or String(scope.get("floor_id", "")).is_empty() or String(scope.get("runtime_plot_id", "")).is_empty() or not scope.get("signed_elevation") is int:
		diagnostics.append(_diagnostic("QUEUE_INPUT_SCOPE_INVALID", "$.floor_scope", {}))
	for collection_name: String in CELL_COLLECTIONS:
		_validate_ordered_points(value.get(collection_name), "x", "y", "$.%s" % collection_name, diagnostics)
	for collection_name: String in QUARTER_COLLECTIONS:
		_validate_ordered_points(value.get(collection_name), "x4", "y4", "$.%s" % collection_name, diagnostics)
	return diagnostics


static func _validate_ordered_points(value: Variant, x_key: String, y_key: String, path: String, diagnostics: Array[Dictionary]) -> void:
	if not value is Array:
		diagnostics.append(_diagnostic("QUEUE_INPUT_COLLECTION_INVALID", path, {})); return
	var previous: Array[int] = [-2147483648, -2147483648]
	var seen: Dictionary = {}
	for index: int in range(value.size()):
		var point: Variant = value[index]
		if not point is Dictionary or not _exact_keys(point, [x_key, y_key]) or not point.get(x_key) is int or not point.get(y_key) is int:
			diagnostics.append(_diagnostic("QUEUE_INPUT_POINT_INVALID", "%s[%d]" % [path, index], {})); continue
		var key := "%d,%d" % [point[x_key], point[y_key]]
		var current: Array[int] = [int(point[y_key]), int(point[x_key])]
		if seen.has(key) or current < previous:
			diagnostics.append(_diagnostic("QUEUE_INPUT_ORDER_INVALID", path, {}))
		seen[key] = true; previous = current


static func _valid_layout_ref(value: Variant) -> bool:
	return value is Dictionary and _exact_keys(value, ["layout_id", "layout_definition_version", "definition_fingerprint"]) and not String(value.get("layout_id", "")).is_empty() and value.get("layout_definition_version") is int and int(value["layout_definition_version"]) > 0 and String(value.get("definition_fingerprint", "")).length() == 64 and String(value["definition_fingerprint"]).to_lower() == value["definition_fingerprint"]


static func _exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	var actual: Array[String] = []
	for key: Variant in value.keys(): actual.append(String(key))
	actual.sort(); var wanted := expected.duplicate(); wanted.sort()
	return actual == wanted


static func _diagnostic(code: String, path: String, values: Dictionary) -> Dictionary:
	return {"code": code, "path": path, "values": values.duplicate(true)}
