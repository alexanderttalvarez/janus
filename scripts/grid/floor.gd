## Floor — Script for floor.tscn scene instances.
## Each floor represents a single level of a plot.
## Structural nodes are authored in the scene. Runtime content is added programmatically.
class_name Floor
extends Node3D


## Which plot this floor belongs to.
@export var plot_id: String = "plot_0"

## Floor level identifier (e.g., "G", "F1", "B1").
@export var floor_level: String = "G"


func _ready() -> void:
	pass


## Get the GridOrigin Marker3D for world-position reference.
func get_grid_origin() -> Marker3D:
	return $GridOrigin as Marker3D


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
