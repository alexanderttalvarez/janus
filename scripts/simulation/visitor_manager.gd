## VisitorManager — Centralized visitor lifecycle, tick handling, and culling.
##
## The first visitor iteration creates a small random population on the
## pedestrian ring and advances each visitor around its perimeter. Interior
## entry, goals, and pathfinding remain future iterations.
class_name VisitorManager
extends Node


## All visitors, visible or not.
var all_visitors: Array[VisitorData] = []

## Visitor ID counter.
var _visitor_counter: int = 0

## Current floor for culling.
var _current_floor: String = "G"

## Current zoom level for culling.
var _current_zoom: float = 20.0

## Hide visitors when zoomed farther out than this threshold.
const ZOOM_HIDE_THRESHOLD: float = 35.0

## Initial population bounds for the exterior visitor iteration.
const INITIAL_VISITOR_MIN: int = 5
const INITIAL_VISITOR_MAX: int = 20

## Maximum visible visitor Node3Ds supported by the architecture.
const MAX_VISIBLE_VISITORS: int = 60


var _pedestrian_area: PedestrianArea
var _visual_container: Node3D
var _grid_manager: GridManager
var _pathfinding_graph: PathfindingGraph
var _visitor_scene: PackedScene


func _ready() -> void:
	_pedestrian_area = get_tree().get_first_node_in_group("pedestrian_walkable") as PedestrianArea
	_visual_container = get_tree().current_scene.get_node_or_null("World/Visitors") as Node3D

	if _pedestrian_area == null:
		push_error("VisitorManager: PedestrianArea walkable marker not found.")
		return
	if _visual_container == null:
		push_error("VisitorManager: World/Visitors visual container not found.")
		return

	_generate_initial_visitors()
	_apply_culling()


## Create the initial small exterior population once per game session.
func _generate_initial_visitors() -> void:
	if not all_visitors.is_empty():
		return

	var visitor_count := randi_range(INITIAL_VISITOR_MIN, INITIAL_VISITOR_MAX)
	for _i in range(visitor_count):
		_create_pedestrian_visitor()


func _create_pedestrian_visitor() -> void:
	var waypoint_count := _pedestrian_area.get_waypoint_count()
	if waypoint_count <= 0:
		return

	var visitor := VisitorData.new()
	visitor.initialize(_next_id(), "G", Vector3.ZERO)
	visitor.location_type = "pedestrian_area"
	visitor.waypoint_index = randi_range(0, waypoint_count - 1)
	visitor.position = _pedestrian_area.get_waypoint(visitor.waypoint_index)
	visitor.target_position = visitor.position
	visitor.current_state = "moving"
	all_visitors.append(visitor)
	EventBus.visitor_entered.emit(visitor.id)

	_set_next_pedestrian_target(visitor)


## Called by TimeManager on each visitor_tick.
func on_visitor_tick() -> void:
	_decay_visitor_needs()
	_sync_data_positions()
	_apply_culling()


## Decay needs for all visitors.
func _decay_visitor_needs() -> void:
	for visitor: VisitorData in all_visitors:
		visitor.decay_needs()


## Keep serialized visitor positions current without owning visual movement.
func _sync_data_positions() -> void:
	for visitor: VisitorData in all_visitors:
		if visitor.is_visible and is_instance_valid(visitor.visual_node):
			visitor.position = visitor.visual_node.global_position


## Advance a visitor to the next waypoint on the pedestrian ring.
func _set_next_pedestrian_target(visitor: VisitorData) -> void:
	if _pedestrian_area == null:
		return

	visitor.waypoint_index = _pedestrian_area.get_next_waypoint_index(visitor.waypoint_index)
	visitor.target_position = _pedestrian_area.get_waypoint(visitor.waypoint_index)
	visitor.current_state = "moving"
	if visitor.is_visible and is_instance_valid(visitor.visual_node):
		var visual := visitor.visual_node as Visitor
		if visual:
			visual.set_target(visitor.target_position)


