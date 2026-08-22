## TrafficManager — Simulates traffic on the authored two-way road layout.
##
## Each lane is straight and independent. Cars use longitudinal lane distance
## instead of physics bodies, which guarantees safe same-lane following without
## requiring collision shapes or navigation meshes.
class_name TrafficManager
extends Node3D


signal car_spawned(lane_id: StringName, car_id: int)
signal car_despawned(lane_id: StringName, car_id: int)
signal crosswalk_hold_started(crosswalk_id: StringName, car_id: int)
signal crosswalk_hold_finished(crosswalk_id: StringName, car_id: int)


const CAR_SCENE_PATH: String = "res://assets/models/kenney_car_kit/sedan.glb"
const CROSSWALK_APPROACHING: int = 0
const CROSSWALK_HOLDING: int = 1
const CROSSWALK_CLEARED: int = 2

const LANE_IDS: Array = [
	&"Lane_North_Eastbound",
	&"Lane_North_Westbound",
	&"Lane_East_Southbound",
	&"Lane_East_Northbound",
	&"Lane_South_Westbound",
	&"Lane_South_Eastbound",
	&"Lane_West_Northbound",
	&"Lane_West_Southbound",
]

const LANE_CROSSWALKS: Dictionary = {
	&"Lane_North_Eastbound": &"Crosswalk_North",
	&"Lane_North_Westbound": &"Crosswalk_North",
	&"Lane_East_Southbound": &"Crosswalk_East",
	&"Lane_East_Northbound": &"Crosswalk_East",
	&"Lane_South_Westbound": &"Crosswalk_South",
	&"Lane_South_Eastbound": &"Crosswalk_South",
	&"Lane_West_Northbound": &"Crosswalk_West",
	&"Lane_West_Southbound": &"Crosswalk_West",
}

const BODY_COLORS: Array = [
	Color(0.78, 0.12, 0.06),
	Color(0.06, 0.27, 0.72),
	Color(0.06, 0.48, 0.24),
	Color(0.82, 0.58, 0.05),
]
const WHEEL_COLOR: Color = Color(0.025, 0.03, 0.035)


class CarState:
	var id: int = 0
	var node: Node3D
	var distance: float = 0.0
	var speed: float = 0.0
	var desired_speed: float = 0.0
	var crosswalk_phase: int = CROSSWALK_APPROACHING
	var hold_remaining: float = 0.0


class LaneState:
	var id: StringName
	var crosswalk_id: StringName
	var spawn: Marker3D
	var stop_line: Marker3D
	var exit: Marker3D
	var start_position: Vector3
	var direction: Vector3
	var length: float = 0.0
	var stop_distance: float = 0.0
	var next_spawn_time: float = 0.0
	var cars: Array[CarState] = []


@export_category("Spawning")
@export var traffic_enabled: bool = true
@export_range(1, 48, 1) var max_active_cars: int = 16
@export_range(1.0, 30.0, 0.1) var spawn_interval_min: float = 5.0
@export_range(1.0, 30.0, 0.1) var spawn_interval_max: float = 12.0
@export_range(0.1, 5.0, 0.1) var spawn_retry_min: float = 0.5
@export_range(0.1, 5.0, 0.1) var spawn_retry_max: float = 1.5
@export_range(1.0, 20.0, 0.1) var spawn_clearance: float = 7.0
@export var random_seed: int = 0

@export_category("Driving")
@export_range(1.0, 20.0, 0.1) var cruise_speed_min: float = 4.2
@export_range(1.0, 20.0, 0.1) var cruise_speed_max: float = 5.5
@export_range(0.1, 20.0, 0.1) var acceleration: float = 1.8
@export_range(0.1, 20.0, 0.1) var braking_deceleration: float = 3.0
@export_range(0.1, 10.0, 0.1) var standstill_gap: float = 2.5
@export_range(0.1, 5.0, 0.1) var time_headway: float = 1.2
@export_range(0.1, 5.0, 0.1) var crosswalk_hold_min: float = 1.5
@export_range(0.1, 5.0, 0.1) var crosswalk_hold_max: float = 3.0
@export_range(0.1, 3.0, 0.1) var fade_in_duration: float = 1.0
@export var mandatory_crosswalk_stops: bool = true

@onready var _active_cars: Node3D = $ActiveCars
@onready var _lanes_root: Node3D = get_node_or_null("../TrafficLayout/Lanes") as Node3D

var _car_scene: PackedScene
var _lanes: Array[LaneState] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _simulation_time: float = 0.0
var _next_car_id: int = 1
var _crosswalk_stop_requests: Dictionary = {}


func _ready() -> void:
	_car_scene = load(CAR_SCENE_PATH) as PackedScene
	if _car_scene == null:
		push_error("TrafficManager could not load car scene: " + CAR_SCENE_PATH)
		set_physics_process(false)
		return
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	if not _initialize_lanes():
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not traffic_enabled:
		return
	_simulation_time += delta
	for lane: LaneState in _lanes:
		_update_lane(lane, delta)
	_spawn_due_cars()


