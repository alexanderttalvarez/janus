## BottomToolbar — Contextual toolbar at the bottom of the screen.
class_name BottomToolbar
extends Control


@onready var _mode_label: Label = $ModeLabel
@onready var _buttons: HBoxContainer = $Buttons
var _painting: bool = false
var _construction_mode: bool = false
var _construction_confirm_button: Button
var _finish_button: Button
var _remove_button: Button
var _transit_button: Button
var _door_mode: bool = false
var _notification_button: Button


func _ready() -> void:
	# Reserve a dedicated status row above the action rail so diagnostics never
	# cover the world preview or get hidden behind dynamic buttons.
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -80.0
	offset_bottom = 0.0
	_mode_label.position = Vector2(8.0, 4.0)
	_mode_label.size = Vector2(maxf(0.0, size.x - 16.0), 28.0)
	_buttons.position = Vector2(8.0, 40.0)
	_buttons.size = Vector2(maxf(0.0, size.x - 16.0), 36.0)
	GameManager.ui_mode_changed.connect(_on_mode_changed)
	if GameManager.ui_mode == GameManager.UIMode.OBSERVE:
		_build_observe_mode()
	else:
		_build_build_mode()


func _build_build_mode() -> void:
	_clear_buttons()
	_door_mode = false
	_mode_label.text = "Build"
	_add_button("Acquire Ground Space", func(): _enter_construction_mode(ConstructionTool.MODE_ACQUIRE))
	_add_button("Build Corridor", func(): _enter_construction_mode(ConstructionTool.MODE_CORRIDOR))
	for zone_type: String in ZoneData.ZONE_TYPE_NAMES:
		_add_button(zone_type, func(): _enter_paint_mode(zone_type))
	_add_button("Remove", func(): _enter_remove_mode())
	_add_button("Place Door", func(): _enter_door_mode(false))
	_add_button("Remove Door", func(): _enter_door_mode(true))
	_add_button("Back", func(): GameManager.enter_observe_mode())


func _build_observe_mode() -> void:
	_clear_buttons()
	_mode_label.text = "Observe"
	_add_button("Build Zones", func(): GameManager.enter_build_mode())
	_add_button("Finances", func(): _open_primary_panel("finances"))
	_add_button("Prestige", func(): _open_primary_panel("prestige"))
	_add_button("Tenants", func(): _open_primary_panel("tenants"))
	_add_button("Visitors", func(): _open_primary_panel("visitors"))
	_add_button("Metrics", func(): _open_primary_panel("metrics"))
	_notification_button = _add_button("Notifications", func(): _open_notification_log())


func set_notification_unresolved(unresolved: bool) -> void:
	if _notification_button == null:
		return
	_notification_button.text = "Notifications •" if unresolved else "Notifications"
	_notification_button.tooltip_text = "High-priority notification requires attention" if unresolved else "Open notification log"


func _open_primary_panel(panel_name: String) -> void:
	var scene_root: Node = get_tree().current_scene
	var presentation_root: Node = scene_root.get_node_or_null("GameUI") if scene_root != null else null
	if presentation_root != null and presentation_root.has_method("open_primary_panel"):
		presentation_root.call("open_primary_panel", panel_name)


func _open_notification_log() -> void:
	var scene_root: Node = get_tree().current_scene
	var presentation_root: Node = scene_root.get_node_or_null("GameUI") if scene_root != null else null
	if presentation_root != null and presentation_root.has_method("open_notification_log"):
		presentation_root.call("open_notification_log")


func _enter_paint_mode(zone_type: String) -> void:
	_deactivate_construction_tool()
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
			(tool as ZoneTool).set_none_mode(false)
			(tool as ZoneTool).is_active = true
	_remove_button = _add_button("Remove", func(): _toggle_remove_mode())
	_remove_button.toggle_mode = true
	_configure_selected_toggle_button(_remove_button)
	_finish_button = _add_button("Finish Zone", func(): _exit_paint_mode())
	_configure_finish_button(_finish_button)
	_add_button("Cancel", func(): _cancel_paint_mode())
	if root:
		var zone_tool := root.get_node_or_null("ZoneTool") as ZoneTool
		if zone_tool:
			_finish_button.disabled = not zone_tool.can_finish


func _enter_construction_mode(mode: String) -> void:
	_painting = false
	_door_mode = false
	_construction_mode = true
	_clear_buttons()
	var root: Node = get_tree().current_scene
	if root == null:
		_build_build_mode()
		return
	var zone_tool: ZoneTool = root.get_node_or_null("ZoneTool") as ZoneTool
	if zone_tool != null:
		zone_tool.cancel()
		zone_tool.is_active = false
	var door_tool: DoorTool = root.get_node_or_null("DoorTool") as DoorTool
	if door_tool != null:
		door_tool.set_active(false)
	var construction_tool: ConstructionTool = root.get_node_or_null("ConstructionTool") as ConstructionTool
	if construction_tool == null or not construction_tool.activate(mode):
		_build_build_mode()
		return
	if not construction_tool.preview_changed.is_connected(_on_construction_preview_changed):
		construction_tool.preview_changed.connect(_on_construction_preview_changed)
	_mode_label.text = construction_tool.get_status_text()
	_construction_confirm_button = _add_button("Confirm", func(): _confirm_construction())
	_construction_confirm_button.disabled = true
	_configure_finish_button(_construction_confirm_button)
	_add_button("Cancel Selection", func(): construction_tool.clear_selection())
	_add_button("Back", func(): _exit_construction_mode())


