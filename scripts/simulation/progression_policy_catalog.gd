class_name ProgressionPolicyCatalog
extends Resource

## Immutable element-08 Progression content. Runtime state lives in TechTreeManager.

const SCHEMA_VERSION: int = 1
const POLICY_REVISION: int = 1
const TIER_IDS: Array[String] = [
	"empty_lot",
	"small_market",
	"neighborhood_center",
	"regional_mall",
	"city_destination",
	"megacity_mall",
]
const TECH_POINT_MILESTONES: Array[Dictionary] = [
	{"milestone_id": "tech_points.small_market", "tier_index": 1, "points": 3},
	{"milestone_id": "tech_points.neighborhood_center", "tier_index": 2, "points": 5},
	{"milestone_id": "tech_points.regional_mall", "tier_index": 3, "points": 7},
	{"milestone_id": "tech_points.city_destination", "tier_index": 4, "points": 10},
	{"milestone_id": "tech_points.megacity_mall", "tier_index": 5, "points": 15},
]
const PLOT_ACCESS_MILESTONES: Array[Dictionary] = [
	{"milestone_id": "plot_access.neighborhood_center", "tier_index": 2, "grants": 2},
	{"milestone_id": "plot_access.regional_mall", "tier_index": 3, "grants": 2},
	{"milestone_id": "plot_access.city_destination", "tier_index": 4, "grants": 2},
	{"milestone_id": "plot_access.megacity_mall", "tier_index": 5, "grants": 2},
]
const NODE_DEFINITIONS: Array[Dictionary] = [
	{"node_id": "basic_zoning", "display_name": "Basic Zoning", "cost": 0, "prerequisites": [], "minimum_tier_index": 0, "available_in_product": true, "initially_unlocked": true},
	{"node_id": "advanced_zoning", "display_name": "Advanced Zoning", "cost": 1, "prerequisites": [], "minimum_tier_index": 0, "available_in_product": true, "initially_unlocked": false},
	{"node_id": "anchor_tenants", "display_name": "Anchor Tenants", "cost": 2, "prerequisites": ["advanced_zoning"], "minimum_tier_index": 0, "available_in_product": true, "initially_unlocked": false},
	{"node_id": "basic_corridors", "display_name": "Basic Corridors", "cost": 0, "prerequisites": [], "minimum_tier_index": 0, "available_in_product": true, "initially_unlocked": true},
	{"node_id": "stairs", "display_name": "Stairs", "cost": 1, "prerequisites": [], "minimum_tier_index": 0, "available_in_product": true, "initially_unlocked": false},
	{"node_id": "multi_floor", "display_name": "Multi-Floor", "cost": 2, "prerequisites": ["stairs"], "minimum_tier_index": 0, "available_in_product": true, "initially_unlocked": false},
	{"node_id": "elevators", "display_name": "Elevators", "cost": 2, "prerequisites": ["stairs"], "minimum_tier_index": 0, "available_in_product": true, "initially_unlocked": false},
	{"node_id": "underground", "display_name": "Underground", "cost": 3, "prerequisites": ["multi_floor"], "minimum_tier_index": 0, "available_in_product": true, "initially_unlocked": false},
	{"node_id": "vertical_expansion_i", "display_name": "Vertical Expansion I", "cost": 1, "prerequisites": ["multi_floor"], "minimum_tier_index": 2, "available_in_product": true, "initially_unlocked": false},
	{"node_id": "vertical_expansion_ii", "display_name": "Vertical Expansion II", "cost": 1, "prerequisites": ["vertical_expansion_i"], "minimum_tier_index": 3, "available_in_product": true, "initially_unlocked": false},
	{"node_id": "vertical_expansion_iii", "display_name": "Vertical Expansion III", "cost": 1, "prerequisites": ["vertical_expansion_ii"], "minimum_tier_index": 4, "available_in_product": true, "initially_unlocked": false},
	{"node_id": "deep_foundations", "display_name": "Deep Foundations", "cost": 1, "prerequisites": ["underground"], "minimum_tier_index": 3, "available_in_product": true, "initially_unlocked": false},
	{"node_id": "transport.bus_stop", "display_name": "Bus Stop", "cost": 1, "prerequisites": ["basic_corridors"], "minimum_tier_index": 1, "available_in_product": false, "initially_unlocked": false},
]


func validate_content() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var node_ids: Dictionary = {}
	for definition: Dictionary in NODE_DEFINITIONS:
		var node_id: String = String(definition.get("node_id", ""))
		if node_id.is_empty() or node_ids.has(node_id):
			diagnostics.append(_diagnostic("PROGRESSION_NODE_ID_INVALID", node_id, "Tech node IDs must be unique and non-empty"))
		node_ids[node_id] = true
		if int(definition.get("cost", -1)) < 0:
			diagnostics.append(_diagnostic("PROGRESSION_NODE_COST_INVALID", node_id, "Tech node costs must be nonnegative"))
		var tier_index: int = int(definition.get("minimum_tier_index", -1))
		if tier_index < 0 or tier_index >= TIER_IDS.size():
			diagnostics.append(_diagnostic("PROGRESSION_TIER_GATE_INVALID", node_id, "Tech node tier gate is invalid"))
	for definition: Dictionary in NODE_DEFINITIONS:
		for prerequisite: String in definition.get("prerequisites", []):
			if not node_ids.has(prerequisite):
				diagnostics.append(_diagnostic("PROGRESSION_PREREQUISITE_UNKNOWN", String(definition.get("node_id", "")), "Tech prerequisite is not in the catalog"))
	var milestone_ids: Dictionary = {}
	for milestone: Dictionary in TECH_POINT_MILESTONES + PLOT_ACCESS_MILESTONES:
		var milestone_id: String = String(milestone.get("milestone_id", ""))
		if milestone_id.is_empty() or milestone_ids.has(milestone_id):
			diagnostics.append(_diagnostic("PROGRESSION_MILESTONE_ID_INVALID", milestone_id, "Progression milestone IDs must be unique and non-empty"))
		milestone_ids[milestone_id] = true
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func get_node_definition(node_id: String) -> Dictionary:
	for definition: Dictionary in NODE_DEFINITIONS:
		if String(definition["node_id"]) == node_id:
			return definition.duplicate(true)
	return {}


func get_node_definitions() -> Array[Dictionary]:
	return NODE_DEFINITIONS.duplicate(true)


func get_tier_index(tier_id: String) -> int:
	return TIER_IDS.find(tier_id)


func get_tier_id(tier_index: int) -> String:
	return TIER_IDS[tier_index] if tier_index >= 0 and tier_index < TIER_IDS.size() else ""


func get_tech_milestones_through(tier_index: int) -> Array[Dictionary]:
	return _milestones_through(TECH_POINT_MILESTONES, tier_index)


func get_plot_access_milestones_through(tier_index: int) -> Array[Dictionary]:
	return _milestones_through(PLOT_ACCESS_MILESTONES, tier_index)


func get_initially_unlocked_node_ids() -> Array[String]:
	var result: Array[String] = []
	for definition: Dictionary in NODE_DEFINITIONS:
		if bool(definition.get("initially_unlocked", false)):
			result.append(String(definition["node_id"]))
	return result


func _milestones_through(source: Array[Dictionary], tier_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for milestone: Dictionary in source:
		if int(milestone["tier_index"]) <= tier_index:
			result.append(milestone.duplicate(true))
	return result


func _diagnostic(code: String, subject: String, message: String) -> Dictionary:
	return {"code": code, "path": "$.progression.%s" % subject, "message": message}
