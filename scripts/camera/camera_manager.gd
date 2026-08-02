## CameraManager — Pivot-based isometric camera rig with rotation, zoom, pan, and floor navigation.
##
## Structure:
##   CameraManager (Node3D, this script)
##   ├── CameraRig (Node3D) — Y-axis rotation pivot
##   │   ├── CameraMount (Node3D) — zoomed Z-offset from pivot
##   │   │   └── Camera3D — orthographic projection
##   │   └── FocusTarget (Marker3D) — look-at point on ground
##
## Rotation: 90° increments around Y, 0.15s Tween, cubic ease-out.
## Zoom: Camera3D.size 5.0–50.0.
## Pan: Move CameraManager in XZ plane.
## Floor nav: go_up()/go_down() with FULL/EXTERIOR/HIDDEN visibility modes.
class_name CameraManager
extends Node3D


## Emitted when the camera rotates (direction: -1=left, 1=right).
signal rotated(direction: int)

## Emitted when zoom changes.
signal zoomed(size: float)

## Emitted when camera focuses on an element.
signal focused(element_type: String, element_id: String)

## Emitted when the active floor changes.
signal floor_changed(floor_level: String)


# ── Exports ────────────────────────────────────────────────────────────

## Minimum orthographic camera size (zoomed in).
@export var min_zoom: float = 5.0

## Maximum orthographic camera size (zoomed out).
@export var max_zoom: float = 50.0

## Default isometric pitch angle (look-down angle in degrees).
@export var isometric_pitch: float = 35.26

## Floor levels the camera can navigate (e.g., ["G", "F1", "F2"]).
@export var floor_levels: Array[String] = ["G"]


# ── Runtime State ──────────────────────────────────────────────────────

## Current rotation direction index: 0=0°, 1=90°, 2=180°, 3=270°.
var _current_direction: int = 0

## Current zoom level (Camera3D.size).
var _current_zoom: float = 20.0

## Current floor index in floor_levels.
var current_floor_index: int = 0

## Whether a Tween rotation is in progress.
var _is_rotating: bool = false

## Reference to the active zoom tween (for interruption).
var _zoom_tween: Tween

## Position limit center and radius (set from GridManager on init).
var _limit_center: Vector3 = Vector3.ZERO
var _limit_radius: float = 50.0  # 20 tiles × TILE_SIZE(2.0) + buffer

# ── OnReady References ─────────────────────────────────────────────────

@onready var _camera_rig: Node3D = $CameraRig
@onready var _camera_mount: Node3D = $CameraRig/CameraMount
@onready var _camera: Camera3D = $CameraRig/CameraMount/Camera3D
@onready var _focus_target: Marker3D = $CameraRig/FocusTarget


func _ready() -> void:
	_setup_camera()
	_apply_zoom(_current_zoom)
	# Don't override scene rotation — use scene's initial 45° Y rotation.


func _process(_delta: float) -> void:
	_handle_input()


# ── Camera Setup ───────────────────────────────────────────────────────

func _setup_camera() -> void:
	_current_zoom = _camera.size
	# Scene starts at 45° Y rotation — use that as initial direction.
	_current_direction = 0


# ── Input Handling ─────────────────────────────────────────────────────

func _handle_input() -> void:
	if _is_rotating:
		return

	# Rotation
	if InputMap.has_action("camera_rotate_left") and Input.is_action_just_pressed("camera_rotate_left"):
		rotate_camera(-1)
	elif InputMap.has_action("camera_rotate_right") and Input.is_action_just_pressed("camera_rotate_right"):
		rotate_camera(1)

	# Zoom
	if Input.is_action_just_pressed("camera_zoom_in"):
		zoom_camera(-2.0)
	elif Input.is_action_just_pressed("camera_zoom_out"):
		zoom_camera(2.0)

	# Pan (WASD / Arrow keys)
	var pan_input := Input.get_vector(
		"camera_pan_left", "camera_pan_right",
		"camera_pan_up", "camera_pan_down"
	)
	if pan_input.length() > 0.01:
		pan_camera(pan_input * get_process_delta_time() * 10.0)

	# Middle-mouse drag for pan
	if Input.is_action_pressed("camera_pan_middle_mouse"):
		var mouse_delta := _get_mouse_delta()
		if mouse_delta.length() > 0.01:
			pan_camera(mouse_delta * -1.0)

	# Floor navigation
	if Input.is_action_just_pressed("camera_floor_up"):
		go_up()
	elif Input.is_action_just_pressed("camera_floor_down"):
		go_down()


# ── Rotation ───────────────────────────────────────────────────────────

## Rotate the camera 90° in the given direction (-1 = left, +1 = right).
func rotate_camera(direction: int) -> void:
	if _is_rotating:
		return

	_current_direction = wrapi(_current_direction + direction, 0, 4)
	_is_rotating = true

	var target_y := deg_to_rad(float(45 + _current_direction * 90))

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_camera_rig, "rotation:y", target_y, 0.15)
	tween.finished.connect(_on_rotation_complete.bind(direction))

	# Update global shader parameter for wall clipping.
	_set_global_camera_direction(45 + _current_direction * 90)


