## Immutable detached compiled Tenant Interiors H1 content snapshot.
class_name CompiledTenantInteriorContent
extends RefCounted

const FINGERPRINT_DOMAIN: String = "JANUS_TENANT_INTERIOR_CONTENT"
const SCHEMA_VERSION: int = 1

var _content: Dictionary = {}
var _canonical_json: String = ""
var _fingerprint: String = ""
var _initialized: bool = false


func initialize(content: Dictionary, canonical_json: String, fingerprint: String) -> bool:
	if _initialized or content.is_empty() or canonical_json.is_empty() or fingerprint.length() != 64:
		return false
	_content = content.duplicate(true)
	_canonical_json = canonical_json
	_fingerprint = fingerprint
	_initialized = true
	return validate_integrity()


func get_content() -> Dictionary:
	return _content.duplicate(true)


func get_canonical_json() -> String:
	return _canonical_json


func get_fingerprint() -> String:
	return _fingerprint


func validate_integrity() -> bool:
	if not _initialized:
		return false
	var result: Dictionary = CanonicalJsonFingerprint.new().fingerprint(_content, FINGERPRINT_DOMAIN, SCHEMA_VERSION)
	return bool(result.get("valid", false)) and result.get("canonical_json", "") == _canonical_json and result.get("fingerprint", "") == _fingerprint
