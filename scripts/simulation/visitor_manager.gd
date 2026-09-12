## VisitorManager — Centralized visitor lifecycle, tick handling, and culling.
##
## Visitors are prepared and committed through ArrivalCoordinator, then advance
## through the public pedestrian ring to parcel-door service proxies. The manager owns lifecycle and culling.
class_name VisitorManager
extends Node

signal visitor_purchase_result_committed(result: Dictionary)
signal visitor_metrics_snapshot_changed(snapshot: Dictionary)


## All visitors, visible or not.
var all_visitors: Array[VisitorData] = []

## Visitor ID counter.
var _visitor_counter: int = 0

var _service_proxies: Dictionary = {}
var _proxy_queues: Dictionary = {}
var _purchase_results: Dictionary = {}
var _metric_revision: int = 0
var _metric_day: int = 0
var _daily_arrivals: int = 0
var _finalized_arrival_total: int = 0
var _finalized_day_count: int = 0
var _metrics_initialized: bool = true
var _route_counter: int = 0
const MAX_REPATH_ATTEMPTS: int = 3

## Current floor for culling.
var _current_floor: String = "G"

## Current zoom level for culling.
var _current_zoom: float = 20.0

## Hide visitors when zoomed farther out than this threshold.
const ZOOM_HIDE_THRESHOLD: float = 35.0

## Maximum active visitors for the current MVP.
const MAX_VISITORS: int = 200

## Maximum visible visitor Node3Ds supported by the architecture.
const MAX_VISIBLE_VISITORS: int = 60
const PERSISTENCE_SCHEMA_VERSION: int = 2
const PERSISTENCE_FIELDS: Array[String] = ["schema_version", "visitor_counter", "visitors", "purchase_results", "metrics"]
const VISITOR_RECORD_FIELDS: Array[String] = ["id", "lifecycle_state", "arrival_source_id", "destination_reference", "purpose", "budget", "needs", "patience", "satisfaction", "floor_level", "location_type"]
const DURABLE_LIFECYCLE_STATES: Array[String] = ["moving", "moving_to_proxy", "queued", "leaving", "leaving_waiting"]

## Visitors are dimmed while the player is in Building mode.
const BUILDING_MODE_VISITOR_OPACITY: float = 0.5


var _pedestrian_area: PedestrianArea
var _visual_container: Node3D
var _pathfinding_graph: PathfindingGraph
var _proxy_anchor_resolver: Callable = Callable()
var _visitor_scene: PackedScene
var _visitor_mode_opacity: float = 1.0
var _arrival_coordinator: ArrivalCoordinator
var _arrival_commit_gate: ArrivalCommitGate
var prepare_arrival_enabled: bool = true
var commit_arrival_enabled: bool = true
var _projection_floor_height: float = 0.0


func configure_projection_metrics(metrics: ProjectionMetrics) -> Dictionary:
	if metrics == null or not bool(metrics.validate().get("valid", false)):
		return {"valid": false, "diagnostics": [{"code": "PROJECTION_METRICS_REQUIRED"}]}
	_projection_floor_height = metrics.floor_height
	return {"valid": true, "diagnostics": []}


func configure_arrival_coordinator(coordinator: ArrivalCoordinator) -> void:
	_arrival_coordinator = coordinator


func set_arrival_commit_gate(gate: ArrivalCommitGate) -> void:
	_arrival_commit_gate = gate


func get_arrival_commit_gate() -> ArrivalCommitGate:
	return _arrival_commit_gate


func get_active_visitor_count() -> int:
	return all_visitors.size()


func consume_service_proxies(proxies: Array[Dictionary]) -> Dictionary:
	var next_proxies: Dictionary = {}
	for proxy_data: Dictionary in proxies:
		var proxy := VisitorServiceProxy.new()
		proxy.configure(proxy_data)
		if not bool(proxy.validate().get("valid", false)):
			continue
		if not bool(proxy_data.get("tenant_active", false)) or not bool(proxy_data.get("public_corridor_reachable", false)) or not bool(proxy_data.get("proxy_enabled", false)):
			continue
		next_proxies[String(proxy_data["parcel_door_proxy_id"])] = proxy_data.duplicate(true)
	_service_proxies = next_proxies
	return {"valid": true, "proxy_count": _service_proxies.size(), "diagnostics": []}


func set_proxy_anchor_resolver(resolver: Callable) -> void:
	_proxy_anchor_resolver = resolver


func select_service_proxy(_visitor_id: String) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for proxy: Dictionary in _service_proxies.values():
		candidates.append(proxy)
	return VisitorServiceProxy.select_canonical(candidates)


