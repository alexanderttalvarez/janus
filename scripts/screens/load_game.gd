## LoadGame — Root script for load_game.tscn
## Displays save slots and allows loading a saved game.
extends Control


func _ready() -> void:
	_populate_slots()
	$VBoxContainer/BackButton.pressed.connect(_on_back)


func _populate_slots() -> void:
	for i in range(1, SaveManager.MAX_SLOTS + 1):
		var slot_node: Button = $VBoxContainer.get_node("Slot%d" % i)
		if SaveManager.has_save(i):
			var meta: Variant = SaveManager.get_save_meta(i)
			if meta and meta is Dictionary:
				slot_node.text = "Slot %d — %s" % [i, meta.get("version", "???")]
			else:
				slot_node.text = "Slot %d — Saved" % i
			slot_node.pressed.connect(_on_load_slot.bind(i))
			slot_node.disabled = false
		else:
			slot_node.text = "Slot %d — Empty" % i
			slot_node.disabled = true


func _on_load_slot(slot: int) -> void:
	var data: Variant = SaveManager.load_game(slot)
	if data != null:
		GameManager.start_new_game()


func _on_back() -> void:
	GameManager.change_scene("res://scenes/screens/main_menu.tscn")
