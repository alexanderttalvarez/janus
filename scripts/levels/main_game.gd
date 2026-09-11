## MainGame — Root script for main_game.tscn.
## Composes production content, runtime authorities, projections, and presentation systems.
class_name MainGame
extends Node3D


## Explicit scene-owned production content selection. An empty configuration is rejected.
@export var bootstrap_config: ProductionDistrictBootstrap

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
@onready var _door_tool: DoorTool = $DoorTool
@onready var _wall_manager: WallManager = $World/WallManager
@onready var _traffic_manager: TrafficManager = $World/TrafficManager
var _district_runtime: DistrictRuntime
var _manual_door_authority: ManualDoorAuthority
var _initial_snapshot: ResolvedDistrictSnapshot
var _projection_coordinator: ProjectionCoordinator
var _public_realm_projection: PublicRealmProjection
var _camera_gateway_projection: CameraGatewayProjection
var _traffic_topology: TrafficTopology
var _parcel_label_renderer: ParcelLabelRenderer
var _zone_label_renderer: ZoneLabelRenderer
var _arrival_coordinator: ArrivalCoordinator
var _traversal_topology_source: DistrictTraversalTopologySource
var _visitor_demand_authority: VisitorDemandAuthority
var _content_registry: RefCounted
var _session_bootstrap: SessionBootstrapCoordinator
var _session_gate: SessionMutationGate
var _authority_initialization_results: Dictionary = {}
var _projection_initialization_results: Dictionary = {}


func _ready() -> void:
	GameManager.session_ready = false
	GameManager.speed = GameManager.Speed.PAUSED
	if not _begin_session_bootstrap():
		return
	_initialize_parcel_label_renderer()
	_initialize_zone_label_renderer()
	_initialize_camera()
	_initialize_time()
	_initialize_visitors()
	_initialize_tenants()
	_initialize_economy()
	_initialize_progression_policy()
	_initialize_prestige()
	_initialize_staff()
	_initialize_synergy()
	_initialize_district_runtime()
	_initialize_projection()
	_initialize_service_proxies()
	_focus_camera_on_generated_floor()
	_initialize_arrivals()
	_initialize_calendar_delivery()
	_initialize_zone_tool()
	_initialize_walls()
	_initialize_save_manager()
	if not _composition_is_complete():
		_fail_session("SESSION_COMPOSITION_FAILED", "required session authorities or projections were not composed")
		return
	var authority_ready: Dictionary = _session_bootstrap.mark_authorities_ready(_authority_initialization_results)
	var projection_ready: Dictionary = _session_bootstrap.mark_projections_ready(_projection_initialization_results)
	if not bool(authority_ready.get("valid", false)) or not bool(projection_ready.get("valid", false)):
		_fail_session("SESSION_INITIALIZATION_RESULTS_INVALID", "required initialization results were invalid or mismatched")
		return
	var ready_result: Dictionary = _session_bootstrap.commit_ready()
	if not bool(ready_result.get("valid", false)):
		_fail_session(String(ready_result.get("diagnostics", [{"code": "SESSION_READY_FAILED"}])[0].get("code", "SESSION_READY_FAILED")), "session readiness barrier did not open")
		return

	# Deferred state initialization — now that the scene is loaded.
	# Start in the clean Observe view; zone buttons explicitly enter Build mode.
	GameManager.ui_mode = GameManager.UIMode.OBSERVE
	GameManager.wall_mode = GameManager.WallMode.CUTAWAY
	GameManager.session_ready = true
	GameManager.speed = GameManager.Speed.PAUSED
	_time_manager.set_speed(0)

	print("MainGame: Ready and paused.")



func _get_initial_floor_address() -> Dictionary:
	if _initial_snapshot == null:
		return {}
	var data: Dictionary = _initial_snapshot.get_data()
	var plots: Array = data.get("plots", [])
	if plots.is_empty() or not plots[0] is Dictionary:
		return {}
	var runtime_plot_id: String = String(plots[0].get("id", ""))
	for floor: Dictionary in data.get("floors", []):
		if String(floor.get("plot_id", "")) == runtime_plot_id and int(floor.get("elevation", 999)) == 0:
			return {
				"runtime_plot_id": runtime_plot_id,
				"floor_id": String(floor.get("id", "")),
				"elevation": 0,
			}
	return {}


func _get_initial_projection_plot_id() -> String:
	if _initial_snapshot == null:
		return ""
	var plots: Array = _initial_snapshot.get_data().get("plots", [])
	if plots.is_empty() or not plots[0] is Dictionary:
		return ""
	return String(plots[0].get("id", ""))


## Return the configured floor labels for the active plot in elevation order.
func _get_initial_floor_levels() -> Array[String]:
	if _initial_snapshot == null:
		return ["G"]
	var plot_id: String = _get_initial_projection_plot_id()
	var floors: Array[Dictionary] = []
	for floor: Variant in _initial_snapshot.get_data().get("floors", []):
		if floor is Dictionary and String(floor.get("plot_id", "")) == plot_id:
			floors.append(floor)
	floors.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("elevation", 0)) < int(right.get("elevation", 0))
	)
	var levels: Array[String] = []
	for floor: Dictionary in floors:
		var elevation: int = int(floor.get("elevation", 0))
		levels.append("G" if elevation == 0 else ("F%d" % elevation if elevation > 0 else "B%d" % absi(elevation)))
	return levels if not levels.is_empty() else ["G"]


