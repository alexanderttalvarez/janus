## SaveManager — V2 JSON persistence orchestration.
## Registered as autoload "SaveManager" in project settings.
##
## SaveManager owns file I/O, exact V2 envelope validation, detached staging,
## and the sole post-commit game_loaded event. The session owner injects
## detached authority reads, validation, and the atomic session commit.
extends Node


## Emitted after a V2 save has been atomically replaced.
signal game_saved(slot: int)

## Emitted only after detached load staging and the live session commit succeed.
signal game_loaded(slot: int)

## Emitted when save data is deleted.
signal save_deleted(slot: int)

## Optional diagnostics emitted only after a staged restore is discarded.
signal restore_failed(result: Dictionary)
signal restore_requested(slot: int)


const SAVE_DIR: String = "user://saves/"
const SETTINGS_PATH: String = "user://settings.cfg"
const MAX_SLOTS: int = 5
const SAVE_EXT: String = ".json"
const V2_SCHEMA_VERSION: int = 2

const V2_ROOT_FIELDS: Array[String] = ["save_schema_version", "meta", "layout_ref", "authorities"]
const V2_META_FIELDS: Array[String] = ["slot", "timestamp", "application_version"]
const V2_LAYOUT_FIELDS: Array[String] = ["layout_id", "layout_definition_version", "definition_fingerprint"]
const V2_AUTHORITY_FIELDS: Array[String] = [
	"district", "zone_parcel", "economy", "progression", "prestige",
	"staff", "synergy", "tenant", "visitor", "time",
]

var _authority_provider: Callable
var _layout_provider: Callable
var _staged_validator: Callable
var _session_commit: Callable
var _session_gate: SessionMutationGate
var _runtime_available: Callable
var _restore_in_progress: bool = false
var _restore_barrier_active: bool = false
var _restore_trace: Array[String] = []
var _restore_fault_stage: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_save_dir()


## Inject the session owner’s detached read, validation, and commit boundaries.
func configure_runtime(
	authority_provider: Callable,
	layout_provider: Callable,
	staged_validator: Callable,
	session_commit: Callable
) -> void:
	_authority_provider = authority_provider
	_layout_provider = layout_provider
	_staged_validator = staged_validator
	_session_commit = session_commit


## Inject the sole session mutation boundary and readiness check.
func configure_session_boundary(gate: SessionMutationGate, runtime_available: Callable) -> Dictionary:
	if gate == null or not runtime_available.is_valid():
		return _failure("SESSION_BOUNDARY_REQUIRED", "SaveManager requires the session gate and readiness provider")
	_session_gate = gate
	_runtime_available = runtime_available
	return {"valid": true, "diagnostics": []}


## Return the exact authority key order required by the V2 envelope.
func get_v2_authority_fields() -> Array[String]:
	return V2_AUTHORITY_FIELDS.duplicate()


func get_v2_authority_registry() -> Array[Dictionary]:
	var registry: Array[Dictionary] = []
	for authority_name: String in V2_AUTHORITY_FIELDS:
		registry.append({"key": authority_name, "order": registry.size()})
	return registry


func set_restore_fault_stage(stage: String) -> void:
	_restore_fault_stage = stage


func get_restore_trace() -> Array[String]:
	return _restore_trace.duplicate()


func is_restore_barrier_active() -> bool:
	return _restore_barrier_active


## Build a detached V2 envelope without writing a slot or emitting events.
func build_v2_envelope(slot: int, authorities: Dictionary, layout_ref: Dictionary, timestamp: int = -1) -> Dictionary:
	return {
		"save_schema_version": V2_SCHEMA_VERSION,
		"meta": {
			"slot": slot,
			"timestamp": Time.get_unix_time_from_system() as int if timestamp < 0 else timestamp,
			"application_version": String(ProjectSettings.get_setting("application/config/version", "0.1.0")),
		},
		"layout_ref": layout_ref.duplicate(true),
		"authorities": authorities.duplicate(true),
	}


