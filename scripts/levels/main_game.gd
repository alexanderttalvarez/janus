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
@onready var _wall_manager: WallManager = $World/WallManager
@onready var _traffic_manager: TrafficManager = $World/TrafficManager
var _district_runtime: DistrictRuntime
var _projection_coordinator: ProjectionCoordinator
var _public_realm_projection: PublicRealmProjection
var _camera_gateway_projection: CameraGatewayProjection
var _traffic_topology: TrafficTopology
var _legacy_grid_projection: RefCounted
var _parcel_label_renderer: ParcelLabelRenderer
var _zone_label_renderer: ZoneLabelRenderer


func _ready() -> void:
	_initialize_grid()
	_initialize_parcel_label_renderer()
	_initialize_zone_label_renderer()
	_initialize_camera()
	_initialize_time()
	_initialize_visitors()
	_initialize_tenants()
	_initialize_economy()
	_initialize_prestige()
	_initialize_staff()
	_initialize_synergy()
	_initialize_district_runtime()
	_initialize_projection()
	_initialize_zone_tool()
	_initialize_walls()

	# Deferred state initialization — now that the scene is loaded.
	# Start in the clean Observe view; zone buttons explicitly enter Build mode.
	GameManager.ui_mode = GameManager.UIMode.OBSERVE
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
				# The default built floor is the public circulation field. Zone
				# commits carve Tenant/Transit space out of this field explicitly.
				tile.element = GridTile.TileElement.CIRCULATION

	var adapters_script: Script = load("res://scripts/district/district_legacy_adapters.gd")
	var exterior_access: RefCounted = adapters_script.LegacyExteriorAccessAdapter.new()
	exterior_access.initialize(gm)
	exterior_access.preserve_frontage(GridManager.DEFAULT_PLOT, GridManager.GROUND_FLOOR)

	gm.rebuild_pathfinding()
	print("MainGame: Grid initialized — plot_0, 25×25, all tiles owned.")


func _initialize_district_runtime() -> void:
	var bootstrap_script: Script = load("res://scripts/district/district_legacy_adapters.gd")
	var bootstrap: RefCounted = bootstrap_script.LegacyLayoutBootstrapAdapter.new()
	var bootstrap_result: Dictionary = bootstrap.create_legacy_snapshot()
	if not bool(bootstrap_result.get("valid", false)):
		push_error("MainGame: District layout bootstrap failed.")
		return
	var snapshot: ResolvedDistrictSnapshot = bootstrap_result.get("snapshot") as ResolvedDistrictSnapshot
	_district_runtime = load("res://scripts/district/district_runtime.gd").new() as DistrictRuntime
	_district_runtime.name = "DistrictRuntime"
	add_child(_district_runtime)

	var ports_script: Script = load("res://scripts/district/district_runtime_ports.gd")
	var ports: DistrictRuntimePorts.DistrictRuntimePortsBundle = ports_script.DistrictRuntimePortsBundle.new()
	var economy_port: DistrictRuntimePorts.EconomyManagerPort = ports_script.EconomyManagerPort.new()
	var zone_port: DistrictRuntimePorts.ZoneManagerPort = ports_script.ZoneManagerPort.new()
	var progression_port: DistrictRuntimePorts.ProgressionManagerPort = ports_script.ProgressionManagerPort.new()
	economy_port.initialize(_economy_manager)
	zone_port.initialize(_zone_manager)
	progression_port.initialize(_prestige_manager, _tech_tree_manager)
	ports.initialize(economy_port, zone_port, progression_port)
	_district_runtime.configure_ports(ports)
	var session_result: Dictionary = _district_runtime.create_session(snapshot)
	if not bool(session_result.get("valid", false)):
		push_error("MainGame: District Runtime session creation failed.")
		return

	var projection: RefCounted = bootstrap_script.LegacyGridProjectionAdapter.new()
	projection.initialize(_world.get_node("GridManager") as GridManager, snapshot)
	_legacy_grid_projection = projection
	_district_runtime.subscribe_committed(Callable(projection, "on_district_committed"))
	projection.project_state(_district_runtime.get_state(), snapshot)


