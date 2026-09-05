## TimeManager — Session-scoped accumulated simulation and visual clocks.
## Decision 12 is delivered through local signals; EventBus receives optional
## projections of the existing day/month signals for legacy presentation.
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


func _process(delta: float) -> void:
	if speed == 0:
		return
	var effective_delta: float = delta * float(speed)
	sim_time += effective_delta
	visual_time += effective_delta
	_emit_crossed_boundaries()


## Emit every crossed boundary in chronological order. Equal instants retain
## the contract order: visitor, hour, day, week, month.
func _emit_crossed_boundaries() -> void:
	while true:
		var next_kind: int = -1
		var next_time: float = INF
		var candidates: Array[float] = [
				float(_last_visitor_tick + 1) * VISITOR_TICK_INTERVAL,
				float(_last_sim_hour + 1) * SIM_SECONDS_PER_HOUR,
				float(_last_sim_day + 1) * SIM_SECONDS_PER_DAY,
				float(_last_sim_week + 1) * SIM_SECONDS_PER_DAY * float(SIM_DAYS_PER_WEEK),
				float(_last_sim_month + 1) * SIM_SECONDS_PER_DAY * float(SIM_DAYS_PER_MONTH),
		]
		for index: int in range(candidates.size()):
			if candidates[index] < next_time:
				next_time = candidates[index]
				next_kind = index
		if next_kind < 0 or next_time > sim_time + 0.000001:
			return
		match next_kind:
			0:
				_last_visitor_tick += 1
				visitor_tick.emit(_last_visitor_tick)
			1:
				_last_sim_hour += 1
				sim_hour_passed.emit(_last_sim_hour)
			2:
				_last_sim_day += 1
				sim_day = _last_sim_day
				sim_day_passed.emit(_last_sim_day)
				_emit_optional_event_bus("sim_day_passed", _last_sim_day)
			3:
				_last_sim_week += 1
				sim_week_passed.emit(_last_sim_week)
			4:
				_last_sim_month += 1
				sim_month = _last_sim_month
				sim_month_passed.emit(_last_sim_month)
				_emit_optional_event_bus("sim_month_passed", _last_sim_month)


func set_speed(new_speed: int) -> void:
	speed = clampi(new_speed, 0, 3)


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
	return "%02d:%02d — %s" % [hour, minute, season_names[get_visual_season()]]


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
