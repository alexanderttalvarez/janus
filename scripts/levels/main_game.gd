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
@onready var _construction_tool: ConstructionTool = $ConstructionTool
@onready var _door_tool: DoorTool = $DoorTool
@onready var _wall_manager: WallManager = $World/WallManager
@onready var _traffic_manager: TrafficManager = $World/TrafficManager
var _district_runtime: DistrictRuntime
var _construction_intent_gateway: ConstructionIntentGateway
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
var _published_restore_candidate: SessionRestoreCandidate


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
	_initialize_construction_tool()
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
		and _construction_intent_gateway != null
		and _construction_tool != null
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
	if not EventBus.zone_created.is_connected(_on_synergy_zone_created):
		EventBus.zone_created.connect(_on_synergy_zone_created)
	if not EventBus.zone_modified.is_connected(_on_synergy_zone_modified):
		EventBus.zone_modified.connect(_on_synergy_zone_modified)
	print("MainGame: Synergy system initialized — zone relationships.")


func _on_synergy_zone_created(_zone_id: String, _zone_type: String, _tile_count: int) -> void:
	if _synergy_manager != null:
		_synergy_manager.recalculate()


func _on_synergy_zone_modified(_zone_id: String) -> void:
	if _synergy_manager != null:
		_synergy_manager.recalculate()


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
	if not _public_realm_projection.pedestrian_graph_delta_published.is_connected(_on_public_realm_graph_delta):
		_public_realm_projection.pedestrian_graph_delta_published.connect(_on_public_realm_graph_delta)
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


func _on_public_realm_graph_delta(_delta: Dictionary) -> void:
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
		"G"
	)
	_zone_tool.configure_district_runtime(_district_runtime)
	_zone_tool.is_active = false
	_zone_tool.active_zone_type = ZoneData.ZONE_TYPE_NAMES[0]  # Retail by default.

	print("MainGame: ZoneTool initialized — idle until a zone type is chosen.")


func _initialize_construction_tool() -> void:
	if _construction_tool == null or _district_runtime == null or _projection_coordinator == null:
		push_error("MainGame: ConstructionTool dependencies are required.")
		return
	var game_ui: GameUI = $GameUI as GameUI
	if game_ui == null:
		push_error("MainGame: GameUI is required for construction intent routing.")
		return
	_construction_intent_gateway = load("res://scripts/construction/construction_intent_gateway.gd").new() as ConstructionIntentGateway
	var gateway_setup: Dictionary = _construction_intent_gateway.initialize(_district_runtime)
	if not bool(gateway_setup.get("valid", false)):
		push_error("MainGame: Construction intent gateway initialization failed: %s" % gateway_setup.get("diagnostics", []))
		_construction_intent_gateway = null
		return
	if not game_ui.register_intent_owner(ConstructionIntentGateway.OWNER_ID, _construction_intent_gateway):
		push_error("MainGame: Construction intent owner registration failed.")
		_construction_intent_gateway = null
		return
	var tool_setup: Dictionary = _construction_tool.configure(
		_district_runtime,
		_projection_coordinator,
		game_ui,
		_get_initial_floor_address(),
	)
	if not bool(tool_setup.get("valid", false)):
		push_error("MainGame: ConstructionTool initialization failed: %s" % tool_setup.get("diagnostics", []))
		_construction_intent_gateway = null
		return
	_construction_tool.deactivate()
	print("MainGame: ConstructionTool initialized — ground acquisition and corridors available through Build.")


# ── Walls ──────────────────────────────────────────────────────────────

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
	var participants: Array[Dictionary] = []
	for key: String in SaveManager.get_v2_authority_fields():
		participants.append({
			"key": key,
			"export_snapshot": Callable(self, "_export_restore_participant").bind(key),
			"validate_snapshot": Callable(self, "_validate_restore_participant").bind(key),
			"import_snapshot": Callable(self, "_import_restore_participant").bind(key),
			"cross_validate": Callable(self, "_cross_validate_restore_participant").bind(key),
		})
	var projections: Array[Dictionary] = [
		{"key": "district_world", "prepare": Callable(self, "_prepare_candidate_district_world")},
		{"key": "public_realm_topology", "prepare": Callable(self, "_prepare_candidate_public_realm")},
		{"key": "camera_gateway", "prepare": Callable(self, "_prepare_candidate_camera_gateway")},
		{"key": "traffic", "prepare": Callable(self, "_prepare_candidate_traffic")},
		{"key": "tenant_visitor", "prepare": Callable(self, "_prepare_candidate_tenant_visitor")},
	]
	var registry_setup: Dictionary = SaveManager.configure_runtime(
		participants,
		Callable(self, "_get_v2_layout_ref"),
		Callable(self, "_resolve_restore_layout"),
		Callable(self, "_create_restore_candidate"),
		projections,
		Callable(self, "_publish_restore_candidate"),
	)
	if not bool(registry_setup.get("valid", false)):
		_record_authority_result("save", registry_setup)
		return
	var setup: Dictionary = SaveManager.configure_session_boundary(_session_gate, Callable(self, "_session_operations_available"))
	_record_authority_result("save", setup)


