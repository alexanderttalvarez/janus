class_name PrestigePolicy
extends Resource

## Immutable H1 Prestige tier/rent content. Runtime state never lives here.

const POLICY_REVISION: int = 1
const SNAPSHOT_SCHEMA_VERSION: int = 2
const TIER_DEFINITIONS: Array[Dictionary] = [
	{"tier_id": "empty_lot", "name": "Empty Lot", "threshold_min": 0, "threshold_max": 499, "supported_tenant_tier": 1, "rent_ceiling_centi_kreds": 500, "exclusive_eligible": false},
	{"tier_id": "small_market", "name": "Small Market", "threshold_min": 500, "threshold_max": 1499, "supported_tenant_tier": 2, "rent_ceiling_centi_kreds": 1000, "exclusive_eligible": false},
	{"tier_id": "neighborhood_center", "name": "Neighborhood Center", "threshold_min": 1500, "threshold_max": 3499, "supported_tenant_tier": 3, "rent_ceiling_centi_kreds": 1800, "exclusive_eligible": false},
	{"tier_id": "regional_mall", "name": "Regional Mall", "threshold_min": 3500, "threshold_max": 6499, "supported_tenant_tier": 4, "rent_ceiling_centi_kreds": 3000, "exclusive_eligible": false},
	{"tier_id": "city_destination", "name": "City Destination", "threshold_min": 6500, "threshold_max": 8999, "supported_tenant_tier": 5, "rent_ceiling_centi_kreds": 4500, "exclusive_eligible": false},
	{"tier_id": "megacity_mall", "name": "Megacity Mall", "threshold_min": 9000, "threshold_max": -1, "supported_tenant_tier": 5, "rent_ceiling_centi_kreds": 6000, "exclusive_eligible": true},
]


func validate_content() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if TIER_DEFINITIONS.size() != 6:
		diagnostics.append(_diagnostic("PRESTIGE_POLICY_INVALID", "tiers", "H1 requires exactly six official tiers"))
	for definition: Dictionary in TIER_DEFINITIONS:
		if String(definition.get("tier_id", "")).is_empty() or int(definition.get("supported_tenant_tier", 0)) < 1 or int(definition.get("rent_ceiling_centi_kreds", 0)) < 0:
			diagnostics.append(_diagnostic("PRESTIGE_POLICY_INVALID", "tiers", "tier definitions require stable IDs, tenant caps, and rent ceilings"))
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func get_tier_definition(tier_id: String) -> Dictionary:
	for definition: Dictionary in TIER_DEFINITIONS:
		if String(definition["tier_id"]) == tier_id:
			return definition.duplicate(true)
	return {}


func get_tier_index(tier_id: String) -> int:
	for index: int in range(TIER_DEFINITIONS.size()):
		if String(TIER_DEFINITIONS[index]["tier_id"]) == tier_id:
			return index
	return -1


func get_tier_for_numeric_prestige(numeric_prestige: int) -> Dictionary:
	var selected: Dictionary = {}
	for definition: Dictionary in TIER_DEFINITIONS:
		var minimum: int = int(definition.get("threshold_min", 0))
		if numeric_prestige >= minimum:
			selected = definition.duplicate(true)
	return selected


func create_initial_snapshot(calendar_identity: String) -> OfficialPrestigeSnapshot:
	var definition: Dictionary = get_tier_definition("empty_lot")
	var snapshot_script: Script = load("res://scripts/simulation/official_prestige_snapshot.gd")
	var snapshot: OfficialPrestigeSnapshot = snapshot_script.new() as OfficialPrestigeSnapshot
	snapshot.configure({
		"schema_version": SNAPSHOT_SCHEMA_VERSION,
		"authority_revision": 0,
		"official_tier_id": definition["tier_id"],
		"supported_tenant_tier": definition["supported_tenant_tier"],
		"exclusive_eligible": definition["exclusive_eligible"],
		"rent_ceiling_centi_kreds": definition["rent_ceiling_centi_kreds"],
		"policy_revision": POLICY_REVISION,
		"calendar_identity": calendar_identity,
		"numeric_prestige_present": false,
		"numeric_prestige": 0,
		"numeric_prestige_provenance": "",
	})
	return snapshot


