class_name TrafficManager
extends Node3D

const CAR_SCENE_PATH: String = "res://assets/models/kenney_car_kit/sedan.glb"
const SPAWN_INTERVAL_SECONDS: float = 7.0
const CAR_SPEED: float = 4.0
const CAR_HEIGHT: float = 0.35

@onready var _spawn_timer: Timer = $SpawnTimer
@onready var _active_cars: Node3D = $ActiveCars

var _next_route_index: int = 0

var _routes: Array[Dictionary] = [
	{
		"spawn": "Spawn_North",
		"end": Vector3(28.5, CAR_HEIGHT, -5.0),
		"rotation_y": -PI * 0.5,
	},
	{
		"spawn": "Spawn_East",
		"end": Vector3(30.0, CAR_HEIGHT, 28.5),
		"rotation_y": PI,
	},
	{
		"spawn": "Spawn_South",
		"end": Vector3(-3.5, CAR_HEIGHT, 30.0),
		"rotation_y": PI * 0.5,
	},
	{
		"spawn": "Spawn_West",
		"end": Vector3(-5.0, CAR_HEIGHT, -3.5),
		"rotation_y": 0.0,
	},
]


func _ready() -> void:
	_spawn_timer.wait_time = SPAWN_INTERVAL_SECONDS
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
	_spawn_car(_routes[_next_route_index])
	_next_route_index = (_next_route_index + 1) % _routes.size()


func _spawn_car(route: Dictionary) -> void:
	var car_scene: PackedScene = load(CAR_SCENE_PATH) as PackedScene
	if car_scene == null:
		push_error("TrafficManager could not load car scene: " + CAR_SCENE_PATH)
		return
	var spawn_marker: Marker3D = get_node_or_null(route["spawn"]) as Marker3D
	if spawn_marker == null:
		push_error("TrafficManager spawn marker missing: " + str(route["spawn"]))
		return
	var car: Node3D = car_scene.instantiate() as Node3D
	if car == null:
		push_error("TrafficManager car scene did not instantiate as Node3D")
		return
	_active_cars.add_child(car)
	car.global_position = spawn_marker.global_position
	car.global_rotation = Vector3(0.0, route["rotation_y"], 0.0)
	var end_position: Vector3 = route["end"]
	var distance: float = car.global_position.distance_to(end_position)
	var travel_time: float = maxf(distance / CAR_SPEED, 0.1)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(car, "global_position", end_position, travel_time)
	tween.tween_callback(car.queue_free)
