## GameManager — Central coordinator for scene transitions, game state, and simulation speed.
## Registered as autoload "GameManager" in project settings.
##
## Responsibilities:
## - Scene transitions (main menu ↔ game ↔ settings)
## - Simulation speed control (Pause, 1x, 2x, 3x)
## - Game session lifecycle (new game, load game, quit)
## - Global pause state
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

## Available simulation speeds. Index 0 = paused.
enum Speed { PAUSED = 0, X1 = 1, X2 = 2, X3 = 3 }

## Current simulation speed (0 = paused, 1-3 = multiplier).
var speed: Speed = Speed.PAUSED:
	set(value):
		speed = value
		_get_tree().paused = (value == Speed.PAUSED)
		speed_changed.emit(value)

## Path to the currently active game scene.
var current_scene: String = ""

## Whether a game session is active (not in main menu).
var is_session_active: bool = false


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


## Start a new game session. Loads the game scene.
func start_new_game(game_scene_path: String = "res://scenes/levels/main_game.tscn") -> void:
	is_session_active = true
	change_scene(game_scene_path)
	game_started.emit()


## End the current game session and return to main menu.
func end_game(main_menu_path: String = "res://scenes/screens/main_menu.tscn") -> void:
	is_session_active = false
	speed = Speed.PAUSED
	change_scene(main_menu_path)
	game_ended.emit()


## Quit the application.
func quit_game() -> void:
	get_tree().quit()


## Helper to access the SceneTree safely.
func _get_tree() -> SceneTree:
	return get_tree()
