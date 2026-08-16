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


var _target_position: Vector3 = Vector3.ZERO
var _has_target: bool = false


func set_target(target_position: Vector3) -> void:
	_target_position = target_position
	_has_target = true


func clear_target() -> void:
	_has_target = false


func _process(delta: float) -> void:
	if not _has_target:
		return

	var next_position := global_position
	next_position.y = _target_position.y
	var offset := _target_position - next_position
	if offset.length() <= arrival_distance:
		global_position = _target_position
		_has_target = false
		target_reached.emit()
		return

	var direction := offset.normalized()
	var movement := direction * speed * delta
	global_position = next_position.move_toward(_target_position, movement.length())
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 8.0)
