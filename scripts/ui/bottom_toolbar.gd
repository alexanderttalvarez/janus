## BottomToolbar — Contextual toolbar at the bottom of the screen.
class_name BottomToolbar
extends Control


@onready var _mode_label: Label = $ModeLabel
@onready var _buttons: HBoxContainer = $Buttons
var _painting: bool = false


func _ready() -> void:
	GameManager.ui_mode_changed.connect(_on_mode_changed)
	_build_build_mode()


func _build_build_mode() -> void:
	_clear_buttons()
	_mode_label.text = "Build"
	for zone_type: String in ZoneData.ZONE_TYPE_NAMES:
		_add_button(zone_type, func(): _enter_paint_mode(zone_type))


func _build_observe_mode() -> void:
	_clear_buttons()
	_mode_label.text = "Observe"
	_add_button("Build Zones", func(): GameManager.enter_build_mode())
	_add_button("Heatmap", func(): pass)
	_add_button("Finances", func(): pass)


func _enter_paint_mode(zone_type: String) -> void:
	_painting = true
	GameManager.enter_build_mode()
	_clear_buttons()
	_mode_label.text = "Build: " + zone_type
	var root := get_tree().current_scene
	if root:
		var tool: Node = root.get_node_or_null("ZoneTool")
		if tool and tool is ZoneTool:
			(tool as ZoneTool).active_zone_type = zone_type
			(tool as ZoneTool).is_active = true
	_add_button("Finish Zone", func(): _exit_paint_mode())


func _exit_paint_mode() -> void:
	_painting = false
	var root := get_tree().current_scene
	if root:
		var tool: Node = root.get_node_or_null("ZoneTool")
		if tool and tool is ZoneTool:
			(tool as ZoneTool).finish()
			(tool as ZoneTool).is_active = false
	GameManager.enter_observe_mode()


func _add_button(text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	_buttons.add_child(btn)


func _clear_buttons() -> void:
	for child in _buttons.get_children():
		child.queue_free()


func _on_mode_changed(mode: String) -> void:
	if _painting:
		return
	match mode:
		"Build": _build_build_mode()
		"Observe": _build_observe_mode()



