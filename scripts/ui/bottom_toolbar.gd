## BottomToolbar — Contextual toolbar at the bottom of the screen.
class_name BottomToolbar
extends Control


@onready var _mode_label: Label = $ModeLabel
@onready var _buttons: HBoxContainer = $Buttons
var _painting: bool = false
var _finish_button: Button
var _remove_button: Button
var _transit_button: Button
var _door_mode: bool = false


func _ready() -> void:
	GameManager.ui_mode_changed.connect(_on_mode_changed)
	_build_build_mode()


func _build_build_mode() -> void:
	_clear_buttons()
	_door_mode = false
	_mode_label.text = "Build"
	for zone_type: String in ZoneData.ZONE_TYPE_NAMES:
		_add_button(zone_type, func(): _enter_paint_mode(zone_type))
	_add_button("Place Door", func(): _enter_door_mode(false))
	_add_button("Remove Door", func(): _enter_door_mode(true))


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
		var door_tool: Node = root.get_node_or_null("DoorTool")
		if door_tool and door_tool is DoorTool:
			(door_tool as DoorTool).set_active(false)
		if tool and tool is ZoneTool:
			if not (tool as ZoneTool).painting_state_changed.is_connected(_on_zone_painting_state_changed):
				(tool as ZoneTool).painting_state_changed.connect(_on_zone_painting_state_changed)
			if not (tool as ZoneTool).preview_validation_changed.is_connected(_on_preview_validation_changed):
				(tool as ZoneTool).preview_validation_changed.connect(_on_preview_validation_changed)
			(tool as ZoneTool).active_zone_type = zone_type
			(tool as ZoneTool).set_remove_mode(false)
			(tool as ZoneTool).is_active = true
	_remove_button = _add_button("Remove", func(): _toggle_remove_mode())
	_remove_button.toggle_mode = true
	_finish_button = _add_button("Finish Zone", func(): _exit_paint_mode())
	_configure_finish_button(_finish_button)
	if root:
		var zone_tool := root.get_node_or_null("ZoneTool") as ZoneTool
		if zone_tool:
			_finish_button.disabled = not zone_tool.can_finish


func _toggle_remove_mode() -> void:
	var tool := get_tree().current_scene.get_node_or_null("ZoneTool") as ZoneTool
	if tool == null:
		return
	tool.set_remove_mode(not tool.is_remove_mode())
	if _remove_button != null:
		_remove_button.button_pressed = tool.is_remove_mode()


func _on_zone_painting_state_changed(has_tiles: bool, _transit_mode: bool) -> void:
	if not _painting:
		return
	if has_tiles and _transit_button == null:
		_transit_button = _add_button("Transit tiles", func():
			var tool := get_tree().current_scene.get_node_or_null("ZoneTool") as ZoneTool
			if tool:
				tool.set_transit_mode(not tool.is_transit_mode())
		)
		_transit_button.toggle_mode = true
	elif not has_tiles and _transit_button != null:
		_transit_button.queue_free()
		_transit_button = null


func _on_preview_validation_changed(can_finish: bool, status: int) -> void:
	if not _painting:
		return
	if _finish_button != null:
		_finish_button.disabled = not can_finish
	_mode_label.text = _preview_mode_label(can_finish, status)


func _preview_mode_label(can_finish: bool, status: int) -> String:
	var tool := get_tree().current_scene.get_node_or_null("ZoneTool") as ZoneTool
	var zone_type := tool.active_zone_type if tool != null else "Zone"
	if can_finish:
		return "Build: %s — Ready" % zone_type
	match status:
		SplitResult.Status.NO_PHYSICAL_DOOR_FRONTAGE:
			return "Build: %s — Add adjacent circulation or Transit" % zone_type
		SplitResult.Status.NO_VALID_FRONTAGE:
			return "Build: %s — No frontage" % zone_type
		SplitResult.Status.INSUFFICIENT_RENTABLE_SPACE:
			return "Build: %s — Insufficient rentable space" % zone_type
		_:
			return "Build: %s — Invalid zone shape" % zone_type


func _enter_door_mode(remove_mode: bool) -> void:
	_painting = false
	_door_mode = true
	_clear_buttons()
	_mode_label.text = "Build: Doors"
	var root := get_tree().current_scene
	if root:
		var zone_tool := root.get_node_or_null("ZoneTool") as ZoneTool
		if zone_tool:
			zone_tool.cancel()
			zone_tool.is_active = false
		var door_tool := root.get_node_or_null("DoorTool") as DoorTool
		if door_tool:
			door_tool.set_active(true, remove_mode)
	_add_button("Place Door", func(): _set_door_remove_mode(false))
	_add_button("Remove Door", func(): _set_door_remove_mode(true))
	_add_button("Back", func(): _exit_door_mode())


func _set_door_remove_mode(remove_mode: bool) -> void:
	var root := get_tree().current_scene
	if root:
		var door_tool := root.get_node_or_null("DoorTool") as DoorTool
		if door_tool:
			door_tool.set_active(true, remove_mode)


func _exit_door_mode() -> void:
	var root := get_tree().current_scene
	if root:
		var door_tool := root.get_node_or_null("DoorTool") as DoorTool
		if door_tool:
			door_tool.set_active(false)
	_door_mode = false
	_build_build_mode()


func _exit_paint_mode() -> void:
	var root := get_tree().current_scene
	if root:
		var tool: Node = root.get_node_or_null("ZoneTool")
		if tool and tool is ZoneTool:
			if not (tool as ZoneTool).finish():
				return
			(tool as ZoneTool).is_active = false
	_painting = false
	GameManager.enter_observe_mode()


func _configure_finish_button(button: Button) -> void:
	# Enabled buttons inherit the regular toolbar theme. The red treatment is
	# reserved for the disabled validation state.
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.5))
	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.85, 0.08, 0.08, 0.5)
	disabled_style.corner_radius_top_left = 4
	disabled_style.corner_radius_top_right = 4
	disabled_style.corner_radius_bottom_left = 4
	disabled_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("disabled", disabled_style)


func _add_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	_buttons.add_child(btn)
	return btn


func _clear_buttons() -> void:
	_finish_button = null
	_remove_button = null
	_transit_button = null
	for child in _buttons.get_children():
		child.queue_free()


func _on_mode_changed(mode: String) -> void:
	if _painting:
		return
	match mode:
		"Build": _build_build_mode()
		"Observe": _build_observe_mode()



