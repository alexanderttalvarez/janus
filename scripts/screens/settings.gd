## Settings — Root script for settings.tscn
## Handles audio volume sliders with persistence via SaveManager.
extends Control


func _ready() -> void:
	_setup_sliders()
	$VBoxContainer/BackButton.pressed.connect(_on_back)


func _setup_sliders() -> void:
	var master := $VBoxContainer/MasterVolume as HSlider
	var music := $VBoxContainer/MusicVolume as HSlider
	var sfx := $VBoxContainer/SFXVolume as HSlider
	var ambient := $VBoxContainer/AmbientVolume as HSlider

	master.value = SaveManager.load_setting("audio", "master_volume", 1.0)
	music.value = SaveManager.load_setting("audio", "music_volume", 0.8)
	sfx.value = SaveManager.load_setting("audio", "sfx_volume", 1.0)
	ambient.value = SaveManager.load_setting("audio", "ambient_volume", 0.6)

	master.value_changed.connect(_on_bus_volume_changed.bind("Master"))
	music.value_changed.connect(_on_bus_volume_changed.bind("Music"))
	sfx.value_changed.connect(_on_bus_volume_changed.bind("SFX"))
	ambient.value_changed.connect(_on_bus_volume_changed.bind("Ambient"))


func _on_bus_volume_changed(value: float, bus_name: String) -> void:
	AudioManager.set_bus_volume(bus_name, value)
	SaveManager.save_setting("audio", bus_name.to_lower() + "_volume", value)


func _on_back() -> void:
	GameManager.change_scene("res://scenes/screens/main_menu.tscn")
