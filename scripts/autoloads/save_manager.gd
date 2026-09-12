## SaveManager - exact V2 persistence and atomic detached-session restore.
extends Node

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal save_deleted(slot: int)
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
const PARTICIPANT_FIELDS: Array[String] = ["key", "export_snapshot", "validate_snapshot", "import_snapshot", "cross_validate"]
const PROJECTION_FIELDS: Array[String] = ["district_world", "public_realm_topology", "camera_gateway", "traffic", "tenant_visitor"]
const PROJECTION_DESCRIPTOR_FIELDS: Array[String] = ["key", "prepare"]

var _participants: Array[Dictionary] = []
var _participant_by_key: Dictionary = {}
var _projection_participants: Array[Dictionary] = []
var _active_layout_ref: Callable
var _layout_resolver: Callable
var _candidate_factory: Callable
var _session_publish: Callable
var _session_gate: SessionMutationGate
var _runtime_available: Callable
var _runtime_configuration: Dictionary = {}
var _active_candidate: SessionRestoreCandidate
var _restore_in_progress: bool = false
var _restore_barrier_active: bool = false
var _restore_trace: Array[String] = []
var _restore_fault_stage: String = ""
var _candidate_created_count: int = 0
var _candidate_disposed_count: int = 0
var _candidate_published_count: int = 0
var _last_write_diagnostics: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_save_dir()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _active_candidate != null:
		_dispose_candidate(_active_candidate)
		_active_candidate = null


## Configure the one fixed registry and the candidate lifecycle boundaries.
func configure_runtime(
	participants: Array[Dictionary],
	active_layout_ref: Callable,
	layout_resolver: Callable,
	candidate_factory: Callable,
	projection_participants: Array[Dictionary],
	session_publish: Callable
) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var by_key: Dictionary = {}
	for index: int in range(participants.size()):
		var descriptor: Dictionary = participants[index]
		var key: String = String(descriptor.get("key", ""))
		if key.is_empty() or by_key.has(key):
			diagnostics.append(_diagnostic("REGISTRY_DUPLICATE_PARTICIPANT", "registry", key, "authority participant keys must be unique"))
			continue
		if descriptor.keys().size() != PARTICIPANT_FIELDS.size():
			diagnostics.append(_diagnostic("REGISTRY_DESCRIPTOR_INVALID", "registry", key, "authority descriptor has unknown or missing fields"))
		for field: String in PARTICIPANT_FIELDS:
			if not descriptor.has(field) or (field != "key" and (not descriptor[field] is Callable or not (descriptor[field] as Callable).is_valid())):
				diagnostics.append(_diagnostic("REGISTRY_DESCRIPTOR_INVALID", "registry", key, "authority descriptor callback is missing"))
		by_key[key] = descriptor
		if index >= V2_AUTHORITY_FIELDS.size() or key != V2_AUTHORITY_FIELDS[index]:
			diagnostics.append(_diagnostic("REGISTRY_ORDER_INVALID", "registry", key, "authority registry order is fixed"))
	for key: String in V2_AUTHORITY_FIELDS:
		if not by_key.has(key):
			diagnostics.append(_diagnostic("REGISTRY_PARTICIPANT_MISSING", "registry", key, "required authority participant is missing"))
	for key: String in by_key:
		if not V2_AUTHORITY_FIELDS.has(key):
			diagnostics.append(_diagnostic("REGISTRY_PARTICIPANT_UNKNOWN", "registry", key, "unregistered authority participant is forbidden"))
	var projection_by_key: Dictionary = {}
	for index: int in range(projection_participants.size()):
		var descriptor: Dictionary = projection_participants[index]
		var key: String = String(descriptor.get("key", ""))
		if key.is_empty() or projection_by_key.has(key):
			diagnostics.append(_diagnostic("PROJECTION_REGISTRY_DUPLICATE", "registry", key, "projection participant keys must be unique"))
			continue
		if descriptor.keys().size() != PROJECTION_DESCRIPTOR_FIELDS.size() or not descriptor.get("prepare") is Callable or not (descriptor["prepare"] as Callable).is_valid():
			diagnostics.append(_diagnostic("PROJECTION_DESCRIPTOR_INVALID", "registry", key, "projection descriptor is invalid"))
		projection_by_key[key] = descriptor
		if index >= PROJECTION_FIELDS.size() or key != PROJECTION_FIELDS[index]:
			diagnostics.append(_diagnostic("PROJECTION_REGISTRY_ORDER_INVALID", "registry", key, "projection preparation order is fixed"))
	for key: String in PROJECTION_FIELDS:
		if not projection_by_key.has(key):
			diagnostics.append(_diagnostic("PROJECTION_PARTICIPANT_MISSING", "registry", key, "required projection participant is missing"))
	if not active_layout_ref.is_valid() or not layout_resolver.is_valid() or not candidate_factory.is_valid() or not session_publish.is_valid():
		diagnostics.append(_diagnostic("RUNTIME_BOUNDARIES_REQUIRED", "configuration", "", "layout, candidate, and publication boundaries are required"))
	_runtime_configuration = {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}
	if not diagnostics.is_empty():
		_participants.clear()
		_participant_by_key.clear()
		_projection_participants.clear()
		return _runtime_configuration.duplicate(true)
	_participants = participants.duplicate(true)
	_participant_by_key = by_key.duplicate()
	_projection_participants = projection_participants.duplicate(true)
	_active_layout_ref = active_layout_ref
	_layout_resolver = layout_resolver
	_candidate_factory = candidate_factory
	_session_publish = session_publish
	return {"valid": true, "diagnostics": []}