## Capture one detached, eligible proxy snapshot for a visitor behavior decision.
func capture_service_proxy_snapshot(visitor_id: String) -> Dictionary:
	var selected: Dictionary = select_service_proxy(visitor_id)
	if not bool(selected.get("valid", false)):
		return selected
	var proxy: Dictionary = selected["proxy"].duplicate(true)
	return {"valid": true, "visitor_id": visitor_id, "proxy": proxy, "proxy_revision": int(proxy["proxy_policy_revision"]), "topology_revision": int(proxy["topology_revision"]), "tenant_revision": int(proxy["tenant_revision"]), "diagnostics": []}


## Revalidate a proxy against its captured immutable revisions before queue/use.
func revalidate_service_proxy(proxy_id: String, proxy_revision: int, topology_revision: int, tenant_revision: int) -> Dictionary:
	if not _service_proxies.has(proxy_id):
		return {"valid": false, "diagnostics": [{"code": "SERVICE_PROXY_STALE"}]}
	var proxy: Dictionary = _service_proxies[proxy_id]
	if int(proxy.get("proxy_policy_revision", -1)) != proxy_revision or int(proxy.get("topology_revision", -1)) != topology_revision or int(proxy.get("tenant_revision", -1)) != tenant_revision:
		return {"valid": false, "diagnostics": [{"code": "SERVICE_PROXY_STALE"}]}
	if not bool(proxy.get("tenant_active", false)) or not bool(proxy.get("public_corridor_reachable", false)) or not bool(proxy.get("proxy_enabled", false)):
		return {"valid": false, "diagnostics": [{"code": "SERVICE_PROXY_UNAVAILABLE"}]}
	return {"valid": true, "proxy": proxy.duplicate(true), "diagnostics": []}


## Request a route to a public-side proxy anchor. Route geometry is transient.
func request_proxy_route(visitor_id: String, snapshot: Dictionary) -> Dictionary:
	var visitor: VisitorData = _find_visitor(visitor_id)
	if visitor == null or not bool(snapshot.get("valid", false)):
		return {"valid": false, "diagnostics": [{"code": "VISITOR_ROUTE_REQUEST_INVALID"}]}
	var proxy: Dictionary = snapshot.get("proxy", {})
	var proxy_id: String = String(proxy.get("parcel_door_proxy_id", ""))
	if proxy_id.is_empty():
		return {"valid": false, "diagnostics": [{"code": "SERVICE_PROXY_INVALID"}]}
	var anchor_result: Dictionary = _resolve_proxy_anchor(String(proxy.get("corridor_anchor_id", "")))
	if not bool(anchor_result.get("valid", false)):
		return anchor_result
	var anchor_position: Vector3 = anchor_result["position"]
	_route_counter += 1
	visitor.target_proxy_id = proxy_id
	visitor.target_proxy_policy_revision = int(snapshot.get("proxy_revision", -1))
	visitor.target_topology_revision = int(snapshot.get("topology_revision", -1))
	visitor.target_tenant_revision = int(snapshot.get("tenant_revision", -1))
	visitor.route_request_id = "visitor_route_%d" % _route_counter
	visitor.route_repath_attempts = 0
	visitor.current_state = "moving_to_proxy"
	visitor.target_position = anchor_position
	if visitor.is_visible and is_instance_valid(visitor.visual_node):
		var visual := visitor.visual_node as Visitor
		var route_variant: Variant = anchor_result.get("path", [])
		if route_variant is Array and not route_variant.is_empty():
			var route: Array[Vector3] = []
			for point: Variant in route_variant:
				if point is Vector3:
					route.append(point)
			if not route.is_empty():
				visual.set_path(route)
			else:
				visual.set_target(anchor_position)
		else:
			visual.set_target(anchor_position)
	return {"valid": true, "route_request_id": visitor.route_request_id, "target_proxy_id": proxy_id, "diagnostics": []}


func _resolve_proxy_anchor(anchor_id: String) -> Dictionary:
	if anchor_id.is_empty() or not _proxy_anchor_resolver.is_valid():
		return {"valid": false, "diagnostics": [{"code": "CORRIDOR_ANCHOR_UNRESOLVED"}]}
	var resolved: Variant = _proxy_anchor_resolver.call(anchor_id)
	if not resolved is Dictionary or not bool(resolved.get("valid", false)):
		return {"valid": false, "diagnostics": resolved.get("diagnostics", [{"code": "CORRIDOR_ANCHOR_UNRESOLVED"}]) if resolved is Dictionary else [{"code": "CORRIDOR_ANCHOR_UNRESOLVED"}]}
	if not resolved.get("position", null) is Vector3:
		return {"valid": false, "diagnostics": [{"code": "CORRIDOR_ANCHOR_UNRESOLVED"}]}
	return resolved.duplicate(true)


func cancel_proxy_target(visitor_id: String) -> Dictionary:
	var visitor: VisitorData = _find_visitor(visitor_id)
	if visitor == null:
		return {"valid": false, "diagnostics": [{"code": "VISITOR_NOT_FOUND"}]}
	_clear_proxy_target(visitor)
	if visitor.current_state == "moving_to_proxy" or visitor.current_state == "queued":
		visitor.current_state = "moving"
	return {"valid": true, "diagnostics": []}


