## Immutable authored service-model definition; runtime use begins in tenant_interiors/H4.
class_name ServicePolicyDefinition
extends Resource

@export var service_policy_id: String = ""
@export_range(1, 2147483647, 1) var revision: int = 1
@export var typology: String = ""
@export var stages: Array[Dictionary] = []
@export_range(0, 2147483647, 1) var cadence_ticks: int = 0
@export_range(0, 2147483647, 1) var turnover_ticks: int = 0
@export_range(0, 2147483647, 1) var queue_cap: int = 0
@export var capacity_tokens: Array[String] = []
@export var scheduler_mode: String = "CONTINUOUS"


func to_record() -> Dictionary:
	var ordered_stages: Array[Dictionary] = []
	var ordered_tokens: Array[String] = capacity_tokens.duplicate()
	ordered_tokens.sort()
	for stage: Dictionary in stages:
		ordered_stages.append(stage.duplicate(true))
	return {
		"service_policy_id": service_policy_id,
		"revision": revision,
		"typology": typology,
		"stages": ordered_stages,
		"cadence_ticks": cadence_ticks,
		"turnover_ticks": turnover_ticks,
		"queue_cap": queue_cap,
		"capacity_tokens": ordered_tokens,
		"scheduler_mode": scheduler_mode,
	}
