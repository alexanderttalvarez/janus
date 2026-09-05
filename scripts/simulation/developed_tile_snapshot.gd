class_name DevelopedTileSnapshot
extends RefCounted

## Detached authoritative developed-tile source for Prestige H2.
const SCHEMA_VERSION: int = 1
const FIELDS: Array[String] = [
	"schema_version",
	"source_revision",
	"developed_tile_count",
	"developed_tile_ids",
	"provenance",
]

var _data: Dictionary = {}


func configure(values: Dictionary) -> void:
	_data = values.duplicate(true)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


func get_source_revision() -> int:
	return int(_data.get("source_revision", -1))


func get_developed_tile_count() -> int:
	return int(_data.get("developed_tile_count", -1))


func get_developed_tile_ids() -> Array:
	return _data.get("developed_tile_ids", []).duplicate(true)


func validate() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	for field: String in FIELDS:
		if not _data.has(field):
			diagnostics.append({"code": "DEVELOPED_TILE_FIELD_MISSING", "path": "$.%s" % field})
	for key: Variant in _data.keys():
		if not FIELDS.has(String(key)):
			diagnostics.append({"code": "DEVELOPED_TILE_FIELD_UNKNOWN", "path": "$.%s" % String(key)})
	if int(_data.get("schema_version", -1)) != SCHEMA_VERSION:
		diagnostics.append({"code": "DEVELOPED_TILE_SCHEMA_INVALID", "path": "$.schema_version"})
	if int(_data.get("source_revision", -1)) < 0:
		diagnostics.append({"code": "DEVELOPED_TILE_REVISION_INVALID", "path": "$.source_revision"})
	var ids: Array = _data.get("developed_tile_ids", [])
	if not ids is Array:
		diagnostics.append({"code": "DEVELOPED_TILE_IDS_INVALID", "path": "$.developed_tile_ids"})
	else:
		var seen: Dictionary = {}
		for tile_id: Variant in ids:
			if not tile_id is String or String(tile_id).is_empty() or seen.has(tile_id):
				diagnostics.append({"code": "DEVELOPED_TILE_IDS_INVALID", "path": "$.developed_tile_ids"})
			else:
				seen[tile_id] = true
		if int(_data.get("developed_tile_count", -1)) != ids.size():
			diagnostics.append({"code": "DEVELOPED_TILE_COUNT_MISMATCH", "path": "$.developed_tile_count"})
	if String(_data.get("provenance", "")).is_empty():
		diagnostics.append({"code": "DEVELOPED_TILE_PROVENANCE_REQUIRED", "path": "$.provenance"})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


static func from_ids(source_revision: int, tile_ids: Array, provenance: String) -> DevelopedTileSnapshot:
	var unique: Dictionary = {}
	for tile_id: Variant in tile_ids:
		if tile_id is String and not String(tile_id).is_empty():
			unique[String(tile_id)] = true
	var normalized: Array = unique.keys()
	normalized.sort()
	var snapshot := DevelopedTileSnapshot.new()
	snapshot.configure({
		"schema_version": SCHEMA_VERSION,
		"source_revision": source_revision,
		"developed_tile_count": normalized.size(),
		"developed_tile_ids": normalized,
		"provenance": provenance,
	})
	return snapshot
