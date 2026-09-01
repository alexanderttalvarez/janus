class_name DistrictLayoutCanonicalEncoder
extends RefCounted

## RFC 8785-compatible canonical encoding boundary for H2 semantic records.
## H1 has already rejected floats and out-of-range integers.

const FRAME_PREFIX: String = "JANUS_DISTRICT_DEFINITION"
const MAX_SAFE_INTEGER: int = 9007199254740991
const MIN_SAFE_INTEGER: int = -9007199254740991


func encode(record: Variant, canonical_schema_version: int) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var json: String = _encode_value(record, "$", diagnostics)
	if not diagnostics.is_empty():
		return {"valid": false, "canonical_json": "", "bytes": PackedByteArray(), "diagnostics": diagnostics}
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append_array(FRAME_PREFIX.to_utf8_buffer())
	bytes.append(0)
	bytes.append_array(str(canonical_schema_version).to_utf8_buffer())
	bytes.append(0)
	bytes.append_array(json.to_utf8_buffer())
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	var fingerprint: String = hash_context.finish().hex_encode()
	return {
		"valid": true,
		"canonical_json": json,
		"bytes": bytes,
		"fingerprint": fingerprint,
		"diagnostics": [],
	}


func _encode_value(value: Variant, path: String, diagnostics: Array[Dictionary]) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT:
			if int(value) < MIN_SAFE_INTEGER or int(value) > MAX_SAFE_INTEGER:
				_add(diagnostics, "INTEGER_OUT_OF_RANGE", path, "canonical integer exceeds the I-JSON safe range")
				return "0"
			return str(int(value))
		TYPE_STRING:
			return JSON.stringify(String(value))
		TYPE_ARRAY:
			var values: Array[String] = []
			for index: int in range(value.size()):
				values.append(_encode_value(value[index], "%s[%d]" % [path, index], diagnostics))
			return "[" + ",".join(values) + "]"
		TYPE_DICTIONARY:
			var keys: Array[String] = []
			for key: Variant in value.keys():
				if typeof(key) != TYPE_STRING:
					_add(diagnostics, "KEY_NOT_STRING", path, "canonical object keys must be strings")
				else:
					keys.append(String(key))
			keys.sort_custom(_compare_utf16)
			var members: Array[String] = []
			for key: String in keys:
				members.append(JSON.stringify(key) + ":" + _encode_value(value[key], "%s.%s" % [path, key], diagnostics))
			return "{" + ",".join(members) + "}"
		_:
			_add(diagnostics, "UNSUPPORTED_VALUE", path, "canonical values must be integer, string, boolean, null, array, or object")
			return "null"


func _compare_utf16(left: String, right: String) -> bool:
	var left_units: Array[int] = _utf16_units(left)
	var right_units: Array[int] = _utf16_units(right)
	var count: int = mini(left_units.size(), right_units.size())
	for index: int in range(count):
		if left_units[index] == right_units[index]:
			continue
		return left_units[index] < right_units[index]
	return left_units.size() < right_units.size()


func _utf16_units(value: String) -> Array[int]:
	var units: Array[int] = []
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if codepoint <= 0xFFFF:
			units.append(codepoint)
		else:
			var scalar: int = codepoint - 0x10000
			units.append(0xD800 + (scalar >> 10))
			units.append(0xDC00 + (scalar & 0x3FF))
	return units


func _add(diagnostics: Array[Dictionary], code: String, path: String, message: String) -> void:
	diagnostics.append({"code": code, "path": path, "message": message})
