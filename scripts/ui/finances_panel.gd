class_name FinancesPanel
extends PanelContainer


func _ready() -> void:
	_refresh()
	EventBus.money_changed.connect(_on_money_changed)


func _refresh() -> void:
	_update_balance()
	_update_rent()


func _update_balance() -> void:
	var root := get_tree().current_scene
	if root:
		var em := root.get_node_or_null("Simulation/EconomyManager")
		if em and em is EconomyManager:
			($VBoxContainer/Balance as Label).text = "Balance: %d K" % (em as EconomyManager).balance


func _update_rent() -> void:
	($VBoxContainer/Rent as Label).text = "Rent Income: 0 K"


func _on_money_changed(balance: int, _delta: int) -> void:
	($VBoxContainer/Balance as Label).text = "Balance: %d K" % balance
