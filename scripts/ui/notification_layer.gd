class_name NotificationLayer
extends Control

signal log_requested

var _adapter: NotificationAdapter
var _toast_stack: VBoxContainer
var _toast_timer: Timer
var _last_visible_ids: Array[String] = []


func bind(adapter: NotificationAdapter) -> void:
	_adapter = adapter
	if is_node_ready():
		_refresh_toasts()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_stack = VBoxContainer.new()
	_toast_stack.name = "ToastStack"
	_toast_stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast_stack.position = Vector2(-360.0, 48.0)
	_toast_stack.size = Vector2(340.0, 420.0)
	_toast_stack.add_theme_constant_override("separation", 8)
	_toast_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_stack)
	_toast_timer = Timer.new()
	_toast_timer.name = "ToastTimer"
	_toast_timer.wait_time = 0.25
	_toast_timer.one_shot = false
	_toast_timer.timeout.connect(_on_toast_timer_timeout)
	add_child(_toast_timer)
	_toast_timer.start()
	_refresh_toasts()


func _on_toast_timer_timeout() -> void:
	if _adapter == null:
		return
	_adapter.advance_time(0.25)
	_refresh_toasts()


func _refresh_toasts() -> void:
	if _toast_stack == null or _adapter == null:
		return
	var visible_ids: Array[String] = _adapter.visible_toasts()
	if visible_ids == _last_visible_ids:
		return
	_last_visible_ids = visible_ids.duplicate()
	for child: Node in _toast_stack.get_children():
		child.queue_free()
	for source_identity: String in visible_ids:
		var entry: Dictionary = _entry_for(source_identity)
		if not entry.is_empty():
			_toast_stack.add_child(_build_toast(entry))


func _entry_for(source_identity: String) -> Dictionary:
	if _adapter == null:
		return {}
	for entry: Dictionary in _adapter.entries():
		if String(entry.get("source_identity", "")) == source_identity:
			return entry
	return {}


func _build_toast(entry: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340.0, 72.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.08, 0.12, 0.96), Color(0.35, 0.48, 0.66, 1.0)))
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	var category := Label.new()
	category.text = "%s  •  %s" % [String(entry.get("category", "General")).capitalize(), String(entry.get("priority", "low")).capitalize()]
	category.add_theme_font_size_override("font_size", 12)
	category.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0))
	text_box.add_child(category)
	var message := Label.new()
	message.text = String(entry.get("text", ""))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 14)
	text_box.add_child(message)
	var dismiss := Button.new()
	dismiss.text = "×"
	dismiss.custom_minimum_size = Vector2(28.0, 28.0)
	dismiss.focus_mode = Control.FOCUS_ALL
	dismiss.pressed.connect(func() -> void: _adapter.dismiss_toast(String(entry.get("source_identity", ""))))
	row.add_child(dismiss)
	return panel


func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style
