## HUDBar — Top bar showing Money, Visitors, Prestige, Speed, Clock, Wall Mode.
## Uses hybrid data flow: reads initial state directly, subscribes to EventBus for updates.
class_name HUDBar
extends Control


@onready var _money_label: Label = $MoneyLabel
@onready var _visitors_label: Label = $VisitorsLabel
@onready var _prestige_label: Label = $PrestigeLabel
@onready var _speed_label: Label = $SpeedLabel
@onready var _clock_label: Label = $ClockLabel
@onready var _wall_mode_label: Label = $WallModeLabel
@onready var _camera_label: Label = $CameraLabel
@onready var _save_button: Button = $SaveLoadButtons/SaveButton
@onready var _load_button: Button = $SaveLoadButtons/LoadButton

const SAVE_SLOT: int = 1


func _ready() -> void:
	_refresh_all()
	EventBus.money_changed.connect(_on_money_changed)
	GameManager.speed_changed.connect(_on_speed_changed)
	GameManager.wall_mode_changed.connect(_on_wall_mode_changed)
	_save_button.pressed.connect(_on_save_pressed)
	_load_button.pressed.connect(_on_load_pressed)


func _process(_delta: float) -> void:
	_refresh_visitors()
	_refresh_clock()
	_refresh_camera()


func _refresh_all() -> void:
	_refresh_money()
	_refresh_visitors()
	_refresh_prestige()
	_refresh_speed()
	_refresh_clock()
	_refresh_wall_mode()
	_refresh_camera()


func _refresh_money() -> void:
	var root := get_tree().current_scene
	if root:
		var em := root.get_node_or_null("Simulation/EconomyManager")
		if em and em is EconomyManager:
			_money_label.text = "%d K" % (em as EconomyManager).balance

func _refresh_visitors() -> void:
	var root := get_tree().current_scene
	if root:
		var vm := root.get_node_or_null("Simulation/VisitorManager")
		if vm and vm is VisitorManager:
			var count := (vm as VisitorManager).all_visitors.size()
			_visitors_label.text = "%d" % count

func _refresh_prestige() -> void:
	var root := get_tree().current_scene
	if root:
		var pm := root.get_node_or_null("Simulation/PrestigeManager")
		if pm and pm is PrestigeManager:
			var pmgr := pm as PrestigeManager
			var snapshot: OfficialPrestigeSnapshot = pmgr.get_committed_snapshot()
			if snapshot != null:
				_prestige_label.text = "%s | T%d | %d cK cap" % [pmgr.get_mall_level_name(), snapshot.get_supported_tenant_tier(), snapshot.get_rent_ceiling_centi_kreds()]

func _refresh_speed() -> void:
	var names := ["||", "1x", "2x", "3x"]
	_speed_label.text = names[GameManager.speed]

func _refresh_clock() -> void:
	var root := get_tree().current_scene
	if root:
		var tm := root.get_node_or_null("Simulation/TimeManager")
		if tm and tm is TimeManager:
			_clock_label.text = (tm as TimeManager).get_visual_clock_string()

func _refresh_wall_mode() -> void:
	_wall_mode_label.text = GameManager.WALL_MODE_NAMES[GameManager.wall_mode]


func _refresh_camera() -> void:
	var root := get_tree().current_scene
	if root:
		var cam: Node3D = root.get_node_or_null("CameraRig/CameraRig")
		if cam:
			_camera_label.text = "Cam: %.0f" % rad_to_deg(cam.rotation.y)


func _on_money_changed(balance: int, _delta: int) -> void:
	_money_label.text = "%d K" % balance

func _on_speed_changed(speed: int) -> void:
	var names := ["||", "1x", "2x", "3x"]
	_speed_label.text = names[speed]

func _on_wall_mode_changed(mode: String) -> void:
	_wall_mode_label.text = mode

func _on_save_pressed() -> void:
	var result: Error = SaveManager.save_game(SAVE_SLOT)
	if result == OK:
		_save_button.tooltip_text = "Saved slot %d" % SAVE_SLOT
	else:
		_save_button.tooltip_text = "Save failed: %s" % error_string(result)

func _on_load_pressed() -> void:
	var result: Dictionary = SaveManager.load_game(SAVE_SLOT)
	if bool(result.get("valid", false)):
		_load_button.tooltip_text = "Loaded slot %d" % SAVE_SLOT
	else:
		_load_button.tooltip_text = "Load failed: %s" % String(result.get("reason_code", "unknown error"))
