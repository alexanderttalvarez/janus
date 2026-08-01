## GameUI — Root script for game_ui.tscn. Registers panels with PanelManager.
class_name GameUI
extends Control


func _ready() -> void:
	var pm := $PanelLayer/PanelManager as PanelManager
	if pm:
		pm._panel_registry["finances"] = load("res://scenes/ui/finances_panel.tscn")
		pm._panel_registry["visitors"] = load("res://scenes/ui/visitors_panel.tscn")

	# Keyboard shortcuts for panels.
	pass