func configure_session_boundary(gate: SessionMutationGate, runtime_available: Callable) -> Dictionary:
	if gate == null or not runtime_available.is_valid():
		return _failure("SESSION_BOUNDARY_REQUIRED", "SaveManager requires the session gate and readiness provider")
	_session_gate = gate
	_runtime_available = runtime_available
	return {"valid": true, "diagnostics": []}


func get_v2_authority_fields() -> Array[String]:
	return V2_AUTHORITY_FIELDS.duplicate()


func get_v2_authority_registry() -> Array[Dictionary]:
	var registry: Array[Dictionary] = []
	for index: int in range(_participants.size()):
		registry.append({"key": String(_participants[index]["key"]), "order": index, "descriptor_fields": PARTICIPANT_FIELDS.duplicate()})
	return registry


func get_runtime_configuration() -> Dictionary:
	return _runtime_configuration.duplicate(true)


func set_restore_fault_stage(stage: String) -> void:
	_restore_fault_stage = stage


func get_restore_trace() -> Array[String]:
	return _restore_trace.duplicate()


func is_restore_barrier_active() -> bool:
	return _restore_barrier_active


func get_candidate_accounting() -> Dictionary:
	return {
		"created": _candidate_created_count,
		"disposed": _candidate_disposed_count,
		"published": _candidate_published_count,
		"retained": _candidate_created_count - _candidate_disposed_count,
		"active_candidate": _active_candidate != null and not _active_candidate.disposed,
	}


func get_last_write_diagnostics() -> Array[Dictionary]:
	return _last_write_diagnostics.duplicate(true)


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


## Validate structure, approved content identity, and every owner while detached.
func validate_v2_envelope(payload: Variant, expected_slot: int = -1) -> Dictionary:
	var structural: Dictionary = _validate_structure(payload, expected_slot)
	if not bool(structural.get("valid", false)):
		return structural
	if not bool(_runtime_configuration.get("valid", false)):
		return _failure("RUNTIME_BOUNDARIES_REQUIRED", "SaveManager runtime registry is not configured")
	var envelope: Dictionary = payload
	var layout: Dictionary = _resolve_layout(envelope["layout_ref"])
	if not bool(layout.get("valid", false)):
		return {"valid": false, "staged": {}, "diagnostics": _stage_diagnostics(layout.get("diagnostics", []), "layout_resolution", "")}
	for descriptor: Dictionary in _participants:
		var key: String = descriptor["key"]
		var validation: Variant = (descriptor["validate_snapshot"] as Callable).call(envelope["authorities"][key], layout)
		if not _result_valid(validation):
			return {"valid": false, "staged": {}, "diagnostics": _stage_diagnostics(_result_diagnostics(validation), "validate", key)}
	return {"valid": true, "staged": {"layout_ref": envelope["layout_ref"].duplicate(true), "authorities": envelope["authorities"].duplicate(true)}, "layout": layout, "diagnostics": []}


