## SaveManager — Handles saving and loading game state.
## Registered as autoload "SaveManager" in project settings.
##
## Responsibilities:
## - Serialize game state to JSON files in user://
## - Load game state from JSON files
## - Manage save slots
## - Handle settings persistence (volume, keybindings, graphics)
##
## This autoload is process mode ALWAYS.
extends Node

## Emitted when a game is saved.
signal game_saved(slot: int)

## Emitted when a game is loaded.
signal game_loaded(slot: int)

## Emitted when save data is deleted.
signal save_deleted(slot: int)

## Base directory for save files.
const SAVE_DIR := "user://saves/"

## Directory for settings.
const SETTINGS_PATH := "user://settings.cfg"

## Maximum number of save slots.
const MAX_SLOTS := 5

## File extension for save files.
const SAVE_EXT := ".json"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_save_dir()


## Ensure the save directory exists.
func _ensure_save_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		dir.make_dir("saves")


## Get the file path for a save slot.
func _slot_path(slot: int) -> String:
	return SAVE_DIR + str(slot) + SAVE_EXT


## Save the current game state to a slot.
## The caller provides a dictionary with all game state data.
func save_game(slot: int, data: Dictionary) -> Error:
	if slot < 1 or slot > MAX_SLOTS:
		push_error("SaveManager: Invalid slot %d (1-%d)." % [slot, MAX_SLOTS])
		return ERR_INVALID_PARAMETER

	var path := _slot_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Cannot write to %s." % path)
		return FileAccess.get_open_error()

	# Add metadata.
	data["meta"] = {
		"slot": slot,
		"timestamp": Time.get_unix_time_from_system(),
		"version": ProjectSettings.get_setting("application/config/version", "0.1.0"),
	}

	var json_string := JSON.stringify(data, "  ")
	file.store_string(json_string)
	file.close()

	game_saved.emit(slot)
	return OK


## Load game state from a slot. Returns the data dictionary or null.
func load_game(slot: int) -> Variant:
	if slot < 1 or slot > MAX_SLOTS:
		push_error("SaveManager: Invalid slot %d (1-%d)." % [slot, MAX_SLOTS])
		return null

	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("SaveManager: No save in slot %d." % slot)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("SaveManager: Cannot read %s." % path)
		return null

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_error := json.parse(json_string)
	if parse_error != OK:
		push_error("SaveManager: JSON parse error in slot %d: %s" % [slot, json.get_error_message()])
		return null

	game_loaded.emit(slot)
	return json.data


## Check if a save slot has data.
func has_save(slot: int) -> bool:
	if slot < 1 or slot > MAX_SLOTS:
		return false
	return FileAccess.file_exists(_slot_path(slot))


## Delete a save slot.
func delete_save(slot: int) -> Error:
	if slot < 1 or slot > MAX_SLOTS:
		return ERR_INVALID_PARAMETER

	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND

	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		return ERR_FILE_CANT_OPEN

	var err := dir.remove(str(slot) + SAVE_EXT)
	if err == OK:
		save_deleted.emit(slot)
	return err


## Get metadata for a save slot without loading the full data.
func get_save_meta(slot: int) -> Variant:
	if not has_save(slot):
		return null

	var data := load_game(slot)
	if data and data.has("meta"):
		return data["meta"]
	return null


## Save a settings value.
func save_setting(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	# Load existing settings if any.
	config.load(SETTINGS_PATH)
	config.set_value(section, key, value)
	config.save(SETTINGS_PATH)


## Load a settings value. Returns default_value if not found.
func load_setting(section: String, key: String, default_value: Variant = null) -> Variant:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		return default_value
	return config.get_value(section, key, default_value)
