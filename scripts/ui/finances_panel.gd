## Placeholder panel scripts — each reads data from simulation managers.
## All use hybrid data flow: read initial state + EventBus updates.

class_name FinancesPanel
extends PanelContainer

func _ready() -> void:
	var vbox := VBoxContainer.new()
	var title := Label.new(); title.text = "Finances"
	var bal := Label.new(); bal.name = "Balance"
	var rent := Label.new(); rent.name = "Rent"
	vbox.add_child(title); vbox.add_child(bal); vbox.add_child(rent)
	add_child(vbox)
	_refresh()

func _refresh() -> void:
	var root := get_tree().current_scene
	if root:
		var em := root.get_node_or_null("Simulation/EconomyManager")
		if em and em is EconomyManager:
			($VBoxContainer/Balance as Label).text = "Balance: %,d K" % (em as EconomyManager).balance
