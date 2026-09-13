## Immutable authored subtype operation and physical-feasibility requirements.
class_name OperationalProfileDefinition
extends Resource

@export var operational_profile_id: String = ""
@export_range(1, 2147483647, 1) var revision: int = 1
@export var subtype_id: String = ""
@export var zone_type: String = ""
@export_range(1, 2147483647, 1) var minimum_area: int = 1
@export_range(1, 2147483647, 1) var core_width: int = 1
@export_range(1, 2147483647, 1) var core_depth: int = 1
@export var core_rotations: Array[int] = [0, 90]
@export_range(1, 2147483647, 1) var target_area_min: int = 1
@export_range(1, 2147483647, 1) var target_area_max: int = 1
@export_range(0, 2147483647, 1) var minimum_frontage: int = 1
@export_range(0, 2147483647, 1) var queue_cap: int = 0
@export var queue_required: bool = false
@export var service_policy_id: String = ""
@export var fixture_program: Array[Dictionary] = []
@export var requires_circulation_loop: bool = false


func to_record() -> Dictionary:
	var rotations: Array[int] = core_rotations.duplicate()
	rotations.sort()
	var program: Array[Dictionary] = []
	for entry: Dictionary in fixture_program:
		program.append(entry.duplicate(true))
	program.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var priority_compare: int = int(left.get("priority", 0)) - int(right.get("priority", 0))
		return priority_compare < 0 or (priority_compare == 0 and String(left.get("fixture_id", "")) < String(right.get("fixture_id", "")))
	)
	return {
		"operational_profile_id": operational_profile_id,
		"revision": revision,
		"subtype_id": subtype_id,
		"zone_type": zone_type,
		"minimum_area": minimum_area,
		"core_width": core_width,
		"core_depth": core_depth,
		"core_rotations": rotations,
		"target_area_min": target_area_min,
		"target_area_max": target_area_max,
		"minimum_frontage": minimum_frontage,
		"queue_cap": queue_cap,
		"queue_required": queue_required,
		"service_policy_id": service_policy_id,
		"fixture_program": program,
		"requires_circulation_loop": requires_circulation_loop,
	}