## Validate an exact V2 envelope against the configured layout and authority owner.
func validate_v2_envelope(payload: Variant, expected_slot: int = -1) -> Dictionary:
	if not payload is Dictionary:
		return _failure("V2_ROOT_NOT_OBJECT", "V2 save root must be an object")
	var envelope: Dictionary = payload
	var diagnostics: Array[Dictionary] = _check_exact_fields(envelope, V2_ROOT_FIELDS, "$")
	if typeof(envelope.get("save_schema_version", null)) != TYPE_INT:
		diagnostics.append(_diagnostic("V2_SCHEMA_VERSION_TYPE", "$.save_schema_version", "save_schema_version must be an integer"))
	elif int(envelope["save_schema_version"]) != V2_SCHEMA_VERSION:
		diagnostics.append(_diagnostic("V2_SCHEMA_VERSION_UNSUPPORTED", "$.save_schema_version", "save schema version must be 2"))

	var meta_value: Variant = envelope.get("meta", null)
	if not meta_value is Dictionary:
		diagnostics.append(_diagnostic("V2_META_NOT_OBJECT", "$.meta", "meta must be an object"))
	else:
		var meta: Dictionary = meta_value
		diagnostics.append_array(_check_exact_fields(meta, V2_META_FIELDS, "$.meta"))
		if typeof(meta.get("slot", null)) != TYPE_INT:
			diagnostics.append(_diagnostic("V2_META_SLOT_TYPE", "$.meta.slot", "meta.slot must be an integer"))
		elif expected_slot > 0 and int(meta["slot"]) != expected_slot:
			diagnostics.append(_diagnostic("V2_META_SLOT_MISMATCH", "$.meta.slot", "meta.slot must match the requested slot"))
		if typeof(meta.get("timestamp", null)) != TYPE_INT:
			diagnostics.append(_diagnostic("V2_META_TIMESTAMP_TYPE", "$.meta.timestamp", "meta.timestamp must be an integer"))
		elif int(meta["timestamp"]) < 0:
			diagnostics.append(_diagnostic("V2_META_TIMESTAMP_INVALID", "$.meta.timestamp", "meta.timestamp must be nonnegative"))
		if typeof(meta.get("application_version", null)) != TYPE_STRING:
			diagnostics.append(_diagnostic("V2_META_APPLICATION_VERSION_TYPE", "$.meta.application_version", "meta.application_version must be a string"))

	var layout_value: Variant = envelope.get("layout_ref", null)
	if not layout_value is Dictionary:
		diagnostics.append(_diagnostic("V2_LAYOUT_REF_NOT_OBJECT", "$.layout_ref", "layout_ref must be an object"))
	else:
		var layout_ref: Dictionary = layout_value
		diagnostics.append_array(_check_exact_fields(layout_ref, V2_LAYOUT_FIELDS, "$.layout_ref"))
		if typeof(layout_ref.get("layout_id", null)) != TYPE_STRING:
			diagnostics.append(_diagnostic("V2_LAYOUT_ID_TYPE", "$.layout_ref.layout_id", "layout_id must be a string"))
		if typeof(layout_ref.get("layout_definition_version", null)) != TYPE_INT:
			diagnostics.append(_diagnostic("V2_LAYOUT_VERSION_TYPE", "$.layout_ref.layout_definition_version", "layout_definition_version must be an integer"))
		var fingerprint: Variant = layout_ref.get("definition_fingerprint", null)
		if typeof(fingerprint) != TYPE_STRING or not _is_sha256(String(fingerprint)):
			diagnostics.append(_diagnostic("V2_FINGERPRINT_INVALID", "$.layout_ref.definition_fingerprint", "definition_fingerprint must be lowercase hexadecimal SHA-256"))
		if _layout_provider.is_valid() and diagnostics.is_empty():
			var expected_layout: Variant = _layout_provider.call()
			if not expected_layout is Dictionary:
				diagnostics.append(_diagnostic("LAYOUT_PROVIDER_INVALID", "$.layout_ref", "configured layout provider did not return an object"))
			else:
				var expected: Dictionary = expected_layout
				if String(layout_ref.get("layout_id", "")) != String(expected.get("layout_id", "")):
					diagnostics.append(_diagnostic("LAYOUT_ID_UNKNOWN", "$.layout_ref.layout_id", "layout ID is not the active known layout"))
				if int(layout_ref.get("layout_definition_version", -1)) != int(expected.get("layout_definition_version", -2)):
					diagnostics.append(_diagnostic("LAYOUT_DEFINITION_VERSION_MISMATCH", "$.layout_ref.layout_definition_version", "layout definition version does not match the active layout"))
				if String(layout_ref.get("definition_fingerprint", "")) != String(expected.get("definition_fingerprint", "")):
					diagnostics.append(_diagnostic("LAYOUT_FINGERPRINT_MISMATCH", "$.layout_ref.definition_fingerprint", "layout definition fingerprint does not match the active layout"))
		elif not _layout_provider.is_valid():
			diagnostics.append(_diagnostic("LAYOUT_PROVIDER_REQUIRED", "$.layout_ref", "a known active layout is required for V2 validation"))

	var authorities_value: Variant = envelope.get("authorities", null)
	if not authorities_value is Dictionary:
		diagnostics.append(_diagnostic("V2_AUTHORITIES_NOT_OBJECT", "$.authorities", "authorities must be an object"))
	else:
		var authorities: Dictionary = authorities_value
		diagnostics.append_array(_check_exact_fields(authorities, V2_AUTHORITY_FIELDS, "$.authorities"))
		for authority_name: String in V2_AUTHORITY_FIELDS:
			if authorities.has(authority_name) and not authorities[authority_name] is Dictionary:
				diagnostics.append(_diagnostic("V2_AUTHORITY_TYPE", "$.authorities.%s" % authority_name, "authority snapshots must be objects"))

	if not diagnostics.is_empty():
		return {"valid": false, "staged": {}, "diagnostics": diagnostics}
	if not _staged_validator.is_valid() or not _session_commit.is_valid() or not _authority_provider.is_valid():
		return _failure("RUNTIME_BOUNDARIES_REQUIRED", "SaveManager requires configured detached authority and session boundaries")
	var staged: Dictionary = {
		"layout_ref": envelope["layout_ref"].duplicate(true),
		"authorities": envelope["authorities"].duplicate(true),
	}
	var owner_validation: Variant = _staged_validator.call(staged["authorities"], staged["layout_ref"])
	if not owner_validation is Dictionary or not bool(owner_validation.get("valid", false)):
		var owner_diagnostics: Array = [] if not owner_validation is Dictionary else owner_validation.get("diagnostics", [])
		return {"valid": false, "staged": {}, "diagnostics": _typed_diagnostics(owner_diagnostics)}
	return {"valid": true, "staged": staged, "diagnostics": []}