func _export_restore_participant(key: String) -> Dictionary:
	match key:
		"district": return _district_runtime.get_state()
		"zone_parcel": return _zone_manager.serialize()
		"economy": return _economy_manager.serialize()
		"progression": return _tech_tree_manager.serialize()
		"prestige": return _prestige_manager.serialize()
		"staff": return _staff_manager.serialize()
		"synergy": return _synergy_manager.serialize()
		"tenant": return _tenant_manager.serialize()
		"visitor": return _visitor_manager.serialize()
		"time": return _time_manager.serialize()
	return {}


func _get_v2_layout_ref() -> Dictionary:
	if _district_runtime == null or not _district_runtime.has_session():
		return {}
	var snapshot: ResolvedDistrictSnapshot = _district_runtime.get_snapshot()
	return {"layout_id": snapshot.get_layout_id(), "layout_definition_version": int(snapshot.get_data().get("layout_definition_version", 0)), "definition_fingerprint": snapshot.get_fingerprint()}


func _resolve_restore_layout(layout_ref: Dictionary) -> Dictionary:
	return _content_registry.validate_layout_ref(layout_ref) if _content_registry != null else {"valid": false, "diagnostics": [{"code": "CONTENT_REGISTRY_NOT_READY"}]}


func _create_restore_candidate(resolved_layout: Dictionary) -> SessionRestoreCandidate:
	var candidate := SessionRestoreCandidate.new()
	var result: Dictionary = candidate.initialize(resolved_layout)
	return candidate if bool(result.get("valid", false)) else null


func _validate_restore_participant(snapshot: Dictionary, resolved_layout: Dictionary, key: String) -> Dictionary:
	var resolved_snapshot: ResolvedDistrictSnapshot = resolved_layout.get("snapshot") as ResolvedDistrictSnapshot
	match key:
		"district":
			return DistrictStateRecords.new().validate(snapshot, resolved_snapshot)
		"zone_parcel":
			return {"valid": snapshot.keys().size() == 4 and snapshot.has_all(["zones", "zone_counter", "parcel_counter", "parcel_display_number_counter"]), "diagnostics": [] if snapshot.keys().size() == 4 else [{"code": "ZONE_SNAPSHOT_INVALID"}]}
		"economy":
			var fields: Array[String] = ["balance", "loans", "loan_counter", "authority_revision", "economy_policy_revision", "settled_staff_weeks"]
			return {"valid": snapshot.keys().size() == fields.size() and snapshot.has_all(fields), "diagnostics": [] if snapshot.keys().size() == fields.size() and snapshot.has_all(fields) else [{"code": "ECONOMY_SNAPSHOT_INVALID"}]}
		"progression":
			var progression := TechTreeManager.new()
			var setup: Dictionary = progression.set_policy_catalog(_content_registry.get_progression_policy_catalog())
			var result: Dictionary = progression.validate_serialized_state(snapshot) if bool(setup.get("valid", false)) else setup
			progression.free()
			return result
		"prestige":
			var prestige := PrestigeManager.new()
			var setup: Dictionary = prestige.initialize(String(snapshot.get("calendar_identity", "")), _content_registry.get_prestige_policy())
			var result: Dictionary = prestige.validate_serialized_state(snapshot) if bool(setup.get("valid", false)) else setup
			prestige.free()
			return result
		"staff":
			var staff := StaffManager.new()
			var result: Dictionary = staff.validate_serialized(snapshot)
			staff.free()
			return result
		"synergy":
			var synergy := SynergyManager.new()
			var result: Dictionary = synergy.validate_serialized(snapshot)
			synergy.free()
			return result
		"tenant":
			var tenant_snapshot := TenantAuthoritySnapshot.new()
			tenant_snapshot.configure(snapshot)
			return tenant_snapshot.validate()
		"visitor":
			var visitor := VisitorManager.new()
			var result: Dictionary = visitor.validate_serialized(snapshot)
			visitor.free()
			return result
		"time":
			var valid: bool = snapshot.keys().size() == 2 and snapshot.has_all(["sim_time", "visual_time"]) and (snapshot["sim_time"] is int or snapshot["sim_time"] is float) and (snapshot["visual_time"] is int or snapshot["visual_time"] is float) and float(snapshot["sim_time"]) >= 0.0 and float(snapshot["visual_time"]) >= 0.0
			return {"valid": valid, "diagnostics": [] if valid else [{"code": "TIME_SNAPSHOT_INVALID"}]}
	return {"valid": false, "diagnostics": [{"code": "REGISTRY_PARTICIPANT_UNKNOWN"}]}


