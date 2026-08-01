## MainGame — Root script for main_game.tscn.
## Initializes World (GridManager + floors), Camera, and shader integration.
class_name MainGame
extends Node3D


@onready var _world: Node3D = $World
@onready var _camera_manager: CameraManager = $CameraRig


func _ready() -> void:
	_initialize_grid()
	_initialize_camera()
	_initialize_heatmap()

	# Deferred state initialization — now that the scene is loaded.
	GameManager.ui_mode = GameManager.UIMode.BUILD
	GameManager.wall_mode = GameManager.WallMode.CUTAWAY
	GameManager.session_ready = true

	print("MainGame: Ready.")


# ── Grid Initialization ────────────────────────────────────────────────

func _initialize_grid() -> void:
	var gm := _world.get_node("GridManager") as GridManager
	if gm == null:
		push_error("MainGame: GridManager not found under World.")
		return

	# Create default plot with 25x25 footprint.
	var footprint_path := "res://resources/plots/footprints/25x25_full.txt"
	var plot := gm.create_plot(GridManager.DEFAULT_PLOT, 25, 25, footprint_path)
	if plot == null:
		push_error("MainGame: Failed to create default plot.")
		return

	# Mark all tiles on ground floor as owned + floor_built.
	var fg := plot.get_floor(GridManager.GROUND_FLOOR)
	if fg != null:
		for x in range(fg.width):
			for y in range(fg.height):
				var tile := fg.get_tile(x, y)
				if tile != null:
					tile.owned = true
					tile.floor_built = true

	# Create floor scene instance.
	_create_floor_instance(GridManager.DEFAULT_PLOT, GridManager.GROUND_FLOOR, fg)

	# Build pathfinding graph.
	gm.rebuild_pathfinding()
	print("MainGame: Grid initialized — plot_0, 25×25, all tiles owned.")


func _create_floor_instance(plot_id: String, floor_level: String, _floor_grid: FloorGrid) -> void:
	var floor_scene := load("res://scenes/world/floor.tscn") as PackedScene
	if floor_scene == null:
		push_error("MainGame: Cannot load floor.tscn.")
		return

	var floor_instance := floor_scene.instantiate() as Floor
	floor_instance.name = "floor_%s_%s" % [plot_id, floor_level]
	floor_instance.plot_id = plot_id
	floor_instance.floor_level = floor_level

	# Position the floor at the correct Y height.
	var y := _get_floor_height(floor_level)
	floor_instance.position = Vector3(0, y, 0)

	_world.add_child(floor_instance)


func _get_floor_height(level: String) -> float:
	if level == "G":
		return 0.0
	var prefix := level[0]
	var num := level.substr(1).to_int()
	var height := float(num) * 3.0
	return height if prefix == "F" else -height


# ── Camera Initialization ──────────────────────────────────────────────

func _initialize_camera() -> void:
	if _camera_manager == null:
		push_error("MainGame: CameraManager not found.")
		return

	_camera_manager.global_position = Vector3(25, 10, 25)
	var center := Vector3(25, 0, 25)
	var radius := 20.0 * GridManager.TILE_SIZE + 10.0
	_camera_manager.set_position_limit(center, radius)
	_camera_manager.floor_levels = ["G"]
	_camera_manager.current_floor_index = 0

	print("MainGame: Camera initialized at center of grid.")


# ── Heatmap Initialization ─────────────────────────────────────────────

func _initialize_heatmap() -> void:
	# HeatmapManager is instantiated via game_ui.tscn in Phase 13.
	# For Integration 1, the shader infrastructure is ready but not yet wired.
	pass
