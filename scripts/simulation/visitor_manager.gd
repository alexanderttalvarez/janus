## VisitorManager — Centralized visitor lifecycle, tick handling, and culling.
##
## Visitors spawn from plot-owned corner spawn points and advance through the
## pedestrian ring into the building. The manager owns lifecycle and culling;
## plot geometry owns spawn-point definitions.
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

## Maximum active visitors for the current MVP.
const MAX_VISITORS: int = 20

## One spawn attempt per five-second visitor tick.
const SPAWN_PER_TICK: int = 1

## Maximum visible visitor Node3Ds supported by the architecture.
const MAX_VISIBLE_VISITORS: int = 60

## Visitors are dimmed while the player is in Building mode.
const BUILDING_MODE_VISITOR_OPACITY: float = 0.5


var _pedestrian_area: PedestrianArea
var _visual_container: Node3D
var _grid_manager: GridManager
var _pathfinding_graph: PathfindingGraph
var _visitor_scene: PackedScene
var _visitor_mode_opacity: float = 1.0


func _ready() -> void:
	_pedestrian_area = get_tree().get_first_node_in_group("pedestrian_walkable") as PedestrianArea
	_visual_container = get_tree().current_scene.get_node_or_null("World/Visitors") as Node3D

	if _pedestrian_area == null:
		push_error("VisitorManager: PedestrianArea walkable marker not found.")
		return
	if _visual_container == null:
		push_error("VisitorManager: World/Visitors visual container not found.")
		return

	GameManager.ui_mode_changed.connect(_on_ui_mode_changed)
	EventBus.zone_created.connect(_on_zone_created)
	EventBus.zone_modified.connect(_on_zone_modified)
	EventBus.door_changed.connect(_on_door_changed)
	_visitor_mode_opacity = _get_mode_visitor_opacity()
	_apply_culling()


## Called by TimeManager on each visitor_tick.
func on_visitor_tick() -> void:
	_spawn_visitors_if_needed()
	_decay_visitor_needs()
	_sync_data_positions()
	_apply_culling()


## Spawn at most one visitor per tick until the active population reaches 20.
func _spawn_visitors_if_needed() -> void:
	if _grid_manager == null or all_visitors.size() >= MAX_VISITORS:
		return
	for _i in range(SPAWN_PER_TICK):
		if all_visitors.size() >= MAX_VISITORS:
			break
		_spawn_visitor_at_plot_spawn_point()


func _spawn_visitor_at_plot_spawn_point() -> void:
	var spawn_points := _grid_manager.get_spawn_points(GridManager.DEFAULT_PLOT)
	if spawn_points.is_empty():
		return
	var point: Dictionary = spawn_points[randi_range(0, spawn_points.size() - 1)]
	var spawn_position: Vector3 = point.get("position", Vector3.ZERO)
	var visitor := VisitorData.new()
	visitor.initialize(_next_id(), "G", spawn_position)
	visitor.location_type = "pedestrian_area"
	visitor.spawn_point_id = point.get("id", "")
	visitor.waypoint_index = _pedestrian_area.get_nearest_waypoint_index(spawn_position)
	visitor.position = spawn_position
	visitor.target_position = _pedestrian_area.get_waypoint(visitor.waypoint_index)
	visitor.current_state = "moving"
	all_visitors.append(visitor)
	EventBus.visitor_entered.emit(visitor.id)



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
	var exterior_pos := _get_door_exterior_position(side)
	if not _grid_manager.has_door_between(interior_pos, exterior_pos):
		_set_next_pedestrian_target(visitor)
		return
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
	# The visual node reaches the target between simulation ticks. Keep the
	# serialized position synchronized before choosing the next grid path.
	visitor.position = visitor.target_position
	if visitor.current_state == "leaving":
		remove_visitor(visitor.id)
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
		if _is_exterior_door_open(door_side):
			_begin_visitor_entry(visitor, door_side)
		else:
			_set_next_pedestrian_target(visitor)
	else:
		_set_next_pedestrian_target(visitor)