func save_game(slot: int, data: Dictionary = {}) -> Error:
	_last_write_diagnostics.clear()
	if not _valid_slot(slot):
		return ERR_INVALID_PARAMETER
	if not _session_available():
		return ERR_BUSY
	var owner_token: String = "save_capture:%d" % slot
	if not bool(_session_gate.acquire(owner_token).get("valid", false)):
		return ERR_BUSY
	var envelope: Dictionary = {}
	var capture_error: Error = OK
	if data.is_empty():
		var authorities: Dictionary = {}
		for descriptor: Dictionary in _participants:
			var key: String = descriptor["key"]
			var snapshot: Variant = (descriptor["export_snapshot"] as Callable).call()
			if not snapshot is Dictionary:
				capture_error = ERR_INVALID_DATA
				_last_write_diagnostics = [_diagnostic("AUTHORITY_EXPORT_INVALID", "export", key, "authority export must return a detached object")]
				break
			authorities[key] = (snapshot as Dictionary).duplicate(true)
		if capture_error == OK:
			var layout_ref: Variant = _active_layout_ref.call()
			if not layout_ref is Dictionary:
				capture_error = ERR_INVALID_DATA
			else:
				envelope = build_v2_envelope(slot, authorities, layout_ref)
	elif not data.has("save_schema_version"):
		capture_error = ERR_UNAVAILABLE
		_last_write_diagnostics = [_diagnostic("SAVE_SCHEMA_ABSENT", "schema", "", "schema-absent saves are incompatible")]
	else:
		envelope = data.duplicate(true)
	if capture_error == OK:
		var validation: Dictionary = validate_v2_envelope(envelope, slot)
		if not bool(validation.get("valid", false)):
			capture_error = ERR_INVALID_DATA
			_last_write_diagnostics = validation.get("diagnostics", []).duplicate(true)
	_session_gate.release(owner_token)
	if capture_error != OK:
		return capture_error
	var write_error: Error = _write_atomically(slot, JSON.stringify(envelope, "  ", true))
	if write_error != OK:
		return write_error
	game_saved.emit(slot)
	return OK


