class_name VisitorMetricsSnapshot
extends RefCounted

const SCHEMA_VERSION: int = 1
const FIELDS: Array[String] = ["schema_version", "simulation_day", "metric_revision", "current_visitors", "daily_arrivals", "daily_average_arrivals", "finalized_arrival_total", "finalized_day_count", "average_available", "provenance"]
var _data: Dictionary = {}


func configure(values: Dictionary) -> void:
	_data = values.duplicate(true)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


func validate() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	for field: String in FIELDS:
		if not _data.has(field):
			diagnostics.append({"code": "VISITOR_METRICS_INVALID", "path": "$.%s" % field})
	for key: Variant in _data.keys():
		if not FIELDS.has(String(key)):
			diagnostics.append({"code": "VISITOR_METRICS_INVALID", "path": "$.%s" % String(key)})
	for field: String in ["simulation_day", "metric_revision", "current_visitors", "daily_arrivals", "finalized_arrival_total", "finalized_day_count"]:
		if int(_data.get(field, -1)) < 0:
			diagnostics.append({"code": "VISITOR_METRICS_INVALID", "path": "$.%s" % field})
	if bool(_data.get("average_available", false)) and int(_data.get("finalized_day_count", 0)) == 0:
		diagnostics.append({"code": "VISITOR_METRICS_INVALID", "path": "$.average_available"})
	if String(_data.get("provenance", "")).is_empty():
		diagnostics.append({"code": "VISITOR_METRICS_INVALID", "path": "$.provenance"})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}
