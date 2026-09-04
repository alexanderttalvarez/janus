## TechTreeManager — Unlock progression via tech points from prestige.
class_name TechTreeManager
extends Node


signal point_spent(node_id: String)
signal points_changed(available: int, total_earned: int)
signal progression_changed(snapshot: Dictionary)
signal plot_selected(plot_id: String)

const MAX_ADDITIONAL_PLOTS: int = 8
const MAX_TOTAL_PLOTS: int = 9
const PLOT_ACCESS_GRANTS_BY_LEVEL: Array[int] = [0, 0, 2, 2, 2, 2]
const NORMAL_ELEVATIONS: Array[int] = [0, 1, 2, -1, -2, -3]
const DEBUG_ELEVATIONS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, -1, -2, -3, -4, -5]


## Tech tree node definition.
class TechNode:
	var id: String
	var name_key: String
	var description_key: String
	var grid_pos: Vector2i
	var prerequisites: Array[String]  # IDs of required nodes.
	var cost: int


## All defined tech nodes.
var nodes: Dictionary = {}  # Dictionary[String, TechNode]

## Unlocked node IDs.
var unlocked: Array[String] = []

## Monotonic authority revision used by coordinated district transactions.
var authority_revision: int = 0

## Available tech points to spend.
var _available_points: int = 0
var _suppress_progression_notifications: bool = false
var available_points: int:
	get:
		return _available_points
	set(value):
		_available_points = value
		if _suppress_progression_notifications:
			return
		points_changed.emit(_available_points, total_earned)

## Total tech points earned over the game.
var total_earned: int = 0

## Stable progression state owned by this authority.
var selected_plot_ids: Array[String] = []
var plot_access_grants_earned: int = 0
var plot_access_grants_consumed: int = 0
var awarded_milestone_ids: Array[String] = []
var _prestige_manager: Node


func _ready() -> void:
	define_tech_tree()


## Define the tech tree nodes.
func define_tech_tree() -> void:
	nodes.clear()
	_add_node("basic_corridors", "Basic Corridors", "Unlock standard corridor placement.", Vector2i(0, 0), [], 0)
	_add_node("stairs", "Stairs", "Unlock stair placement.", Vector2i(1, 0), [], 1)
	_add_node("multi_floor", "Multi-Floor", "Unlock F1 and F2 vertical rights.", Vector2i(1, 1), ["stairs"], 2)
	_add_node("underground", "Underground", "Unlock U1 through U3 vertical rights.", Vector2i(1, 2), ["multi_floor"], 3)
	_add_node("escalator_1", "Escalators I", "Unlock escalator placement.", Vector2i(2, 0), [], 2)
	_add_node("elevator_1", "Elevators I", "Unlock elevator placement.", Vector2i(4, 0), [], 2)
	_add_node("escalator_2", "Escalators II", "Faster escalators.", Vector2i(2, 2), ["escalator_1"], 4)
	_add_node("elevator_2", "Elevators II", "Larger capacity elevators.", Vector2i(4, 2), ["elevator_1"], 4)
	_add_node("amenity_garden", "Gardens", "Place gardens for prestige.", Vector2i(1, 4), [], 3)
	_add_node("amenity_seating", "Seating Areas", "Place seating for comfort.", Vector2i(3, 4), [], 3)
	_add_node("staff_cleaner", "Cleaners", "Hire cleaning staff.", Vector2i(0, 2), [], 3)
	_add_node("staff_security", "Security", "Hire security staff.", Vector2i(6, 2), [], 3)
	_add_node("zone_anchor", "Anchor Stores", "Unlock anchor-type zones.", Vector2i(5, 4), [], 5)


func _add_node(id: String, name_key: String, desc: String, pos: Vector2i, pre: Array[String], cost: int) -> void:
	var node := TechNode.new()
	node.id = id; node.name_key = name_key; node.description_key = desc
	node.grid_pos = pos; node.prerequisites = pre; node.cost = cost
	nodes[id] = node


## Return the monotonic progression revision.
func get_district_revision() -> int:
	return authority_revision


func set_prestige_manager(manager: Node) -> void:
	_prestige_manager = manager