func load_game(slot: int) -> Dictionary:
	if _restore_in_progress:
		return _failure("RESTORE_ALREADY_IN_PROGRESS", "observer or command attempted restore reentry")
	if not _valid_slot(slot):
		return _failure("INVALID_SLOT", "requested slot is outside the supported range")
	if not _session_available():
		return _failure("SESSION_MUTATION_BUSY", "save/load is blocked until the session boundary is available")
	_restore_in_progress = true
	_restore_barrier_active = false
	_restore_trace = ["restore_requested"]
	restore_requested.emit(slot)
	if _restore_fault_stage == "parse":
		return _restore_failure(slot, "RESTORE_PARSE_INJECTED", "parse", "", "restore parse failure injected")
	var parsed: Dictionary = _read_payload(slot)
	_restore_trace.append("parse")
	if not bool(parsed.get("valid", false)):
		return _restore_failure(slot, String(parsed.get("reason_code", "SAVE_READ_FAILED")), "parse", "", "save read failed", parsed.get("diagnostics", []))
	var structural: Dictionary = _validate_structure(parsed["data"], slot)
	if not bool(structural.get("valid", false)):
		var first: Dictionary = structural.get("diagnostics", [{}])[0]
		return _restore_failure(slot, String(first.get("code", "V2_REJECTED")), "schema", "", "V2 schema rejected", structural.get("diagnostics", []))
	if _restore_fault_stage == "layout_resolution":
		return _restore_failure(slot, "RESTORE_LAYOUT_RESOLUTION_INJECTED", "layout_resolution", "", "layout resolution failure injected")
	var envelope: Dictionary = parsed["data"]
	var resolved_layout: Dictionary = _resolve_layout(envelope["layout_ref"])
	_restore_trace.append("layout_resolution")
	if not bool(resolved_layout.get("valid", false)):
		return _restore_failure(slot, _first_code(resolved_layout, "LAYOUT_RESOLUTION_FAILED"), "layout_resolution", "", "saved layout is incompatible", resolved_layout.get("diagnostics", []))
	var factory_result: Variant = _candidate_factory.call(resolved_layout)
	if not factory_result is SessionRestoreCandidate:
		return _restore_failure(slot, "CANDIDATE_CONSTRUCTION_FAILED", "candidate_construction", "", "candidate factory did not return an isolated container")
	var candidate: SessionRestoreCandidate = factory_result
	_candidate_created_count += 1
	_restore_trace.append("candidate_constructed")
	for descriptor: Dictionary in _participants:
		var key: String = descriptor["key"]
		if _restore_fault_stage == "validate:%s" % key or (_restore_fault_stage == "authority_validation" and key == V2_AUTHORITY_FIELDS[0]):
			return _candidate_failure(slot, candidate, "RESTORE_AUTHORITY_VALIDATION_INJECTED", "validate", key, "authority validation failure injected")
		var validation: Variant = (descriptor["validate_snapshot"] as Callable).call(envelope["authorities"][key], resolved_layout)
		_restore_trace.append("validate:%s" % key)
		if not _result_valid(validation):
			return _candidate_failure(slot, candidate, _first_code(validation, "AUTHORITY_VALIDATION_FAILED"), "validate", key, "authority detached validation failed", _result_diagnostics(validation))
	for descriptor: Dictionary in _participants:
		var key: String = descriptor["key"]
		if _restore_fault_stage == "import:%s" % key:
			return _candidate_failure(slot, candidate, "RESTORE_AUTHORITY_IMPORT_INJECTED", "import", key, "authority import failure injected")
		var imported: Variant = (descriptor["import_snapshot"] as Callable).call(envelope["authorities"][key], candidate)
		_restore_trace.append("import:%s" % key)
		if not _result_valid(imported):
			return _candidate_failure(slot, candidate, _first_code(imported, "AUTHORITY_IMPORT_FAILED"), "import", key, "authority candidate import failed", _result_diagnostics(imported))
	for descriptor: Dictionary in _participants:
		var key: String = descriptor["key"]
		if _restore_fault_stage == "cross_validate:%s" % key:
			return _candidate_failure(slot, candidate, "RESTORE_CROSS_VALIDATION_INJECTED", "cross_validate", key, "cross-authority validation failure injected")
		var cross_validation: Variant = (descriptor["cross_validate"] as Callable).call(candidate)
		_restore_trace.append("cross_validate:%s" % key)
		if not _result_valid(cross_validation):
			return _candidate_failure(slot, candidate, _first_code(cross_validation, "CROSS_AUTHORITY_VALIDATION_FAILED"), "cross_validate", key, "cross-authority validation failed", _result_diagnostics(cross_validation))
	for descriptor: Dictionary in _projection_participants:
		var key: String = descriptor["key"]
		if _restore_fault_stage == "prepare:%s" % key or (_restore_fault_stage == "projection_preparation" and key == PROJECTION_FIELDS[0]):
			return _candidate_failure(slot, candidate, "RESTORE_PROJECTION_PREPARATION_INJECTED", "prepare", key, "projection preparation failure injected")
		var preparation: Variant = (descriptor["prepare"] as Callable).call(candidate)
		_restore_trace.append("prepare:%s" % key)
		if not _result_valid(preparation):
			return _candidate_failure(slot, candidate, _first_code(preparation, "PROJECTION_PREPARATION_FAILED"), "prepare", key, "candidate projection preparation failed", _result_diagnostics(preparation))
	var readiness: Dictionary = candidate.mark_prepared(V2_AUTHORITY_FIELDS, PROJECTION_FIELDS)
	if not bool(readiness.get("valid", false)):
		return _candidate_failure(slot, candidate, _first_code(readiness, "CANDIDATE_NOT_READY"), "readiness", "", "candidate restore barrier did not open", readiness.get("diagnostics", []))
	if _restore_fault_stage in ["pre_publish", "commit"]:
		return _candidate_failure(slot, candidate, "RESTORE_PRE_PUBLICATION_INJECTED", "pre_publish", "", "pre-publication failure injected")
	var owner_token: String = "restore_replace:%d" % slot
	if not bool(_session_gate.acquire(owner_token).get("valid", false)):
		return _candidate_failure(slot, candidate, "SESSION_MUTATION_BUSY", "pre_publish", "", "another session mutation is active")
	_restore_barrier_active = true
	_restore_trace.append("commit_barrier")
	var previous_candidate: SessionRestoreCandidate = _active_candidate
	_session_publish.call(candidate)
	candidate.mark_published()
	_active_candidate = candidate
	_candidate_published_count += 1
	_restore_trace.append("published")
	if previous_candidate != null:
		_dispose_candidate(previous_candidate)
	_restore_trace.append("old_disposed")
	_restore_barrier_active = false
	_session_gate.release(owner_token)
	_restore_trace.append("committed")
	# Keep the reentry guard set while observers receive the sole load event.
	game_loaded.emit(slot)
	_restore_trace.append("game_loaded")
	_restore_in_progress = false
	return {"valid": true, "slot": slot, "envelope": envelope.duplicate(true), "candidate": candidate, "diagnostics": []}


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


