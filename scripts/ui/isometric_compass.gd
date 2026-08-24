class_name IsometricCompass
extends Control

const DESIGN_SIZE := Vector2(55.0, 45.0)
const NORTH_DIRECTION := Vector2(1.0, -0.58)
const BLACK_FACE_COLOR := Color(0.02, 0.02, 0.02, 1.0)
const WHITE_FACE_COLOR := Color(0.97, 0.97, 0.95, 1.0)
const OUTLINE_COLOR := Color(0.02, 0.02, 0.02, 1.0)
const BACKGROUND_COLOR := Color(0.72, 0.91, 0.94, 0.96)
const BACKGROUND_BORDER_COLOR := Color(0.02, 0.02, 0.02, 0.42)

var _initial_camera_yaw: float = 0.0
var _card_rotation: float = 0.0
var _has_initial_camera_yaw: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return

	var camera_yaw: float = camera.global_rotation.y
	if not _has_initial_camera_yaw:
		_initial_camera_yaw = camera_yaw
		_has_initial_camera_yaw = true
		return

	var new_card_rotation: float = _initial_camera_yaw - camera_yaw
	if is_equal_approx(_card_rotation, new_card_rotation):
		return

	_card_rotation = new_card_rotation
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var scale_factor: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var panel_rect := Rect2(Vector2.ZERO, size)
	draw_rect(panel_rect, BACKGROUND_COLOR)
	draw_rect(panel_rect, BACKGROUND_BORDER_COLOR, false, 1.0, true)

	var center: Vector2 = size * 0.5
	var direction: Vector2 = NORTH_DIRECTION.normalized().rotated(_card_rotation)
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var tip: Vector2 = center + direction * (20.0 * scale_factor)
	var tail: Vector2 = center - direction * (15.0 * scale_factor)
	var left_corner: Vector2 = center - direction * (3.0 * scale_factor) - perpendicular * (12.0 * scale_factor)
	var right_corner: Vector2 = center - direction * (3.0 * scale_factor) + perpendicular * (12.0 * scale_factor)
	var outline_width: float = maxf(1.0, 1.2 * scale_factor)

	draw_colored_polygon(PackedVector2Array([tip, left_corner, tail]), BLACK_FACE_COLOR)
	draw_colored_polygon(PackedVector2Array([tip, tail, right_corner]), WHITE_FACE_COLOR)
	draw_polyline(PackedVector2Array([tip, left_corner, tail, right_corner, tip]), OUTLINE_COLOR, outline_width, true)
	draw_line(tip, tail, OUTLINE_COLOR, outline_width, true)
