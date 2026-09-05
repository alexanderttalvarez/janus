class_name ConstructionPolicy
extends RefCounted

## Immutable authored MVP construction catalog. Values are returned detached.

const SCHEMA_VERSION: int = 1
const REVISION: int = 1

var _entries: Dictionary = {}


func _init() -> void:
	_entries = {
		"corridor": {
			"kind": "corridor",
			"geometry_available": true,
			"footprint_width": 1,
			"footprint_depth": 1,
			"charge_lines": [{"category": "CONSTRUCTION_CORRIDOR", "value": 0}],
		},
		"stairs": {
			"kind": "stairs",
			"geometry_available": true,
			"footprint_width": 2,
			"footprint_depth": 2,
			"charge_lines": [{"category": "CONSTRUCTION_STAIRS", "value": 500}],
		},
		"elevator": {
			"kind": "elevator",
			"geometry_available": true,
			"footprint_width": 1,
			"footprint_depth": 1,
			"charge_lines": [{"category": "CONSTRUCTION_ELEVATOR_SHAFT", "value": 2000}],
			"lobby_charge_category": "CONSTRUCTION_ELEVATOR_LOBBY",
			"lobby_charge_value": 500,
		},
		"operations_room": {
			"kind": "operations_room",
			"geometry_available": false,
			"footprint_width": 2,
			"footprint_depth": 2,
			"charge_lines": [{"category": "CONSTRUCTION_OPERATIONS_ROOM", "value": 2000}],
		},
	}


func get_revision() -> int:
	return REVISION


func duplicate_value() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"revision": REVISION,
		"entries": _entries.duplicate(true),
	}


func entry_for(kind: String) -> Dictionary:
	return _entries.get(kind, {}).duplicate(true)


func charge_lines_for(kind: String, lobby_count: int = 0) -> Array[Dictionary]:
	var entry: Dictionary = entry_for(kind)
	if entry.is_empty():
		return []
	var lines: Array[Dictionary] = []
	for line: Dictionary in entry.get("charge_lines", []):
		lines.append(line.duplicate(true))
	if kind == "elevator":
		for index: int in range(lobby_count):
			lines.append({
				"category": String(entry.get("lobby_charge_category", "")),
				"value": int(entry.get("lobby_charge_value", -1)),
				"line_index": index,
			})
	return lines


func validate() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	for kind: String in ["corridor", "stairs", "elevator", "operations_room"]:
		var entry: Dictionary = entry_for(kind)
		if entry.is_empty():
			diagnostics.append({"code": "CONSTRUCTION_POLICY_UNAVAILABLE", "message": "approved construction kind is missing"})
			continue
		if not entry.has("geometry_available") or not entry.has("footprint_width") or not entry.has("footprint_depth"):
			diagnostics.append({"code": "CONSTRUCTION_POLICY_UNAVAILABLE", "message": "construction geometry metadata is incomplete"})
		for line: Dictionary in entry.get("charge_lines", []):
			if String(line.get("category", "")).is_empty() or int(line.get("value", -1)) < 0:
				diagnostics.append({"code": "CONSTRUCTION_POLICY_UNAVAILABLE", "message": "construction charge metadata is malformed"})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}