func get_save_meta(slot: int) -> Variant:
	if not _valid_slot(slot) or not FileAccess.file_exists(_slot_path(slot)):
		return null
	var parsed: Dictionary = _read_payload(slot)
	if not bool(parsed.get("valid", false)) or not parsed["data"] is Dictionary:
		return null
	return parsed["data"].get("meta", null)


func save_setting(section: String, key: String, value: Variant) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(section, key, value)
	if config.save(SETTINGS_PATH) != OK:
		push_error("SaveManager: Could not save settings.")


func load_setting(section: String, key: String, default_value: Variant = null) -> Variant:
	var config: ConfigFile = ConfigFile.new()
	return default_value if config.load(SETTINGS_PATH) != OK else config.get_value(section, key, default_value)


func _validate_structure(payload: Variant, expected_slot: int) -> Dictionary:
	if not payload is Dictionary:
		return _validation_failure("V2_ROOT_NOT_OBJECT", "$", "V2 save root must be an object")
	var envelope: Dictionary = payload
	if not envelope.has("save_schema_version"):
		return _validation_failure("SAVE_SCHEMA_ABSENT", "$.save_schema_version", "schema-absent saves are incompatible and are not migrated")
	if typeof(envelope.get("save_schema_version")) != TYPE_INT:
		return _validation_failure("V2_SCHEMA_VERSION_TYPE", "$.save_schema_version", "save schema version must be an integer")
	if int(envelope["save_schema_version"]) == 1:
		return _validation_failure("SAVE_SCHEMA_V1_UNSUPPORTED", "$.save_schema_version", "V1 saves are incompatible and are not migrated")
	var diagnostics: Array[Dictionary] = _check_exact_fields(envelope, V2_ROOT_FIELDS, "$", "schema", "")
	if int(envelope["save_schema_version"]) != V2_SCHEMA_VERSION:
		diagnostics.append(_diagnostic("V2_SCHEMA_VERSION_UNSUPPORTED", "schema", "", "save schema version must be 2", "$.save_schema_version"))
	var meta: Variant = envelope.get("meta")
	if not meta is Dictionary:
		diagnostics.append(_diagnostic("V2_META_NOT_OBJECT", "schema", "", "meta must be an object", "$.meta"))
	else:
		diagnostics.append_array(_check_exact_fields(meta, V2_META_FIELDS, "$.meta", "schema", ""))
		if typeof(meta.get("slot")) != TYPE_INT or (expected_slot > 0 and int(meta.get("slot", -1)) != expected_slot):
			diagnostics.append(_diagnostic("V2_META_SLOT_INVALID", "schema", "", "meta.slot must match the requested slot", "$.meta.slot"))
		if typeof(meta.get("timestamp")) != TYPE_INT or int(meta.get("timestamp", -1)) < 0:
			diagnostics.append(_diagnostic("V2_META_TIMESTAMP_INVALID", "schema", "", "meta.timestamp must be nonnegative", "$.meta.timestamp"))
		if typeof(meta.get("application_version")) != TYPE_STRING:
			diagnostics.append(_diagnostic("V2_META_APPLICATION_VERSION_TYPE", "schema", "", "application_version must be a string", "$.meta.application_version"))
	var layout_ref: Variant = envelope.get("layout_ref")
	if not layout_ref is Dictionary:
		diagnostics.append(_diagnostic("V2_LAYOUT_REF_NOT_OBJECT", "schema", "", "layout_ref must be an object", "$.layout_ref"))
	else:
		diagnostics.append_array(_check_exact_fields(layout_ref, V2_LAYOUT_FIELDS, "$.layout_ref", "schema", ""))
		if typeof(layout_ref.get("layout_id")) != TYPE_STRING or String(layout_ref.get("layout_id", "")).is_empty():
			diagnostics.append(_diagnostic("V2_LAYOUT_ID_TYPE", "schema", "", "layout_id must be a nonempty string", "$.layout_ref.layout_id"))
		if typeof(layout_ref.get("layout_definition_version")) != TYPE_INT:
			diagnostics.append(_diagnostic("V2_LAYOUT_VERSION_TYPE", "schema", "", "layout_definition_version must be an integer", "$.layout_ref.layout_definition_version"))
		if typeof(layout_ref.get("definition_fingerprint")) != TYPE_STRING or not _is_sha256(String(layout_ref.get("definition_fingerprint", ""))):
			diagnostics.append(_diagnostic("V2_FINGERPRINT_INVALID", "schema", "", "definition_fingerprint must be lowercase SHA-256", "$.layout_ref.definition_fingerprint"))
	var authorities: Variant = envelope.get("authorities")
	if not authorities is Dictionary:
		diagnostics.append(_diagnostic("V2_AUTHORITIES_NOT_OBJECT", "schema", "", "authorities must be an object", "$.authorities"))
	else:
		diagnostics.append_array(_check_exact_fields(authorities, V2_AUTHORITY_FIELDS, "$.authorities", "schema", ""))
		for key: String in V2_AUTHORITY_FIELDS:
			if authorities.has(key) and not authorities[key] is Dictionary:
				diagnostics.append(_diagnostic("V2_AUTHORITY_TYPE", "schema", key, "authority snapshots must be objects", "$.authorities.%s" % key))
	return {"valid": diagnostics.is_empty(), "staged": {}, "diagnostics": diagnostics}