func _find_visitor(visitor_id: String) -> VisitorData:
	for visitor: VisitorData in all_visitors:
		if visitor.id == visitor_id:
			return visitor
	return null


func enqueue_service_proxy(visitor_id: String, proxy_id: String) -> Dictionary:
	if not _service_proxies.has(proxy_id):
		return {"valid": false, "diagnostics": [{"code": "SERVICE_PROXY_UNAVAILABLE"}]}
	var proxy: Dictionary = _service_proxies[proxy_id]
	if not bool(proxy.get("queue_accepting", false)):
		return {"valid": false, "diagnostics": [{"code": "SERVICE_PROXY_QUEUE_UNAVAILABLE"}]}
	var queue: Array[String] = []
	for queued_id: Variant in _proxy_queues.get(proxy_id, []):
		if queued_id is String:
			queue.append(queued_id)
	if queue.has(visitor_id):
		return {"valid": true, "already_queued": true, "diagnostics": []}
	queue.append(visitor_id)
	_proxy_queues[proxy_id] = queue
	return {"valid": true, "diagnostics": []}


func cancel_service_proxy(visitor_id: String, proxy_id: String) -> void:
	if not _proxy_queues.has(proxy_id):
		return
	var queue: Array[String] = []
	for queued_id: Variant in _proxy_queues[proxy_id]:
		if queued_id is String:
			queue.append(queued_id)
	queue.erase(visitor_id)
	if queue.is_empty():
		_proxy_queues.erase(proxy_id)
	else:
		_proxy_queues[proxy_id] = queue


func complete_service_proxy(visitor_id: String, proxy_id: String, simulation_day: int) -> Dictionary:
	if _purchase_results.has(visitor_id):
		return {"valid": false, "diagnostics": [{"code": "VISITOR_PURCHASE_ALREADY_COMMITTED"}]}
	var queue: Array[String] = []
	for queued_id: Variant in _proxy_queues.get(proxy_id, []):
		if queued_id is String:
			queue.append(queued_id)
	if not queue.has(visitor_id) or not _service_proxies.has(proxy_id):
		return {"valid": false, "diagnostics": [{"code": "SERVICE_PROXY_UNAVAILABLE"}]}
	var proxy: Dictionary = _service_proxies[proxy_id]
	queue.erase(visitor_id)
	if queue.is_empty():
		_proxy_queues.erase(proxy_id)
	else:
		_proxy_queues[proxy_id] = queue
	var result := {"visitor_id": visitor_id, "parcel_door_proxy_id": proxy_id, "tenant_id": String(proxy["tenant_id"]), "parcel_id": String(proxy["parcel_id"]), "door_id": String(proxy["door_id"]), "result_kind": "proxy_interaction_completed", "simulation_day": simulation_day, "proxy_policy_revision": int(proxy["proxy_policy_revision"])}
	_purchase_results[visitor_id] = result.duplicate(true)
	visitor_purchase_result_committed.emit(result.duplicate(true))
	return {"valid": true, "result": result, "diagnostics": []}


func get_metrics_snapshot() -> Dictionary:
	var average_available := _finalized_day_count > 0
	var average: float = float(_finalized_arrival_total) / float(_finalized_day_count) if average_available else 0.0
	return {"schema_version": VisitorMetricsSnapshot.SCHEMA_VERSION, "simulation_day": _metric_day, "metric_revision": _metric_revision, "current_visitors": all_visitors.size(), "daily_arrivals": _daily_arrivals, "daily_average_arrivals": average, "finalized_arrival_total": _finalized_arrival_total, "finalized_day_count": _finalized_day_count, "average_available": average_available, "provenance": "visitor_metrics_revision_%d" % _metric_revision}


func on_sim_day_passed(simulation_day: int) -> void:
	if simulation_day != _metric_day:
		if _metrics_initialized:
			_finalized_arrival_total += _daily_arrivals
			_finalized_day_count += 1
		_metrics_initialized = true
		_metric_day = simulation_day
		_daily_arrivals = 0
		_metric_revision += 1
		visitor_metrics_snapshot_changed.emit(get_metrics_snapshot())


func _clear_proxy_target(visitor: VisitorData) -> void:
	if visitor.queued_proxy_id != "":
		cancel_service_proxy(visitor.id, visitor.queued_proxy_id)
	visitor.target_proxy_id = ""
	visitor.target_proxy_policy_revision = -1
	visitor.target_topology_revision = -1
	visitor.target_tenant_revision = -1
	visitor.route_request_id = ""
	visitor.route_repath_attempts = 0
	visitor.queued_proxy_id = ""
	if visitor.is_visible and is_instance_valid(visitor.visual_node):
		var visual := visitor.visual_node as Visitor
		if visual:
			visual.clear_target()


