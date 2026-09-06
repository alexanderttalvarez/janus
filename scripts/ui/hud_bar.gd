## HUDBar — Top bar rendering the detached PresentationCoordinator HUD model.
class_name HUDBar
extends Control

signal save_requested
signal load_requested

@onready var _money_label: Label = $MoneyLabel
@onready var _visitors_label: Label = $VisitorsLabel
@onready var _prestige_label: Label = $PrestigeLabel
@onready var _speed_label: Label = $SpeedLabel
@onready var _clock_label: Label = $ClockLabel
@onready var _wall_mode_label: Label = $WallModeLabel
@onready var _camera_label: Label = $CameraLabel
@onready var _save_button: Button = $SaveLoadButtons/SaveButton
@onready var _load_button: Button = $SaveLoadButtons/LoadButton

var _presentation_root: GameUI
var _model: Dictionary = {}


func bind_presentation(presentation_root: GameUI) -> void:
	_presentation_root = presentation_root
	apply_model(presentation_root.get_hud_model())


func _ready() -> void:
	GameManager.speed_changed.connect(_on_speed_changed)
	GameManager.wall_mode_changed.connect(_on_wall_mode_changed)
	_save_button.pressed.connect(func() -> void: save_requested.emit())
	_load_button.pressed.connect(func() -> void: load_requested.emit())
	_money_label.size = Vector2(160.0, 23.0)
	_visitors_label.position = Vector2(180.0, 8.0)
	_visitors_label.size = Vector2(180.0, 23.0)
	_prestige_label.position = Vector2(370.0, 8.0)
	_prestige_label.size = Vector2(230.0, 23.0)
	_speed_label.position = Vector2(800.0, 8.0)
	_speed_label.size = Vector2(70.0, 23.0)
	_clock_label.position = Vector2(900.0, 8.0)
	_wall_mode_label.position = Vector2(1100.0, 8.0)
	apply_model(_model)


func apply_model(model: Dictionary) -> void:
	_model = model.duplicate(true)
	if not is_node_ready():
		return
	var metrics: Dictionary = _model.get("metrics", {})
	_money_label.text = "Money: %s K" % _format_integer(int(metrics.get("money", 0))) if metrics.has("money") else "Money: unavailable"
	if metrics.has("current_visitors") or metrics.has("daily_arrivals"):
		_visitors_label.text = "Visitors: %d / %d" % [int(metrics.get("current_visitors", 0)), int(metrics.get("daily_arrivals", 0))]
	else:
		_visitors_label.text = "Visitors: unavailable"
	_prestige_label.text = "Prestige: %s" % str(metrics.get("prestige", "unavailable")) if metrics.has("prestige") else "Prestige: unavailable"
	_speed_label.text = _speed_text(int(metrics.get("simulation_speed", GameManager.speed))) if metrics.has("simulation_speed") else "Speed: unavailable"
	_clock_label.text = str(metrics.get("clock", "Clock: unavailable")) if metrics.has("clock") else "Clock: unavailable"
	_wall_mode_label.text = "Walls: %s" % str(metrics.get("wall_mode", "unavailable")) if metrics.has("wall_mode") else "Walls: unavailable"


func set_save_status(success: bool, message: String) -> void:
	_save_button.tooltip_text = message
	_save_button.modulate = Color.WHITE if success else Color(1.0, 0.5, 0.5)


func set_load_status(success: bool, message: String) -> void:
	_load_button.tooltip_text = message
	_load_button.modulate = Color.WHITE if success else Color(1.0, 0.5, 0.5)


func _on_speed_changed(speed: int) -> void:
	_speed_label.text = _speed_text(speed)


func _on_wall_mode_changed(mode: String) -> void:
	_wall_mode_label.text = "Walls: %s" % mode


func _speed_text(speed: int) -> String:
	var names: Array[String] = ["||", "1x", "2x", "3x"]
	return "Speed: %s" % (names[speed] if speed >= 0 and speed < names.size() else "?")


func _format_integer(value: int) -> String:
	var raw: String = str(value)
	if abs(value) < 1000:
		return raw
	var split_at: int = raw.length() - 3
	return raw.substr(0, split_at) + "," + raw.substr(split_at)