func _resolve_layout(layout_ref: Dictionary) -> Dictionary:
	var result: Variant = _layout_resolver.call(layout_ref.duplicate(true))
	if not result is Dictionary:
		return {"valid": false, "diagnostics": [_diagnostic("LAYOUT_RESOLVER_INVALID", "layout_resolution", "", "layout resolver returned an invalid result")]}
	return result


func _read_payload(slot: int) -> Dictionary:
	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"valid": false, "reason_code": "SAVE_NOT_FOUND", "diagnostics": [_diagnostic("SAVE_NOT_FOUND", "parse", "", "save slot does not exist")]}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"valid": false, "reason_code": "SAVE_READ_FAILED", "diagnostics": [_diagnostic("SAVE_READ_FAILED", "parse", "", "save slot could not be opened")]}
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK:
		return {"valid": false, "reason_code": "SAVE_READ_FAILED", "diagnostics": [_diagnostic("SAVE_READ_FAILED", "parse", "", "save slot read did not complete")]}
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {"valid": false, "reason_code": "JSON_PARSE_FAILED", "diagnostics": [_diagnostic("JSON_PARSE_FAILED", "parse", "", "save slot contains invalid JSON")]}
	return {"valid": true, "data": _normalize_json_numbers(json.data), "diagnostics": []}