func validate_snapshot_data(value: Variant, expected_authority_revision: int = -1) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if not value is Dictionary:
		return _failure("PRESTIGE_SNAPSHOT_INVALID", "Prestige snapshot must be an object")
	var data: Dictionary = value
	_check_exact_fields(data, OfficialPrestigeSnapshot.FIELDS, diagnostics)
	_check_type(data, "schema_version", TYPE_INT, diagnostics)
	_check_type(data, "authority_revision", TYPE_INT, diagnostics)
	_check_type(data, "official_tier_id", TYPE_STRING, diagnostics)
	_check_type(data, "supported_tenant_tier", TYPE_INT, diagnostics)
	_check_type(data, "exclusive_eligible", TYPE_BOOL, diagnostics)
	_check_type(data, "rent_ceiling_centi_kreds", TYPE_INT, diagnostics)
	_check_type(data, "policy_revision", TYPE_INT, diagnostics)
	_check_type(data, "calendar_identity", TYPE_STRING, diagnostics)
	_check_type(data, "numeric_prestige_present", TYPE_BOOL, diagnostics)
	_check_type(data, "numeric_prestige", TYPE_INT, diagnostics)
	_check_type(data, "numeric_prestige_provenance", TYPE_STRING, diagnostics)
	if int(data.get("schema_version", -1)) != SNAPSHOT_SCHEMA_VERSION:
		_add(diagnostics, "PRESTIGE_SCHEMA_UNSUPPORTED", "$.schema_version", "Prestige snapshot schema must be V2")
	if int(data.get("authority_revision", -1)) < 0:
		_add(diagnostics, "PRESTIGE_REVISION_INVALID", "$.authority_revision", "authority revision must be nonnegative")
	if expected_authority_revision >= 0 and int(data.get("authority_revision", -1)) != expected_authority_revision:
		_add(diagnostics, "PRESTIGE_REVISION_STALE", "$.authority_revision", "candidate revision does not match the committed revision")
	var definition: Dictionary = get_tier_definition(String(data.get("official_tier_id", "")))
	if definition.is_empty():
		_add(diagnostics, "PRESTIGE_TIER_UNKNOWN", "$.official_tier_id", "official tier is not in the immutable policy")
	else:
		for field: String in ["supported_tenant_tier", "rent_ceiling_centi_kreds", "exclusive_eligible"]:
			if data.get(field) != definition[field]:
				_add(diagnostics, "PRESTIGE_POLICY_MISMATCH", "$.%s" % field, "snapshot field does not match immutable tier policy")
	if int(data.get("policy_revision", -1)) != POLICY_REVISION:
		_add(diagnostics, "PRESTIGE_POLICY_REVISION_INVALID", "$.policy_revision", "snapshot policy revision is not supported")
	if String(data.get("calendar_identity", "")).is_empty():
		_add(diagnostics, "PRESTIGE_CALENDAR_IDENTITY_INVALID", "$.calendar_identity", "calendar identity is required")
	var numeric_present: bool = bool(data.get("numeric_prestige_present", false))
	var provenance: String = String(data.get("numeric_prestige_provenance", ""))
	if numeric_present and provenance.is_empty():
		_add(diagnostics, "PRESTIGE_PROVENANCE_REQUIRED", "$.numeric_prestige_provenance", "numeric Prestige requires explicit provenance")
	if not numeric_present and (int(data.get("numeric_prestige", 0)) != 0 or not provenance.is_empty()):
		_add(diagnostics, "PRESTIGE_NUMERIC_VALUE_UNAVAILABLE", "$.numeric_prestige", "unapproved numeric Prestige must be absent")
	if numeric_present and int(data.get("numeric_prestige", -1)) < 0:
		_add(diagnostics, "PRESTIGE_NUMERIC_VALUE_INVALID", "$.numeric_prestige", "numeric Prestige must be nonnegative")
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics, "snapshot": data.duplicate(true) if diagnostics.is_empty() else {}}


func _check_exact_fields(value: Dictionary, fields: Array[String], diagnostics: Array[Dictionary]) -> void:
	for field: String in fields:
		if not value.has(field):
			_add(diagnostics, "PRESTIGE_FIELD_MISSING", "$.%s" % field, "required Prestige field is missing")
	for field: Variant in value.keys():
		if not fields.has(String(field)):
			_add(diagnostics, "PRESTIGE_FIELD_UNKNOWN", "$.%s" % String(field), "unknown Prestige field is forbidden")


func _check_type(value: Dictionary, field: String, expected_type: int, diagnostics: Array[Dictionary]) -> void:
	if value.has(field) and typeof(value[field]) != expected_type:
		_add(diagnostics, "PRESTIGE_FIELD_TYPE_INVALID", "$.%s" % field, "Prestige field has an invalid type")


func _add(diagnostics: Array[Dictionary], code: String, path: String, message: String) -> void:
	diagnostics.append({"code": code, "path": path, "message": message})


func _diagnostic(code: String, path: String, message: String) -> Dictionary:
	return {"code": code, "path": "$.%s" % path, "message": message}


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "snapshot": {}, "diagnostics": [{"code": code, "path": "$", "message": message}]}