## Send a visitor through the next fixed exterior door into the building.
func _begin_visitor_entry(visitor: VisitorData, side: int) -> void:
	if _grid_manager == null:
		_set_next_pedestrian_target(visitor)
		return

	var interior_pos := _get_door_interior_position(side)
	if not _grid_manager.is_walkable(interior_pos.x, interior_pos.y):
		_set_next_pedestrian_target(visitor)
		return

	visitor.entry_door_side = int(side)
	visitor.current_state = "entering"
	visitor.target_position = _grid_manager.grid_to_world(interior_pos.x, interior_pos.y, GridManager.GROUND_FLOOR)
	if visitor.is_visible and is_instance_valid(visitor.visual_node):
		var visual := visitor.visual_node as Visitor
		if visual:
			visual.set_target(visitor.target_position)


func _on_visitor_target_reached(visitor: VisitorData) -> void:
	if not all_visitors.has(visitor):
		return
	if visitor.current_state == "entering":
		visitor.location_type = "building"
		visitor.current_state = "inside_wandering"
		_set_interior_target(visitor)
		return
	if visitor.location_type == "building":
		_set_interior_target(visitor)
		return

	var door_side := _get_door_side_for_waypoint(visitor.waypoint_index)
	if door_side != 0:
		_begin_visitor_entry(visitor, door_side)
	else:
		_set_next_pedestrian_target(visitor)


func _set_interior_target(visitor: VisitorData) -> void:
	if _grid_manager == null:
		return
	var floor_grid := _grid_manager.get_floor_grid(GridManager.DEFAULT_PLOT, GridManager.GROUND_FLOOR)
	if floor_grid == null:
		return
	var x := randi_range(1, maxi(1, floor_grid.width - 2))
	var y := randi_range(1, maxi(1, floor_grid.height - 2))
	visitor.current_state = "inside_wandering"
	visitor.target_position = _grid_manager.grid_to_world(x, y, GridManager.GROUND_FLOOR)
	if visitor.is_visible and is_instance_valid(visitor.visual_node):
		var visual := visitor.visual_node as Visitor
		if visual:
			visual.set_target(visitor.target_position)


func _get_door_side_for_waypoint(waypoint_index: int) -> int:
	if _pedestrian_area == null:
		return 0
	for side: int in [
		GridTile.DoorSide.NORTH, GridTile.DoorSide.SOUTH,
		GridTile.DoorSide.EAST, GridTile.DoorSide.WEST
	]:
		if waypoint_index == _pedestrian_area.get_door_waypoint_index(side):
			return side
	return 0


func _get_door_interior_position(side: int) -> Vector2i:
	match side:
		GridTile.DoorSide.NORTH:
			return Vector2i(12, 0)
		GridTile.DoorSide.SOUTH:
			return Vector2i(12, 24)
		GridTile.DoorSide.EAST:
			return Vector2i(24, 12)
		GridTile.DoorSide.WEST:
			return Vector2i(0, 12)
	return Vector2i.ZERO



# ── Culling ────────────────────────────────────────────────────────────

## Apply floor-based and zoom-based culling.
func _apply_culling() -> void:
	var zoom_hide := _current_zoom > ZOOM_HIDE_THRESHOLD
	for visitor: VisitorData in all_visitors:
		var should_show := not zoom_hide and _is_visible_on_current_view(visitor)
		if should_show and not visitor.is_visible:
			_show_visitor(visitor)
		elif not should_show and visitor.is_visible:
			_hide_visitor(visitor)


func _is_visible_on_current_view(visitor: VisitorData) -> bool:
	if visitor.location_type == "pedestrian_area":
		return _current_floor == "G"
	return visitor.floor_level == _current_floor