func sync_mall_level(level_index: int) -> void:
	var bounded_level: int = clampi(level_index, 0, PLOT_ACCESS_GRANTS_BY_LEVEL.size() - 1)
	for milestone_level: int in range(1, bounded_level + 1):
		var milestone_id: String = "plot_access_mall_level_%d" % milestone_level
		if awarded_milestone_ids.has(milestone_id):
			continue
		awarded_milestone_ids.append(milestone_id)
		plot_access_grants_earned += PLOT_ACCESS_GRANTS_BY_LEVEL[milestone_level]
		awarded_milestone_ids.sort()
		authority_revision += 1


func get_policy_snapshot() -> Dictionary:
	var level_index: int = 0
	var level_name: String = "Empty Lot"
	if _prestige_manager != null:
		if _prestige_manager.has_method("get_mall_level_index"):
			level_index = int(_prestige_manager.call("get_mall_level_index"))
		if _prestige_manager.has_method("get_mall_level_name"):
			level_name = String(_prestige_manager.call("get_mall_level_name"))
	var god_mode: bool = _debug_god_mode_active()
	var eligible_elevations: Array[int] = DEBUG_ELEVATIONS.duplicate() if god_mode else _normal_eligible_elevations()
	var selected: Array[String] = selected_plot_ids.duplicate()
	selected.sort()
	var remaining: int = maxi(0, MAX_ADDITIONAL_PLOTS - selected.size()) if god_mode else maxi(0, plot_access_grants_earned - plot_access_grants_consumed)
	return {
		"schema_version": 1,
		"revision": authority_revision,
		"mall_level_index": level_index,
		"mall_level": level_name,
		"unlocked_node_ids": unlocked.duplicate(),
		"available_points": available_points,
		"total_earned": total_earned,
		"plot_access_grants_earned": plot_access_grants_earned,
		"plot_access_grants_consumed": plot_access_grants_consumed,
		"plot_access_grants_remaining": remaining,
		"selected_plot_ids": selected,
		"elevation_eligibility": eligible_elevations,
		"unavailable_elevations": _unavailable_elevations(eligible_elevations),
		"street_conversion_eligible": god_mode or level_index >= 2,
		"transport_capabilities": ["PEDESTRIAN"],
		"unavailable_capabilities": ["NON_PEDESTRIAN_TRANSPORT"],
		"god_mode": god_mode,
		"content_policy_revision": 1,
	}


func select_plot(plot_id: String, snapshot: ResolvedDistrictSnapshot) -> Dictionary:
	if snapshot == null:
		return _progression_failure("DISTRICT_SNAPSHOT_REQUIRED", "Plot selection requires the resolved district snapshot")
	if plot_id.is_empty():
		return _progression_failure("PLOT_ID_REQUIRED", "Plot selection requires a stable Plot ID")
	if selected_plot_ids.has(plot_id):
		return _progression_failure("PLOT_ALREADY_SELECTED", "Plot is already selected")
	var plot: Dictionary = _record_by_id(snapshot.get_data().get("plots", []), plot_id)
	if plot.is_empty():
		return _progression_failure("PLOT_UNKNOWN", "Plot ID is not present in the resolved snapshot")
	var initial_plot_ids: Array[String] = _initial_plot_ids(snapshot)
	if initial_plot_ids.has(plot_id):
		return _progression_failure("INITIAL_PLOT_ALREADY_OWNED", "the initially owned Plot cannot be selected")
	var remaining: int = int(get_policy_snapshot().get("plot_access_grants_remaining", 0))
	if selected_plot_ids.size() >= MAX_ADDITIONAL_PLOTS or remaining <= 0:
		return _progression_failure("PLOT_ACCESS_EXHAUSTED", "no Plot Access selection remains")
	if not _adjacent_to_accessible_plot(snapshot, plot_id, initial_plot_ids):
		return _progression_failure("PLOT_NOT_ADJACENT", "Plot selection requires orthogonal adjacency")
	selected_plot_ids.append(plot_id)
	selected_plot_ids.sort()
	plot_access_grants_consumed += 1
	authority_revision += 1
	var result_snapshot: Dictionary = get_policy_snapshot()
	plot_selected.emit(plot_id)
	progression_changed.emit(result_snapshot.duplicate(true))
	return {"valid": true, "plot_id": plot_id, "snapshot": result_snapshot, "diagnostics": []}


