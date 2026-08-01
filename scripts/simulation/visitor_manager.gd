## VisitorManager — Centralized visitor lifecycle, tick handling, generation, and culling.
##
## All visitors exist in all_visitors regardless of visibility.
## Visual Node3Ds are created/destroyed based on floor-based culling rules.
## Uses StateMachine framework (Phase 0) for visitor state management.
class_name VisitorManager
extends Node


## All visitors, visible or not.
var all_visitors: Array[VisitorData] = []

## Visitor ID counter.
var _visitor_counter: int = 0

## Current floor (from CameraManager) for culling.
var _current_floor: String = "G"

## Current zoom level (from CameraManager) for culling.
var _current_zoom: float = 20.0

## Zoom threshold: hide all visitors when zoomed past this.
const ZOOM_HIDE_THRESHOLD: float = 35.0

## Max visitors to generate per tick.
const MAX_SPAWN_PER_TICK: int = 3

## Max total visible visitors.
const MAX_VISIBLE_VISITORS: int = 60

## Visitor spawn position (near plot edges).
var _spawn_positions: Array[Vector3] = []

## Pathfinding graph reference.
var _pathfinding_graph: PathfindingGraph

## Shared material for all visitor meshes (1 draw call).
var _shared_material: ShaderMaterial

## Visitor scene reference.
var _visitor_scene: PackedScene


func _ready() -> void:
	_generate_spawn_positions()


func _generate_spawn_positions() -> void:
	# Spawn visitors at the edges of the 25×25 grid.
	for i in range(4):
		_spawn_positions.append(Vector3(i * 6 + 3, 0, -2))  # North edge
		_spawn_positions.append(Vector3(i * 6 + 3, 0, 27))  # South edge
		_spawn_positions.append(Vector3(-2, 0, i * 6 + 3))  # West edge
		_spawn_positions.append(Vector3(27, 0, i * 6 + 3))  # East edge


# ── Tick Handler ───────────────────────────────────────────────────────

## Called by TimeManager on each visitor_tick (every 5 sim seconds).
func on_visitor_tick() -> void:
	_decay_visitor_needs()
	_generate_visitors()
	_update_visitor_decisions()
	_apply_culling()


## Decay needs for all visitors.
func _decay_visitor_needs() -> void:
	for v: VisitorData in all_visitors:
		v.decay_needs()


## Generate new visitors (spawn rate based on zone count).
func _generate_visitors() -> void:
	if all_visitors.size() >= MAX_VISIBLE_VISITORS * 2:
		return  # Cap total population.

	var spawn_count := randi_range(0, MAX_SPAWN_PER_TICK)
	for i in range(spawn_count):
		var visitor := VisitorData.new()
		visitor.initialize(_next_id(), _current_floor, _spawn_positions[randi() % _spawn_positions.size()])
		all_visitors.append(visitor)
		EventBus.visitor_entered.emit(visitor.id)


## Update visitor decisions (goal selection, pathfinding).
func _update_visitor_decisions() -> void:
	for v: VisitorData in all_visitors:
		if v.current_state == "entering":
			v.current_state = "setting_goals"
		elif v.current_state == "setting_goals":
			# Assign a random destination from zone data.
			_assign_visitor_goal(v, v.current_state)
		elif v.current_state == "moving":
			# Interpolate position toward target.
			_move_visitor_toward_target(v)


## Assign a goal to a visitor based on their needs.
func _assign_visitor_goal(visitor: VisitorData, _state: String) -> void:
	# For MVP: wander toward center of the grid.
	var random_target := Vector3(
		randf_range(5, 45),
		0,
		randf_range(5, 45)
	)
	visitor.target_position = random_target
	visitor.current_state = "moving"


## Move visitor toward their target (simple interpolation).
func _move_visitor_toward_target(visitor: VisitorData, speed: float = 2.0) -> void:
	var dist := visitor.position.distance_to(visitor.target_position)
	if dist < 0.5:
		# Arrived — decide next action.
		if visitor.goal_queue.is_empty():
			if randf() < 0.1:  # 10% chance to leave each tick after goals done.
				visitor.current_state = "leaving"
			else:
				var random_target := Vector3(randf_range(5, 45), 0, randf_range(5, 45))
				visitor.target_position = random_target
		return

	visitor.position = visitor.position.move_toward(visitor.target_position, speed * 5.0 * 0.1)