func _ready() -> void:
	_pedestrian_area = get_tree().get_first_node_in_group("pedestrian_walkable") as PedestrianArea
	_visual_container = get_tree().current_scene.get_node_or_null("World/Visitors") as Node3D

	if _pedestrian_area == null:
		push_error("VisitorManager: PedestrianArea walkable marker not found.")
		return
	if _visual_container == null:
		push_error("VisitorManager: World/Visitors visual container not found.")
		return

	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager != null:
		game_manager.connect("ui_mode_changed", _on_ui_mode_changed)
	_visitor_mode_opacity = _get_mode_visitor_opacity()
	_apply_culling()


## Called by TimeManager on each visitor_tick.
func on_visitor_tick(_tick: int = 0) -> Dictionary:
	if _arrival_coordinator != null:
		var session_owner_token: String = ""
		if _arrival_commit_gate != null and _arrival_commit_gate.get_session_gate() != null and _arrival_commit_gate.get_session_gate().is_held():
			session_owner_token = _arrival_commit_gate.get_session_gate().get_owner_token()
		var arrival_result: Dictionary = _arrival_coordinator.on_visitor_tick(session_owner_token)
		if not bool(arrival_result.get("valid", false)):
			return arrival_result
	_revalidate_leaving_visitors()
	_decay_visitor_needs()
	_sync_data_positions()
	_apply_culling()
	return {"valid": true, "diagnostics": []}



## Decay needs for all visitors.
func _decay_visitor_needs() -> void:
	for visitor: VisitorData in all_visitors:
		visitor.decay_needs()


## Keep serialized visitor positions current without owning visual movement.
func _sync_data_positions() -> void:
	for visitor: VisitorData in all_visitors:
		if visitor.is_visible and is_instance_valid(visitor.visual_node):
			visitor.position = visitor.visual_node.global_position


## Advance a visitor to the next waypoint on the pedestrian ring.
func _set_next_pedestrian_target(visitor: VisitorData) -> void:
	if _pedestrian_area == null:
		return

	visitor.waypoint_index = _pedestrian_area.get_next_waypoint_index(visitor.waypoint_index)
	visitor.target_position = _pedestrian_area.get_waypoint(visitor.waypoint_index)
	visitor.current_state = "moving"
	if visitor.is_visible and is_instance_valid(visitor.visual_node):
		var visual := visitor.visual_node as Visitor
		if visual:
			visual.set_target(visitor.target_position)


## Select a public-corridor parcel-door proxy without entering the tenant parcel.
func _begin_visitor_entry(visitor: VisitorData, _side: int) -> void:
	var snapshot: Dictionary = capture_service_proxy_snapshot(visitor.id)
	if not bool(snapshot.get("valid", false)):
		_set_next_pedestrian_target(visitor)
		return
	var route_result: Dictionary = request_proxy_route(visitor.id, snapshot)
	if not bool(route_result.get("valid", false)):
		_clear_proxy_target(visitor)
		_set_next_pedestrian_target(visitor)


func _on_visitor_target_reached(visitor: VisitorData) -> void:
	if not all_visitors.has(visitor):
		return
	# The visual node reaches the target between simulation ticks. Keep the
	# serialized position synchronized before choosing the next grid path.
	visitor.position = visitor.target_position
	if visitor.current_state == "leaving":
		if _arrival_coordinator == null:
			remove_visitor(visitor.id)
			return
		var exit_result: Dictionary = _arrival_coordinator.revalidate_exit_source(visitor.arrival_source_id)
		if not bool(exit_result.get("valid", false)):
			visitor.current_state = "leaving_waiting"
			if visitor.is_visible and is_instance_valid(visitor.visual_node):
				var waiting_visual := visitor.visual_node as Visitor
				if waiting_visual:
					waiting_visual.clear_target()
			return
		var exit_source: Dictionary = exit_result.get("source", {})
		if String(exit_source.get("arrival_source_id", "")) != visitor.arrival_source_id or visitor.target_position != _source_position(exit_source):
			_set_exit_target(visitor, exit_source)
			return
		remove_visitor(visitor.id)
		return
	if visitor.current_state == "moving_to_proxy":
		_complete_proxy_interaction(visitor)
		return
	if visitor.current_state == "queued":
		_complete_proxy_interaction(visitor)
		return

	var door_side := _get_door_side_for_waypoint(visitor.waypoint_index)
	if door_side != 0:
		if _is_exterior_door_open(door_side):
			_begin_visitor_entry(visitor, door_side)
		else:
			_set_next_pedestrian_target(visitor)
	else:
		_set_next_pedestrian_target(visitor)


