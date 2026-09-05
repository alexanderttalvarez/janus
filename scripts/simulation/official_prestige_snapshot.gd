class_name OfficialPrestigeSnapshot
extends RefCounted

## Detached, committed Prestige authority state. Callers receive copies of its
## serialized values and cannot mutate the manager's committed snapshot.

const FIELDS: Array[String] = [
	"schema_version",
	"authority_revision",
	"official_tier_id",
	"supported_tenant_tier",
	"exclusive_eligible",
	"rent_ceiling_centi_kreds",
	"policy_revision",
	"calendar_identity",
	"numeric_prestige_present",
	"numeric_prestige",
	"numeric_prestige_provenance",
]

var _data: Dictionary = {}


func configure(values: Dictionary) -> void:
	_data = values.duplicate(true)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


func get_schema_version() -> int:
	return int(_data.get("schema_version", -1))


func get_authority_revision() -> int:
	return int(_data.get("authority_revision", -1))


func get_tier_id() -> String:
	return String(_data.get("official_tier_id", ""))


func get_supported_tenant_tier() -> int:
	return int(_data.get("supported_tenant_tier", -1))


func is_exclusive_eligible() -> bool:
	return bool(_data.get("exclusive_eligible", false))


func get_rent_ceiling_centi_kreds() -> int:
	return int(_data.get("rent_ceiling_centi_kreds", -1))


func get_policy_revision() -> int:
	return int(_data.get("policy_revision", -1))


func get_calendar_identity() -> String:
	return String(_data.get("calendar_identity", ""))


func has_numeric_prestige() -> bool:
	return bool(_data.get("numeric_prestige_present", false))


func get_numeric_prestige() -> int:
	return int(_data.get("numeric_prestige", 0))


func get_numeric_prestige_provenance() -> String:
	return String(_data.get("numeric_prestige_provenance", ""))
