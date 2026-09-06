class_name FinancesPanel
extends PanelContainer

var _model: Dictionary = {}


func configure_model(model: Dictionary) -> void:
	_model = model.duplicate(true)
	if is_node_ready():
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	var balance: Label = get_node_or_null("VBoxContainer/Balance") as Label
	var rent: Label = get_node_or_null("VBoxContainer/Rent") as Label
	var availability: String = String(_model.get("availability", "UNAVAILABLE"))
	if availability != "AVAILABLE":
		if balance != null:
			balance.text = "Balance: unavailable"
		if rent != null:
			rent.text = "Rent income: unavailable"
		return
	var values: Dictionary = _model.get("values", {})
	if balance != null:
		balance.text = "Balance: %s K" % _format_integer(int(values.get("balance", 0)))
	if rent != null:
		rent.text = "Rent income: %s K" % _format_integer(int(values.get("rent_income", 0)))


func _format_integer(value: int) -> String:
	var raw: String = str(value)
	if abs(value) < 1000:
		return raw
	var split_at: int = raw.length() - 3
	return raw.substr(0, split_at) + "," + raw.substr(split_at)