## Save the configured runtime as V2, or accept an already formed V2 envelope for tests/tools.
func save_game(slot: int, data: Dictionary = {}) -> Error:
	if not _valid_slot(slot):
		push_error("SaveManager: Invalid slot %d (1-%d)." % [slot, MAX_SLOTS])
		return ERR_INVALID_PARAMETER
	if not _session_available():
		return ERR_BUSY
	if _session_gate == null:
		return ERR_UNCONFIGURED
	var owner_token: String = "save_capture:%d" % slot
	var acquired: Dictionary = _session_gate.acquire(owner_token)
	if not bool(acquired.get("valid", false)):
		return ERR_BUSY
	var envelope: Dictionary = {}
	var capture_error: Error = OK
	if data.is_empty():
		if not _authority_provider.is_valid() or not _layout_provider.is_valid():
			capture_error = ERR_UNCONFIGURED
		else:
			var authorities: Variant = _authority_provider.call()
			var layout_ref: Variant = _layout_provider.call()
			if not authorities is Dictionary or not layout_ref is Dictionary:
				capture_error = ERR_INVALID_DATA
			else:
				envelope = build_v2_envelope(slot, authorities, layout_ref)
	elif not data.has("save_schema_version"):
		capture_error = ERR_UNAVAILABLE
	else:
		envelope = data.duplicate(true)
	if capture_error == OK:
		var validation: Dictionary = validate_v2_envelope(envelope, slot)
		if not bool(validation.get("valid", false)):
			push_error("SaveManager: V2 save rejected: %s" % validation.get("diagnostics", []))
			capture_error = ERR_INVALID_DATA
	_session_gate.release(owner_token)
	if capture_error != OK:
		return capture_error
	# File I/O is intentionally outside the session mutation gate.
	var write_error: Error = _write_atomically(slot, JSON.stringify(envelope, "  ", true))
	if write_error != OK:
		push_error("SaveManager: Atomic save failed for slot %d: %s" % [slot, error_string(write_error)])
		return write_error
	game_saved.emit(slot)
	return OK