func _write_atomically(slot: int, content: String) -> Error:
	_ensure_save_dir()
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return _write_failure(ERR_FILE_CANT_OPEN, "WRITE_DIRECTORY_OPEN_FAILED", "write_directory")
	var file_name: String = "%d%s" % [slot, SAVE_EXT]
	var temporary_name: String = "%d%s.tmp" % [slot, SAVE_EXT]
	var backup_name: String = "%d%s.bak" % [slot, SAVE_EXT]
	_remove_if_present(dir, temporary_name)
	_remove_if_present(dir, backup_name)
	if _restore_fault_stage == "write:temporary":
		return _write_failure(ERR_CANT_CREATE, "WRITE_TEMPORARY_INJECTED", "write_temporary")
	var temporary_path: String = SAVE_DIR + temporary_name
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _write_failure(FileAccess.get_open_error(), "WRITE_TEMPORARY_OPEN_FAILED", "write_temporary")
	file.store_string(content)
	if file.get_error() != OK:
		var store_error: Error = file.get_error()
		file.close()
		_remove_if_present(dir, temporary_name)
		return _write_failure(store_error, "WRITE_TEMPORARY_FAILED", "write_temporary")
	if _restore_fault_stage == "write:flush":
		file.close()
		_remove_if_present(dir, temporary_name)
		return _write_failure(ERR_FILE_CANT_WRITE, "WRITE_FLUSH_INJECTED", "write_flush")
	file.flush()
	var flush_error: Error = file.get_error()
	file.close()
	if flush_error != OK or not _verify_file(temporary_path, content):
		_remove_if_present(dir, temporary_name)
		return _write_failure(flush_error if flush_error != OK else ERR_FILE_CORRUPT, "WRITE_TEMPORARY_VERIFY_FAILED", "write_verify")
	var had_original: bool = FileAccess.file_exists(SAVE_DIR + file_name)
	if had_original:
		var backup_error: Error = dir.rename(file_name, backup_name)
		if backup_error != OK:
			_remove_if_present(dir, temporary_name)
			return _write_failure(backup_error, "WRITE_BACKUP_FAILED", "write_replace")
	if _restore_fault_stage == "write:replace":
		if had_original:
			dir.rename(backup_name, file_name)
		_remove_if_present(dir, temporary_name)
		return _write_failure(ERR_CANT_CREATE, "WRITE_REPLACE_INJECTED", "write_replace")
	var replace_error: Error = dir.rename(temporary_name, file_name)
	if replace_error != OK or not _verify_file(SAVE_DIR + file_name, content):
		_remove_if_present(dir, file_name)
		if had_original:
			dir.rename(backup_name, file_name)
		_remove_if_present(dir, temporary_name)
		return _write_failure(replace_error if replace_error != OK else ERR_FILE_CORRUPT, "WRITE_REPLACE_VERIFY_FAILED", "write_replace")
	_remove_if_present(dir, backup_name)
	return OK


