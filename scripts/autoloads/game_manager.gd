## GameManager — Central coordinator for scene transitions, game state, simulation speed,
## and UI mode management.
## Registered as autoload "GameManager" in project settings.
##
## Responsibilities:
## - Scene transitions (main menu ↔ game ↔ settings)
## - Simulation speed control (Pause, 1x, 2x, 3x)
## - Game session lifecycle (new game, load game, quit)
## - Global pause state
## - UI mode tracking (Build, Observe, EditZone)
## - Wall visualization mode (Cutaway, Partial, Full)
##
## This autoload is process mode ALWAYS so it runs while paused.
extends Node

## Emitted when the active scene changes.
signal scene_changed(scene_path: String)

## Emitted when the global pause state changes.
signal game_paused(is_paused: bool)

## Emitted when simulation speed changes.
signal speed_changed(speed: int)

## Emitted when a new game session starts.
signal game_started

## Emitted when the current game session ends.
signal game_ended

## Emitted when the UI mode changes.
signal ui_mode_changed(mode: String)

## Emitted when the wall visualization mode changes.
signal wall_mode_changed(mode: String)

## Available simulation speeds. Index 0 = paused.
enum Speed { PAUSED = 0, X1 = 1, X2 = 2, X3 = 3 }

## UI interaction modes (integer indices).
enum UIMode { BUILD = 0, OBSERVE = 1, EDIT_ZONE = 2 }

## Human-readable names for UI modes (matches enum indices).
const UI_MODE_NAMES: Array[String] = ["Build", "Observe", "EditZone"]

## Wall visualization modes (integer indices).
enum WallMode { CUTAWAY = 0, PARTIAL = 1, FULL = 2 }

## Human-readable names for wall modes (matches enum indices).
const WALL_MODE_NAMES: Array[String] = ["Cutaway", "Partial", "Full"]

## Current simulation speed (0 = paused, 1-3 = multiplier).
var speed: Speed = Speed.PAUSED:
	set(value):
		speed = value
		_get_tree().paused = (value == Speed.PAUSED)
		speed_changed.emit(value)

## Current UI mode.
var ui_mode: UIMode = UIMode.BUILD:
	set(value):
		ui_mode = value
		ui_mode_changed.emit(UI_MODE_NAMES[value])

## Current wall visualization mode.
var wall_mode: WallMode = WallMode.CUTAWAY:
	set(value):
		wall_mode = value
		wall_mode_changed.emit(WALL_MODE_NAMES[value])
		RenderingServer.global_shader_parameter_set("wall_mode", value)

## Path to the currently active game scene.
var current_scene: String = ""

## Whether a game session is active (not in main menu).
var is_session_active: bool = false

## Current heatmap mode (empty = none active).
var active_heatmap: String = ""

## Currently open informational panels (max 3).
var open_panels: Array[String] = []


func _ready() -> void:
	# Ensure this autoload processes even when the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


## Change to a new scene by file path.
func change_scene(path: String) -> void:
	current_scene = path
	get_tree().change_scene_to_file(path)
	scene_changed.emit(path)


## Set the global pause state.
func set_paused(paused: bool) -> void:
	if paused:
		speed = Speed.PAUSED
	else:
		speed = Speed.X1


## Cycle simulation speed forward: Pause → 1x → 2x → 3x → Pause.
func cycle_speed() -> void:
	speed = wrapi(speed + 1, Speed.PAUSED, Speed.X3 + 1) as Speed


## Set simulation speed directly.
func set_speed(new_speed: Speed) -> void:
	speed = new_speed


## Cycle wall visualization mode: Cutaway → Partial → Full → Cutaway.
func cycle_wall_mode() -> void:
	wall_mode = wrapi(wall_mode + 1, WallMode.CUTAWAY, WallMode.FULL + 1) as WallMode


## Set wall visualization mode directly.
func set_wall_mode(mode: WallMode) -> void:
	wall_mode = mode


## Set UI mode.
func set_ui_mode(mode: UIMode) -> void:
	ui_mode = mode


## Enter Build mode.
func enter_build_mode() -> void:
	ui_mode = UIMode.BUILD


## Enter Observe mode.
func enter_observe_mode() -> void:
	ui_mode = UIMode.OBSERVE


## Enter Edit Zone mode.
func enter_edit_zone_mode() -> void:
	ui_mode = UIMode.EDIT_ZONE


## Exit current mode (returns to Observe).
func exit_current_mode() -> void:
	ui_mode = UIMode.OBSERVE


## Toggle a heatmap mode. If already active, deactivate it.
func toggle_heatmap(mode: String) -> void:
	if active_heatmap == mode:
		active_heatmap = ""
	else:
		active_heatmap = mode


## Open an informational panel (max 3).
func open_panel(panel_name: String) -> bool:
	if open_panels.has(panel_name):
		return false
	if open_panels.size() >= 3:
		return false
	open_panels.append(panel_name)
	return true


## Close an informational panel.
func close_panel(panel_name: String) -> void:
	open_panels.erase(panel_name)


## Close all open panels.
func close_all_panels() -> void:
	open_panels.clear()


## Start a new game session. Loads the game scene.
func start_new_game(game_scene_path: String = "res://scenes/levels/main_game.tscn") -> void:
	is_session_active = true
	open_panels.clear()
	active_heatmap = ""
	ui_mode = UIMode.BUILD
	wall_mode = WallMode.CUTAWAY
	change_scene(game_scene_path)
	game_started.emit()


## End the current game session and return to main menu.
func end_game(main_menu_path: String = "res://scenes/screens/main_menu.tscn") -> void:
	is_session_active = false
	speed = Speed.PAUSED
	open_panels.clear()
	active_heatmap = ""
	change_scene(main_menu_path)
	game_ended.emit()


## Quit the application.
func quit_game() -> void:
	get_tree().quit()


## Helper to access the SceneTree safely.
func _get_tree() -> SceneTree:
	return get_tree()