func _resolve_initial_snapshot() -> ResolvedDistrictSnapshot:
	if _content_registry == null:
		push_error("MainGame: Content registry is required for layout selection.")
		return null
	var result: Dictionary = _content_registry.resolve_layout(bootstrap_config.layout_id)
	if not bool(result.get("valid", false)):
		push_error("MainGame: Explicit layout selection rejected: %s" % result.get("diagnostics", []))
		return null
	return result.get("snapshot") as ResolvedDistrictSnapshot


func _begin_session_bootstrap() -> bool:
	if bootstrap_config == null:
		push_error("MainGame: Production bootstrap configuration is required.")
		return false
	var bootstrap_validation: Dictionary = bootstrap_config.validate()
	if not bool(bootstrap_validation.get("valid", false)):
		push_error("MainGame: Production bootstrap configuration is invalid: %s" % bootstrap_validation.get("diagnostics", []))
		return false
	_content_registry = load("res://scripts/session/content_registry.gd").new()
	var production_entries: Array[Dictionary] = [{
		"layout_id": bootstrap_config.layout_id,
		"definition_path": bootstrap_config.definition_path,
	}]
	var catalog: Dictionary = _content_registry.initialize_production_catalog(production_entries)
	if not bool(catalog.get("valid", false)):
		push_error("MainGame: Approved content catalog failed validation: %s" % catalog.get("diagnostics", []))
		return false
	_session_gate = SessionMutationGate.new()
	_session_bootstrap = load("res://scripts/session/session_bootstrap_coordinator.gd").new() as SessionBootstrapCoordinator
	var gate_configuration: Dictionary = _session_bootstrap.configure_session_gate(_session_gate)
	if not bool(gate_configuration.get("valid", false)):
		push_error("MainGame: Session mutation gate configuration failed.")
		return false
	var selection: Dictionary = _session_bootstrap.begin(bootstrap_config.layout_id, _content_registry)
	if not bool(selection.get("valid", false)):
		push_error("MainGame: Session bootstrap rejected explicit content: %s" % selection.get("diagnostics", []))
		return false
	_initial_snapshot = selection.get("snapshot") as ResolvedDistrictSnapshot
	return _initial_snapshot != null


func _composition_is_complete() -> bool:
	return (
		_initial_snapshot != null
		and _district_runtime != null
		and _district_runtime.has_session()
		and _manual_door_authority != null
		and _time_manager != null
		and _projection_coordinator != null
		and _public_realm_projection != null
		and _camera_gateway_projection != null
		and _traffic_topology != null
		and _arrival_coordinator != null
		and _session_gate != null
		and _required_results_valid(_authority_initialization_results, ["economy_policy", "progression_policy", "district", "arrival", "calendar", "save"])
		and _required_results_valid(_projection_initialization_results, ["district_projection", "public_realm", "camera_gateway", "traffic"])
	)


func _fail_session(code: String, message: String) -> void:
	GameManager.session_ready = false
	GameManager.speed = GameManager.Speed.PAUSED
	if _session_bootstrap != null:
		_session_bootstrap.fail({"code": code, "message": message})
	push_error("MainGame: %s" % message)


func _initialize_district_runtime() -> void:
	if _initial_snapshot == null:
		_initial_snapshot = _resolve_initial_snapshot()
	if _initial_snapshot == null:
		return
	var snapshot: ResolvedDistrictSnapshot = _initial_snapshot
	_district_runtime = load("res://scripts/district/district_runtime.gd").new() as DistrictRuntime
	_district_runtime.name = "DistrictRuntime"
	add_child(_district_runtime)
	var gate_setup: Dictionary = _district_runtime.configure_session_gate(_session_gate)
	if not bool(gate_setup.get("valid", false)):
		_record_authority_result("district", gate_setup)
		return

	var ports_script: Script = load("res://scripts/district/district_runtime_ports.gd")
	var ports: DistrictRuntimePorts.DistrictRuntimePortsBundle = ports_script.DistrictRuntimePortsBundle.new()
	var economy_port: DistrictRuntimePorts.EconomyManagerPort = ports_script.EconomyManagerPort.new()
	var zone_port: DistrictRuntimePorts.ZoneManagerPort = ports_script.ZoneManagerPort.new()
	var progression_port: DistrictRuntimePorts.ProgressionManagerPort = ports_script.ProgressionManagerPort.new()
	economy_port.initialize(_economy_manager)
	zone_port.initialize(_zone_manager)
	progression_port.initialize(_tech_tree_manager)
	var ports_result: Dictionary = ports.initialize(economy_port, zone_port, progression_port)
	if not bool(ports_result.get("valid", false)):
		_record_authority_result("district", ports_result)
		return
	_district_runtime.configure_ports(ports)
	var session_result: Dictionary = _district_runtime.create_session(snapshot)
	_record_authority_result("district", session_result)
	if not bool(session_result.get("valid", false)):
		push_error("MainGame: District Runtime session creation failed.")
		return
	var manual_door_script: Script = load("res://scripts/walls/manual_door_authority.gd")
	_manual_door_authority = manual_door_script.new() as ManualDoorAuthority
	_manual_door_authority.configure(_district_runtime, _zone_manager)
	if not _district_runtime.district_delta_committed.is_connected(_on_district_delta_committed):
		_district_runtime.district_delta_committed.connect(_on_district_delta_committed)
	_traversal_topology_source = load("res://scripts/district/district_traversal_topology_source.gd").new() as DistrictTraversalTopologySource
	_traversal_topology_source.configure(_zone_manager)


