class_name PresentationCoordinator
extends RefCounted

## Detached presentation projection. It stores no authority or Node references.
const AVAILABLE: String = "AVAILABLE"
const UNAVAILABLE: String = "UNAVAILABLE"
const STALE: String = "STALE"
const PRIMARY_PANELS: Array[String] = ["finances", "prestige", "tenants", "visitors", "metrics"]


func build_hud(sources: Dictionary) -> Dictionary:
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
		var source_id := String(definition["source"])
		var source: Dictionary = sources.get(source_id, {})
		var source_result := _available_value(source, String(definition["field"]))
		if bool(source_result.get("valid", false)):
			hud["metrics"][String(definition["slot"])] = source_result["value"]
			hud["sources"][String(definition["slot"])] = {"source_id": source_id, "source_revision": int(source.get("source_revision", -1))}
	return hud


func build_panel(panel_name: String, sources: Dictionary) -> Dictionary:
	if not PRIMARY_PANELS.has(panel_name):
		return {"availability": UNAVAILABLE, "diagnostics": [{"code": "PANEL_UNAVAILABLE"}]}
	var source_id: String = String({"finances": "economy", "prestige": "prestige", "tenants": "tenant", "visitors": "visitors", "metrics": "hud"}.get(panel_name, ""))
	var source: Dictionary = sources.get(source_id, {})
	if source.is_empty() or String(source.get("availability", UNAVAILABLE)) != AVAILABLE:
		return {"availability": UNAVAILABLE, "source_id": source_id, "diagnostics": [{"code": "SOURCE_UNAVAILABLE", "source_id": source_id}]}
	return {"availability": AVAILABLE, "source_id": source_id, "source_revision": int(source.get("source_revision", -1)), "values": source.get("values", {}).duplicate(true), "diagnostics": []}


func build_heatmap(kind: String, sources: Dictionary) -> Dictionary:
	var source_id: String = "visitor_density" if kind == "visitor_density" else ("zone_viability" if kind == "zone_viability" else "")
	var source: Dictionary = sources.get(source_id, {})
	if source_id.is_empty() or source.is_empty() or String(source.get("availability", UNAVAILABLE)) != AVAILABLE:
		return {"active": false, "availability": UNAVAILABLE, "diagnostics": [{"code": "HEATMAP_SOURCE_UNAVAILABLE", "heatmap": kind}]}
	return {"active": true, "availability": AVAILABLE, "source_revision": int(source.get("source_revision", -1)), "samples": source.get("values", {}).duplicate(true), "diagnostics": []}


func _available_value(source: Dictionary, field: String) -> Dictionary:
	if source.is_empty() or String(source.get("availability", UNAVAILABLE)) != AVAILABLE:
		return {"valid": false}
	var values: Dictionary = source.get("values", {})
	if not values.has(field):
		return {"valid": false}
	return {"valid": true, "value": values[field]}
