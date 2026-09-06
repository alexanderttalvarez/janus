class_name VisitorsPanel
extends PanelContainer

var _model: Dictionary = {}


func configure_model(model: Dictionary) -> void:
	_model = model.duplicate(true)
	if is_node_ready():
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	var availability: String = String(_model.get("availability", "UNAVAILABLE"))
	var values: Dictionary = _model.get("values", {})
	var count: Label = get_node_or_null("VBoxContainer/Count") as Label
	var arrivals: Label = get_node_or_null("VBoxContainer/Arrivals") as Label
	var satisfaction: Label = get_node_or_null("VBoxContainer/Satisfaction") as Label
	var status: Label = get_node_or_null("VBoxContainer/Status") as Label
	if availability != "AVAILABLE":
		if count != null:
			count.text = "Active: unavailable"
		if arrivals != null:
			arrivals.text = "Daily arrivals: unavailable"
		if satisfaction != null:
			satisfaction.text = "Satisfaction: unavailable"
		if status != null:
			status.text = "Source unavailable"
		return
	if count != null:
		count.text = "Active: %d" % int(values.get("current_visitors", 0))
	if arrivals != null:
		arrivals.text = "Daily arrivals: %d" % int(values.get("daily_arrivals", 0))
	if satisfaction != null:
		satisfaction.text = "Satisfaction: unavailable"
	if status != null:
		status.text = "Committed visitor metrics"
