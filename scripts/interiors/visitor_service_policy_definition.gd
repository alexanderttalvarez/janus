## Immutable visitor goal-generation policy for detached H1 planning/tests.
class_name VisitorServicePolicyDefinition
extends Resource

@export var visitor_policy_id: String = ""
@export_range(1, 2147483647, 1) var revision: int = 1
@export var goal_count_weights: Array[int] = [40, 45, 15]
@export_range(1, 2147483647, 1) var wait_tolerance_min_ticks: int = 2
@export_range(1, 2147483647, 1) var wait_tolerance_max_ticks: int = 8
@export var empty_category_goal_id: String = "BROWSING"
@export var leaving_goal_id: String = "LEAVING"
@export var draws_with_replacement: bool = true


func to_record() -> Dictionary:
	return {
		"visitor_policy_id": visitor_policy_id,
		"revision": revision,
		"goal_count_weights": goal_count_weights.duplicate(),
		"wait_tolerance_min_ticks": wait_tolerance_min_ticks,
		"wait_tolerance_max_ticks": wait_tolerance_max_ticks,
		"empty_category_goal_id": empty_category_goal_id,
		"leaving_goal_id": leaving_goal_id,
		"draws_with_replacement": draws_with_replacement,
	}
