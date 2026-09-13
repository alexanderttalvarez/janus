## Preserved commercial identity linked to one operational interior profile.
class_name InteriorTenantProfileDefinition
extends Resource

@export var profile_id: String = ""
@export_range(1, 2147483647, 1) var candidate_revision: int = 1
@export var theme_id: String = ""
@export var subtype_id: String = ""
@export var zone_type: String = ""
@export_range(1, 2147483647, 1) var tier: int = 1
@export var operational_profile_id: String = ""


func to_record() -> Dictionary:
	return {
		"profile_id": profile_id,
		"candidate_revision": candidate_revision,
		"theme_id": theme_id,
		"subtype_id": subtype_id,
		"zone_type": zone_type,
		"tier": tier,
		"operational_profile_id": operational_profile_id,
	}