## Inject explicit H3-owned parcel-door attachments and rebuild derived consumers.
func set_h3_door_access_attachments(records: Array[Dictionary]) -> Dictionary:
	if _traversal_topology_source == null or _district_runtime == null:
		return {"valid": false, "diagnostics": [{"code": "TRAVERSAL_TOPOLOGY_UNAVAILABLE"}]}
	var result: Dictionary = _traversal_topology_source.apply_to_runtime(_district_runtime, records)
	if not bool(result.get("valid", false)):
		return result
	var projection_result: Dictionary = _rebuild_loaded_projections()
	if not bool(projection_result.get("valid", false)):
		return projection_result
	_refresh_service_proxy_snapshot()
	return {"valid": true, "diagnostics": []}


func _initialize_projection() -> void:
	if _district_runtime == null or not _district_runtime.has_session():
		push_error("MainGame: District Runtime is required for projection.")
		return
	var metrics: ProjectionMetrics = load("res://scripts/projection/projection_metrics.gd").new() as ProjectionMetrics
	metrics.identity = bootstrap_config.projection_metrics_identity
	metrics.revision = bootstrap_config.projection_metrics_revision
	metrics.grid_unit_size = bootstrap_config.grid_unit_size
	metrics.floor_height = bootstrap_config.floor_height
	metrics.origin = bootstrap_config.origin
	var camera_metrics: Dictionary = _camera_manager.configure_projection_metrics(metrics)
	if not bool(camera_metrics.get("valid", false)):
		push_error("MainGame: Camera projection metrics configuration failed.")
		return
	var visitor_metrics: Dictionary = _visitor_manager.configure_projection_metrics(metrics)
	if not bool(visitor_metrics.get("valid", false)):
		push_error("MainGame: Visitor projection metrics configuration failed.")
		return
	_projection_coordinator = load("res://scripts/projection/projection_coordinator.gd").new() as ProjectionCoordinator
	_projection_coordinator.name = "ProjectionCoordinator"
	_world.add_child(_projection_coordinator)
	var configuration: Dictionary = _projection_coordinator.configure(_district_runtime, metrics)
	if not bool(configuration.get("valid", false)):
		push_error("MainGame: Projection Coordinator configuration failed.")
		return
	var projection_result: Dictionary = _projection_coordinator.rebuild()
	_record_projection_result("district_projection", projection_result)
	if not bool(projection_result.get("valid", false)):
		push_error("MainGame: Initial projection build failed.")
		return
	var floor_visibility_result: Dictionary = _camera_manager.configure_floor_visibility(_projection_coordinator)
	if not bool(floor_visibility_result.get("valid", false)):
		push_error("MainGame: Camera floor visibility configuration failed.")
		return
	_public_realm_projection = load("res://scripts/public_realm/public_realm_projection.gd").new() as PublicRealmProjection
	var public_configuration: Dictionary = _public_realm_projection.initialize(_district_runtime, _projection_coordinator, metrics)
	if not bool(public_configuration.get("valid", false)):
		push_error("MainGame: Public-realm projection configuration failed.")
		return
	var public_result: Dictionary = _public_realm_projection.rebuild()
	_record_projection_result("public_realm", public_result)
	if not bool(public_result.get("valid", false)):
		push_error("MainGame: Initial public-realm projection build failed.")
		return
	if _parcel_label_renderer != null:
		_parcel_label_renderer.hydrate_active_floor()
	if _zone_label_renderer != null:
		_zone_label_renderer.hydrate_active_floor()
	_camera_gateway_projection = load("res://scripts/camera/camera_gateway_projection.gd").new() as CameraGatewayProjection
	var camera_gateway_setup: Dictionary = _camera_gateway_projection.initialize(_district_runtime, _public_realm_projection, _camera_manager, metrics)
	if not bool(camera_gateway_setup.get("valid", false)):
		push_error("MainGame: Camera/gateway projection configuration failed.")
		return
	var camera_gateway_result: Dictionary = _camera_gateway_projection.rebuild()
	_record_projection_result("camera_gateway", camera_gateway_result)
	if not bool(camera_gateway_result.get("valid", false)):
		push_error("MainGame: Initial camera/gateway projection build failed: %s" % camera_gateway_result.get("diagnostics", []))
		return
	if _tech_tree_manager != null and not _tech_tree_manager.progression_changed.is_connected(_camera_gateway_projection.on_progression_changed):
		_tech_tree_manager.progression_changed.connect(_camera_gateway_projection.on_progression_changed)
	_traffic_topology = load("res://scripts/traffic/traffic_topology.gd").new() as TrafficTopology
	_traffic_topology.name = "TrafficTopology"
	_world.add_child(_traffic_topology)
	var traffic_setup: Dictionary = _traffic_topology.initialize(_district_runtime, _public_realm_projection, metrics)
	if not bool(traffic_setup.get("valid", false)):
		push_error("MainGame: Traffic topology configuration failed.")
		return
	_traffic_topology.road_graph_published.connect(_on_road_graph_published)
	_traffic_topology.road_graph_delta_published.connect(_on_road_graph_delta_published)
	if _traffic_manager != null and not GameManager.speed_changed.is_connected(_traffic_manager.set_control_time_scale):
		GameManager.speed_changed.connect(_traffic_manager.set_control_time_scale)
		_traffic_manager.set_control_time_scale(float(GameManager.speed))
	var traffic_result: Dictionary = _traffic_topology.rebuild()
	_record_projection_result("traffic", traffic_result)
	if not bool(traffic_result.get("valid", false)):
		push_error("MainGame: Initial traffic topology build failed: %s" % traffic_result.get("diagnostics", []))
		return