func _complete_proxy_interaction(visitor: VisitorData) -> void:
	var validation: Dictionary = revalidate_service_proxy(
		visitor.target_proxy_id,
		visitor.target_proxy_policy_revision,
		visitor.target_topology_revision,
		visitor.target_tenant_revision
	)
	if not bool(validation.get("valid", false)):
		var repath_attempts: int = visitor.route_repath_attempts + 1
		_clear_proxy_target(visitor)
		if repath_attempts <= MAX_REPATH_ATTEMPTS:
			var fresh_snapshot: Dictionary = capture_service_proxy_snapshot(visitor.id)
			if bool(fresh_snapshot.get("valid", false)) and bool(request_proxy_route(visitor.id, fresh_snapshot).get("valid", false)):
				visitor.route_repath_attempts = repath_attempts
				return
		visitor.current_state = "moving"
		return
	var queue_result: Dictionary = enqueue_service_proxy(visitor.id, visitor.target_proxy_id)
	if not bool(queue_result.get("valid", false)):
		_clear_proxy_target(visitor)
		visitor.current_state = "moving"
		return
	visitor.queued_proxy_id = visitor.target_proxy_id
	visitor.current_state = "queued"
	var result: Dictionary = complete_service_proxy(visitor.id, visitor.target_proxy_id, _metric_day)
	if bool(result.get("valid", false)):
		_clear_proxy_target(visitor)
		visitor.current_state = "moving"
	else:
		_clear_proxy_target(visitor)
		visitor.current_state = "moving"


func _get_door_side_for_waypoint(waypoint_index: int) -> int:
	if _pedestrian_area == null:
		return 0
	for side: int in [
		PedestrianArea.DOOR_NORTH, PedestrianArea.DOOR_SOUTH,
		PedestrianArea.DOOR_EAST, PedestrianArea.DOOR_WEST
	]:
		if waypoint_index == _pedestrian_area.get_door_waypoint_index(side):
			return side
	return 0


func _is_exterior_door_open(_side: int) -> bool:
	# H8 arrival eligibility is the production authority for visitor entry.
	return _arrival_coordinator != null


func _get_door_exterior_position(side: int) -> Vector2i:
	match side:
		PedestrianArea.DOOR_NORTH:
			return Vector2i(12, -1)
		PedestrianArea.DOOR_SOUTH:
			return Vector2i(12, 25)
		PedestrianArea.DOOR_EAST:
			return Vector2i(25, 12)
		PedestrianArea.DOOR_WEST:
			return Vector2i(-1, 12)
	return Vector2i.ZERO



# ── Culling ────────────────────────────────────────────────────────────

func _get_mode_visitor_opacity() -> float:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	return BUILDING_MODE_VISITOR_OPACITY if game_manager != null and int(game_manager.get("ui_mode")) == 0 else 1.0


func _on_ui_mode_changed(_mode: String) -> void:
	_visitor_mode_opacity = _get_mode_visitor_opacity()
	for visitor: VisitorData in all_visitors:
		if visitor.is_visible and is_instance_valid(visitor.visual_node):
			var visual := visitor.visual_node as Visitor
			if visual:
				visual.set_mode_opacity(_visitor_mode_opacity)


## Apply floor-based and zoom-based culling.
func _apply_culling() -> void:
	var zoom_hide := _current_zoom > ZOOM_HIDE_THRESHOLD
	for visitor: VisitorData in all_visitors:
		var should_show := not zoom_hide and _is_visible_on_current_view(visitor)
		if should_show and not visitor.is_visible:
			_show_visitor(visitor)
		elif not should_show and visitor.is_visible:
			_hide_visitor(visitor)


func _is_visible_on_current_view(visitor: VisitorData) -> bool:
	if visitor.location_type == "pedestrian_area":
		return _current_floor == "G"
	return visitor.floor_level == _current_floor


## Create the reusable visual scene for a visitor.
func _show_visitor(visitor: VisitorData) -> void:
	if visitor.visual_node or _visual_container == null:
		return

	var node := _get_visitor_scene().instantiate() as Visitor
	if node == null:
		return
	_visual_container.add_child(node)
	node.global_position = visitor.position
	node.set_mode_opacity(_visitor_mode_opacity, 0.0)
	node.target_reached.connect(_on_visitor_target_reached.bind(visitor))
	node.set_target(visitor.target_position)

	visitor.visual_node = node
	visitor.is_visible = true


## Remove only the visual node; simulation data remains.
func _hide_visitor(visitor: VisitorData) -> void:
	if visitor.visual_node and is_instance_valid(visitor.visual_node):
		visitor.visual_node.queue_free()
	visitor.visual_node = null
	visitor.is_visible = false


## Load the dedicated visitor scene.
func _get_visitor_scene() -> PackedScene:
	if _visitor_scene:
		return _visitor_scene
	_visitor_scene = load("res://scenes/characters/visitor.tscn") as PackedScene
	if _visitor_scene == null:
		push_error("VisitorManager: Cannot load scenes/characters/visitor.tscn.")
	return _visitor_scene


# ── Camera Integration ─────────────────────────────────────────────────

## Called when camera changes floor.
func on_floor_changed(floor_level: String) -> void:
	_current_floor = floor_level
	for visitor: VisitorData in all_visitors:
		_hide_visitor(visitor)
	_apply_culling()


