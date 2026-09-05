class_name OfficialPrestigeCandidate
extends RefCounted

## Detached monthly calculation candidate. PrestigeManager remains the sole
## authority allowed to convert this candidate into a committed snapshot.
const SCHEMA_VERSION: int = 1
const CALCULATION_REVISION: int = 1
const BASELINE_QUALITY_POLICY_REVISION: int = 1
const BASELINE_QUALITY: int = 20
const PROVENANCE: String = "mvp_developed_tile_scale_baseline_quality"
const FIELDS: Array[String] = [
	"calculation_schema_version",
	"calculation_revision",
	"baseline_quality_policy_revision",
	"calendar_identity",
	"source_revision",
	"developed_tile_count",
	"scale_quarters",
	"baseline_quality",
	"numeric_prestige",
	"policy_revision",
	"provenance",
]

var _data: Dictionary = {}


func configure(values: Dictionary) -> void:
	_data = values.duplicate(true)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


func get_calendar_identity() -> String:
	return String(_data.get("calendar_identity", ""))


func get_source_revision() -> int:
	return int(_data.get("source_revision", -1))


func get_policy_revision() -> int:
	return int(_data.get("policy_revision", -1))


func get_numeric_prestige() -> int:
	return int(_data.get("numeric_prestige", -1))


func validate() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	for field: String in FIELDS:
		if not _data.has(field):
			diagnostics.append({"code": "PRESTIGE_CANDIDATE_FIELD_MISSING", "path": "$.%s" % field})
	for key: Variant in _data.keys():
		if not FIELDS.has(String(key)):
			diagnostics.append({"code": "PRESTIGE_CANDIDATE_FIELD_UNKNOWN", "path": "$.%s" % String(key)})
	if int(_data.get("calculation_schema_version", -1)) != SCHEMA_VERSION:
		diagnostics.append({"code": "PRESTIGE_CANDIDATE_SCHEMA_INVALID", "path": "$.calculation_schema_version"})
	if int(_data.get("calculation_revision", -1)) != CALCULATION_REVISION:
		diagnostics.append({"code": "PRESTIGE_CANDIDATE_CALCULATION_REVISION_INVALID", "path": "$.calculation_revision"})
	if int(_data.get("baseline_quality_policy_revision", -1)) != BASELINE_QUALITY_POLICY_REVISION:
		diagnostics.append({"code": "PRESTIGE_CANDIDATE_QUALITY_POLICY_INVALID", "path": "$.baseline_quality_policy_revision"})
	if String(_data.get("calendar_identity", "")).is_empty():
		diagnostics.append({"code": "PRESTIGE_CANDIDATE_CALENDAR_REQUIRED", "path": "$.calendar_identity"})
	if int(_data.get("source_revision", -1)) < 0:
		diagnostics.append({"code": "PRESTIGE_CANDIDATE_SOURCE_REVISION_INVALID", "path": "$.source_revision"})
	var count: int = int(_data.get("developed_tile_count", -1))
	var scale_quarters: int = int(_data.get("scale_quarters", -1))
	var quality: int = int(_data.get("baseline_quality", -1))
	if count < 0 or scale_quarters < 0 or scale_quarters > 400:
		diagnostics.append({"code": "PRESTIGE_CANDIDATE_ARITHMETIC_INVALID", "path": "$.scale_quarters"})
	if quality != BASELINE_QUALITY:
		diagnostics.append({"code": "PRESTIGE_CANDIDATE_QUALITY_INVALID", "path": "$.baseline_quality"})
	if scale_quarters != mini(count, 400):
		diagnostics.append({"code": "PRESTIGE_CANDIDATE_SCALE_MISMATCH", "path": "$.scale_quarters"})
	if int(_data.get("numeric_prestige", -1)) != scale_quarters * 5:
		diagnostics.append({"code": "PRESTIGE_CANDIDATE_VALUE_MISMATCH", "path": "$.numeric_prestige"})
	if int(_data.get("policy_revision", -1)) < 0:
		diagnostics.append({"code": "PRESTIGE_CANDIDATE_POLICY_REVISION_INVALID", "path": "$.policy_revision"})
	if String(_data.get("provenance", "")) != PROVENANCE:
		diagnostics.append({"code": "PRESTIGE_CANDIDATE_PROVENANCE_INVALID", "path": "$.provenance"})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


static func calculate(source: DevelopedTileSnapshot, calendar_identity: String, policy_revision: int) -> OfficialPrestigeCandidate:
	var candidate := OfficialPrestigeCandidate.new()
	if source == null:
		return candidate
	candidate.configure({
		"calculation_schema_version": SCHEMA_VERSION,
		"calculation_revision": CALCULATION_REVISION,
		"baseline_quality_policy_revision": BASELINE_QUALITY_POLICY_REVISION,
		"calendar_identity": calendar_identity,
		"source_revision": source.get_source_revision(),
		"developed_tile_count": source.get_developed_tile_count(),
		"scale_quarters": mini(source.get_developed_tile_count(), 400),
		"baseline_quality": BASELINE_QUALITY,
		"numeric_prestige": mini(source.get_developed_tile_count(), 400) * 5,
		"policy_revision": policy_revision,
		"provenance": PROVENANCE,
	})
	return candidate