func _import_restore_participant(snapshot: Dictionary, candidate: SessionRestoreCandidate, key: String) -> Dictionary:
	return candidate.import_authority_snapshot(key, snapshot)


func _cross_validate_restore_participant(candidate: SessionRestoreCandidate, key: String) -> Dictionary:
	if key == "zone_parcel":
		var district_state: Dictionary = candidate.authority_snapshots["district"]
		var access: Dictionary = PublicBandAccessSnapshot.derive(candidate.layout_snapshot, district_state, int(district_state.get("district_revision", -1)))
		if not bool(access.get("valid", false)):
			return access
		var zone := ZoneManager.new()
		var result: Dictionary = zone.validate_serialized_state(candidate.authority_snapshots[key], access.get("snapshot") as PublicBandAccessSnapshot)
		zone.free()
		return result
	if key == "staff":
		return _validate_candidate_staff_construction(candidate)
	if key == "visitor":
		var valid_sources: Dictionary = {}
		for source: Dictionary in candidate.layout_snapshot.get_data().get("arrival_source_attachments", []):
			valid_sources[String(source.get("authored_id", ""))] = true
		for record: Dictionary in candidate.authority_snapshots[key].get("visitors", []):
			if not valid_sources.has(String(record.get("arrival_source_id", ""))):
				return {"valid": false, "diagnostics": [{"code": "VISITOR_ARRIVAL_SOURCE_INVALID", "visitor_id": record.get("id", "")}]}
	return {"valid": true, "diagnostics": []}


func _validate_candidate_staff_construction(candidate: SessionRestoreCandidate) -> Dictionary:
	var operation_rooms: Dictionary = {}
	for record: Dictionary in candidate.authority_snapshots["district"].get("construction_records", []):
		if String(record.get("kind", "")) == "operations_room":
			operation_rooms[String(record.get("construction_id", ""))] = record
	for room_id: String in candidate.authority_snapshots["staff"].get("rooms", {}):
		var room: Dictionary = candidate.authority_snapshots["staff"]["rooms"][room_id]
		if not operation_rooms.has(room_id) or String(room.get("building_id", "")) != String(operation_rooms[room_id].get("plot_id", "")):
			return {"valid": false, "diagnostics": [{"code": "STAFF_CONSTRUCTION_REFERENCE_INVALID", "operations_room_id": room_id}]}
	return {"valid": true, "diagnostics": []}


func _candidate_metrics() -> ProjectionMetrics:
	var metrics := ProjectionMetrics.new()
	metrics.identity = bootstrap_config.projection_metrics_identity
	metrics.revision = bootstrap_config.projection_metrics_revision
	metrics.grid_unit_size = bootstrap_config.grid_unit_size
	metrics.floor_height = bootstrap_config.floor_height
	metrics.origin = bootstrap_config.origin
	return metrics