func _verify_file(path: String, expected: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var actual: String = file.get_as_text()
	var error: Error = file.get_error()
	file.close()
	return error == OK and actual == expected


func _write_failure(error: Error, code: String, stage: String) -> Error:
	_last_write_diagnostics = [_diagnostic(code, stage, "", error_string(error))]
	return error


func _remove_if_present(dir: DirAccess, name: String) -> void:
	if FileAccess.file_exists(SAVE_DIR + name):
		dir.remove(name)


func _candidate_failure(slot: int, candidate: SessionRestoreCandidate, code: String, stage: String, key: String, message: String, details: Array = []) -> Dictionary:
	_dispose_candidate(candidate)
	return _restore_failure(slot, code, stage, key, message, details)


func _dispose_candidate(candidate: SessionRestoreCandidate) -> void:
	if candidate == null or candidate.disposed:
		return
	candidate.dispose()
	_candidate_disposed_count += 1


func _restore_failure(slot: int, code: String, stage: String, key: String, message: String, details: Array = []) -> Dictionary:
	_restore_barrier_active = false
	_restore_trace.append("discarded")
	var diagnostics: Array[Dictionary] = _stage_diagnostics(details, stage, key)
	if diagnostics.is_empty():
		diagnostics.append(_diagnostic(code, stage, key, message))
	var result: Dictionary = {"valid": false, "slot": slot, "reason_code": code, "failed_stage": stage, "failed_key": key, "slot_preserved": true, "old_session_preserved": true, "candidate_disposed": stage not in ["parse", "schema", "layout_resolution"], "diagnostics": diagnostics}
	restore_failed.emit(result.duplicate(true))
	_restore_in_progress = false
	return result


func _stage_diagnostics(values: Array, stage: String, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in values:
		if value is Dictionary:
			var item: Dictionary = value.duplicate(true)
			item["stage"] = stage
			if not key.is_empty():
				item["key"] = key
			result.append(item)
	return result


func _result_valid(value: Variant) -> bool:
	return value is Dictionary and bool(value.get("valid", false))


func _result_diagnostics(value: Variant) -> Array:
	return value.get("diagnostics", []) if value is Dictionary else []


func _first_code(value: Variant, fallback: String) -> String:
	if value is Dictionary:
		var diagnostics: Array = value.get("diagnostics", [])
		if not diagnostics.is_empty() and diagnostics[0] is Dictionary:
			return String(diagnostics[0].get("code", fallback))
	return fallback


func _validation_failure(code: String, path: String, message: String) -> Dictionary:
	return {"valid": false, "staged": {}, "diagnostics": [_diagnostic(code, "schema", "", message, path)]}


func _check_exact_fields(value: Dictionary, expected: Array[String], path: String, stage: String, key: String) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	for field: String in expected:
		if not value.has(field):
			diagnostics.append(_diagnostic("FIELD_MISSING", stage, key, "required field is missing", "%s.%s" % [path, field]))
	for field: Variant in value.keys():
		if not expected.has(String(field)):
			diagnostics.append(_diagnostic("UNKNOWN_FIELD", stage, key, "unknown field is forbidden", "%s.%s" % [path, String(field)]))
	return diagnostics


func _diagnostic(code: String, stage: String, key: String, message: String, path: String = "$") -> Dictionary:
	var result: Dictionary = {"code": code, "stage": stage, "path": path, "message": message}
	if not key.is_empty():
		result["key"] = key
	return result


func _normalize_json_numbers(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key: Variant in value:
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


func _is_sha256(value: String) -> bool:
	var regex: RegEx = RegEx.new()
	regex.compile("^[0-9a-f]{64}$")
	return regex.search(value) != null


func _ensure_save_dir() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive("saves")


func _slot_path(slot: int) -> String:
	return SAVE_DIR + str(slot) + SAVE_EXT


func _valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= MAX_SLOTS


func _session_available() -> bool:
	return bool(_runtime_configuration.get("valid", false)) and _runtime_available.is_valid() and bool(_runtime_available.call()) and _session_gate != null and not _session_gate.is_busy()


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "reason_code": code, "slot_preserved": true, "staged": {}, "diagnostics": [_diagnostic(code, "request", "", message)]}