func _initialize_parcel_label_renderer() -> void:
	if _zone_manager == null:
		push_error("MainGame: ZoneManager not found for ParcelLabelRenderer.")
		return
	_parcel_label_renderer = ParcelLabelRenderer.new()
	_parcel_label_renderer.name = "ParcelLabelRenderer"
	_parcel_label_renderer.zone_manager = _zone_manager
	_parcel_label_renderer.camera_manager = _camera_manager
	_parcel_label_renderer.configure_plot_mapping(_get_initial_projection_plot_id(), _get_initial_projection_plot_id())
	_world.add_child(_parcel_label_renderer)


func _initialize_zone_label_renderer() -> void:
	if _zone_manager == null:
		push_error("MainGame: ZoneManager not found for ZoneLabelRenderer.")
		return
	_zone_label_renderer = ZoneLabelRenderer.new()
	_zone_label_renderer.name = "ZoneLabelRenderer"
	_zone_label_renderer.zone_manager = _zone_manager
	_zone_label_renderer.camera_manager = _camera_manager
	_zone_label_renderer.configure_plot_mapping(_get_initial_projection_plot_id(), _get_initial_projection_plot_id())
	_world.add_child(_zone_label_renderer)


func _get_floor_height(level: String) -> float:
	var floor_height: float = bootstrap_config.floor_height if bootstrap_config != null else 0.0
	if floor_height <= 0.0:
		return 0.0
	if level == "G":
		return 0.0
	var prefix := level[0]
	var num := level.substr(1).to_int()
	return float(num) * floor_height if prefix == "F" else -float(num) * floor_height


# ── Camera Initialization ──────────────────────────────────────────────

func _initialize_camera() -> void:
	if _camera_manager == null:
		push_error("MainGame: CameraManager not found.")
		return

	# Center camera on the 25-tile grid (tiles at 0..24, center at 12.5).
	_camera_manager.global_position = Vector3(12.5, 20, 12.5)
	# Floor navigation follows the resolved H3 floor descriptors for this plot.
	_camera_manager.floor_levels = _get_initial_floor_levels()
	_camera_manager.current_floor_index = maxi(0, _camera_manager.floor_levels.find("G"))

	print("MainGame: Camera initialized at center of grid.")


func _focus_camera_on_generated_floor() -> void:
	if _projection_coordinator == null or _camera_manager == null:
		return
	var floor: Floor = _projection_coordinator.get_projected_floor(_get_initial_floor_address())
	if floor == null:
		return
	var center: Vector3 = floor.to_global(floor.grid_coordinate_to_local(Vector2(floor.grid_width, floor.grid_height) * 0.5))
	var camera_position: Vector3 = _camera_manager.global_position
	_camera_manager.global_position = Vector3(center.x, camera_position.y, center.z)
	print("MainGame: Camera focused on generated floor at %s." % center)


# ── Time Initialization ────────────────────────────────────────────────

func _initialize_time() -> void:
	if _time_manager == null:
		push_error("MainGame: TimeManager not found.")
		return

	# Wire GameManager speed → TimeManager speed.
	GameManager.speed_changed.connect(_time_manager.set_speed)

	# Keep simulation paused until the session readiness barrier commits.
	_time_manager.set_speed(0)

	print("MainGame: Time system initialized — 1x speed.")


# ── Visitor Initialization ─────────────────────────────────────────────

func _initialize_visitors() -> void:
	if _visitor_manager == null:
		push_error("MainGame: VisitorManager not found.")
		return

	# Calendar callbacks are injected into the deterministic coordinator.

	# Wire camera signals for culling.
	_camera_manager.floor_changed.connect(_visitor_manager.on_floor_changed)
	_camera_manager.zoomed.connect(_visitor_manager.on_zoom_changed)

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

	print("MainGame: Tenant system initialized — applications & viability.")


# ── Economy Initialization ────────────────────────────────────────────

func _initialize_economy() -> void:
	if _economy_manager == null:
		push_error("MainGame: EconomyManager not found.")
		return

	var policy_result: Dictionary = _economy_manager.set_policy_snapshot(_content_registry.get_economy_policy_snapshot())
	_record_authority_result("economy_policy", policy_result)
	if not bool(policy_result.get("valid", false)):
		push_error("MainGame: Economy policy injection failed: %s" % policy_result.get("diagnostics", []))
		return
	_economy_manager.initialize(_zone_manager, _tenant_manager, _staff_manager)

	print("MainGame: Economy initialized — 500K starting balance.")


func _initialize_progression_policy() -> void:
	if _tech_tree_manager == null:
		_record_authority_result("progression_policy", {"valid": false, "diagnostics": [{"code": "PROGRESSION_MANAGER_REQUIRED"}]})
		return
	var policy_result: Dictionary = _tech_tree_manager.set_policy_catalog(_content_registry.get_progression_policy_catalog())
	_record_authority_result("progression_policy", policy_result)
	if not bool(policy_result.get("valid", false)):
		push_error("MainGame: Progression policy injection failed: %s" % policy_result.get("diagnostics", []))


# ── Prestige Initialization ────────────────────────────────────────────

func _initialize_prestige() -> void:
	if _prestige_manager == null:
		push_error("MainGame: PrestigeManager not found.")
		return
	var policy: PrestigePolicy = _content_registry.get_prestige_policy() as PrestigePolicy
	var initialization: Dictionary = _prestige_manager.initialize("sim_month:0", policy)
	if not bool(initialization.get("valid", false)):
		push_error("MainGame: Prestige policy initialization failed: %s" % initialization.get("diagnostics", []))
		return
	if _tech_tree_manager != null:
		var initial_snapshot: OfficialPrestigeSnapshot = _prestige_manager.get_committed_snapshot()
		_tech_tree_manager.sync_official_tier(
			initial_snapshot.get_tier_id(),
			_prestige_manager.get_mall_level_name(),
			_prestige_manager.get_mall_level_index(),
			initial_snapshot.get_policy_revision()
		)
	_prestige_manager.official_tier_changed.connect(_on_official_tier_changed)
	print("MainGame: Prestige H1 initialized — Empty Lot authority; H2 calculation unavailable.")


