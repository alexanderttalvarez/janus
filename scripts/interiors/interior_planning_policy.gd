## Immutable deterministic-work and qualitative-rating policy.
class_name InteriorPlanningPolicy
extends Resource

@export var planning_policy_id: String = "tenant_interiors.planning.default"
@export_range(1, 2147483647, 1) var revision: int = 1
@export_range(1, 2147483647, 1) var placement_validation_budget: int = 10000
@export_range(0, 100, 1) var occupied_area_ceiling_percent: int = 75
@export_range(0, 2147483647, 1) var comfort_extra_modules: int = 2
@export_range(1, 2147483647, 1) var excellent_tickets: int = 6
@export_range(1, 2147483647, 1) var good_tickets: int = 3
@export_range(1, 2147483647, 1) var acceptable_tickets: int = 1
@export var rotation_order: Array[int] = [0, 90, 180, 270]


func to_record() -> Dictionary:
	return {
		"planning_policy_id": planning_policy_id,
		"revision": revision,
		"placement_validation_budget": placement_validation_budget,
		"occupied_area_ceiling_percent": occupied_area_ceiling_percent,
		"comfort_extra_modules": comfort_extra_modules,
		"excellent_tickets": excellent_tickets,
		"good_tickets": good_tickets,
		"acceptable_tickets": acceptable_tickets,
		"rotation_order": rotation_order.duplicate(),
	}