func _initialize_projection() -> void:
	if _district_runtime == null or not _district_runtime.has_session():
		push_error("MainGame: District Runtime is required for projection.")
		return
	var metrics: ProjectionMetrics = load("res://scripts/projection/projection_metrics.gd").new() as ProjectionMetrics
	metrics.identity = "main_game_projection_metrics"
	metrics.revision = 1
	metrics.grid_unit_size = GridManager.TILE_SIZE
	metrics.floor_height = GridManager.FLOOR_HEIGHT
	metrics.origin = Vector3.ZERO
	_projection_coordinator = load("res://scripts/projection/projection_coordinator.gd").new() as ProjectionCoordinator
	_projection_coordinator.name = "ProjectionCoordinator"
	_world.add_child(_projection_coordinator)
	var configuration: Dictionary = _projection_coordinator.configure(_district_runtime, metrics)
	if not bool(configuration.get("valid", false)):
		push_error("MainGame: Projection Coordinator configuration failed.")
		return
	var projection_result: Dictionary = _projection_coordinator.rebuild()
	if not bool(projection_result.get("valid", false)):
		push_error("MainGame: Initial projection build failed.")
	_public_realm_projection = load("res://scripts/public_realm/public_realm_projection.gd").new() as PublicRealmProjection
	var public_configuration: Dictionary = _public_realm_projection.initialize(_district_runtime, _projection_coordinator, metrics)
	if not bool(public_configuration.get("valid", false)):
		push_error("MainGame: Public-realm projection configuration failed.")
		return
	var public_result: Dictionary = _public_realm_projection.rebuild()
	if not bool(public_result.get("valid", false)):
		push_error("MainGame: Initial public-realm projection build failed.")
		return
	_camera_gateway_projection = load("res://scripts/camera/camera_gateway_projection.gd").new() as CameraGatewayProjection
	var camera_gateway_setup: Dictionary = _camera_gateway_projection.initialize(_district_runtime, _public_realm_projection, _camera_manager, metrics)
	if not bool(camera_gateway_setup.get("valid", false)):
		push_error("MainGame: Camera/gateway projection configuration failed.")
		return
	var camera_gateway_result: Dictionary = _camera_gateway_projection.rebuild()
	if not bool(camera_gateway_result.get("valid", false)):
		push_error("MainGame: Initial camera/gateway projection build failed: %s" % camera_gateway_result.get("diagnostics", []))
		return
	_traffic_topology = load("res://scripts/traffic/traffic_topology.gd").new() as TrafficTopology
	_traffic_topology.name = "TrafficTopology"
	_world.add_child(_traffic_topology)
	var traffic_setup: Dictionary = _traffic_topology.initialize(_district_runtime, _public_realm_projection, metrics)
	if not bool(traffic_setup.get("valid", false)):
		push_error("MainGame: Traffic topology configuration failed.")
		return
	_traffic_topology.road_graph_published.connect(_on_road_graph_published)
	if _traffic_manager != null and not GameManager.speed_changed.is_connected(_traffic_manager.set_control_time_scale):
		GameManager.speed_changed.connect(_traffic_manager.set_control_time_scale)
		_traffic_manager.set_control_time_scale(float(GameManager.speed))
	var traffic_result: Dictionary = _traffic_topology.rebuild()
	if not bool(traffic_result.get("valid", false)):
		push_error("MainGame: Initial traffic topology build failed: %s" % traffic_result.get("diagnostics", []))
		return
	_on_road_graph_published(traffic_result.get("snapshot") as RoadGraphSnapshot)


func _initialize_parcel_label_renderer() -> void:
	if _zone_manager == null:
		push_error("MainGame: ZoneManager not found for ParcelLabelRenderer.")
		return
	_parcel_label_renderer = ParcelLabelRenderer.new()
	_parcel_label_renderer.name = "ParcelLabelRenderer"
	_parcel_label_renderer.zone_manager = _zone_manager
	_parcel_label_renderer.camera_manager = _camera_manager
	_world.add_child(_parcel_label_renderer)


