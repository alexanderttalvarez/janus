## PanelManager — Controls informational panel lifecycle.
## Opens/closes/stacks panels (max 3), repositions horizontally from the right edge.
class_name PanelManager
extends Control


const MAX_PANELS: int = 3
const PANEL_WIDTH: int = 320
const PANEL_GAP: int = 8

var _open_panels: Array[Control] = []
var _panel_registry: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func register_panel(panel_name: String, panel_scene: PackedScene) -> void:
	_panel_registry[panel_name] = panel_scene


func open_panel(panel_name: String) -> bool:
	if _panel_registry.has(panel_name):
		return false
	if _open_panels.size() >= MAX_PANELS:
		return false
	var scene: PackedScene = _panel_registry.get(panel_name, null)
	if scene == null:
		return false
	var panel: Control = scene.instantiate() as Control
	panel.name = panel_name
	panel.size = Vector2(PANEL_WIDTH, 600)
	add_child(panel)
	_open_panels.append(panel)
	_reposition_panels()
	EventBus.panel_opened.emit(panel_name)
	return true


func close_panel(panel_name: String) -> void:
	for i in range(_open_panels.size() - 1, -1, -1):
		if _open_panels[i].name == panel_name:
			_open_panels[i].queue_free()
			_open_panels.remove_at(i)
			EventBus.panel_closed.emit(panel_name)
			break
	_reposition_panels()


func close_all() -> void:
	for p: Control in _open_panels:
		p.queue_free()
	_open_panels.clear()


func _reposition_panels() -> void:
	var x := size.x - PANEL_GAP
	for p: Control in _open_panels:
		x -= PANEL_WIDTH + PANEL_GAP
		p.position = Vector2(x, 40.0)