## Create the reusable visual scene for a visitor.
func _show_visitor(visitor: VisitorData) -> void:
	if visitor.visual_node or _visual_container == null:
		return

	var node := _get_visitor_scene().instantiate() as Visitor
	if node == null:
		return
	_visual_container.add_child(node)
	node.global_position = visitor.position
	node.target_reached.connect(_on_visitor_target_reached.bind(visitor))
	node.set_target(visitor.target_position)

	visitor.visual_node = node
	visitor.is_visible = true


## Remove only the visual node; simulation data remains.
func _hide_visitor(visitor: VisitorData) -> void:
	if visitor.visual_node and is_instance_valid(visitor.visual_node):
		visitor.visual_node.queue_free()
	visitor.visual_node = null
	visitor.is_visible = false


## Load the dedicated visitor scene.
func _get_visitor_scene() -> PackedScene:
	if _visitor_scene:
		return _visitor_scene
	_visitor_scene = load("res://scenes/characters/visitor.tscn") as PackedScene
	if _visitor_scene == null:
		push_error("VisitorManager: Cannot load scenes/characters/visitor.tscn.")
	return _visitor_scene


# ── Camera Integration ─────────────────────────────────────────────────

## Called when camera changes floor.
func on_floor_changed(floor_level: String) -> void:
	_current_floor = floor_level
	for visitor: VisitorData in all_visitors:
		_hide_visitor(visitor)
	_apply_culling()


## Called when camera zoom changes.
func on_zoom_changed(zoom: float) -> void:
	_current_zoom = zoom
	_apply_culling()


# ── Lifecycle ──────────────────────────────────────────────────────────

## Remove a visitor and their visual node.
func remove_visitor(visitor_id: String) -> void:
	for index in range(all_visitors.size() - 1, -1, -1):
		if all_visitors[index].id == visitor_id:
			var visitor := all_visitors[index]
			_hide_visitor(visitor)
			EventBus.visitor_left.emit(visitor_id, visitor.satisfaction)
			all_visitors.remove_at(index)
			break


# ── Helpers ────────────────────────────────────────────────────────────

func _next_id() -> String:
	_visitor_counter += 1
	return "visitor_%d" % _visitor_counter


# ── Serialization ──────────────────────────────────────────────────────

func serialize() -> Dictionary:
	_sync_data_positions()
	var data: Array[Dictionary] = []
	for visitor: VisitorData in all_visitors:
		data.append({
			"id": visitor.id,
			"position": {"x": visitor.position.x, "y": visitor.position.y, "z": visitor.position.z},
			"floor_level": visitor.floor_level,
			"location_type": visitor.location_type,
			"entry_door_side": visitor.entry_door_side,
			"waypoint_index": visitor.waypoint_index,
			"current_state": visitor.current_state,
			"budget": visitor.budget,
			"satisfaction": visitor.satisfaction,
		})
	return {"visitors": data, "counter": _visitor_counter}


func deserialize(data: Dictionary) -> void:
	for visitor: VisitorData in all_visitors:
		_hide_visitor(visitor)
	all_visitors.clear()
	_visitor_counter = data.get("counter", 0)

	for visitor_data: Dictionary in data.get("visitors", []):
		var visitor := VisitorData.new()
		visitor.id = visitor_data.get("id", _next_id())
		var position_data: Dictionary = visitor_data.get("position", {})
		visitor.position = Vector3(
			position_data.get("x", 0.0),
			position_data.get("y", 0.0),
			position_data.get("z", 0.0)
		)
		visitor.floor_level = visitor_data.get("floor_level", "G")
		visitor.location_type = visitor_data.get("location_type", "pedestrian_area")
		visitor.entry_door_side = visitor_data.get("entry_door_side", 0)
		visitor.waypoint_index = visitor_data.get("waypoint_index", 0)
		visitor.current_state = visitor_data.get("current_state", "moving")
		visitor.budget = visitor_data.get("budget", 0)
		visitor.satisfaction = visitor_data.get("satisfaction", 50)
		visitor.target_position = _pedestrian_area.get_waypoint(visitor.waypoint_index) if _pedestrian_area else visitor.position
		all_visitors.append(visitor)

	_apply_culling()