func _on_rotation_complete(direction: int) -> void:
	_is_rotating = false
	rotated.emit(direction)


# ── Zoom ───────────────────────────────────────────────────────────────

## Zoom the camera by delta amount. Positive = zoom out, negative = zoom in.
func zoom_camera(delta: float) -> void:
	var target := clampf(_current_zoom + delta, min_zoom, max_zoom)

	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_apply_zoom, _current_zoom, target, 0.2)
	tween.finished.connect(_on_zoom_complete.bind(target))
	_zoom_tween = tween


func _apply_zoom(size: float) -> void:
	_current_zoom = size
	_camera.size = size
	if size > 35.0:
		zoomed.emit(size)


func _on_zoom_complete(size: float) -> void:
	zoomed.emit(size)


# ── Pan ────────────────────────────────────────────────────────────────

## Pan the camera in XZ plane by the given offset.
func pan_camera(offset: Vector2) -> void:
	# Scale pan by zoom level so movement feels consistent.
	var speed := _current_zoom * 2.0
	var pan_dir := Vector3(offset.x * speed, 0, offset.y * speed)
	pan_dir = pan_dir.rotated(Vector3.UP, _camera_rig.rotation.y)
	_camera_rig.position += pan_dir


# ── Focus ──────────────────────────────────────────────────────────────

## Smoothly focus the camera on a world position.
func focus_on(target_position: Vector3) -> void:
	_focus_target.global_position = target_position

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "global_position", target_position, 0.3)


# ── Floor Navigation ───────────────────────────────────────────────────

## Move up one floor level.
func go_up() -> void:
	if not can_go_up():
		return
	current_floor_index = min(current_floor_index + 1, floor_levels.size() - 1)
	_on_floor_changed()


## Move down one floor level.
func go_down() -> void:
	if not can_go_down():
		return
	current_floor_index = max(current_floor_index - 1, 0)
	_on_floor_changed()


## Check if camera can go up a floor.
func can_go_up() -> bool:
	return current_floor_index < floor_levels.size() - 1


## Check if camera can go down a floor.
func can_go_down() -> bool:
	return current_floor_index > 0


## Get the current floor level string.
func get_current_floor() -> String:
	if floor_levels.is_empty() or current_floor_index >= floor_levels.size():
		return "G"
	return floor_levels[current_floor_index]


func _on_floor_changed() -> void:
	var level := get_current_floor()
	# Move camera Y to the new floor level.
	var target_y := _get_floor_height(level)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "global_position:y", target_y, 0.3)

	floor_changed.emit(level)
	_apply_floor_visibility(level)


func _get_floor_height(level: String) -> float:
	# Parse floor level to height. Ground floor is at Y=0.
	# F1=+3, F2=+6, B1=-3, etc.
	if level == "G":
		return 0.0
	var prefix := level[0]
	var num := level.substr(1).to_int()
	var height := float(num) * 3.0
	return height if prefix == "F" else -height


## Apply visibility to floors based on current floor and modes.
## FULL (current) = all nodes visible
## EXTERIOR (below) = floor plane, walls, tiles, circulation visible; rest hidden
## HIDDEN (above) = all nodes hidden
func _apply_floor_visibility(_current_level: String) -> void:
	# TODO Phase 7/13: Iterate floor instances and set visibility per mode.
	# For now, this is a placeholder — visitable culling is in Phase 7.
	pass


# ── Position Limits ────────────────────────────────────────────────────

## Set the position limit from GridManager data.
func set_position_limit(center: Vector3, radius: float) -> void:
	_limit_center = center
	_limit_radius = radius


## Clamp camera position to stay within the allowed area.
func _clamp_position(pos: Vector3) -> Vector3:
	# Unused — panning now works via CameraRig, not root.
	return pos


# ── Shader Integration ─────────────────────────────────────────────────

## Set the global camera_direction shader parameter for wall clipping.
func _set_global_camera_direction(angle_deg: float) -> void:
	if not GameManager.session_ready:
		return
	var angle := deg_to_rad(angle_deg)
	RenderingServer.global_shader_parameter_set("camera_direction", Vector2(cos(angle), sin(angle)))


# ── Initial State ──────────────────────────────────────────────────────

func _apply_rotation(_dir_index: int) -> void:
	# Scene sets initial 45° Y via the tscn file — don't override.
	pass


# ── Helpers ────────────────────────────────────────────────────────────

## Get the current mouse delta from the last frame (for middle-mouse pan).
func _get_mouse_delta() -> Vector2:
	# Mouse relative motion is not available in Godot without InputEventMouseMotion.
	# For middle-mouse pan, we use a simple velocity-based approach in _process.
	return Vector2.ZERO  # Middle-mouse pan handled by InputEventMouseMotion in _input.


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_action_pressed("camera_pan_middle_mouse"):
		pan_camera(event.relative * -0.5)