func _on_official_tier_changed(_previous: OfficialPrestigeSnapshot, current: OfficialPrestigeSnapshot) -> void:
	if _tech_tree_manager == null or current == null:
		return
	_tech_tree_manager.sync_official_tier(
		current.get_tier_id(),
		_prestige_manager.get_mall_level_name(),
		_prestige_manager.get_mall_level_index(),
		current.get_policy_revision()
	)


# ── Staff Initialization ───────────────────────────────────────────────

func _initialize_staff() -> void:
	if _staff_manager == null:
		push_error("MainGame: StaffManager not found.")
		return

	print("MainGame: Staff system initialized — cleaners & security.")


# ── Synergy Initialization ─────────────────────────────────────────────

func _initialize_synergy() -> void:
	if _synergy_manager == null:
		push_error("MainGame: SynergyManager not found.")
		return

	_synergy_manager.initialize(_zone_manager)

	# Recalculate synergy when zones change.
	EventBus.zone_created.connect(func(_z: String, _t: String, _c: int): _synergy_manager.recalculate())
	EventBus.zone_modified.connect(func(_z: String): _synergy_manager.recalculate())

	print("MainGame: Synergy system initialized — zone relationships.")


# ── Visitor Service Proxy Composition ─────────────────────────────────

func _initialize_service_proxies() -> void:
	if _visitor_manager == null or _tenant_manager == null or _public_realm_projection == null:
		return
	_visitor_manager.set_proxy_anchor_resolver(Callable(_public_realm_projection, "resolve_service_proxy_anchor"))
	if not _tenant_manager.service_proxy_snapshot_published.is_connected(_on_service_proxy_snapshot_published):
		_tenant_manager.service_proxy_snapshot_published.connect(_on_service_proxy_snapshot_published)
	if not _tenant_manager.tenant_bound.is_connected(_on_tenant_proxy_source_changed):
		_tenant_manager.tenant_bound.connect(_on_tenant_proxy_source_changed)
	if not _tenant_manager.tenant_released.is_connected(_on_tenant_proxy_source_changed):
		_tenant_manager.tenant_released.connect(_on_tenant_proxy_source_changed)
	if not _public_realm_projection.public_realm_rebuilt.is_connected(_on_public_realm_proxy_source_changed):
		_public_realm_projection.public_realm_rebuilt.connect(_on_public_realm_proxy_source_changed)
	if not EventBus.zone_created.is_connected(_on_proxy_zone_created):
		EventBus.zone_created.connect(_on_proxy_zone_created)
	if not EventBus.zone_modified.is_connected(_on_proxy_zone_modified):
		EventBus.zone_modified.connect(_on_proxy_zone_modified)
	if not EventBus.zone_deleted.is_connected(_on_proxy_zone_deleted):
		EventBus.zone_deleted.connect(_on_proxy_zone_deleted)
	if not EventBus.door_changed.is_connected(_on_proxy_door_changed):
		EventBus.door_changed.connect(_on_proxy_door_changed)
	_refresh_service_proxy_snapshot(0)


func _on_tenant_proxy_source_changed(_tenant_id: String, _zone_id: String, _parcel_id: String) -> void:
	_refresh_service_proxy_snapshot()


func _on_public_realm_proxy_source_changed(_manifest: Dictionary) -> void:
	_refresh_service_proxy_snapshot()


func _on_proxy_zone_created(_zone_id: String, _zone_type: String, _tile_count: int) -> void:
	_refresh_service_proxy_snapshot()


func _on_proxy_zone_modified(_zone_id: String) -> void:
	_refresh_service_proxy_snapshot()


func _on_proxy_zone_deleted(_zone_id: String) -> void:
	_refresh_service_proxy_snapshot()


func _on_proxy_door_changed(_from: Vector2i, _to: Vector2i, _enabled: bool) -> void:
	_refresh_service_proxy_snapshot()


func _refresh_service_proxy_snapshot(_simulation_day: int = 0) -> void:
	if _tenant_manager == null or _public_realm_projection == null:
		return
	var result: Dictionary = _tenant_manager.publish_service_proxy_snapshot(_public_realm_projection.get_service_proxy_attachments())
	if not bool(result.get("valid", false)):
		push_warning("MainGame: service proxy publication failed: %s" % result.get("diagnostics", []))


func _on_service_proxy_snapshot_published(snapshot: Array[Dictionary]) -> void:
	if _visitor_manager != null:
		_visitor_manager.consume_service_proxies(snapshot)


# ── Zone Tool Initialization ───────────────────────────────────────────

