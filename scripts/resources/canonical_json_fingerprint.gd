## CanonicalJsonFingerprint — RFC 8785 closed-value encoding with domain-separated SHA-256.
class_name CanonicalJsonFingerprint
extends RefCounted

const MAX_SAFE_INTEGER: int = 9007199254740991
const MIN_SAFE_INTEGER: int = -9007199254740991


func encode(value: Variant) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var canonical_json: String = _encode_value(value, "$", diagnostics)
	return {
		"valid": diagnostics.is_empty(),
		"canonical_json": canonical_json if diagnostics.is_empty() else "",
		"bytes": canonical_json.to_utf8_buffer() if diagnostics.is_empty() else PackedByteArray(),
		"diagnostics": diagnostics,
	}


func fingerprint(value: Variant, domain: String, revision: int) -> Dictionary:
	var encoded: Dictionary = encode(value)
	if not bool(encoded.get("valid", false)):
		return encoded.merged({"fingerprint": ""})
	if domain.is_empty() or revision <= 0:
		return {
			"valid": false,
			"canonical_json": "",
			"bytes": PackedByteArray(),
			"fingerprint": "",
			"diagnostics": [{"code": "INVALID_FINGERPRINT_FRAME", "path": "$", "values": {"domain": domain, "revision": revision}}],
		}
	var framed_bytes: PackedByteArray = PackedByteArray()
	framed_bytes.append_array(domain.to_utf8_buffer())
	framed_bytes.append(0)
	framed_bytes.append_array(str(revision).to_utf8_buffer())
	framed_bytes.append(0)
	framed_bytes.append_array(encoded["bytes"])
	var hashing_context: HashingContext = HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	hashing_context.update(framed_bytes)
	encoded["bytes"] = framed_bytes
	encoded["fingerprint"] = hashing_context.finish().hex_encode()
	return encoded


func _encode_value(value: Variant, path: String, diagnostics: Array[Dictionary]) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT:
			if int(value) < MIN_SAFE_INTEGER or int(value) > MAX_SAFE_INTEGER:
				_add(diagnostics, "INTEGER_OUT_OF_RANGE", path)
				return "0"
			return str(int(value))
		TYPE_STRING:
			return JSON.stringify(String(value))
		TYPE_ARRAY:
			var items: Array[String] = []
			for index: int in range(value.size()):
				items.append(_encode_value(value[index], "%s[%d]" % [path, index], diagnostics))
			return "[" + ",".join(items) + "]"
		TYPE_DICTIONARY:
			var keys: Array[String] = []
			for key: Variant in value.keys():
				if typeof(key) != TYPE_STRING:
					_add(diagnostics, "KEY_NOT_STRING", path)
				else:
					keys.append(String(key))
			keys.sort_custom(_compare_utf16)
			var members: Array[String] = []
			for key: String in keys:
				members.append(JSON.stringify(key) + ":" + _encode_value(value[key], "%s.%s" % [path, key], diagnostics))
			return "{" + ",".join(members) + "}"
		_:
			_add(diagnostics, "UNSUPPORTED_VALUE", path)
			return "null"


func _compare_utf16(left: String, right: String) -> bool:
	var left_units: Array[int] = _utf16_units(left)
	var right_units: Array[int] = _utf16_units(right)
	for index: int in range(mini(left_units.size(), right_units.size())):
		if left_units[index] != right_units[index]:
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


func _add(diagnostics: Array[Dictionary], code: String, path: String) -> void:
	diagnostics.append({"code": code, "path": path, "values": {}})