func _prepare_candidate_district_world(candidate: SessionRestoreCandidate) -> Dictionary:
	var zone := ZoneManager.new()
	var economy := EconomyManager.new()
	var progression := TechTreeManager.new()
	var prestige := PrestigeManager.new()
	var staff := StaffManager.new()
	var synergy := SynergyManager.new()
	var tenant := TenantManager.new()
	var visitor := VisitorManager.new()
	var time := TimeManager.new()
	var district := DistrictRuntime.new()
	var setup: Dictionary = {}
	for pair: Array in [["district", district], ["zone_parcel", zone], ["economy", economy], ["progression", progression], ["prestige", prestige], ["staff", staff], ["synergy", synergy], ["tenant", tenant], ["visitor", visitor], ["time", time]]:
		setup = candidate.set_authority(String(pair[0]), pair[1])
		if not bool(setup.get("valid", false)): return setup
	setup = economy.set_policy_snapshot(_content_registry.get_economy_policy_snapshot())
	if not bool(setup.get("valid", false)): return setup
	setup = progression.set_policy_catalog(_content_registry.get_progression_policy_catalog())
	if not bool(setup.get("valid", false)): return setup
	setup = prestige.initialize(String(candidate.authority_snapshots["prestige"].get("calendar_identity", "")), _content_registry.get_prestige_policy())
	if not bool(setup.get("valid", false)): return setup
	tenant.initialize(zone)
	economy.initialize(zone, tenant, staff)
	synergy.initialize(zone)
	setup = visitor.configure_projection_metrics(_candidate_metrics())
	if not bool(setup.get("valid", false)): return setup
	var ports_script: Script = load("res://scripts/district/district_runtime_ports.gd")
	var ports: DistrictRuntimePorts.DistrictRuntimePortsBundle = ports_script.DistrictRuntimePortsBundle.new()
	var economy_port: DistrictRuntimePorts.EconomyManagerPort = ports_script.EconomyManagerPort.new()
	var zone_port: DistrictRuntimePorts.ZoneManagerPort = ports_script.ZoneManagerPort.new()
	var progression_port: DistrictRuntimePorts.ProgressionManagerPort = ports_script.ProgressionManagerPort.new()
	economy_port.initialize(economy); zone_port.initialize(zone); progression_port.initialize(progression)
	setup = ports.initialize(economy_port, zone_port, progression_port)
	if not bool(setup.get("valid", false)): return setup
	district.configure_ports(ports)
	setup = district.configure_session_gate(SessionMutationGate.new())
	if not bool(setup.get("valid", false)): return setup
	setup = district.create_session(candidate.layout_snapshot, candidate.authority_snapshots["district"])
	if not bool(setup.get("valid", false)): return setup
	zone.deserialize(candidate.authority_snapshots["zone_parcel"])
	economy.deserialize(candidate.authority_snapshots["economy"])
	progression.deserialize(candidate.authority_snapshots["progression"], false)
	setup = prestige.deserialize(candidate.authority_snapshots["prestige"])
	if not bool(setup.get("valid", false)): return setup
	setup = staff.deserialize(candidate.authority_snapshots["staff"])
	if not bool(setup.get("valid", false)): return setup
	setup = synergy.deserialize(candidate.authority_snapshots["synergy"])
	if not bool(setup.get("valid", false)): return setup
	tenant.deserialize(candidate.authority_snapshots["tenant"])
	setup = visitor.deserialize(candidate.authority_snapshots["visitor"])
	if not bool(setup.get("valid", false)): return setup
	time.deserialize(candidate.authority_snapshots["time"])
	var coordinator := ProjectionCoordinator.new()
	setup = candidate.set_projection("district_world", coordinator)
	if not bool(setup.get("valid", false)): return setup
	setup = coordinator.configure(district, _candidate_metrics())
	if not bool(setup.get("valid", false)): return setup
	setup = coordinator.rebuild()
	if not bool(setup.get("valid", false)): return setup
	candidate.projection_manifests["district_world"] = setup.get("manifest", {}).duplicate(true)
	return {"valid": true, "diagnostics": []}


func _prepare_candidate_public_realm(candidate: SessionRestoreCandidate) -> Dictionary:
	var projection := PublicRealmProjection.new()
	var setup: Dictionary = candidate.set_projection("public_realm_topology", projection)
	if not bool(setup.get("valid", false)): return setup
	setup = projection.initialize(candidate.authorities["district"], candidate.projections["district_world"], _candidate_metrics())
	if not bool(setup.get("valid", false)): return setup
	var result: Dictionary = projection.rebuild()
	if not bool(result.get("valid", false)): return result
	candidate.projection_manifests["public_realm_topology"] = result.get("manifest", {}).duplicate(true)
	return {"valid": true, "diagnostics": []}


func _prepare_candidate_camera_gateway(candidate: SessionRestoreCandidate) -> Dictionary:
	var projection := CameraGatewayProjection.new()
	var setup: Dictionary = candidate.set_projection("camera_gateway", projection)
	if not bool(setup.get("valid", false)): return setup
	setup = projection.initialize(candidate.authorities["district"], candidate.projections["public_realm_topology"], null, _candidate_metrics())
	if not bool(setup.get("valid", false)): return setup
	var result: Dictionary = projection.rebuild()
	if not bool(result.get("valid", false)): return result
	candidate.projection_manifests["camera_gateway"] = {"district_revision": candidate.authority_snapshots["district"].get("district_revision", -1)}
	return {"valid": true, "diagnostics": []}