func _initialize_arrivals() -> void:
	if _district_runtime == null or _public_realm_projection == null or _camera_gateway_projection == null or _visitor_manager == null:
		push_error("MainGame: Arrival MVP dependencies are required.")
		return
	var graph: PedestrianGraphSnapshot = _public_realm_projection.get_graph_snapshot()
	var gateways: GatewayEligibilitySnapshot = _camera_gateway_projection.get_gateway_eligibility_snapshot()
	if graph == null or gateways == null:
		push_error("MainGame: Arrival MVP requires committed H5/H6 snapshots.")
		return
	_arrival_coordinator = load("res://scripts/simulation/arrival_coordinator.gd").new() as ArrivalCoordinator
	var setup: Dictionary = _arrival_coordinator.initialize(_district_runtime, graph, gateways, _visitor_manager, _session_gate)
	_record_authority_result("arrival", setup)
	if not bool(setup.get("valid", false)):
		push_error("MainGame: Arrival coordinator setup failed: %s" % setup.get("diagnostics", []))
		return
	_visitor_demand_authority = load("res://scripts/simulation/visitor_demand_authority.gd").new() as VisitorDemandAuthority
	_visitor_demand_authority.set_desired_count(VisitorManager.MAX_VISITORS)
	_arrival_coordinator.set_demand_authority(_visitor_demand_authority)
	_visitor_manager.configure_arrival_coordinator(_arrival_coordinator)
	_camera_gateway_projection.rebuilt.connect(_on_arrival_gateway_rebuilt)
	print("MainGame: Arrival MVP initialized — demand, source allocation, and realization separated.")


func _on_arrival_gateway_rebuilt(_bounds: CameraBoundsSnapshot, gateways: GatewayEligibilitySnapshot) -> void:
	if _arrival_coordinator == null or _public_realm_projection == null:
		return
	var graph: PedestrianGraphSnapshot = _public_realm_projection.get_graph_snapshot()
	if graph != null and gateways != null:
		_arrival_coordinator.set_snapshots(graph, gateways)


func _initialize_calendar_delivery() -> void:
	var consumer_result: Dictionary = _session_bootstrap.configure_boundary_consumers({
		"visitor": [
			{"name": "visitor_update", "callable": Callable(_visitor_manager, "on_visitor_tick"), "mandatory": true},
			{"name": "staff_update", "callable": Callable(_staff_manager, "on_visitor_tick"), "mandatory": true},
		],
		"hour": [],
		"day": [
			{"name": "tenant_lifecycle", "callable": Callable(self, "_deliver_tenant_day"), "mandatory": true},
			{"name": "economy_rent", "callable": Callable(_economy_manager, "settle_daily_rent"), "mandatory": true},
			{"name": "visitor_metrics", "callable": Callable(_visitor_manager, "on_sim_day_passed"), "mandatory": true},
			{"name": "service_proxies", "callable": Callable(self, "_deliver_service_proxy_day"), "mandatory": false},
		],
		"week": [{"name": "economy_payroll", "callable": Callable(_economy_manager, "_settle_staff_wages"), "mandatory": true}],
		"month": [{"name": "economy_loans", "callable": Callable(self, "_deliver_economy_month"), "mandatory": true}],
	})
	if not bool(consumer_result.get("valid", false)):
		_record_authority_result("calendar", consumer_result)
		return
	var time_result: Dictionary = _time_manager.configure_boundary_delivery(_session_gate, Callable(_session_bootstrap, "deliver_boundary"))
	_record_authority_result("calendar", time_result)


func _deliver_tenant_day(day: int) -> Dictionary:
	if _zone_manager == null or not _zone_manager.permits_tenant_lifecycle():
		return {"valid": true, "skipped": true, "diagnostics": []}
	_tenant_manager.on_sim_day_passed(day)
	return {"valid": true, "diagnostics": []}


func _deliver_service_proxy_day(day: int) -> Dictionary:
	_refresh_service_proxy_snapshot(day)
	return {"valid": true, "diagnostics": []}


func _deliver_economy_month(month: int) -> Dictionary:
	_economy_manager.on_sim_month_passed(month)
	return {"valid": true, "diagnostics": []}


func _initialize_zone_tool() -> void:
	if _zone_tool == null:
		push_error("MainGame: ZoneTool not found.")
		return

	# ZoneTool starts INACTIVE: painting only begins when the player presses a
	# zone-type button in the BottomToolbar (which sets is_active = true).
	_zone_tool.configure_projection(
		_projection_coordinator,
		_get_initial_floor_address(),
		_get_initial_projection_plot_id(),
		_get_initial_floor_address().get("floor_id", "G")
	)
	_zone_tool.is_active = false
	_zone_tool.active_zone_type = ZoneData.ZONE_TYPE_NAMES[0]  # Retail by default.

	print("MainGame: ZoneTool initialized — idle until a zone type is chosen.")


# ── Walls ──────────────────────────────────────────────────────────────

func _on_district_delta_committed(envelope: Dictionary) -> void:
	if String(envelope.get("delta", {}).get("operation", "")) != DistrictRuntime.OP_SET_MANUAL_DOOR:
		return
	var projection_result: Dictionary = _rebuild_loaded_projections()
	if not bool(projection_result.get("valid", false)):
		push_warning("MainGame: manual-door projection refresh failed: %s" % projection_result.get("diagnostics", []))


func _on_road_graph_published(snapshot: RoadGraphSnapshot) -> void:
	if _traffic_manager == null or snapshot == null:
		return
	_traffic_manager.set_road_graph(snapshot)
	print("MainGame: Traffic topology bound — graph revision %d, %d lanes." % [snapshot.graph_revision, snapshot.lanes.size()])


func _on_road_graph_delta_published(delta: RoadGraphDelta) -> void:
	if _traffic_manager == null or delta == null:
		return
	var result: Dictionary = _traffic_manager.apply_road_graph_delta(delta)
	if not bool(result.get("valid", false)):
		push_warning("MainGame: Traffic manager requested full graph recovery: %s" % result.get("diagnostics", []))


