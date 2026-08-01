## MainMenu — Root script for main_menu.tscn
## Handles navigation to New Game, Load Game, Settings, and Quit.
extends Control


func _ready() -> void:
	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game)
	$VBoxContainer/LoadGameButton.pressed.connect(_on_load_game)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit)


func _on_new_game() -> void:
	GameManager.start_new_game()


func _on_load_game() -> void:
	GameManager.change_scene("res://scenes/screens/load_game.tscn")


func _on_settings() -> void:
	GameManager.change_scene("res://scenes/screens/settings.tscn")


func _on_quit() -> void:
	GameManager.quit_game()
