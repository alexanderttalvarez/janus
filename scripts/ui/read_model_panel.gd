class_name ReadModelPanel
extends PanelContainer

var _panel_name: String = ""
var _model: Dictionary = {}


func configure(panel_name: String, model: Dictionary) -> void:
	_panel_name = panel_name
	_model = model.duplicate(true)


func _ready() -> void:
	custom_minimum_size = Vector2(320.0, 360.0)
	add_theme_stylebox_override("panel", _style(Color(0.04, 0.05, 0.08, 0.98), Color(0.3, 0.4, 0.55, 1.0)))
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = _panel_name.capitalize()
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_ALL
	close.pressed.connect(_close_panel)
	header.add_child(close)
	var availability: String = String(_model.get("availability", "UNAVAILABLE"))
	if availability != PresentationCoordinator.AVAILABLE:
		var unavailable := Label.new()
		unavailable.text = "Source unavailable\n" + _diagnostic_text()
		unavailable.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(unavailable)
		return
	var values: Dictionary = _model.get("values", {})
	if values.is_empty():
		var empty := Label.new()
		empty.text = "No committed values available"
		content.add_child(empty)
		return
	for key: String in _sorted_value_keys(values):
		var row := Label.new()
		row.text = "%s: %s" % [key.replace("_", " ").capitalize(), _display_value(values[key])]
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(row)


func _sorted_value_keys(values: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in values.keys():
		keys.append(String(key))
	keys.sort()
	return keys


func _display_value(value: Variant) -> String:
	if value is Array or value is Dictionary:
		return JSON.stringify(value)
	return str(value)


func _diagnostic_text() -> String:
	var diagnostics: Array = _model.get("diagnostics", [])
	return JSON.stringify(diagnostics) if not diagnostics.is_empty() else "No compatible committed snapshot."


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