# ── Culling ────────────────────────────────────────────────────────────

## Apply floor-based and zoom-based culling.
func _apply_culling() -> void:
	var zoom_hide := _current_zoom > ZOOM_HIDE_THRESHOLD

	for v: VisitorData in all_visitors:
		var should_show := not zoom_hide and v.floor_level == _current_floor

		if should_show and not v.is_visible:
			_show_visitor(v)
		elif not should_show and v.is_visible:
			_hide_visitor(v)


## Create a visual Node3D for a visitor.
func _show_visitor(visitor: VisitorData) -> void:
	if visitor.visual_node:
		return

	var node := _get_visitor_scene().instantiate() as Node3D
	node.name = visitor.id
	node.position = visitor.position
	add_child(node)

	visitor.visual_node = node
	visitor.is_visible = true


## Remove the visual Node3D (keep data).
func _hide_visitor(visitor: VisitorData) -> void:
	if visitor.visual_node:
		visitor.visual_node.queue_free()
		visitor.visual_node = null
	visitor.is_visible = false


## Load or create the visitor scene template.
func _get_visitor_scene() -> PackedScene:
	if _visitor_scene:
		return _visitor_scene
	# Create a simple visitor scene programmatically.
	var scene := PackedScene.new()
	var root := Node3D.new()
	root.name = "Visitor"

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 1.8, 0.6)
	mesh.mesh = box
	root.add_child(mesh)

	scene.pack(root)
	_visitor_scene = scene
	return _visitor_scene


# ── Camera Integration ─────────────────────────────────────────────────

## Called when camera changes floor.
func on_floor_changed(floor_level: String) -> void:
	_current_floor = floor_level
	# Hide all current visuals, show new floor's visitors.
	for v: VisitorData in all_visitors:
		_hide_visitor(v)
	_apply_culling()


## Called when camera zoom changes.
func on_zoom_changed(zoom: float) -> void:
	_current_zoom = zoom
	_apply_culling()


# ── Lifecycle ──────────────────────────────────────────────────────────

## Remove a visitor and their visual node.
func remove_visitor(visitor_id: String) -> void:
	for i in range(all_visitors.size() - 1, -1, -1):
		if all_visitors[i].id == visitor_id:
			_hide_visitor(all_visitors[i])
			EventBus.visitor_left.emit(visitor_id, all_visitors[i].satisfaction)
			all_visitors.remove_at(i)
			break


## Clean up leaving visitors.
func _process_leaving_visitors() -> void:
	for i in range(all_visitors.size() - 1, -1, -1):
		if all_visitors[i].current_state == "leaving":
			if randi() % 3 == 0:  # Gradual removal.
				remove_visitor(all_visitors[i].id)


# ── Helper ─────────────────────────────────────────────────────────────

func _next_id() -> String:
	_visitor_counter += 1
	return "visitor_%d" % _visitor_counter


# ── Serialization ──────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var data: Array[Dictionary] = []
	for v: VisitorData in all_visitors:
		data.append({
			"id": v.id,
			"position": {"x": v.position.x, "y": v.position.y, "z": v.position.z},
			"floor_level": v.floor_level,
			"current_state": v.current_state,
			"budget": v.budget,
			"satisfaction": v.satisfaction,
		})
	return {"visitors": data, "counter": _visitor_counter}


func deserialize(data: Dictionary) -> void:
	all_visitors.clear()
	_visitor_counter = data.get("counter", 0)
	for v_data: Dictionary in data.get("visitors", []):
		var v := VisitorData.new()
		v.id = v_data["id"]
		v.position = Vector3(v_data["position"]["x"], v_data["position"]["y"], v_data["position"]["z"])
		v.floor_level = v_data.get("floor_level", "G")
		v.current_state = v_data.get("current_state", "moving")
		v.budget = v_data.get("budget", 0)
		v.satisfaction = v_data.get("satisfaction", 50)
		all_visitors.append(v)
