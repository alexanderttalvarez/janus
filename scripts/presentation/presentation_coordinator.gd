class_name PresentationCoordinator
extends RefCounted

## Detached presentation projection. It stores no authority or Node references.
const AVAILABLE: String = "AVAILABLE"
const UNAVAILABLE: String = "UNAVAILABLE"
const STALE: String = "STALE"
const PRIMARY_PANELS: Array[String] = ["finances", "prestige", "tenants", "visitors", "metrics"]


func build_hud(sources: Dictionary, expected_revisions: Dictionary = {}) -> Dictionary:
	var hud: Dictionary = {"availability": AVAILABLE, "metrics": {}, "sources": {}, "diagnostics": []}
	var definitions: Array[Dictionary] = [
		{"slot": "money", "source": "economy", "field": "balance"},
		{"slot": "current_visitors", "source": "visitors", "field": "current_visitors"},
		{"slot": "daily_arrivals", "source": "visitors", "field": "daily_arrivals"},
		{"slot": "prestige", "source": "prestige", "field": "official_prestige"},
		{"slot": "simulation_speed", "source": "time", "field": "simulation_speed"},
		{"slot": "clock", "source": "time", "field": "clock"},
		{"slot": "wall_mode", "source": "presentation", "field": "wall_mode"},
	]
	for definition: Dictionary in definitions:
		var source_id: String = String(definition["source"])
		var source: Dictionary = sources.get(source_id, {})
		var expected_revision: int = int(expected_revisions.get(source_id, -1))
		var source_result: Dictionary = _available_value(source, String(definition["field"]), expected_revision)
		if bool(source_result.get("valid", false)):
			var slot: String = String(definition["slot"])
			hud["metrics"][slot] = source_result["value"]
			hud["sources"][slot] = {
				"source_id": source_id,
				"source_revision": int(source.get("source_revision", -1)),
			}
		elif not source_result.get("diagnostic", {}).is_empty():
			hud["diagnostics"].append(source_result["diagnostic"])
	return hud


func build_panel(panel_name: String, sources: Dictionary, expected_revisions: Dictionary = {}) -> Dictionary:
	if not PRIMARY_PANELS.has(panel_name):
		return _unavailable("PANEL_UNAVAILABLE", panel_name)
	var source_id: String = String({
		"finances": "economy",
		"prestige": "prestige",
		"tenants": "tenant",
		"visitors": "visitors",
		"metrics": "hud",
	}.get(panel_name, ""))
	var source: Dictionary = sources.get(source_id, {})
	var expected_revision: int = int(expected_revisions.get(source_id, -1))
	var source_result: Dictionary = _validate_source(source, expected_revision)
	if not bool(source_result.get("valid", false)):
		return {
			"availability": source_result.get("availability", UNAVAILABLE),
			"source_id": source_id,
			"diagnostics": [source_result.get("diagnostic", {"code": "SOURCE_UNAVAILABLE", "source_id": source_id})],
		}
	return {
		"availability": AVAILABLE,
		"source_id": source_id,
		"source_revision": int(source.get("source_revision", -1)),
		"values": (source.get("values", {}) as Dictionary).duplicate(true),
		"diagnostics": [],
	}


func build_heatmap(kind: String, sources: Dictionary, expected_revisions: Dictionary = {}) -> Dictionary:
	var source_id: String = "visitor_density" if kind == "visitor_density" else ("zone_viability" if kind == "zone_viability" else "")
	var source: Dictionary = sources.get(source_id, {})
	var expected_revision: int = int(expected_revisions.get(source_id, -1))
	var source_result: Dictionary = _validate_source(source, expected_revision)
	if source_id.is_empty():
		return {"active": false, "availability": UNAVAILABLE, "diagnostics": [{"code": "HEATMAP_UNSUPPORTED", "heatmap": kind}]}
	if not bool(source_result.get("valid", false)):
		return {
			"active": false,
			"availability": source_result.get("availability", UNAVAILABLE),
			"diagnostics": [source_result.get("diagnostic", {"code": "HEATMAP_SOURCE_UNAVAILABLE", "heatmap": kind})],
		}
	return {
		"active": true,
		"availability": AVAILABLE,
		"source_revision": int(source.get("source_revision", -1)),
		"samples": (source.get("values", {}) as Dictionary).duplicate(true),
		"diagnostics": [],
	}


func source(availability: String, revision: int, values: Dictionary) -> Dictionary:
	return {
		"availability": availability,
		"source_revision": revision,
		"values": values.duplicate(true),
	}


func _available_value(source: Dictionary, field: String, expected_revision: int = -1) -> Dictionary:
	var validation: Dictionary = _validate_source(source, expected_revision)
	if not bool(validation.get("valid", false)):
		return validation
	var values: Dictionary = source.get("values", {})
	if not values.has(field):
		return {"valid": false, "diagnostic": {"code": "SOURCE_FIELD_UNAVAILABLE", "field": field}}
	return {"valid": true, "value": values[field]}


func _validate_source(source: Dictionary, expected_revision: int = -1) -> Dictionary:
	if source.is_empty() or String(source.get("availability", UNAVAILABLE)) == UNAVAILABLE:
		return {"valid": false, "availability": UNAVAILABLE, "diagnostic": {"code": "SOURCE_UNAVAILABLE"}}
	var revision: int = int(source.get("source_revision", -1))
	if expected_revision >= 0 and revision != expected_revision:
		return {
			"valid": false,
			"availability": STALE,
			"diagnostic": {"code": "SOURCE_REVISION_STALE", "expected_revision": expected_revision, "source_revision": revision},
		}
	if not source.get("values", {}) is Dictionary:
		return {"valid": false, "availability": UNAVAILABLE, "diagnostic": {"code": "SOURCE_VALUES_INVALID"}}
	return {"valid": true, "availability": AVAILABLE}


func _unavailable(code: String, panel_name: String) -> Dictionary:
	return {"availability": UNAVAILABLE, "panel": panel_name, "diagnostics": [{"code": code}]}
