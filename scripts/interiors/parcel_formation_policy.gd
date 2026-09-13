## Immutable deterministic-work and scale-distribution policy for detached H2 formation.
class_name ParcelFormationPolicy
extends Resource

const SCHEMA_ID: String = "tenant_parcel_formation_policy"
const SCHEMA_VERSION: int = 1

@export var policy_id: String = "tenant_parcel_formation"
@export_range(1, 2147483647, 1) var policy_revision: int = 1
@export var compact_area: Array[int] = [4, 12]
@export var standard_area: Array[int] = [13, 24]
@export var large_area: Array[int] = [25, 96]
@export var scale_slot_cycle: Array[String] = ["STANDARD", "COMPACT", "LARGE", "COMPACT"]
@export_range(1, 2147483647, 1) var formation_work_budget: int = 50000
@export_range(1, 2147483647, 1) var maximum_complete_plan_candidates: int = 256


func to_record() -> Dictionary:
	return {
		"schema_id": SCHEMA_ID, "schema_version": SCHEMA_VERSION,
		"policy_id": policy_id, "policy_revision": policy_revision,
		"compact_area": compact_area.duplicate(), "standard_area": standard_area.duplicate(),
		"large_area": large_area.duplicate(), "scale_slot_cycle": scale_slot_cycle.duplicate(),
		"formation_work_budget": formation_work_budget,
		"maximum_complete_plan_candidates": maximum_complete_plan_candidates,
	}


func scale_for_area(area: int) -> String:
	if area >= compact_area[0] and area <= compact_area[1]:
		return "COMPACT"
	if area >= standard_area[0] and area <= standard_area[1]:
		return "STANDARD"
	if area >= large_area[0] and area <= large_area[1]:
		return "LARGE"
	return "OUT_OF_RANGE"


func validate_revision_one() -> bool:
	var expected := ParcelFormationPolicy.new()
	return to_record() == expected.to_record()
