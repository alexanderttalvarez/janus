## PedestrianArea — Walkable exterior ring surrounding the mall plot.
##
## The ring is marked as walkable independently from the building grid. Visitors
## use its perimeter waypoints until interior entrances are implemented.
class_name PedestrianArea
extends Node3D


## Plot dimensions in world tiles/meters, matching the current 25×25 plot.
@export var plot_size: Vector2 = Vector2(25.0, 25.0)

## Width of the pedestrian ring in world units.
@export var sidewalk_width: float = 2.0

## Distance between perimeter waypoints.
@export var waypoint_spacing: float = 1.0


var _waypoints: Array[Vector3] = []


func _ready() -> void:
	add_to_group("walkable")
	add_to_group("pedestrian_walkable")
	set_meta("walkable", true)
	set_meta("walkable_area_type", "pedestrian")
	_build_waypoints()


## Return true when a ground position is inside the pedestrian ring.
func is_walkable_position(world_position: Vector3) -> bool:
	var in_outer_bounds := world_position.x >= -sidewalk_width and world_position.x <= plot_size.x + sidewalk_width
	in_outer_bounds = in_outer_bounds and world_position.z >= -sidewalk_width and world_position.z <= plot_size.y + sidewalk_width
	var inside_plot := world_position.x >= 0.0 and world_position.x <= plot_size.x
	inside_plot = inside_plot and world_position.z >= 0.0 and world_position.z <= plot_size.y
	return in_outer_bounds and not inside_plot


## Return a random position on the marked pedestrian ring.
func get_random_walkable_position() -> Vector3:
	_ensure_waypoints()
	if _waypoints.is_empty():
		return Vector3.ZERO
	return _waypoints[randi_range(0, _waypoints.size() - 1)]


## Return the number of perimeter waypoints.
func get_waypoint_count() -> int:
	_ensure_waypoints()
	return _waypoints.size()


## Return the nearest perimeter waypoint to a world position.
func get_nearest_waypoint_index(world_position: Vector3) -> int:
	_ensure_waypoints()
	if _waypoints.is_empty():
		return 0
	var nearest_index := 0
	var nearest_distance := INF
	for index in range(_waypoints.size()):
		var distance := world_position.distance_squared_to(_waypoints[index])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


## Return a waypoint using a wrapped index.
func get_waypoint(index: int) -> Vector3:
	_ensure_waypoints()
	if _waypoints.is_empty():
		return Vector3.ZERO
	return _waypoints[posmod(index, _waypoints.size())]


## Return the next waypoint in the pedestrian ring loop.
func get_next_waypoint_index(index: int, step: int = 1) -> int:
	_ensure_waypoints()
	if _waypoints.is_empty():
		return 0
	return posmod(index + step, _waypoints.size())


## Return the perimeter waypoint aligned with a building door side.
func get_door_waypoint_index(side: GridTile.DoorSide) -> int:
	_ensure_waypoints()
	var x_count := maxi(1, int(round(plot_size.x / waypoint_spacing)))
	var z_count := maxi(1, int(round(plot_size.y / waypoint_spacing)))
	var middle_x := int(x_count / 2)
	var middle_z := int(z_count / 2)
	match side:
		GridTile.DoorSide.NORTH:
			return middle_x
		GridTile.DoorSide.EAST:
			return x_count + middle_z
		GridTile.DoorSide.SOUTH:
			return x_count + z_count + (x_count - 1 - middle_x)
		GridTile.DoorSide.WEST:
			return x_count + z_count + x_count + (z_count - 1 - middle_z)
	return 0


func _ensure_waypoints() -> void:
	if _waypoints.is_empty():
		_build_waypoints()


func _build_waypoints() -> void:
	_waypoints.clear()
	var x_count := maxi(1, int(round(plot_size.x / waypoint_spacing)))
	var z_count := maxi(1, int(round(plot_size.y / waypoint_spacing)))
	var half_width := sidewalk_width * 0.5

	for x_index in range(x_count):
		var x := (float(x_index) + 0.5) * waypoint_spacing
		_waypoints.append(Vector3(x, 0.0, -half_width))
	for z_index in range(z_count):
		var z := (float(z_index) + 0.5) * waypoint_spacing
		_waypoints.append(Vector3(plot_size.x + half_width, 0.0, z))
	for x_index in range(x_count - 1, -1, -1):
		var x := (float(x_index) + 0.5) * waypoint_spacing
		_waypoints.append(Vector3(x, 0.0, plot_size.y + half_width))
	for z_index in range(z_count - 1, -1, -1):
		var z := (float(z_index) + 0.5) * waypoint_spacing
		_waypoints.append(Vector3(-half_width, 0.0, z))
