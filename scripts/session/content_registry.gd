class_name ContentRegistry
extends RefCounted

## Sealed read-only catalog of approved immutable layout content.
## Selection is always caller-supplied; this registry never chooses a default.

var _layout_entries: Dictionary = {}
var _prestige_policy: PrestigePolicy
var _sealed: bool = false


## Load and seal the explicit production layout catalog.
func initialize_production_catalog(entries: Array[Dictionary]) -> Dictionary:
	if _sealed:
		return _failure("CONTENT_REGISTRY_SEALED", "content registry is already sealed")
	if entries.is_empty():
		return _failure("CONTENT_REGISTRY_EMPTY", "at least one production layout is required")

	var resolver: DistrictLayoutResolver = load("res://scripts/resources/district_layout_resolver.gd").new() as DistrictLayoutResolver
	var loader: DistrictLayoutDefinitionLoader = load("res://scripts/resources/district_layout_definition_loader.gd").new() as DistrictLayoutDefinitionLoader
	var diagnostics: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var layout_id: String = String(entry.get("layout_id", ""))
		var definition_path: String = String(entry.get("definition_path", ""))
		if layout_id.is_empty():
			diagnostics.append(_diagnostic("LAYOUT_ID_REQUIRED", "layout_id", "production layout identities cannot be empty"))
			continue
		if definition_path.is_empty():
			diagnostics.append(_diagnostic("LAYOUT_DEFINITION_PATH_REQUIRED", layout_id, "production layout definitions require an explicit resource path"))
			continue
		if _layout_entries.has(layout_id):
			diagnostics.append(_diagnostic("LAYOUT_ID_DUPLICATE", layout_id, "production layout identities must be unique"))
			continue
		var resource: ProductionDistrictDefinition = load(definition_path) as ProductionDistrictDefinition
		if resource == null:
			diagnostics.append(_diagnostic("LAYOUT_DEFINITION_LOAD_FAILED", layout_id, "production layout definition could not be loaded"))
			continue
		var definition: DistrictLayoutDefinition = loader.load_definition(resource.get_raw_record())
		if not definition.is_published():
			diagnostics.append_array(definition.get_diagnostics())
			continue
		var resolved: Dictionary = resolver.resolve(definition.get_semantic_record())
		if not bool(resolved.get("valid", false)):
			diagnostics.append_array(resolved.get("diagnostics", []))
			continue
		var snapshot: ResolvedDistrictSnapshot = resolved.get("snapshot") as ResolvedDistrictSnapshot
		if snapshot == null or snapshot.get_layout_id() != layout_id:
			diagnostics.append(_diagnostic("LAYOUT_ID_MISMATCH", layout_id, "resolved content identity does not match its catalog key"))
			continue
		_layout_entries[layout_id] = {
			"layout_id": layout_id,
			"layout_definition_version": int(snapshot.get_data().get("layout_definition_version", 0)),
			"definition_fingerprint": snapshot.get_fingerprint(),
			"snapshot": snapshot,
		}

	if not diagnostics.is_empty():
		_layout_entries.clear()
		return {"valid": false, "diagnostics": diagnostics}
	var policy_script: Script = load("res://scripts/simulation/prestige_policy.gd")
	_prestige_policy = policy_script.new() as PrestigePolicy
	var policy_validation: Dictionary = _prestige_policy.validate_content()
	if not bool(policy_validation.get("valid", false)):
		_layout_entries.clear()
		_prestige_policy = null
		return policy_validation
	_sealed = true
	return {"valid": true, "diagnostics": [], "layout_ids": get_layout_ids(), "prestige_policy_revision": PrestigePolicy.POLICY_REVISION}


## Validate a caller-provided layout identity and optional V2 identity fields.
func resolve_layout(layout_id: String, expected_version: int = -1, expected_fingerprint: String = "") -> Dictionary:
	if not _sealed:
		return _failure("CONTENT_REGISTRY_NOT_READY", "content registry must be sealed before selection")
	if layout_id.is_empty():
		return _failure("LAYOUT_ID_REQUIRED", "a layout identity is required; no default is inferred")
	if not _layout_entries.has(layout_id):
		return _failure("LAYOUT_ID_UNKNOWN", "layout identity is not approved")
	var entry: Dictionary = _layout_entries[layout_id]
	if expected_version >= 0 and expected_version != int(entry["layout_definition_version"]):
		return _failure("LAYOUT_DEFINITION_VERSION_MISMATCH", "layout definition version does not match approved content")
	if not expected_fingerprint.is_empty() and expected_fingerprint != String(entry["definition_fingerprint"]):
		return _failure("LAYOUT_FINGERPRINT_MISMATCH", "layout fingerprint does not match approved content")
	return {
		"valid": true,
		"layout_id": layout_id,
		"snapshot": entry["snapshot"],
		"layout_ref": get_layout_ref(layout_id),
		"diagnostics": [],
	}


func validate_layout_ref(layout_ref: Variant) -> Dictionary:
	if not layout_ref is Dictionary:
		return _failure("LAYOUT_REF_INVALID", "layout reference must be an object")
	var value: Dictionary = layout_ref
	var layout_id: String = String(value.get("layout_id", ""))
	if typeof(value.get("layout_id", null)) != TYPE_STRING or layout_id.is_empty():
		return _failure("LAYOUT_ID_REQUIRED", "layout reference requires an explicit layout identity")
	if typeof(value.get("layout_definition_version", null)) != TYPE_INT:
		return _failure("LAYOUT_DEFINITION_VERSION_INVALID", "layout reference requires an integer definition version")
	if typeof(value.get("definition_fingerprint", null)) != TYPE_STRING:
		return _failure("LAYOUT_FINGERPRINT_INVALID", "layout reference requires a fingerprint")
	return resolve_layout(layout_id, int(value["layout_definition_version"]), String(value["definition_fingerprint"]))


func get_layout_ref(layout_id: String) -> Dictionary:
	if not _layout_entries.has(layout_id):
		return {}
	var entry: Dictionary = _layout_entries[layout_id]
	return {
		"layout_id": layout_id,
		"layout_definition_version": int(entry["layout_definition_version"]),
		"definition_fingerprint": String(entry["definition_fingerprint"]),
	}


func get_layout_ids() -> Array[String]:
	var result: Array[String] = []
	for layout_id: String in _layout_entries.keys():
		result.append(layout_id)
	result.sort()
	return result


func is_sealed() -> bool:
	return _sealed


func get_prestige_policy() -> PrestigePolicy:
	return _prestige_policy


func _diagnostic(code: String, path: String, message: String) -> Dictionary:
	return {"code": code, "path": path, "message": message}


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "diagnostics": [_diagnostic(code, "$.layout_ref", message)]}