## Called when camera zoom changes.
func on_zoom_changed(zoom: float) -> void:
	_current_zoom = zoom
	_apply_culling()


# ── Lifecycle ──────────────────────────────────────────────────────────

## Request a voluntary exit through a canonically selected eligible arrival source.
func request_visitor_leave(visitor_id: String) -> void:
	if _arrival_coordinator != null:
		var selected: Dictionary = _arrival_coordinator.select_exit_source()
		if not bool(selected.get("valid", false)):
			for waiting_visitor: VisitorData in all_visitors:
				if waiting_visitor.id == visitor_id:
					waiting_visitor.current_state = "leaving_waiting"
			return
		var source: Dictionary = selected.get("source", {})
		for visitor: VisitorData in all_visitors:
			if visitor.id != visitor_id or visitor.current_state == "leaving":
				continue
			_set_exit_target(visitor, source)
			return
		return


## Prepare a detached visitor record without exposing it to lifecycle, save, or observers.
func prepare_detached_visitor(arrival_source_id: String, source_record: Dictionary, demand_snapshot: ArrivalDemandSnapshot) -> Dictionary:
	if not prepare_arrival_enabled:
		return {"valid": false, "diagnostics": [{"code": "VISITOR_PREPARE_FAILED", "message": "visitor preparation was rejected"}]}
	if arrival_source_id.is_empty() or demand_snapshot == null:
		return {"valid": false, "diagnostics": [{"code": "VISITOR_PREPARE_INPUT_INVALID", "message": "arrival source and demand snapshot are required"}]}
	var position: Vector3 = _source_position(source_record)
	var counter_before: int = _visitor_counter
	var visitor := VisitorData.new()
	visitor.initialize(_next_id(), "G", position)
	visitor.arrival_source_id = arrival_source_id
	visitor.demand_snapshot_id = demand_snapshot.snapshot_id
	visitor.location_type = "pedestrian_area"
	visitor.position = position
	visitor.target_position = position
	visitor.current_state = "moving"
	return {
		"valid": true,
		"visitor": visitor,
		"visitor_id": visitor.id,
		"arrival_source_id": arrival_source_id,
		"demand_snapshot_id": demand_snapshot.snapshot_id,
		"counter_before": counter_before,
		"source": source_record.duplicate(true),
		"diagnostics": [],
	}


## Commit a prepared record into VisitorManager-owned immutable visitor state.
func commit_prepared_visitor(prepared: Dictionary) -> Dictionary:
	if not commit_arrival_enabled:
		return {"valid": false, "diagnostics": [{"code": "VISITOR_COMMIT_FAILED", "message": "visitor commit was rejected"}]}
	if all_visitors.size() >= MAX_VISITORS:
		return {"valid": false, "diagnostics": [{"code": "MAX_ACTIVE_VISITORS_REACHED", "message": "the global active visitor budget is full"}]}
	if _arrival_commit_gate != null and not _arrival_commit_gate.is_held():
		return {"valid": false, "diagnostics": [{"code": "ARRIVAL_GATE_REQUIRED", "message": "visitor state may only commit while the arrival gate is held"}]}
	var visitor: VisitorData = prepared.get("visitor", null) as VisitorData
	if visitor == null or String(prepared.get("visitor_id", "")) != visitor.id:
		return {"valid": false, "diagnostics": [{"code": "VISITOR_RECORD_INVALID", "message": "prepared visitor record is invalid"}]}
	all_visitors.append(visitor)
	_daily_arrivals += 1
	_metric_revision += 1
	visitor_metrics_snapshot_changed.emit(get_metrics_snapshot())
	return {"valid": true, "visitor": visitor, "diagnostics": []}


## Restore VisitorManager state after a pre-append failure.
func rollback_prepared_visitor(prepared: Dictionary) -> void:
	var visitor_id: String = String(prepared.get("visitor_id", ""))
	for index: int in range(all_visitors.size() - 1, -1, -1):
		if all_visitors[index].id == visitor_id:
			_clear_proxy_target(all_visitors[index])
			_hide_visitor(all_visitors[index])
			all_visitors.remove_at(index)
			break
	_visitor_counter = int(prepared.get("counter_before", _visitor_counter))
	_daily_arrivals = maxi(_daily_arrivals - 1, 0)
	_metric_revision += 1


func _set_exit_target(visitor: VisitorData, source: Dictionary) -> void:
	visitor.arrival_source_id = String(source.get("arrival_source_id", ""))
	visitor.current_state = "leaving"
	visitor.target_position = _source_position(source)
	if visitor.is_visible and is_instance_valid(visitor.visual_node):
		var visual := visitor.visual_node as Visitor
		if visual:
			visual.set_target(visitor.target_position)