## Enable or disable the traffic simulation. Disabling removes active cars.
func set_enabled(enabled: bool) -> void:
	traffic_enabled = enabled
	if not traffic_enabled:
		clear_active_cars()


## Scale future randomized arrival intervals without changing current cars.
func set_arrival_rate_multiplier(multiplier: float) -> void:
	var safe_multiplier := maxf(multiplier, 0.01)
	for lane: LaneState in _lanes:
		lane.next_spawn_time = _simulation_time + _random_spawn_interval() / safe_multiplier


## Future pedestrian systems can request a stop for a specific crosswalk.
## Mandatory timed stops remain enabled by default for the current presentation.
func set_crosswalk_stop_requested(crosswalk_id: StringName, requested: bool) -> void:
	_crosswalk_stop_requests[crosswalk_id] = requested


func clear_active_cars() -> void:
	for lane: LaneState in _lanes:
		for car: CarState in lane.cars:
			if is_instance_valid(car.node):
				car.node.queue_free()
		lane.cars.clear()


func get_active_car_count() -> int:
	var total: int = 0
	for lane: LaneState in _lanes:
		total += lane.cars.size()
	return total


func _initialize_lanes() -> bool:
	if _lanes_root == null:
		push_error("TrafficManager requires World/TrafficLayout/Lanes")
		return false
	for lane_id: StringName in LANE_IDS:
		var lane_node := _lanes_root.get_node_or_null(String(lane_id)) as Node3D
		if lane_node == null:
			push_error("TrafficManager lane is missing: " + String(lane_id))
			return false
		var lane := LaneState.new()
		lane.id = lane_id
		lane.crosswalk_id = LANE_CROSSWALKS[lane_id] as StringName
		lane.spawn = lane_node.get_node_or_null("Spawn") as Marker3D
		lane.stop_line = lane_node.get_node_or_null("StopLine") as Marker3D
		lane.exit = lane_node.get_node_or_null("Exit") as Marker3D
		if lane.spawn == null or lane.stop_line == null or lane.exit == null:
			push_error("TrafficManager lane markers are incomplete: " + String(lane_id))
			return false
		lane.start_position = lane.spawn.global_position
		var route := lane.exit.global_position - lane.start_position
		lane.length = route.length()
		if lane.length <= 0.01:
			push_error("TrafficManager lane has no usable route: " + String(lane_id))
			return false
		lane.direction = route / lane.length
		lane.stop_distance = (lane.stop_line.global_position - lane.start_position).dot(lane.direction)
		if lane.stop_distance <= 0.0 or lane.stop_distance >= lane.length:
			push_error("TrafficManager stop line is outside lane bounds: " + String(lane_id))
			return false
		lane.next_spawn_time = _rng.randf_range(0.75, 3.0)
		_lanes.append(lane)
	return true


func _update_lane(lane: LaneState, delta: float) -> void:
	for index in range(lane.cars.size() - 1, -1, -1):
		var car := lane.cars[index]
		if not is_instance_valid(car.node):
			lane.cars.remove_at(index)
	lane.cars.sort_custom(func(first: CarState, second: CarState) -> bool: return first.distance > second.distance)
	for index in range(lane.cars.size()):
		var leader: CarState = lane.cars[index - 1] if index > 0 else null
		_update_car(lane, lane.cars[index], leader, delta)
	for index in range(lane.cars.size() - 1, -1, -1):
		var car := lane.cars[index]
		if car.distance < lane.length:
			continue
		if is_instance_valid(car.node):
			car.node.queue_free()
		car_despawned.emit(lane.id, car.id)
		lane.cars.remove_at(index)


func _update_car(lane: LaneState, car: CarState, leader: CarState, delta: float) -> void:
	if car.crosswalk_phase == CROSSWALK_HOLDING:
		car.speed = 0.0
		car.hold_remaining -= delta
		if car.hold_remaining <= 0.0:
			car.crosswalk_phase = CROSSWALK_CLEARED
			crosswalk_hold_finished.emit(lane.crosswalk_id, car.id)
		_apply_car_transform(lane, car)
		return

	var target_speed := car.desired_speed
	if car.crosswalk_phase == CROSSWALK_APPROACHING:
		if _should_stop_at_crosswalk(lane.crosswalk_id):
			var remaining_to_stop := lane.stop_distance - car.distance
			if remaining_to_stop <= 0.0:
				_begin_crosswalk_hold(lane, car)
				_apply_car_transform(lane, car)
				return
			target_speed = minf(target_speed, _speed_to_stop(remaining_to_stop))
		else:
			car.crosswalk_phase = CROSSWALK_CLEARED

	if leader != null:
		var safe_gap := standstill_gap + time_headway * car.speed
		var available_distance := leader.distance - safe_gap - car.distance
		if available_distance <= 0.0:
			target_speed = 0.0
		else:
			target_speed = minf(target_speed, _speed_to_stop(available_distance))

	var speed_change := acceleration * delta if target_speed >= car.speed else braking_deceleration * delta
	car.speed = move_toward(car.speed, target_speed, speed_change)
	var next_distance := car.distance + car.speed * delta

	if car.crosswalk_phase == CROSSWALK_APPROACHING and _should_stop_at_crosswalk(lane.crosswalk_id) and next_distance >= lane.stop_distance:
		car.distance = lane.stop_distance
		_begin_crosswalk_hold(lane, car)
		_apply_car_transform(lane, car)
		return

	if leader != null:
		var required_gap := standstill_gap + time_headway * car.speed
		var maximum_distance := leader.distance - required_gap
		if next_distance > maximum_distance:
			next_distance = maxf(car.distance, maximum_distance)
			car.speed = minf(car.speed, maxf(0.0, (next_distance - car.distance) / delta))

	car.distance = next_distance
	_apply_car_transform(lane, car)