## Load, stage, validate, and atomically commit one V2 slot.
func load_game(slot: int) -> Dictionary:
	if _restore_in_progress:
		return _failure("RESTORE_ALREADY_IN_PROGRESS", "another session restore is already staging")
	if not _valid_slot(slot):
		return _failure("INVALID_SLOT", "requested slot is outside the supported range")
	if not _session_available() or _session_gate == null:
		return _failure("SESSION_MUTATION_BUSY", "save/load is blocked until the session boundary is available")
	_restore_in_progress = true
	_restore_barrier_active = false
	_restore_trace = ["restore_requested"]
	restore_requested.emit(slot)
	if _restore_fault_stage == "parse":
		return _restore_failure(slot, "RESTORE_PARSE_INJECTED", "restore parse failure injected")
	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return _restore_failure(slot, "SAVE_NOT_FOUND", "no save exists in the requested slot")
	var parsed: Dictionary = _read_payload(slot)
	_restore_trace.append("parse")
	if not bool(parsed.get("valid", false)):
		return _restore_failure(slot, String(parsed.get("reason_code", "SAVE_READ_FAILED")), String(parsed.get("diagnostics", [{"message": "save read failed"}])[0].get("message", "save read failed")), parsed.get("diagnostics", []))
	var validation: Dictionary = validate_v2_envelope(parsed["data"], slot)
	_restore_trace.append("detached_validation")
	if _restore_fault_stage == "authority_validation":
		return _restore_failure(slot, "RESTORE_AUTHORITY_VALIDATION_INJECTED", "restore authority validation failure injected")
	if not bool(validation.get("valid", false)):
		return _restore_failure(slot, String(validation["diagnostics"][0].get("code", "V2_REJECTED")), "V2 restore validation rejected the candidate", validation.get("diagnostics", []))
	var staged: Dictionary = validation["staged"]
	_restore_trace.append("candidate_staged")
	if _restore_fault_stage == "projection_preparation":
		return _restore_failure(slot, "RESTORE_PROJECTION_PREPARATION_INJECTED", "restore projection preparation failure injected")
	var owner_token: String = "restore_replace:%d" % slot
	var acquired: Dictionary = _session_gate.acquire(owner_token)
	if not bool(acquired.get("valid", false)):
		return _restore_failure(slot, "SESSION_MUTATION_BUSY", "another session mutation is active")
	_restore_barrier_active = true
	_restore_trace.append("commit_barrier")
	if _restore_fault_stage == "commit":
		_restore_barrier_active = false
		_session_gate.release(owner_token)
		return _restore_failure(slot, "RESTORE_COMMIT_INJECTED", "restore commit failure injected")
	var commit_result: Variant = _session_commit.call(staged["authorities"], staged["layout_ref"])
	_restore_barrier_active = false
	_session_gate.release(owner_token)
	if commit_result is Dictionary and not bool(commit_result.get("valid", false)):
		return _restore_failure(slot, "SESSION_COMMIT_REJECTED", "session owner rejected the staged V2 state", commit_result.get("diagnostics", []))
	if commit_result is bool and not bool(commit_result):
		return _restore_failure(slot, "SESSION_COMMIT_REJECTED", "session owner rejected the staged V2 state")
	_restore_trace.append("committed")
	_restore_in_progress = false
	game_loaded.emit(slot)
	_restore_trace.append("game_loaded")
	return {"valid": true, "slot": slot, "envelope": parsed["data"].duplicate(true), "staged": staged, "diagnostics": []}


func has_save(slot: int) -> bool:
	return _valid_slot(slot) and FileAccess.file_exists(_slot_path(slot))


func delete_save(slot: int) -> Error:
	if not _valid_slot(slot):
		return ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(_slot_path(slot)):
		return ERR_FILE_NOT_FOUND
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return ERR_FILE_CANT_OPEN
	var result: Error = dir.remove("%d%s" % [slot, SAVE_EXT])
	if result == OK:
		save_deleted.emit(slot)
	return result


## Read only metadata; this path never emits game_loaded or commits state.
func get_save_meta(slot: int) -> Variant:
	if not _valid_slot(slot) or not FileAccess.file_exists(_slot_path(slot)):
		return null
	var parsed: Dictionary = _read_payload(slot)
	if not bool(parsed.get("valid", false)) or not parsed["data"] is Dictionary:
		return null
	var data: Dictionary = parsed["data"]
	return data.get("meta", null)


func save_setting(section: String, key: String, value: Variant) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(section, key, value)
	var result: Error = config.save(SETTINGS_PATH)
	if result != OK:
		push_error("SaveManager: Could not save settings.")


func load_setting(section: String, key: String, default_value: Variant = null) -> Variant:
	var config: ConfigFile = ConfigFile.new()
	var result: Error = config.load(SETTINGS_PATH)
	if result != OK:
		return default_value
	return config.get_value(section, key, default_value)


