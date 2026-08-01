## MainGame — Root script for main_game.tscn.
## Initializes World (GridManager + floors), Camera, Simulation, Zone systems.
class_name MainGame
extends Node3D


@onready var _world: Node3D = $World
@onready var _camera_manager: CameraManager = $CameraRig
@onready var _time_manager: TimeManager = $Simulation/TimeManager
@onready var _visitor_manager: VisitorManager = $Simulation/VisitorManager
@onready var _tenant_manager: TenantManager = $Simulation/TenantManager
@onready var _economy_manager: EconomyManager = $Simulation/EconomyManager
@onready var _prestige_manager: PrestigeManager = $Simulation/PrestigeManager
@onready var _tech_tree_manager: TechTreeManager = $Simulation/TechTreeManager
@onready var _staff_manager: StaffManager = $Simulation/StaffManager
@onready var _synergy_manager: SynergyManager = $Simulation/SynergyManager
@onready var _zone_manager: ZoneManager = $World/ZoneManager
@onready var _zone_tool: ZoneTool = $ZoneTool


func _ready() -> void:
	_initialize_grid()
	_initialize_camera()
	_initialize_time()
	_initialize_visitors()
	_initialize_tenants()
	_initialize_economy()
	_initialize_prestige()
	_initialize_staff()
	_initialize_synergy()
	_initialize_zone_tool()

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

	var footprint_path := "res://resources/plots/footprints/25x25_full.txt"
	var plot := gm.create_plot(GridManager.DEFAULT_PLOT, 25, 25, footprint_path)
	if plot == null:
		push_error("MainGame: Failed to create default plot.")
		return

	var fg := plot.get_floor(GridManager.GROUND_FLOOR)
	if fg != null:
		for x in range(fg.width):
			for y in range(fg.height):
				var tile := fg.get_tile(x, y)
				if tile != null:
					tile.owned = true
					tile.floor_built = true

	_create_floor_instance(GridManager.DEFAULT_PLOT, GridManager.GROUND_FLOOR, fg)
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

	var y := _get_floor_height(floor_level)
	floor_instance.position = Vector3(0, y, 0)

	_world.add_child(floor_instance)


func _get_floor_height(level: String) -> float:
	if level == "G":
		return 0.0
	var prefix := level[0]
	var num := level.substr(1).to_int()
	return float(num) * 3.0 if prefix == "F" else -float(num) * 3.0


# ── Camera Initialization ──────────────────────────────────────────────

func _initialize_camera() -> void:
	if _camera_manager == null:
		push_error("MainGame: CameraManager not found.")
		return

	# Position camera at plot center, elevated.
	_camera_manager.global_position = Vector3(25, 15, 25)
	_camera_manager.set_position_limit(Vector3(25, 0, 25), 20.0 * GridManager.TILE_SIZE + 10.0)
	_camera_manager.floor_levels = ["G"]
	_camera_manager.current_floor_index = 0

	print("MainGame: Camera initialized at center of grid.")


# ── Time Initialization ────────────────────────────────────────────────

func _initialize_time() -> void:
	if _time_manager == null:
		push_error("MainGame: TimeManager not found.")
		return

	# Wire GameManager speed → TimeManager speed.
	GameManager.speed_changed.connect(_time_manager.set_speed)

	# Start at 1x speed.
	_time_manager.set_speed(1)
	GameManager.speed = GameManager.Speed.X1

	print("MainGame: Time system initialized — 1x speed.")


# ── Visitor Initialization ─────────────────────────────────────────────

func _initialize_visitors() -> void:
	if _visitor_manager == null:
		push_error("MainGame: VisitorManager not found.")
		return

	# Wire TimeManager.visitor_tick → VisitorManager update.
	_time_manager.visitor_tick.connect(_visitor_manager.on_visitor_tick)

	# Wire camera signals for culling.
	_camera_manager.floor_changed.connect(_visitor_manager.on_floor_changed)
	_camera_manager.zoomed.connect(_visitor_manager.on_zoom_changed)

	# Wire GridManager pathfinding graph.
	var gm: GridManager = _world.get_node("GridManager") as GridManager
	if gm:
		_visitor_manager._pathfinding_graph = gm.pathfinding_graph

	print("MainGame: Visitor system initialized — culling & tick wired.")


# ── Tenant Initialization ──────────────────────────────────────────────

func _initialize_tenants() -> void:
	if _tenant_manager == null:
		push_error("MainGame: TenantManager not found.")
		return

	_tenant_manager.initialize(_zone_manager)
	_time_manager.sim_day_passed.connect(_tenant_manager.on_sim_day_passed)

	print("MainGame: Tenant system initialized — applications & viability.")


# ── Economy Initialization ────────────────────────────────────────────