func is_plot_selected(plot_id: String) -> bool:
	return selected_plot_ids.has(plot_id)


func is_elevation_eligible(elevation: int) -> bool:
	return get_policy_snapshot().get("elevation_eligibility", []).has(elevation)


func is_street_conversion_eligible() -> bool:
	return bool(get_policy_snapshot().get("street_conversion_eligible", false))


func _normal_eligible_elevations() -> Array[int]:
	var result: Array[int] = [0]
	if unlocked.has("multi_floor"):
		result.append(1)
		result.append(2)
	if unlocked.has("underground"):
		result.append(-1)
		result.append(-2)
		result.append(-3)
	return result


func _unavailable_elevations(eligible: Array[int]) -> Array[int]:
	var unavailable: Array[int] = []
	for elevation: int in DEBUG_ELEVATIONS:
		if not eligible.has(elevation):
			unavailable.append(elevation)
	return unavailable


func _initial_plot_ids(snapshot: ResolvedDistrictSnapshot) -> Array[String]:
	var result: Array[String] = []
	for section: Dictionary in snapshot.get_data().get("sections", []):
		if not bool(section.get("initially_owned", false)):
			continue
		var plot_id: String = String(section.get("plot_id", ""))
		if not plot_id.is_empty() and not result.has(plot_id):
			result.append(plot_id)
	result.sort()
	return result


func _adjacent_to_accessible_plot(snapshot: ResolvedDistrictSnapshot, plot_id: String, initial_plot_ids: Array[String]) -> bool:
	var target: Dictionary = _record_by_id(snapshot.get_data().get("plots", []), plot_id)
	for candidate_id: String in initial_plot_ids + selected_plot_ids:
		var candidate: Dictionary = _record_by_id(snapshot.get_data().get("plots", []), candidate_id)
		if not candidate.is_empty() and _plots_adjacent(snapshot, target, candidate):
			return true
	return false


func _plots_adjacent(snapshot: ResolvedDistrictSnapshot, left: Dictionary, right: Dictionary) -> bool:
	var left_slot: Dictionary = _record_by_id(snapshot.get_data().get("slots", []), String(left.get("slot_id", "")))
	var right_slot: Dictionary = _record_by_id(snapshot.get_data().get("slots", []), String(right.get("slot_id", "")))
	if left_slot.is_empty() or right_slot.is_empty():
		return false
	var same_row: bool = String(left_slot.get("row_track_id", "")) == String(right_slot.get("row_track_id", ""))
	var same_column: bool = String(left_slot.get("column_track_id", "")) == String(right_slot.get("column_track_id", ""))
	var column_step: int = absi(_track_ordinal(String(left_slot.get("column_track_id", ""))) - _track_ordinal(String(right_slot.get("column_track_id", ""))))
	var row_step: int = absi(_track_ordinal(String(left_slot.get("row_track_id", ""))) - _track_ordinal(String(right_slot.get("row_track_id", ""))))
	return (same_row and column_step == 1) or (same_column and row_step == 1)


func _track_ordinal(track_id: String) -> int:
	var parts: PackedStringArray = track_id.split("_")
	return 0 if parts.size() < 2 else int(parts[1])


func _record_by_id(records: Array, record_id: String) -> Dictionary:
	for record: Variant in records:
		if record is Dictionary and String(record.get("id", "")) == record_id:
			return record
	return {}


func _progression_failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "diagnostics": [{"code": code, "message": message}]}


func _debug_god_mode_active() -> bool:
	if OS.has_feature("release") or not is_inside_tree():
		return false
	var debug_manager: Node = get_tree().root.get_node_or_null("DebugManager")
	return debug_manager != null and bool(debug_manager.get("god_mode"))


## Earn tech points (from PrestigeManager level-ups).
func earn_points(amount: int) -> void:
	authority_revision += 1
	available_points += amount
	total_earned += amount
	points_changed.emit(available_points, total_earned)


## Check if a node can be unlocked.
func can_unlock(node_id: String) -> bool:
	if not nodes.has(node_id):
		return false
	if unlocked.has(node_id):
		return false
	if _debug_god_mode_active():
		return true
	var node: TechNode = nodes[node_id]
	if available_points < node.cost:
		return false
	for pre: String in node.prerequisites:
		if not unlocked.has(pre):
			return false
	return true