func _revalidate_leaving_visitors() -> void:
	if _arrival_coordinator == null:
		return
	for visitor: VisitorData in all_visitors:
		if visitor.current_state != "leaving" and visitor.current_state != "leaving_waiting":
			continue
		var result: Dictionary = _arrival_coordinator.revalidate_exit_source(visitor.arrival_source_id)
		if not bool(result.get("valid", false)):
			visitor.current_state = "leaving_waiting"
			if visitor.is_visible and is_instance_valid(visitor.visual_node):
				var waiting_visual := visitor.visual_node as Visitor
				if waiting_visual:
					waiting_visual.clear_target()
			continue
		_set_exit_target(visitor, result.get("source", {}))


func _source_position(source_record: Dictionary) -> Vector3:
	if source_record.get("position", null) is Vector3:
		return source_record["position"]
	var pose: Dictionary = source_record.get("pose", {})
	if pose.is_empty():
		pose = source_record.get("gateway_projection", {}).get("baseline_pose", {})
	if _projection_floor_height <= 0.0:
		push_error("VisitorManager: ProjectionMetrics must be configured before resolving an arrival source.")
		return Vector3.ZERO
	return Vector3(float(pose.get("x4", 0)) / 4.0, float(pose.get("elevation", 0)) * _projection_floor_height, float(pose.get("z4", 0)) / 4.0)


## Remove a visitor and their visual node.
func remove_visitor(visitor_id: String) -> void:
	for index in range(all_visitors.size() - 1, -1, -1):
		if all_visitors[index].id == visitor_id:
			var visitor := all_visitors[index]
			_clear_proxy_target(visitor)
			_hide_visitor(visitor)
			var event_bus: Node = get_node_or_null("/root/EventBus")
			if event_bus != null:
				event_bus.emit_signal("visitor_left", visitor_id, visitor.satisfaction)
			all_visitors.remove_at(index)
			_metric_revision += 1
			visitor_metrics_snapshot_changed.emit(get_metrics_snapshot())
			break


# ── Helpers ────────────────────────────────────────────────────────────

func _next_id() -> String:
	_visitor_counter += 1
	return "visitor_%d" % _visitor_counter


# ── Serialization ──────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var records: Array[Dictionary] = []
	for visitor: VisitorData in all_visitors:
		records.append({
			"id": visitor.id,
			"lifecycle_state": visitor.current_state if DURABLE_LIFECYCLE_STATES.has(visitor.current_state) else "moving",
			"arrival_source_id": visitor.arrival_source_id,
			"destination_reference": visitor.target_proxy_id,
			"purpose": int(visitor.purpose),
			"budget": visitor.budget,
			"needs": visitor.needs.duplicate(true),
			"patience": visitor.patience,
			"satisfaction": visitor.satisfaction,
			"floor_level": visitor.floor_level,
			"location_type": visitor.location_type,
		})
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["id"]) < String(right["id"]))
	var purchase_results: Array[Dictionary] = []
	for result: Dictionary in _purchase_results.values():
		purchase_results.append(result.duplicate(true))
	purchase_results.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("visitor_id", "")) < String(right.get("visitor_id", "")))
	return {
		"schema_version": PERSISTENCE_SCHEMA_VERSION,
		"visitor_counter": _visitor_counter,
		"visitors": records,
		"purchase_results": purchase_results,
		"metrics": {
			"metric_day": _metric_day,
			"daily_arrivals": _daily_arrivals,
			"finalized_arrival_total": _finalized_arrival_total,
			"finalized_day_count": _finalized_day_count,
			"metric_revision": _metric_revision,
		},
	}


