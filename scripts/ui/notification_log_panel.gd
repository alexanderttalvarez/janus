class_name NotificationLogPanel
extends PanelContainer

var _adapter: NotificationAdapter
var _category_filter: OptionButton
var _status_filter: OptionButton
var _entries_box: VBoxContainer


func configure(adapter: NotificationAdapter) -> void:
	_adapter = adapter


func _ready() -> void:
	custom_minimum_size = Vector2(320.0, 600.0)
	add_theme_stylebox_override("panel", _style(Color(0.04, 0.05, 0.08, 0.98), Color(0.3, 0.4, 0.55, 1.0)))
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "Notifications"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_ALL
	close.pressed.connect(_close_panel)
	header.add_child(close)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	root.add_child(filters)
	_category_filter = OptionButton.new()
	_category_filter.name = "CategoryFilter"
	_category_filter.add_item("All")
	for category: String in ["zone", "tenant", "financial", "milestone", "seasonal", "visitor", "staff", "general"]:
		_category_filter.add_item(category.capitalize())
	_category_filter.item_selected.connect(func(_index: int) -> void: _refresh_entries())
	filters.add_child(_category_filter)
	_status_filter = OptionButton.new()
	_status_filter.name = "StatusFilter"
	_status_filter.add_item("All")
	for status: String in ["unread", "read", "resolved"]:
		_status_filter.add_item(status.capitalize())
	_status_filter.item_selected.connect(func(_index: int) -> void: _refresh_entries())
	filters.add_child(_status_filter)
	var clear := Button.new()
	clear.text = "Clear"
	clear.focus_mode = Control.FOCUS_ALL
	clear.pressed.connect(_clear_read)
	filters.add_child(clear)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_entries_box = VBoxContainer.new()
	_entries_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_entries_box)
	_refresh_entries()


func _refresh_entries() -> void:
	if _entries_box == null or _adapter == null:
		return
	for child: Node in _entries_box.get_children():
		child.queue_free()
	var category: String = "" if _category_filter == null or _category_filter.selected == 0 else _category_filter.get_item_text(_category_filter.selected).to_lower()
	var status: String = "" if _status_filter == null or _status_filter.selected == 0 else _status_filter.get_item_text(_status_filter.selected).to_lower()
	var filtered: Array[Dictionary] = _adapter.entries(category, status)
	if filtered.is_empty():
		var empty := Label.new()
		empty.text = "No notifications"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_entries_box.add_child(empty)
		return
	for entry: Dictionary in filtered:
		_entries_box.add_child(_build_entry(entry))


func _build_entry(entry: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 76.0)
	panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.1, 0.15, 1.0), Color(0.2, 0.28, 0.38, 1.0)))
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	var heading := Label.new()
	heading.text = "%s  •  %s  •  %s" % [String(entry.get("category", "general")).capitalize(), String(entry.get("priority", "low")).capitalize(), String(entry.get("status", "unread")).capitalize()]
	heading.add_theme_font_size_override("font_size", 12)
	text_box.add_child(heading)
	var message := Label.new()
	message.text = String(entry.get("text", ""))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(message)
	var actions := VBoxContainer.new()
	row.add_child(actions)
	var read_button := Button.new()
	read_button.text = "Read"
	read_button.focus_mode = Control.FOCUS_ALL
	read_button.pressed.connect(func() -> void:
		_adapter.mark_read(String(entry.get("source_identity", "")))
		_refresh_entries()
	)
	actions.add_child(read_button)
	var resolve_button := Button.new()
	resolve_button.text = "Resolve"
	resolve_button.focus_mode = Control.FOCUS_ALL
	resolve_button.pressed.connect(func() -> void:
		_adapter.mark_resolved(String(entry.get("source_identity", "")))
		_refresh_entries()
	)
	actions.add_child(resolve_button)
	return panel


func _clear_read() -> void:
	if _adapter != null:
		_adapter.clear_read_resolved()
		_refresh_entries()


func _close_panel() -> void:
	var manager := get_parent() as PanelManager
	if manager != null:
		manager.close_panel(name)


func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style
