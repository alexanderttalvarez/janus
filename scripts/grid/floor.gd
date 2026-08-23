## Floor — Script for floor.tscn scene instances.
## Spawns 25×25 individual tile meshes at runtime.
class_name Floor
extends Node3D


@export var plot_id: String = "plot_0"
@export var floor_level: String = "G"
@export var grid_width: int = 25
@export var grid_height: int = 25
@export var tile_size: float = 1.0


func _ready() -> void:
	_spawn_tile_grid()


func _spawn_tile_grid() -> void:
	var container := $TileContainer
	if container == null:
		return

	# Shared mesh and material for all tiles (single draw call).
	var mesh := BoxMesh.new()
	mesh.size = Vector3(tile_size, 0.1, tile_size)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.5, 1.0)

	for x in range(grid_width):
		for y in range(grid_height):
			var tile_mesh := MeshInstance3D.new()
			tile_mesh.name = "Tile_%d_%d" % [x, y]
			tile_mesh.mesh = mesh
			tile_mesh.material_override = mat
			tile_mesh.position = Vector3(x + 0.5, 0, y + 0.5)
			container.add_child(tile_mesh)


## Get the GridOrigin Marker3D for world-position reference.
func get_grid_origin() -> Marker3D:
	return $GridOrigin as Marker3D


## Convert a fractional grid coordinate into this floor's local 3D position.
## Labels and overlays must use this instead of duplicating grid scale/origin math.
func grid_coordinate_to_local(grid_coordinate: Vector2) -> Vector3:
	var grid_origin := get_grid_origin()
	var origin_position := grid_origin.position if grid_origin != null else Vector3.ZERO
	return origin_position + Vector3(
		grid_coordinate.x * tile_size,
		0.0,
		grid_coordinate.y * tile_size
	)


## Return the canonical local center of one instantiated floor tile.
func tile_center_to_local(tile_position: Vector2i) -> Vector3:
	return grid_coordinate_to_local(Vector2(tile_position) + Vector2(0.5, 0.5))


## Add a tile visual to the TileContainer.
func add_tile_visual(node: Node3D) -> void:
	var container := $TileContainer
	if container:
		container.add_child(node)


## Remove all tile visuals from this floor.
func clear_tile_visuals() -> void:
	_clear_container($TileContainer)


## Add a zone overlay to the ZoneContainer.
func add_zone_overlay(node: Node3D) -> void:
	var container := $ZoneContainer
	if container:
		container.add_child(node)


## Clear all zone overlays.
func clear_zone_overlays() -> void:
	_clear_container($ZoneContainer)


## Add a visitor node to the VisitorContainer.
func add_visitor(node: Node3D) -> void:
	var container := $VisitorContainer
	if container:
		container.add_child(node)


## Add a circulation element to the CirculationContainer.
func add_circulation(node: Node3D) -> void:
	var container := $CirculationContainer
	if container:
		container.add_child(node)


## Add an indicator to the IndicatorContainer.
func add_indicator(node: Node3D) -> void:
	var container := $IndicatorContainer
	if container:
		container.add_child(node)


## Clear all children of a container node.
func _clear_container(container: Node) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