func _set_interior_target(visitor: VisitorData) -> void:
	if _grid_manager == null:
		return
	var floor_grid := _grid_manager.get_floor_grid(GridManager.DEFAULT_PLOT, GridManager.GROUND_FLOOR)
	if floor_grid == null:
		return

	var start_pos := _grid_manager.world_to_grid(visitor.position)
	for _attempt in range(24):
		var target_pos := Vector2i(
			randi_range(1, maxi(1, floor_grid.width - 2)),
			randi_range(1, maxi(1, floor_grid.height - 2))
		)
		var target_tile := floor_grid.get_tile(target_pos.x, target_pos.y)
		if target_tile == null or not floor_grid.is_walkable(target_pos.x, target_pos.y) or not target_tile.zone_id.is_empty():
			continue
		var grid_path := _find_floor_path(floor_grid, start_pos, target_pos)
		if grid_path.size() < 2:
			continue
		var world_path: Array[Vector3] = []
		for index in range(1, grid_path.size()):
			var grid_pos: Vector2i = grid_path[index]
			world_path.append(_grid_manager.grid_to_world(grid_pos.x, grid_pos.y, GridManager.GROUND_FLOOR))
		visitor.current_state = "inside_wandering"
		visitor.target_position = world_path[world_path.size() - 1]
		if visitor.is_visible and is_instance_valid(visitor.visual_node):
			var visual := visitor.visual_node as Visitor
			if visual:
				visual.set_path(world_path)
		return