func _prepare_candidate_traffic(candidate: SessionRestoreCandidate) -> Dictionary:
	var topology := TrafficTopology.new()
	var setup: Dictionary = candidate.set_projection("traffic", topology)
	if not bool(setup.get("valid", false)): return setup
	setup = topology.initialize(candidate.authorities["district"], candidate.projections["public_realm_topology"], _candidate_metrics())
	if not bool(setup.get("valid", false)): return setup
	var result: Dictionary = topology.rebuild()
	if not bool(result.get("valid", false)): return result
	candidate.projection_manifests["traffic"] = {"graph_revision": topology.get_graph_revision()}
	return {"valid": true, "diagnostics": []}


func _prepare_candidate_tenant_visitor(candidate: SessionRestoreCandidate) -> Dictionary:
	var prestige: PrestigeManager = candidate.authorities["prestige"]
	var progression: TechTreeManager = candidate.authorities["progression"]
	var official: OfficialPrestigeSnapshot = prestige.get_committed_snapshot()
	var binding: Dictionary = progression.restore_official_tier_source(official.get_tier_id(), prestige.get_mall_level_name(), prestige.get_mall_level_index(), official.get_policy_revision())
	if not bool(binding.get("valid", false)): return binding
	var tenant: TenantManager = candidate.authorities["tenant"]
	var public_realm: PublicRealmProjection = candidate.projections["public_realm_topology"]
	var proxies: Dictionary = tenant.publish_service_proxy_snapshot(public_realm.get_service_proxy_attachments())
	if not bool(proxies.get("valid", false)): return proxies
	var visitor: VisitorManager = candidate.authorities["visitor"]
	visitor.consume_service_proxies(proxies.get("snapshots", []))
	var positions: Dictionary = {}
	for source: Dictionary in candidate.layout_snapshot.get_data().get("arrival_source_attachments", []):
		var pose: Dictionary = source.get("pose", source.get("gateway_projection", {}).get("baseline_pose", {}))
		positions[String(source.get("authored_id", ""))] = Vector3(float(pose.get("x4", 0)) / 4.0, float(pose.get("elevation", 0)) * bootstrap_config.floor_height, float(pose.get("z4", 0)) / 4.0)
	var restored: Dictionary = visitor.prepare_restored_visitors(positions)
	if not bool(restored.get("valid", false)): return restored
	return candidate.set_projection("tenant_visitor", RefCounted.new(), {"visitor_count": visitor.get_active_visitor_count(), "proxy_count": proxies.get("snapshots", []).size()})


## Publication contains no validation, import, graph construction, or recoverable branch.
func _publish_restore_candidate(candidate: SessionRestoreCandidate) -> void:
	var first_publication: bool = _published_restore_candidate == null
	var retired_nodes: Array[Node] = []
	var retired_public_realm: PublicRealmProjection
	var retired_camera_gateway: CameraGatewayProjection
	if first_publication:
		retired_nodes = [_district_runtime, _zone_manager, _economy_manager, _tech_tree_manager, _prestige_manager, _staff_manager, _synergy_manager, _tenant_manager, _visitor_manager, _time_manager, _projection_coordinator, _traffic_topology]
		retired_public_realm = _public_realm_projection
		retired_camera_gateway = _camera_gateway_projection
	# Retired camera projections must not clear the newly rebound shared camera.
	if _camera_gateway_projection != null:
		_camera_gateway_projection._camera_manager = null
	_district_runtime = candidate.authorities["district"]
	_zone_manager = candidate.authorities["zone_parcel"]
	_economy_manager = candidate.authorities["economy"]
	_tech_tree_manager = candidate.authorities["progression"]
	_prestige_manager = candidate.authorities["prestige"]
	_staff_manager = candidate.authorities["staff"]
	_synergy_manager = candidate.authorities["synergy"]
	_tenant_manager = candidate.authorities["tenant"]
	_visitor_manager = candidate.authorities["visitor"]
	_time_manager = candidate.authorities["time"]
	_projection_coordinator = candidate.projections["district_world"]
	_public_realm_projection = candidate.projections["public_realm_topology"]
	_camera_gateway_projection = candidate.projections["camera_gateway"]
	_traffic_topology = candidate.projections["traffic"]
	_initial_snapshot = candidate.layout_snapshot
	_attach_candidate_node(_district_runtime, self, "DistrictRuntime")
	_attach_candidate_node(_zone_manager, _world, "ZoneManager")
	_attach_candidate_node(_economy_manager, $Simulation, "EconomyManager")
	_attach_candidate_node(_tech_tree_manager, $Simulation, "TechTreeManager")
	_attach_candidate_node(_prestige_manager, $Simulation, "PrestigeManager")
	_attach_candidate_node(_staff_manager, $Simulation, "StaffManager")
	_attach_candidate_node(_synergy_manager, $Simulation, "SynergyManager")
	_attach_candidate_node(_tenant_manager, $Simulation, "TenantManager")
	_attach_candidate_node(_visitor_manager, $Simulation, "VisitorManager")
	_attach_candidate_node(_time_manager, $Simulation, "TimeManager")
	_attach_candidate_node(_projection_coordinator, _world, "ProjectionCoordinator")
	_attach_candidate_node(_traffic_topology, _world, "TrafficTopology")
	_rebind_published_session()
	_published_restore_candidate = candidate
	if retired_public_realm != null: retired_public_realm.dispose()
	if retired_camera_gateway != null: retired_camera_gateway.dispose()
	for node: Node in retired_nodes:
		if node != null and is_instance_valid(node) and node.get_parent() != null:
			node.get_parent().remove_child(node)
			node.queue_free()