func _on_construction_preview_changed(can_confirm: bool, status_text: String, _result: Dictionary) -> void:
	if not _construction_mode:
		return
	_mode_label.text = status_text
	if _construction_confirm_button != null:
		_construction_confirm_button.disabled = not can_confirm


func _confirm_construction() -> void:
	var root: Node = get_tree().current_scene
	var construction_tool: ConstructionTool = root.get_node_or_null("ConstructionTool") as ConstructionTool if root != null else null
	if construction_tool == null:
		return
	var result: Dictionary = construction_tool.confirm_selected()
	if bool(result.get("valid", result.get("accepted", false))):
		_exit_construction_mode()


func _exit_construction_mode() -> void:
	_deactivate_construction_tool()
	_build_build_mode()


func _deactivate_construction_tool() -> void:
	var root: Node = get_tree().current_scene
	var construction_tool: ConstructionTool = root.get_node_or_null("ConstructionTool") as ConstructionTool if root != null else null
	if construction_tool != null:
		construction_tool.deactivate()
	_construction_mode = false


func _enter_remove_mode() -> void:
	_enter_paint_mode(ZoneData.ZONE_TYPE_NAMES[0])
	_toggle_remove_mode()
	_mode_label.text = "Build: Remove"


func _toggle_remove_mode() -> void:
	var tool := get_tree().current_scene.get_node_or_null("ZoneTool") as ZoneTool
	if tool == null:
		return
	var enable_remove := not tool.is_none_mode()
	if enable_remove and tool.is_transit_mode():
		tool.set_transit_mode(false)
		if _transit_button != null:
			_transit_button.button_pressed = false
	tool.set_none_mode(enable_remove)
	if _remove_button != null:
		_remove_button.button_pressed = enable_remove
	_mode_label.text = "Build: Remove" if enable_remove else "Build: %s" % tool.active_zone_type


func _on_zone_painting_state_changed(has_tiles: bool, _transit_mode: bool) -> void:
	if not _painting:
		return
	var tool := get_tree().current_scene.get_node_or_null("ZoneTool") as ZoneTool
	if tool != null and tool.is_none_mode():
		if _transit_button != null:
			_transit_button.queue_free()
			_transit_button = null
		return
	if has_tiles and _transit_button == null:
		_transit_button = _add_button("Transit tiles", func():
			var transit_tool := get_tree().current_scene.get_node_or_null("ZoneTool") as ZoneTool
			if transit_tool:
				var enable_transit := not transit_tool.is_transit_mode()
				if enable_transit:
					transit_tool.set_remove_mode(false)
					transit_tool.set_none_mode(false)
					if _remove_button != null:
						_remove_button.button_pressed = false
				transit_tool.set_transit_mode(enable_transit)
				if _transit_button != null:
					_transit_button.button_pressed = enable_transit
		)
		_transit_button.toggle_mode = true
		_configure_selected_toggle_button(_transit_button)
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
		SplitResult.Status.EXISTING_DOOR_INVALIDATED:
			return "Build: %s — Blocks an existing door" % zone_type
		SplitResult.Status.INVALID_ZONE_GEOMETRY:
			if tool != null and tool.is_none_mode() and tool.preview_split_result != null and tool.preview_split_result.diagnostics.has("DISCONNECTED_ZONE"):
				return "Build: Remove — Disconnected zone"
			return "Build: %s — Invalid zone shape" % zone_type
		SplitResult.Status.NO_VALID_FRONTAGE:
			return "Build: %s — No frontage" % zone_type
		SplitResult.Status.INSUFFICIENT_RENTABLE_SPACE:
			return "Build: %s — Insufficient rentable space" % zone_type
		_:
			return "Build: %s — Invalid zone shape" % zone_type


func _enter_door_mode(remove_mode: bool) -> void:
	_deactivate_construction_tool()
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


func _cancel_paint_mode() -> void:
	var root := get_tree().current_scene
	if root:
		var tool := root.get_node_or_null("ZoneTool") as ZoneTool
		if tool != null:
			tool.cancel()
			tool.is_active = false
	_painting = false
	GameManager.enter_build_mode()


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


func _configure_selected_toggle_button(button: Button) -> void:
	var selected_style := StyleBoxFlat.new()
	var pressed_style := button.get_theme_stylebox("pressed")
	if pressed_style is StyleBoxFlat:
		selected_style = (pressed_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	else:
		selected_style.bg_color = Color(0.16, 0.19, 0.24, 1.0)
	selected_style.border_color = Color.WHITE
	selected_style.border_width_left = 3
	selected_style.border_width_top = 3
	selected_style.border_width_right = 3
	selected_style.border_width_bottom = 3
	button.add_theme_stylebox_override("pressed", selected_style)
	button.add_theme_stylebox_override("hover_pressed", selected_style.duplicate())


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
	_construction_confirm_button = null
	_finish_button = null
	_notification_button = null
	_remove_button = null
	_transit_button = null
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()


func _on_mode_changed(mode: String) -> void:
	if _painting or _construction_mode:
		return
	match mode:
		"Build": _build_build_mode()
		"Observe": _build_observe_mode()



