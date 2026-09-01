class_name ResolvedDistrictSnapshot
extends Resource

## Immutable H2 resolver output plus the canonical H1 identity bytes.

var _data: Dictionary = {}
var _canonical_json: String = ""
var _canonical_bytes: PackedByteArray = PackedByteArray()
var _fingerprint: String = ""


func initialize(data: Dictionary, canonical_json: String, canonical_bytes: PackedByteArray, fingerprint: String) -> void:
	_data = data.duplicate(true)
	_canonical_json = canonical_json
	_canonical_bytes = canonical_bytes.duplicate()
	_fingerprint = fingerprint


func get_data() -> Dictionary:
	return _data.duplicate(true)


func get_canonical_json() -> String:
	return _canonical_json


func get_canonical_bytes() -> PackedByteArray:
	return _canonical_bytes.duplicate()


func get_fingerprint() -> String:
	return _fingerprint


func get_layout_id() -> String:
	return String(_data.get("layout_id", ""))


func get_counts() -> Dictionary:
	return {
		"slots": _data.get("slots", []).size(),
		"plots": _data.get("plots", []).size(),
		"sections": _data.get("sections", []).size(),
		"fixed_occupants": _data.get("fixed_occupants", []).size(),
		"floors": _data.get("floors", []).size(),
		"cells": _data.get("cells", []).size(),
		"street_segments": _data.get("street_segments", []).size(),
		"intersections": _data.get("intersections", []).size(),
		"pedestrian_bands": _data.get("pedestrian_bands", []).size(),
		"carriageways": _data.get("carriageways", []).size(),
		"lanes": _data.get("lanes", []).size(),
		"arrival_source_attachments": _data.get("arrival_source_attachments", []).size(),
	}
