## TimeManager — Session-scoped accumulated simulation and visual clocks.
class_name TimeManager
extends Node

signal visitor_tick(tick: int)
signal sim_hour_passed(hour: int)
signal sim_day_passed(day: int)
signal sim_week_passed(week: int)
signal sim_month_passed(month: int)

const SIM_SECONDS_PER_HOUR: float = 1.0
const SIM_SECONDS_PER_DAY: float = 24.0
const SIM_DAYS_PER_WEEK: int = 7
const SIM_DAYS_PER_MONTH: int = 30
const VISUAL_SECONDS_PER_DAY: float = 600.0
const VISITOR_TICK_INTERVAL: float = 5.0
const BOUNDARY_KINDS: Array[String] = ["visitor", "hour", "day", "week", "month"]

var sim_time: float = 0.0
var visual_time: float = 0.0
var speed: int = 0
var sim_day: int = 0
var sim_month: int = 0

var _last_visitor_tick: int = 0
var _last_sim_hour: int = 0
var _last_sim_day: int = 0
var _last_sim_week: int = 0
var _last_sim_month: int = 0
var _session_gate: SessionMutationGate
var _boundary_coordinator: Callable
var _pending_boundary: Dictionary = {}


func configure_boundary_delivery(session_gate: SessionMutationGate, coordinator: Callable) -> Dictionary:
	if session_gate == null or not coordinator.is_valid():
		return {"valid": false, "diagnostics": [{"code": "BOUNDARY_COORDINATOR_REQUIRED", "message": "TimeManager requires the session gate and direct boundary coordinator"}]}
	_session_gate = session_gate
	_boundary_coordinator = coordinator
	return {"valid": true, "diagnostics": []}


func _process(delta: float) -> void:
	if not _pending_boundary.is_empty():
		retry_pending_boundary()
		return
	if speed == 0:
		return
	var effective_delta: float = delta * float(speed)
	sim_time += effective_delta
	visual_time += effective_delta
	_emit_crossed_boundaries()


## Deliver every crossed boundary in chronological tie order. A boundary
## advances only after its complete mandatory successor chain succeeds.
func _emit_crossed_boundaries() -> void:
	while true:
		var next: Dictionary = _next_boundary()
		if next.is_empty() or float(next["time"]) > sim_time + 0.000001:
			return
		if not _deliver_boundary(String(next["kind"]), int(next["id"])):
			return


func retry_pending_boundary() -> Dictionary:
	if _pending_boundary.is_empty():
		return {"valid": true, "retried": false, "diagnostics": []}
	var pending: Dictionary = _pending_boundary.duplicate(true)
	if _deliver_boundary(String(pending["kind"]), int(pending["id"]), true):
		return {"valid": true, "retried": true, "diagnostics": []}
	return {"valid": false, "retried": true, "diagnostics": _pending_boundary.get("diagnostics", []).duplicate(true)}


func has_pending_boundary() -> bool:
	return not _pending_boundary.is_empty()


func get_pending_boundary() -> Dictionary:
	return _pending_boundary.duplicate(true)


func set_speed(new_speed: int) -> void:
	if not _pending_boundary.is_empty() and new_speed > 0:
		speed = 0
		return
	speed = clampi(new_speed, 0, 3)


func _next_boundary() -> Dictionary:
	var times: Array[float] = [
		float(_last_visitor_tick + 1) * VISITOR_TICK_INTERVAL,
		float(_last_sim_hour + 1) * SIM_SECONDS_PER_HOUR,
		float(_last_sim_day + 1) * SIM_SECONDS_PER_DAY,
		float(_last_sim_week + 1) * SIM_SECONDS_PER_DAY * float(SIM_DAYS_PER_WEEK),
		float(_last_sim_month + 1) * SIM_SECONDS_PER_DAY * float(SIM_DAYS_PER_MONTH),
	]
	var next_index: int = 0
	for index: int in range(1, times.size()):
		if times[index] < times[next_index]:
			next_index = index
	return {"kind": BOUNDARY_KINDS[next_index], "id": _boundary_id(next_index), "time": times[next_index]}


func _boundary_id(index: int) -> int:
	match index:
		0:
			return _last_visitor_tick + 1
		1:
			return _last_sim_hour + 1
		2:
			return _last_sim_day + 1
		3:
			return _last_sim_week + 1
		_:
			return _last_sim_month + 1


