## Floor — Script for floor.tscn scene instances.
## Uses bounded shared floor geometry; per-cell authority remains outside the scene.
@tool
class_name Floor
extends Node3D


@export var plot_id: String = "plot_0"
@export var floor_level: String = "G"
@export var grid_width: int = 25
@export var grid_height: int = 25
@export var tile_size: float = 1.0

## Per-floor camera presentation modes from ADR 16.
enum VisibilityMode { FULL, EXTERIOR, HIDDEN }

## The currently applied camera presentation mode.
var visibility_mode: int = VisibilityMode.FULL


func _ready() -> void:
	_update_grid_overlay()


## Apply the ADR 16 per-floor presentation contract.
## FULL shows all floor-owned content, EXTERIOR preserves only structural and
## circulation context, and HIDDEN removes the floor completely.
func set_visibility_mode(mode: int) -> void:
	visibility_mode = mode
	visible = mode != VisibilityMode.HIDDEN
	if mode == VisibilityMode.HIDDEN:
		return
	var exterior_visible: Array[String] = [
		"GridOverlay",
		"TileContainer",
		"CirculationContainer",
		"FloorPlane",
		"WallMesh",
		"WallContainer",
		"DoorContainer",
	]
	for child: Node in get_children():
		if child is Node3D and child.name != &"GridOrigin":
			(child as Node3D).visible = mode == VisibilityMode.FULL or exterior_visible.has(String(child.name))


## Apply an H4 projection descriptor without creating per-cell Nodes.
func apply_projection(descriptor: Dictionary, metrics: ProjectionMetrics) -> void:
	if metrics == null:
		return
	var bounds: AABB = descriptor.get("bounds", AABB())
	grid_width = maxi(1, int(round(bounds.size.x / metrics.grid_unit_size)))
	grid_height = maxi(1, int(round(bounds.size.z / metrics.grid_unit_size)))
	tile_size = metrics.grid_unit_size
	_update_grid_overlay()


func _update_grid_overlay() -> void:
	var overlay: MeshInstance3D = get_node_or_null("GridOverlay") as MeshInstance3D
	if overlay == null or overlay.mesh == null:
		return
	var plane: PlaneMesh = overlay.mesh.duplicate() as PlaneMesh
	if plane == null:
		return
	plane.size = Vector2(float(grid_width) * tile_size, float(grid_height) * tile_size)
	overlay.mesh = plane
	overlay.position = Vector3(float(grid_width) * tile_size / 2.0, overlay.position.y, float(grid_height) * tile_size / 2.0)
	# FloorPlane and WallMesh use centered meshes; keep their centers aligned
	# with the grid's canonical origin for every generated floor size.
	for centered_name: String in ["FloorPlane", "WallMesh"]:
		var centered_mesh: Node3D = get_node_or_null(centered_name) as Node3D
		if centered_mesh != null:
			centered_mesh.position = Vector3(overlay.position.x, centered_mesh.position.y, overlay.position.z)


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