func _find_floor_path(floor_grid: FloorGrid, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if not floor_grid.is_walkable(start.x, start.y) or not floor_grid.is_walkable(goal.x, goal.y):
		return []
	var queue: Array[Vector2i] = [start]
	var queue_index: int = 0
	var visited: Dictionary = {start: true}
	var came_from: Dictionary = {}
	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1
		if current == goal:
			break
		for neighbor: Vector2i in floor_grid.get_walkable_neighbors(current.x, current.y):
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			came_from[neighbor] = current
			queue.append(neighbor)
	if not visited.has(goal):
		return []
	var path: Array[Vector2i] = [goal]
	var current_pos := goal
	while current_pos != start:
		current_pos = came_from[current_pos]
		path.push_front(current_pos)
	return path


func _on_zone_created(zone_id: String, _zone_type: String, _tile_count: int) -> void:
	_on_zone_changed(zone_id)


func _on_zone_modified(zone_id: String) -> void:
	_on_zone_changed(zone_id)


## Remove visitors occupying a newly walled zone and repath remaining visitors.
func _on_door_changed(from: Vector2i, to: Vector2i, enabled: bool) -> void:
	var exterior_side := _get_exterior_door_side(from, to)
	if exterior_side != 0:
		if not enabled:
			_redirect_visitors_from_closed_door(exterior_side)
		return
	# Internal door changes need building visitors to receive fresh routes, but
	# that work is deferred so the placement/removal click remains responsive.
	call_deferred("_repath_visitors_after_door_change")


func _redirect_visitors_from_closed_door(side: int) -> void:
	for visitor: VisitorData in all_visitors:
		var heading_to_door := visitor.location_type == "pedestrian_area" and (
			visitor.current_state == "entering" or visitor.waypoint_index == _pedestrian_area.get_door_waypoint_index(side)
		)
		if not heading_to_door:
			continue
		if visitor.is_visible and is_instance_valid(visitor.visual_node):
			var visual := visitor.visual_node as Visitor
			if visual:
				visual.clear_target()
		_set_next_pedestrian_target(visitor)


func _repath_visitors_after_door_change() -> void:
	_sync_data_positions()
	for visitor: VisitorData in all_visitors:
		if visitor.current_state == "leaving":
			continue
		if visitor.is_visible and is_instance_valid(visitor.visual_node):
			var visual := visitor.visual_node as Visitor
			if visual:
				visual.clear_target()
		if visitor.current_state == "entering":
			_set_next_pedestrian_target(visitor)
		elif visitor.location_type == "building":
			_set_interior_target(visitor)


func _on_zone_changed(zone_id: String) -> void:
	if _grid_manager == null:
		return
	var zone_manager := get_tree().current_scene.get_node_or_null("World/ZoneManager") as ZoneManager
	if zone_manager == null:
		return
	var zone: ZoneData = zone_manager.zones.get(zone_id, null)
	if zone == null:
		return
	_sync_data_positions()
	var remove_ids: Array[String] = []
	for visitor: VisitorData in all_visitors:
		if visitor.floor_level != zone.floor:
			continue
		var current_tile := _grid_manager.world_to_grid(visitor.position)
		var target_tile := _grid_manager.world_to_grid(visitor.target_position)
		if zone.tiles.has(current_tile) or zone.tiles.has(target_tile):
			remove_ids.append(visitor.id)
		elif visitor.location_type == "building":
			_set_interior_target(visitor)
	for visitor_id: String in remove_ids:
		remove_visitor(visitor_id)


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


func _is_exterior_door_open(side: int) -> bool:
	if _grid_manager == null:
		return false
	return _grid_manager.has_door_between(_get_door_interior_position(side), _get_door_exterior_position(side))


func _get_door_exterior_position(side: int) -> Vector2i:
	match side:
		GridTile.DoorSide.NORTH:
			return Vector2i(12, -1)
		GridTile.DoorSide.SOUTH:
			return Vector2i(12, 25)
		GridTile.DoorSide.EAST:
			return Vector2i(25, 12)
		GridTile.DoorSide.WEST:
			return Vector2i(-1, 12)
	return Vector2i.ZERO


func _get_exterior_door_side(from: Vector2i, to: Vector2i) -> int:
	var exterior := to if _grid_manager.get_tile(to.x, to.y) == null else from
	if _grid_manager.get_tile(exterior.x, exterior.y) != null:
		return 0
	if exterior.y < 0:
		return GridTile.DoorSide.NORTH
	if exterior.y >= 25:
		return GridTile.DoorSide.SOUTH
	if exterior.x < 0:
		return GridTile.DoorSide.WEST
	if exterior.x >= 25:
		return GridTile.DoorSide.EAST
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

func _get_mode_visitor_opacity() -> float:
	return BUILDING_MODE_VISITOR_OPACITY if GameManager.ui_mode == GameManager.UIMode.BUILD else 1.0


func _on_ui_mode_changed(_mode: String) -> void:
	_visitor_mode_opacity = _get_mode_visitor_opacity()
	for visitor: VisitorData in all_visitors:
		if visitor.is_visible and is_instance_valid(visitor.visual_node):
			var visual := visitor.visual_node as Visitor
			if visual:
				visual.set_mode_opacity(_visitor_mode_opacity)


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
	node.set_mode_opacity(_visitor_mode_opacity, 0.0)
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

## Request a voluntary exit through a selected plot spawn point.
func request_visitor_leave(visitor_id: String, spawn_point_id: String = "") -> void:
	var spawn_points := _grid_manager.get_spawn_points(GridManager.DEFAULT_PLOT) if _grid_manager else []
	for visitor: VisitorData in all_visitors:
		if visitor.id != visitor_id or visitor.current_state == "leaving":
			continue
		var point: Dictionary = {}
		if spawn_point_id.is_empty() and not spawn_points.is_empty():
			point = spawn_points[randi_range(0, spawn_points.size() - 1)]
		else:
			for candidate: Dictionary in spawn_points:
				if candidate.get("id", "") == spawn_point_id:
					point = candidate
					break
		if point.is_empty():
			return
		visitor.spawn_point_id = point.get("id", "")
		visitor.current_state = "leaving"
		visitor.target_position = point.get("position", visitor.position)
		if visitor.is_visible and is_instance_valid(visitor.visual_node):
			var visual := visitor.visual_node as Visitor
			if visual:
				visual.set_target(visitor.target_position)
		return


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
			"spawn_point_id": visitor.spawn_point_id,
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
		visitor.spawn_point_id = visitor_data.get("spawn_point_id", "")
		visitor.waypoint_index = visitor_data.get("waypoint_index", 0)
		visitor.current_state = visitor_data.get("current_state", "moving")
		visitor.budget = visitor_data.get("budget", 0)
		visitor.satisfaction = visitor_data.get("satisfaction", 50)
		visitor.target_position = _pedestrian_area.get_waypoint(visitor.waypoint_index) if _pedestrian_area else visitor.position
		all_visitors.append(visitor)

	_apply_culling()