func _initialize_zone_label_renderer() -> void:
	if _zone_manager == null:
		push_error("MainGame: ZoneManager not found for ZoneLabelRenderer.")
		return
	_zone_label_renderer = ZoneLabelRenderer.new()
	_zone_label_renderer.name = "ZoneLabelRenderer"
	_zone_label_renderer.zone_manager = _zone_manager
	_zone_label_renderer.camera_manager = _camera_manager
	_world.add_child(_zone_label_renderer)


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

	# Center camera on the 25-tile grid (tiles at 0..24, center at 12.5).
	_camera_manager.global_position = Vector3(12.5, 20, 12.5)
	# Allow camera to move well beyond the grid edges.
	_camera_manager.set_position_limit(Vector3.ZERO, 50.0)
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
		_visitor_manager._grid_manager = gm
		_visitor_manager._pathfinding_graph = gm.pathfinding_graph

	print("MainGame: Visitor system initialized — culling & tick wired.")


# ── Tenant Initialization ──────────────────────────────────────────────

func _initialize_tenants() -> void:
	if _tenant_manager == null:
		push_error("MainGame: TenantManager not found.")
		return
	if _zone_manager != null and not _zone_manager.permits_tenant_lifecycle():
		print("MainGame: Tenant lifecycle disabled for DEBUG_IMMEDIATE assignment mode.")
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

	# ZoneTool starts INACTIVE: painting only begins when the player presses a
	# zone-type button in the BottomToolbar (which sets is_active = true).
	_zone_tool.is_active = false
	_zone_tool.active_zone_type = ZoneData.ZONE_TYPE_NAMES[0]  # Retail by default.

	print("MainGame: ZoneTool initialized — idle until a zone type is chosen.")


# ── Walls ──────────────────────────────────────────────────────────────

func _on_road_graph_published(snapshot: RoadGraphSnapshot) -> void:
	if _traffic_manager == null or snapshot == null:
		return
	_traffic_manager.set_road_graph(snapshot)
	print("MainGame: Traffic topology bound — graph revision %d, %d lanes." % [snapshot.graph_revision, snapshot.lanes.size()])


func _initialize_walls() -> void:
	if _wall_manager == null:
		push_error("MainGame: WallManager not found.")
		return

	_wall_manager.rebuild()

	print("MainGame: Walls initialized — floor perimeter generated.")


# ── Input ──────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# Cycle wall visualization mode: Cutaway → Partial → Full → Cutaway.
	if event.is_action_pressed("cycle_wall_mode"):
		GameManager.cycle_wall_mode()


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
		"district_state": _district_runtime.get_state() if _district_runtime and _district_runtime.has_session() else {},
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
	if _district_runtime and _district_runtime.has_session() and data.has("district_state"):
		var district_load: Dictionary = _district_runtime.replace_session(_district_runtime.get_snapshot(), data["district_state"])
		if bool(district_load.get("valid", false)) and _legacy_grid_projection:
			_legacy_grid_projection.project_state(_district_runtime.get_state(), _district_runtime.get_snapshot())
		if bool(district_load.get("valid", false)) and _projection_coordinator:
			_projection_coordinator.rebuild()
		if bool(district_load.get("valid", false)) and _public_realm_projection:
			_public_realm_projection.rebuild()
		if bool(district_load.get("valid", false)) and _camera_gateway_projection:
			_camera_gateway_projection.rebuild()
		if bool(district_load.get("valid", false)) and _traffic_topology:
			_traffic_topology.rebuild()
	if gm: gm.rebuild_pathfinding()
	if _parcel_label_renderer:
		_parcel_label_renderer.hydrate_active_floor()
	if _zone_label_renderer:
		_zone_label_renderer.hydrate_active_floor()