func _initialize_walls() -> void:
	if _manual_door_authority != null and _door_tool != null and _projection_coordinator != null:
		_door_tool.configure_production(_manual_door_authority, _projection_coordinator, _get_initial_floor_address())
	if _wall_manager == null:
		push_error("MainGame: WallManager not found.")
		return
	if _district_runtime != null and _projection_coordinator != null:
		_wall_manager.configure_production(_district_runtime, _get_initial_floor_address())
	_wall_manager.rebuild()

	print("MainGame: Walls initialized — floor perimeter generated.")


# ── Input ──────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _session_operations_available():
		return
	# Cycle wall visualization mode: Cutaway → Partial → Full → Cutaway.
	if event.is_action_pressed("cycle_wall_mode"):
		GameManager.cycle_wall_mode()


# ── Save / Load ────────────────────────────────────────────────────────

func _initialize_save_manager() -> void:
	if _district_runtime == null or not _district_runtime.has_session():
		push_error("MainGame: SaveManager requires an active District Runtime session.")
		return
	SaveManager.configure_runtime(
		Callable(self, "_serialize_v2_authorities"),
		Callable(self, "_get_v2_layout_ref"),
		Callable(self, "_validate_v2_authorities"),
		Callable(self, "_commit_v2_authorities")
	)
	var setup: Dictionary = SaveManager.configure_session_boundary(_session_gate, Callable(self, "_session_operations_available"))
	_record_authority_result("save", setup)


func _serialize_v2_authorities() -> Dictionary:
	return {
		"district": _district_runtime.get_state() if _district_runtime != null and _district_runtime.has_session() else {},
		"zone_parcel": _zone_manager.serialize() if _zone_manager != null else {},
		"tenant": _tenant_manager.serialize() if _tenant_manager != null else {},
		"visitor": _visitor_manager.serialize() if _visitor_manager != null else {},
		"economy": _economy_manager.serialize() if _economy_manager != null else {},
		"progression": _tech_tree_manager.serialize() if _tech_tree_manager != null else {},
		"prestige": _prestige_manager.serialize() if _prestige_manager != null else {},
		"staff": _staff_manager.serialize() if _staff_manager != null else {},
		"synergy": _synergy_manager.serialize() if _synergy_manager != null else {},
		"time": _time_manager.serialize() if _time_manager != null else {},
	}


func _get_v2_layout_ref() -> Dictionary:
	if _district_runtime == null or not _district_runtime.has_session():
		return {}
	var snapshot: ResolvedDistrictSnapshot = _district_runtime.get_snapshot()
	return {
		"layout_id": snapshot.get_layout_id(),
		"layout_definition_version": int(snapshot.get_data().get("layout_definition_version", 0)),
		"definition_fingerprint": snapshot.get_fingerprint(),
	}


func _validate_v2_authorities(authorities: Dictionary, _layout_ref: Dictionary) -> Dictionary:
	var required: Dictionary = {
		"zone_parcel": ["zones", "parcel_counter", "parcel_display_number_counter"],
		"tenant": ["tenants", "tenant_counter"],
		"visitor": ["visitors", "counter"],
		"economy": ["balance", "loans", "loan_counter"],
		"progression": ["unlocked", "available_points", "total_earned", "selected_plot_ids", "plot_access_grants_earned", "plot_access_grants_consumed", "awarded_milestone_ids"],
		"prestige": OfficialPrestigeSnapshot.FIELDS,
		"staff": ["rooms", "staff", "staff_counter"],
		"synergy": ["zone_scores"],
		"time": ["sim_time", "visual_time"],
	}
	var diagnostics: Array[Dictionary] = []
	for authority_name: String in SaveManager.get_v2_authority_fields():
		if not authorities.has(authority_name) or not authorities[authority_name] is Dictionary:
			diagnostics.append({"code": "AUTHORITY_SNAPSHOT_INVALID", "path": "$.authorities.%s" % authority_name, "message": "authority snapshot must be an object"})
			continue
		if not required.has(authority_name):
			continue
		var authority: Dictionary = authorities[authority_name]
		for field: String in required[authority_name]:
			if not authority.has(field):
				diagnostics.append({"code": "AUTHORITY_FIELD_MISSING", "path": "$.authorities.%s.%s" % [authority_name, field], "message": "required authority field is missing"})
	if authorities.get("progression", {}) is Dictionary and _tech_tree_manager != null:
		var progression_validation: Dictionary = _tech_tree_manager.validate_serialized_state(authorities["progression"])
		if not bool(progression_validation.get("valid", false)):
			diagnostics.append_array(progression_validation.get("diagnostics", []))
	if authorities.get("prestige", {}) is Dictionary and _prestige_manager != null:
		var prestige_validation: Dictionary = _prestige_manager.validate_serialized_state(authorities["prestige"])
		if not bool(prestige_validation.get("valid", false)):
			diagnostics.append_array(prestige_validation.get("diagnostics", []))
	if _district_runtime == null or not _district_runtime.has_session():
		diagnostics.append({"code": "DISTRICT_RUNTIME_REQUIRED", "path": "$.authorities.district", "message": "district validation requires an active session"})
	else:
		var district_state: Dictionary = authorities.get("district", {})
		var district_validation: Dictionary = DistrictStateRecords.new().validate(district_state, _district_runtime.get_snapshot())
		if not bool(district_validation.get("valid", false)):
			diagnostics.append_array(district_validation.get("diagnostics", []))
		else:
			var access_result: Dictionary = PublicBandAccessSnapshot.derive(_district_runtime.get_snapshot(), district_state, int(district_state.get("district_revision", -1)))
			if not bool(access_result.get("valid", false)):
				diagnostics.append_array(access_result.get("diagnostics", []))
			elif authorities.get("zone_parcel", {}) is Dictionary and _zone_manager != null:
				var zone_validation: Dictionary = _zone_manager.validate_serialized_state(authorities["zone_parcel"], access_result.get("snapshot") as PublicBandAccessSnapshot)
				if not bool(zone_validation.get("valid", false)):
					diagnostics.append_array(zone_validation.get("diagnostics", []))
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func _commit_v2_authorities(authorities: Dictionary, _layout_ref: Dictionary) -> Dictionary:
	if _district_runtime == null or not _district_runtime.has_session():
		return {"valid": false, "diagnostics": [{"code": "DISTRICT_RUNTIME_REQUIRED", "message": "cannot commit without an active District Runtime session"}]}
	var previous: Dictionary = _serialize_v2_authorities()
	var applied: Dictionary = _apply_v2_authorities(authorities)
	if bool(applied.get("valid", false)):
		return applied
	_apply_v2_authorities(previous)
	return applied