func _attach_candidate_node(node: Node, parent: Node, published_name: String) -> void:
	if parent.has_node(published_name):
		parent.get_node(published_name).name = "Retired%s" % published_name
	node.name = published_name
	if node.get_parent() == null:
		parent.add_child(node)


func _rebind_published_session() -> void:
	_initialize_construction_tool()
	_economy_manager.initialize(_zone_manager, _tenant_manager, _staff_manager)
	_synergy_manager.initialize(_zone_manager)
	_time_manager.configure_boundary_delivery(_session_gate, Callable(_session_bootstrap, "deliver_boundary"))
	if not GameManager.speed_changed.is_connected(_time_manager.set_speed): GameManager.speed_changed.connect(_time_manager.set_speed)
	if not _camera_manager.floor_changed.is_connected(_visitor_manager.on_floor_changed): _camera_manager.floor_changed.connect(_visitor_manager.on_floor_changed)
	if not _camera_manager.zoomed.is_connected(_visitor_manager.on_zoom_changed): _camera_manager.zoomed.connect(_visitor_manager.on_zoom_changed)
	if not _prestige_manager.official_tier_changed.is_connected(_on_official_tier_changed): _prestige_manager.official_tier_changed.connect(_on_official_tier_changed)
	_camera_gateway_projection.initialize(_district_runtime, _public_realm_projection, _camera_manager, _candidate_metrics())
	_camera_manager.set_camera_bounds_snapshot(_camera_gateway_projection.get_camera_bounds_snapshot())
	# Rebind floor presentation to the newly published projection before the
	# loaded event is emitted; otherwise restored floors retain their default
	# visibility mode instead of the camera's current floor policy.
	_camera_manager.configure_floor_visibility(_projection_coordinator)
	_initialize_service_proxies()
	_initialize_arrivals()
	_initialize_calendar_delivery()
	_manual_door_authority.configure(_district_runtime, _zone_manager)
	_traversal_topology_source.configure(_zone_manager)
	_zone_tool.configure_district_runtime(_district_runtime)
	if _wall_manager != null:
		_wall_manager.configure_production(_district_runtime, _get_initial_floor_address())
		_wall_manager.rebuild()
	_parcel_label_renderer.zone_manager = _zone_manager
	_zone_label_renderer.zone_manager = _zone_manager
	_parcel_label_renderer.configure_plot_mapping(_get_initial_projection_plot_id(), _get_initial_projection_plot_id())
	_zone_label_renderer.configure_plot_mapping(_get_initial_projection_plot_id(), _get_initial_projection_plot_id())
	_parcel_label_renderer.hydrate_active_floor()
	_zone_label_renderer.hydrate_active_floor()


func _rebuild_loaded_projections() -> Dictionary:
	for projection: Variant in [_projection_coordinator, _public_realm_projection, _camera_gateway_projection, _traffic_topology]:
		if projection != null:
			var result: Dictionary = projection.rebuild()
			if not bool(result.get("valid", false)):
				return result
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