func _deliver_boundary(kind: String, boundary_id: int, retry: bool = false) -> bool:
	if _session_gate == null or not _boundary_coordinator.is_valid():
		_pause_boundary(kind, boundary_id, [{"code": "BOUNDARY_COORDINATOR_REQUIRED", "message": "calendar boundary delivery is not configured"}])
		return false
	var owner_token: String = "calendar:%s:%d" % [kind, boundary_id]
	var acquired: Dictionary = _session_gate.acquire(owner_token, retry)
	if not bool(acquired.get("valid", false)):
		_pause_boundary(kind, boundary_id, acquired.get("diagnostics", []))
		return false
	var delivery: Variant = _boundary_coordinator.call(kind, boundary_id)
	if not delivery is Dictionary or not bool(delivery.get("valid", false)):
		var diagnostics: Array = [{"code": "BOUNDARY_DELIVERY_FAILED", "message": "calendar coordinator returned an invalid result"}] if not delivery is Dictionary else delivery.get("diagnostics", [])
		_pause_boundary(kind, boundary_id, diagnostics)
		_session_gate.block(owner_token, _pending_boundary)
		_session_gate.release(owner_token)
		return false
	if retry and _session_gate.is_blocked():
		_session_gate.clear_block(owner_token)
	_pending_boundary.clear()
	_advance_boundary(kind, boundary_id)
	_session_gate.release(owner_token)
	return true


func _advance_boundary(kind: String, boundary_id: int) -> void:
	match kind:
		"visitor":
			_last_visitor_tick = boundary_id
			visitor_tick.emit(boundary_id)
		"hour":
			_last_sim_hour = boundary_id
			sim_hour_passed.emit(boundary_id)
		"day":
			_last_sim_day = boundary_id
			sim_day = boundary_id
			sim_day_passed.emit(boundary_id)
			_emit_optional_event_bus("sim_day_passed", boundary_id)
		"week":
			_last_sim_week = boundary_id
			sim_week_passed.emit(boundary_id)
		"month":
			_last_sim_month = boundary_id
			sim_month = boundary_id
			sim_month_passed.emit(boundary_id)
			_emit_optional_event_bus("sim_month_passed", boundary_id)


func _pause_boundary(kind: String, boundary_id: int, diagnostics: Array) -> void:
	speed = 0
	_pending_boundary = {"kind": kind, "id": boundary_id, "diagnostics": diagnostics.duplicate(true)}


func _emit_optional_event_bus(signal_name: String, boundary: int) -> void:
	if not is_inside_tree():
		return
	var event_bus: Node = get_tree().root.get_node_or_null("EventBus")
	if event_bus != null:
		event_bus.emit_signal(signal_name, boundary)


func get_visual_hour() -> float:
	var total_seconds: float = fmod(visual_time, VISUAL_SECONDS_PER_DAY)
	return (total_seconds / VISUAL_SECONDS_PER_DAY) * 24.0


func get_visual_season() -> int:
	var total_days: float = visual_time / VISUAL_SECONDS_PER_DAY
	return int(total_days / 10.0) % 4


func get_visual_clock_string() -> String:
	var hour: int = int(get_visual_hour())
	var minute: int = int(fmod(get_visual_hour(), 1.0) * 60.0)
	var season_names: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
	return "%02d:%02d - %s" % [hour, minute, season_names[get_visual_season()]]


func serialize() -> Dictionary:
	return {"sim_time": sim_time, "visual_time": visual_time}


## Restore elapsed clocks without replaying historical boundaries.
func deserialize(data: Dictionary) -> void:
	sim_time = float(data.get("sim_time", 0.0))
	visual_time = float(data.get("visual_time", 0.0))
	_last_visitor_tick = int(floor(sim_time / VISITOR_TICK_INTERVAL))
	_last_sim_hour = int(floor(sim_time / SIM_SECONDS_PER_HOUR))
	_last_sim_day = int(floor(sim_time / SIM_SECONDS_PER_DAY))
	_last_sim_week = int(floor(sim_time / (SIM_SECONDS_PER_DAY * float(SIM_DAYS_PER_WEEK))))
	_last_sim_month = int(floor(sim_time / (SIM_SECONDS_PER_DAY * float(SIM_DAYS_PER_MONTH))))
	sim_day = _last_sim_day
	sim_month = _last_sim_month
	_pending_boundary.clear()