func _apply_v2_authorities(authorities: Dictionary) -> Dictionary:
	var district_load: Dictionary = _district_runtime.replace_session(_district_runtime.get_snapshot(), authorities.get("district", {}))
	if not bool(district_load.get("valid", false)):
		return district_load
	# Import in the fixed Session H2 registry order.
	_zone_manager.deserialize(authorities["zone_parcel"])
	_economy_manager.deserialize(authorities["economy"])
	_tech_tree_manager.deserialize(authorities["progression"], false)
	var prestige_load: Dictionary = _prestige_manager.deserialize(authorities["prestige"])
	if not bool(prestige_load.get("valid", false)):
		return prestige_load
	_staff_manager.deserialize(authorities["staff"])
	_synergy_manager.deserialize(authorities["synergy"])
	_tenant_manager.deserialize(authorities["tenant"])
	_visitor_manager.deserialize(authorities["visitor"])
	_time_manager.deserialize(authorities["time"])
	var loaded_snapshot: OfficialPrestigeSnapshot = _prestige_manager.get_committed_snapshot()
	_tech_tree_manager.sync_official_tier(
		loaded_snapshot.get_tier_id(),
		_prestige_manager.get_mall_level_name(),
		_prestige_manager.get_mall_level_index(),
		loaded_snapshot.get_policy_revision()
	)
	var projection_result: Dictionary = _rebuild_loaded_projections()
	if not bool(projection_result.get("valid", false)):
		return projection_result
	if _wall_manager != null:
		_wall_manager.rebuild()
	_refresh_service_proxy_snapshot()
	if _parcel_label_renderer:
		_parcel_label_renderer.hydrate_active_floor()
	if _zone_label_renderer:
		_zone_label_renderer.hydrate_active_floor()
	return {"valid": true, "diagnostics": []}


func _rebuild_loaded_projections() -> Dictionary:
	if _projection_coordinator != null:
		var projection_result: Dictionary = _projection_coordinator.rebuild()
		if not bool(projection_result.get("valid", false)):
			return projection_result
	if _public_realm_projection != null:
		var public_result: Dictionary = _public_realm_projection.rebuild()
		if not bool(public_result.get("valid", false)):
			return public_result
	if _camera_gateway_projection != null:
		var camera_result: Dictionary = _camera_gateway_projection.rebuild()
		if not bool(camera_result.get("valid", false)):
			return camera_result
	if _traffic_topology != null:
		var traffic_result: Dictionary = _traffic_topology.rebuild()
		if not bool(traffic_result.get("valid", false)):
			return traffic_result
	return {"valid": true, "diagnostics": []}


func save_game(slot: int) -> void:
	if not _session_operations_available():
		return
	var result: Error = SaveManager.save_game(slot)
	if result != OK:
		push_error("MainGame: Save failed for slot %d: %s" % [slot, error_string(result)])


func load_game(slot: int) -> void:
	if not _session_operations_available():
		return
	var result: Dictionary = SaveManager.load_game(slot)
	if not bool(result.get("valid", false)):
		push_warning("MainGame: Load rejected for slot %d: %s" % [slot, result.get("diagnostics", [])])


func _record_authority_result(name: String, result: Dictionary) -> void:
	var recorded: Dictionary = result.duplicate(true)
	if bool(recorded.get("valid", false)):
		recorded["layout_id"] = bootstrap_config.layout_id if bootstrap_config != null else ""
		recorded["definition_fingerprint"] = _initial_snapshot.get_fingerprint() if _initial_snapshot != null else ""
	_authority_initialization_results[name] = recorded


func _record_projection_result(name: String, result: Dictionary) -> void:
	var recorded: Dictionary = result.duplicate(true)
	if bool(recorded.get("valid", false)):
		recorded["layout_id"] = bootstrap_config.layout_id if bootstrap_config != null else ""
		recorded["definition_fingerprint"] = _initial_snapshot.get_fingerprint() if _initial_snapshot != null else ""
	_projection_initialization_results[name] = recorded


func _required_results_valid(results: Dictionary, required_names: Array[String]) -> bool:
	for result_name: String in required_names:
		if not results.has(result_name):
			return false
		var result: Variant = results[result_name]
		if not result is Dictionary or not bool(result.get("valid", false)):
			return false
	return true


func _session_operations_available() -> bool:
	return (
		_session_bootstrap != null
		and _session_bootstrap.can_accept_input()
		and _session_gate != null
		and not _session_gate.is_busy()
		and _time_manager != null
		and not _time_manager.has_pending_boundary()
	)