## Unlock a tech node.
func unlock_node(node_id: String) -> bool:
	if not can_unlock(node_id):
		return false
	var node: TechNode = nodes[node_id]
	if not _debug_god_mode_active():
		available_points -= node.cost
	unlocked.append(node_id)
	authority_revision += 1
	point_spent.emit(node_id)
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.tech_point_spent.emit(node_id)
		event_bus.tech_points_changed.emit(available_points, total_earned)
	return true


func serialize() -> Dictionary:
	var snapshot: Dictionary = get_policy_snapshot()
	return {
		"unlocked": unlocked.duplicate(),
		"available_points": available_points,
		"total_earned": total_earned,
		"selected_plot_ids": selected_plot_ids.duplicate(),
		"plot_access_grants_earned": plot_access_grants_earned,
		"plot_access_grants_consumed": plot_access_grants_consumed,
		"awarded_milestone_ids": awarded_milestone_ids.duplicate(),
		"progression_revision": authority_revision,
		"content_policy_revision": int(snapshot.get("content_policy_revision", 1)),
	}


func validate_serialized_state(data: Variant) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if not data is Dictionary:
		return _progression_failure("PROGRESSION_STATE_INVALID", "progression state must be an object")
	var selected: Variant = data.get("selected_plot_ids", [])
	if not selected is Array:
		diagnostics.append({"code": "SELECTED_PLOTS_INVALID", "message": "selected Plot IDs must be an array"})
	else:
		var seen: Dictionary = {}
		for plot_id: Variant in selected:
			if typeof(plot_id) != TYPE_STRING or String(plot_id).is_empty() or seen.has(String(plot_id)):
				diagnostics.append({"code": "SELECTED_PLOTS_INVALID", "message": "selected Plot IDs must be unique non-empty strings"})
			seen[String(plot_id)] = true
		if selected.size() > MAX_ADDITIONAL_PLOTS:
			diagnostics.append({"code": "PLOT_ACCESS_EXHAUSTED", "message": "no more than eight additional Plots may be selected"})
	var consumed: int = int(data.get("plot_access_grants_consumed", selected.size()))
	if consumed < selected.size() or consumed > MAX_ADDITIONAL_PLOTS:
		diagnostics.append({"code": "PLOT_ACCESS_GRANT_COUNT_INVALID", "message": "consumed Plot Access grants must match selected Plot count"})
	if int(data.get("plot_access_grants_earned", 0)) < consumed:
		diagnostics.append({"code": "PLOT_ACCESS_GRANT_COUNT_INVALID", "message": "earned Plot Access grants cannot be below consumed grants"})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func deserialize(data: Dictionary) -> void:
	_suppress_progression_notifications = true
	var loaded_unlocked: Variant = data.get("unlocked", [])
	unlocked.clear()
	if loaded_unlocked is Array:
		for entry: Variant in loaded_unlocked:
			if typeof(entry) == TYPE_STRING:
				unlocked.append(String(entry))
	authority_revision += 1
	var loaded_points: Variant = data.get("available_points", 0)
	available_points = loaded_points
	var loaded_earned: Variant = data.get("total_earned", 0)
	total_earned = int(loaded_earned)
	selected_plot_ids.clear()
	var loaded_selected: Variant = data.get("selected_plot_ids", [])
	if loaded_selected is Array:
		for entry: Variant in loaded_selected:
			if typeof(entry) == TYPE_STRING and not selected_plot_ids.has(String(entry)):
				selected_plot_ids.append(String(entry))
	selected_plot_ids.sort()
	plot_access_grants_earned = maxi(0, int(data.get("plot_access_grants_earned", 0)))
	plot_access_grants_consumed = maxi(0, int(data.get("plot_access_grants_consumed", selected_plot_ids.size())))
	var loaded_milestones: Variant = data.get("awarded_milestone_ids", [])
	awarded_milestone_ids.clear()
	if loaded_milestones is Array:
		for entry: Variant in loaded_milestones:
			if typeof(entry) == TYPE_STRING and not awarded_milestone_ids.has(String(entry)):
				awarded_milestone_ids.append(String(entry))
	awarded_milestone_ids.sort()
	_suppress_progression_notifications = false
	progression_changed.emit(get_policy_snapshot())