func _begin_crosswalk_hold(lane: LaneState, car: CarState) -> void:
	car.distance = lane.stop_distance
	car.speed = 0.0
	car.crosswalk_phase = CROSSWALK_HOLDING
	car.hold_remaining = _rng.randf_range(crosswalk_hold_min, crosswalk_hold_max)
	crosswalk_hold_started.emit(lane.crosswalk_id, car.id)


func _spawn_due_cars() -> void:
	for lane: LaneState in _lanes:
		if _simulation_time < lane.next_spawn_time:
			continue
		if get_active_car_count() >= max_active_cars or not _lane_can_spawn(lane):
			lane.next_spawn_time = _simulation_time + _rng.randf_range(spawn_retry_min, spawn_retry_max)
			continue
		_spawn_car(lane)
		lane.next_spawn_time = _simulation_time + _random_spawn_interval()


func _lane_can_spawn(lane: LaneState) -> bool:
	for car: CarState in lane.cars:
		if car.distance < spawn_clearance:
			return false
	return true


func _spawn_car(lane: LaneState) -> void:
	var car_node := _car_scene.instantiate() as Node3D
	if car_node == null:
		push_error("TrafficManager car scene did not instantiate as Node3D")
		return
	_active_cars.add_child(car_node)
	var car := CarState.new()
	car.id = _next_car_id
	_next_car_id += 1
	car.node = car_node
	car.desired_speed = _rng.randf_range(cruise_speed_min, cruise_speed_max)
	_configure_car_visuals(car_node, BODY_COLORS[_rng.randi_range(0, BODY_COLORS.size() - 1)] as Color)
	_set_car_opacity(0.0, car_node)
	var fade_tween := create_tween()
	fade_tween.tween_method(_set_car_opacity.bind(car_node), 0.0, 1.0, fade_in_duration)
	lane.cars.append(car)
	_apply_car_transform(lane, car)
	car_spawned.emit(lane.id, car.id)


func _apply_car_transform(lane: LaneState, car: CarState) -> void:
	if not is_instance_valid(car.node):
		return
	car.node.global_position = lane.start_position + lane.direction * car.distance
	car.node.look_at(car.node.global_position + lane.direction, Vector3.UP)


func _configure_car_visuals(car_node: Node3D, body_color: Color) -> void:
	var geometry_nodes: Array[GeometryInstance3D] = []
	_collect_geometry_nodes(car_node, geometry_nodes)
	for geometry: GeometryInstance3D in geometry_nodes:
		var mesh_instance := geometry as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var source_material := mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
		var material: StandardMaterial3D = source_material.duplicate() as StandardMaterial3D if source_material != null else StandardMaterial3D.new()
		material.albedo_color = body_color if mesh_instance.name == "body" else WHEEL_COLOR
		material.roughness = 0.8
		mesh_instance.material_override = material


func _set_car_opacity(opacity: float, car_node: Node3D) -> void:
	if not is_instance_valid(car_node):
		return
	var geometry_nodes: Array[GeometryInstance3D] = []
	_collect_geometry_nodes(car_node, geometry_nodes)
	var transparency := 1.0 - clampf(opacity, 0.0, 1.0)
	for geometry: GeometryInstance3D in geometry_nodes:
		geometry.transparency = transparency


func _collect_geometry_nodes(node: Node, result: Array[GeometryInstance3D]) -> void:
	for child: Node in node.get_children():
		if child is GeometryInstance3D:
			result.append(child as GeometryInstance3D)
		_collect_geometry_nodes(child, result)


func _should_stop_at_crosswalk(crosswalk_id: StringName) -> bool:
	return mandatory_crosswalk_stops or _crosswalk_stop_requests.get(crosswalk_id, false)


func _speed_to_stop(distance: float) -> float:
	return sqrt(maxf(0.0, 2.0 * braking_deceleration * distance))


func _random_spawn_interval() -> float:
	var minimum := minf(spawn_interval_min, spawn_interval_max)
	var maximum := maxf(spawn_interval_min, spawn_interval_max)
	return _rng.randf_range(minimum, maximum)