func validate_serialized(data: Dictionary) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if data.keys().size() != PERSISTENCE_FIELDS.size():
		diagnostics.append({"code": "VISITOR_FIELDS_INVALID", "path": "$"})
	for field: String in PERSISTENCE_FIELDS:
		if not data.has(field):
			diagnostics.append({"code": "VISITOR_FIELD_MISSING", "path": "$.%s" % field})
	if typeof(data.get("schema_version")) != TYPE_INT or int(data.get("schema_version", -1)) != PERSISTENCE_SCHEMA_VERSION:
		diagnostics.append({"code": "VISITOR_SCHEMA_INVALID", "path": "$.schema_version"})
	if typeof(data.get("visitor_counter")) != TYPE_INT or int(data.get("visitor_counter", -1)) < 0:
		diagnostics.append({"code": "VISITOR_COUNTER_INVALID", "path": "$.visitor_counter"})
	if not data.get("visitors") is Array or not data.get("purchase_results") is Array or not data.get("metrics") is Dictionary:
		diagnostics.append({"code": "VISITOR_SNAPSHOT_INVALID", "path": "$"})
		return {"valid": false, "diagnostics": diagnostics}
	var seen: Dictionary = {}
	var previous_id: String = ""
	var maximum_ordinal: int = 0
	for index: int in range((data["visitors"] as Array).size()):
		var path: String = "$.visitors[%d]" % index
		var value: Variant = data["visitors"][index]
		if not value is Dictionary:
			diagnostics.append({"code": "VISITOR_RECORD_INVALID", "path": path})
			continue
		var record: Dictionary = value
		if record.keys().size() != VISITOR_RECORD_FIELDS.size():
			diagnostics.append({"code": "VISITOR_RECORD_FIELDS_INVALID", "path": path})
		for field: String in VISITOR_RECORD_FIELDS:
			if not record.has(field):
				diagnostics.append({"code": "VISITOR_RECORD_FIELD_MISSING", "path": "%s.%s" % [path, field]})
		var visitor_id: String = String(record.get("id", ""))
		var ordinal: int = _visitor_ordinal(visitor_id)
		if ordinal < 1 or seen.has(visitor_id) or (not previous_id.is_empty() and previous_id >= visitor_id):
			diagnostics.append({"code": "VISITOR_ID_INVALID", "path": "%s.id" % path})
		seen[visitor_id] = true
		previous_id = visitor_id
		maximum_ordinal = maxi(maximum_ordinal, ordinal)
		if String(record.get("arrival_source_id", "")).is_empty() or not DURABLE_LIFECYCLE_STATES.has(String(record.get("lifecycle_state", ""))):
			diagnostics.append({"code": "VISITOR_REFERENCE_INVALID", "path": path})
		if typeof(record.get("destination_reference")) != TYPE_STRING or typeof(record.get("purpose")) != TYPE_INT or not record.get("needs") is Dictionary:
			diagnostics.append({"code": "VISITOR_RECORD_INVALID", "path": path})
		for numeric_field: String in ["budget", "patience", "satisfaction"]:
			if typeof(record.get(numeric_field)) != TYPE_INT:
				diagnostics.append({"code": "VISITOR_RECORD_INVALID", "path": "%s.%s" % [path, numeric_field]})
	if (data["visitors"] as Array).size() > MAX_VISITORS or maximum_ordinal > int(data.get("visitor_counter", -1)):
		diagnostics.append({"code": "VISITOR_COUNTER_INVALID", "path": "$.visitor_counter"})
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func deserialize(data: Dictionary) -> Dictionary:
	var validation: Dictionary = validate_serialized(data)
	if not bool(validation.get("valid", false)):
		return validation
	for visitor: VisitorData in all_visitors:
		_hide_visitor(visitor)
	all_visitors.clear()
	_proxy_queues.clear()
	_purchase_results.clear()
	_route_counter = 0
	_visitor_counter = int(data["visitor_counter"])
	var metrics: Dictionary = data["metrics"]
	_metric_revision = int(metrics.get("metric_revision", 0))
	_metric_day = int(metrics.get("metric_day", 0))
	_metrics_initialized = true
	_daily_arrivals = int(metrics.get("daily_arrivals", 0))
	_finalized_arrival_total = int(metrics.get("finalized_arrival_total", 0))
	_finalized_day_count = int(metrics.get("finalized_day_count", 0))
	for result_data: Dictionary in data["purchase_results"]:
		_purchase_results[String(result_data.get("visitor_id", ""))] = result_data.duplicate(true)
	for record: Dictionary in data["visitors"]:
		var visitor := VisitorData.new()
		visitor.id = String(record["id"])
		visitor.current_state = String(record["lifecycle_state"])
		visitor.arrival_source_id = String(record["arrival_source_id"])
		visitor.target_proxy_id = String(record["destination_reference"])
		visitor.purpose = int(record["purpose"]) as VisitorData.VisitPurpose
		visitor.budget = int(record["budget"])
		visitor.needs = record["needs"].duplicate(true)
		visitor.patience = int(record["patience"])
		visitor.satisfaction = int(record["satisfaction"])
		visitor.floor_level = String(record["floor_level"])
		visitor.location_type = String(record["location_type"])
		all_visitors.append(visitor)
	return {"valid": true, "diagnostics": []}


## Resolve transient positions from committed source projections before publication.
func prepare_restored_visitors(source_positions: Dictionary) -> Dictionary:
	for visitor: VisitorData in all_visitors:
		if not source_positions.has(visitor.arrival_source_id) or not source_positions[visitor.arrival_source_id] is Vector3:
			return {"valid": false, "diagnostics": [{"code": "VISITOR_ARRIVAL_SOURCE_INVALID", "visitor_id": visitor.id, "arrival_source_id": visitor.arrival_source_id}]}
		visitor.position = source_positions[visitor.arrival_source_id]
		visitor.target_position = visitor.position
		visitor.waypoint_index = 0
		visitor.route_request_id = ""
		visitor.route_repath_attempts = 0
		visitor.queued_proxy_id = ""
	return {"valid": true, "diagnostics": []}


func _visitor_ordinal(visitor_id: String) -> int:
	if not visitor_id.begins_with("visitor_"):
		return -1
	var suffix: String = visitor_id.trim_prefix("visitor_")
	return int(suffix) if suffix.is_valid_int() and int(suffix) > 0 and visitor_id == "visitor_%d" % int(suffix) else -1