func _ensure_save_dir() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive("saves")


func _slot_path(slot: int) -> String:
	return SAVE_DIR + str(slot) + SAVE_EXT


func _valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= MAX_SLOTS


func _read_payload(slot: int) -> Dictionary:
	var file: FileAccess = FileAccess.open(_slot_path(slot), FileAccess.READ)
	if file == null:
		return {"valid": false, "slot": slot, "reason_code": "SAVE_READ_FAILED", "slot_preserved": true, "staged": {}, "diagnostics": [_diagnostic("SAVE_READ_FAILED", "$", "save slot could not be opened")]}
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {"valid": false, "slot": slot, "reason_code": "JSON_PARSE_FAILED", "slot_preserved": true, "staged": {}, "diagnostics": [_diagnostic("JSON_PARSE_FAILED", "$", "save slot contains invalid JSON")]}
	return {"valid": true, "slot": slot, "data": _normalize_json_numbers(json.data), "diagnostics": []}


func _normalize_json_numbers(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key: Variant in value.keys():
			dictionary[key] = _normalize_json_numbers(value[key])
		return dictionary
	if value is Array:
		var array: Array = []
		for item: Variant in value:
			array.append(_normalize_json_numbers(item))
		return array
	if typeof(value) == TYPE_FLOAT and is_finite(float(value)) and is_equal_approx(float(value), round(float(value))):
		return int(value)
	return value


func _write_atomically(slot: int, content: String) -> Error:
	_ensure_save_dir()
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return ERR_FILE_CANT_OPEN
	var file_name: String = "%d%s" % [slot, SAVE_EXT]
	var temporary_name: String = "%d%s.tmp" % [slot, SAVE_EXT]
	var backup_name: String = "%d%s.bak" % [slot, SAVE_EXT]
	if FileAccess.file_exists(SAVE_DIR + temporary_name):
		dir.remove(temporary_name)
	if FileAccess.file_exists(SAVE_DIR + backup_name):
		dir.remove(backup_name)
	var file: FileAccess = FileAccess.open(SAVE_DIR + temporary_name, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	file.close()
	var had_original: bool = FileAccess.file_exists(SAVE_DIR + file_name)
	if had_original:
		var backup_error: Error = dir.rename(file_name, backup_name)
		if backup_error != OK:
			dir.remove(temporary_name)
			return backup_error
	var replace_error: Error = dir.rename(temporary_name, file_name)
	if replace_error != OK:
		if had_original:
			dir.rename(backup_name, file_name)
		dir.remove(temporary_name)
		return replace_error
	if had_original:
		dir.remove(backup_name)
	return OK


func _is_sha256(value: String) -> bool:
	var regex: RegEx = RegEx.new()
	regex.compile("^[0-9a-f]{64}$")
	return regex.search(value) != null


func _check_exact_fields(value: Dictionary, expected: Array[String], path: String) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	for field: String in expected:
		if not value.has(field):
			diagnostics.append(_diagnostic("FIELD_MISSING", "%s.%s" % [path, field], "required field is missing"))
	for field: Variant in value.keys():
		if not expected.has(String(field)):
			diagnostics.append(_diagnostic("UNKNOWN_FIELD", "%s.%s" % [path, String(field)], "unknown field is forbidden"))
	return diagnostics


func _typed_diagnostics(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in values:
		if value is Dictionary:
			result.append(value)
	return result


func _diagnostic(code: String, path: String, message: String) -> Dictionary:
	return {"code": code, "path": path, "message": message}


func _session_available() -> bool:
	return _runtime_available.is_valid() and bool(_runtime_available.call()) and _session_gate != null and not _session_gate.is_busy()


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "reason_code": code, "slot_preserved": true, "staged": {}, "diagnostics": [_diagnostic(code, "$", message)]}


func _restore_failure(slot: int, code: String, message: String, details: Array = []) -> Dictionary:
	_restore_barrier_active = false
	_restore_in_progress = false
	_restore_trace.append("discarded")
	var diagnostics: Array[Dictionary] = _typed_diagnostics(details)
	if diagnostics.is_empty():
		diagnostics.append(_diagnostic(code, "$.authorities", message))
	var result: Dictionary = {"valid": false, "slot": slot, "reason_code": code, "slot_preserved": true, "old_session_preserved": true, "staged": {}, "diagnostics": diagnostics}
	restore_failed.emit(result.duplicate(true))
	return result
