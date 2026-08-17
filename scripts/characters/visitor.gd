## Visitor — Visual agent that smoothly walks between pedestrian ring waypoints.
##
## Decision-making remains centralized in VisitorManager. This scene only owns
## the per-frame visual interpolation required by the visitor architecture.
class_name Visitor
extends Node3D


signal target_reached


## Visual movement speed in meters per second.
@export var speed: float = 1.5

## Distance at which the target is considered reached.
@export var arrival_distance: float = 0.05

## Duration of the per-instance spawn fade-in.
@export var fade_in_duration: float = 2.0

## Duration of the Building-mode opacity transition.
@export var mode_opacity_transition_duration: float = 0.2


var _target_position: Vector3 = Vector3.ZERO
var _has_target: bool = false
var _path: Array[Vector3] = []
var _path_index: int = 0
var _fade_opacity: float = 0.0
var _mode_opacity: float = 1.0
var _fade_tween: Tween
var _mode_opacity_tween: Tween


func _ready() -> void:
	fade_in()


## Fade this visitor in without mutating the shared mesh material.
func fade_in() -> void:
	_fade_opacity = 0.0
	_apply_visual_opacity()
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_method(_set_fade_opacity, 0.0, 1.0, fade_in_duration)


## Set the opacity multiplier imposed by the current UI mode.
func set_mode_opacity(opacity: float, duration: float = mode_opacity_transition_duration) -> void:
	var target_opacity := clampf(opacity, 0.0, 1.0)
	if _mode_opacity_tween and _mode_opacity_tween.is_valid():
		_mode_opacity_tween.kill()
	if duration <= 0.0:
		_set_mode_opacity(target_opacity)
		return
	_mode_opacity_tween = create_tween()
	_mode_opacity_tween.tween_method(_set_mode_opacity, _mode_opacity, target_opacity, duration)


func _set_fade_opacity(opacity: float) -> void:
	_fade_opacity = opacity
	_apply_visual_opacity()


func _set_mode_opacity(opacity: float) -> void:
	_mode_opacity = opacity
	_apply_visual_opacity()


func _apply_visual_opacity() -> void:
	var geometry_nodes: Array[GeometryInstance3D] = []
	_collect_geometry_nodes(self, geometry_nodes)
	var transparency := 1.0 - (_fade_opacity * _mode_opacity)
	for geometry: GeometryInstance3D in geometry_nodes:
		geometry.transparency = transparency


func _collect_geometry_nodes(node: Node, result: Array[GeometryInstance3D]) -> void:
	for child: Node in node.get_children():
		if child is GeometryInstance3D:
			result.append(child as GeometryInstance3D)
		_collect_geometry_nodes(child, result)


func set_target(target_position: Vector3) -> void:
	_path.clear()
	_path_index = 0
	_target_position = target_position
	_has_target = true


## Follow a sequence of world-space waypoints without cutting across walls.
func set_path(path_points: Array[Vector3]) -> void:
	_path = path_points.duplicate()
	_path_index = 0
	if _path.is_empty():
		_has_target = false
		return
	_target_position = _path[0]
	_has_target = true


func clear_target() -> void:
	_path.clear()
	_path_index = 0
	_has_target = false


func _process(delta: float) -> void:
	if not _has_target:
		return

	var next_position := global_position
	next_position.y = _target_position.y
	var offset := _target_position - next_position
	if offset.length() <= arrival_distance:
		global_position = _target_position
		if _path_index + 1 < _path.size():
			_path_index += 1
			_target_position = _path[_path_index]
			return
		_path.clear()
		_path_index = 0
		_has_target = false
		target_reached.emit()
		return

	var direction := offset.normalized()
	var movement := direction * speed * delta
	global_position = next_position.move_toward(_target_position, movement.length())
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 8.0)