func _initialize_economy() -> void:
	if _economy_manager == null:
		push_error("MainGame: EconomyManager not found.")
		return

	_economy_manager.initialize(_zone_manager, _tenant_manager)
	_time_manager.sim_day_passed.connect(_economy_manager.on_sim_day_passed)
	_time_manager.sim_month_passed.connect(_economy_manager.on_sim_month_passed)

	print("MainGame: Economy initialized — 500K starting balance.")


# ── Prestige Initialization ────────────────────────────────────────────

func _initialize_prestige() -> void:
	if _prestige_manager == null:
		push_error("MainGame: PrestigeManager not found.")
		return

	_prestige_manager.initialize(_zone_manager, _tenant_manager, _visitor_manager)
	_time_manager.sim_month_passed.connect(func(_m: int): _prestige_manager.recalculate())

	# Wire prestige level-up to tech tree point earning.
	_prestige_manager.prestige_recalculated.connect(func(_p: int, _s: int, _q: int):
		if _tech_tree_manager:
			_tech_tree_manager.available_points = _prestige_manager.tech_points
	)

	print("MainGame: Prestige system initialized — monthly recalculation.")


# ── Staff Initialization ───────────────────────────────────────────────

func _initialize_staff() -> void:
	if _staff_manager == null:
		push_error("MainGame: StaffManager not found.")
		return

	var gm: GridManager = _world.get_node("GridManager") as GridManager
	if gm:
		_staff_manager.initialize(gm)

	_time_manager.visitor_tick.connect(_staff_manager.on_visitor_tick)

	print("MainGame: Staff system initialized — cleaners & security.")


# ── Synergy Initialization ─────────────────────────────────────────────

func _initialize_synergy() -> void:
	if _synergy_manager == null:
		push_error("MainGame: SynergyManager not found.")
		return

	var gm: GridManager = _world.get_node("GridManager") as GridManager
	if gm:
		_synergy_manager.initialize(_zone_manager, gm)

	# Recalculate synergy when zones change.
	EventBus.zone_created.connect(func(_z: String, _t: String, _c: int): _synergy_manager.recalculate())
	EventBus.zone_modified.connect(func(_z: String): _synergy_manager.recalculate())

	print("MainGame: Synergy system initialized — zone relationships.")


# ── Zone Tool Initialization ───────────────────────────────────────────

func _initialize_zone_tool() -> void:
	if _zone_tool == null:
		push_error("MainGame: ZoneTool not found.")
		return

	# ZoneTool input is handled via _unhandled_input — it's active in Build mode.
	_zone_tool.is_active = true
	_zone_tool.active_zone_type = ZoneData.ZONE_TYPE_NAMES[0]  # Retail by default.

	print("MainGame: ZoneTool initialized — Build mode active.")


# ── Save / Load ────────────────────────────────────────────────────────

func save_game(slot: int) -> void:
	var gm: GridManager = _world.get_node("GridManager") as GridManager
	var zm: ZoneManager = _world.get_node("ZoneManager") as ZoneManager
	var data := {
		"economy": _economy_manager.serialize() if _economy_manager else {},
		"grid": gm.serialize() if gm else {},
		"zones": zm.serialize() if zm else {},
		"tenants": _tenant_manager.serialize() if _tenant_manager else {},
		"visitors": _visitor_manager.serialize() if _visitor_manager else {},
		"time": _time_manager.serialize() if _time_manager else {},
		"prestige": _prestige_manager.serialize() if _prestige_manager else {},
		"staff": _staff_manager.serialize() if _staff_manager else {},
		"synergy": _synergy_manager.serialize() if _synergy_manager else {},
	}
	SaveManager.save_game(slot, data)


func load_game(slot: int) -> void:
	var data: Variant = SaveManager.load_game(slot)
	if data == null or not data is Dictionary:
		return
	var gm: GridManager = _world.get_node("GridManager") as GridManager
	var zm: ZoneManager = _world.get_node("ZoneManager") as ZoneManager
	if _economy_manager: _economy_manager.deserialize(data.get("economy", {}))
	if gm: gm.deserialize(data.get("grid", {}))
	if zm: zm.deserialize(data.get("zones", {}))
	if _tenant_manager: _tenant_manager.deserialize(data.get("tenants", {}))
	if _visitor_manager: _visitor_manager.deserialize(data.get("visitors", {}))
	if _time_manager: _time_manager.deserialize(data.get("time", {}))
	if _prestige_manager: _prestige_manager.deserialize(data.get("prestige", {}))
	if _staff_manager: _staff_manager.deserialize(data.get("staff", {}))
	if _synergy_manager: _synergy_manager.deserialize(data.get("synergy", {}))
	if gm: gm.rebuild_pathfinding()
