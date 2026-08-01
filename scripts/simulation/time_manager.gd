## TimeManager — Dual-clock simulation time system.
## Accumulated real-time simulation with EventBus signal integration.
## Speed is proxied from GameManager.
##
## Two independent timers that scale together with speed controls:
##   Simulation Clock: fast game logic (1 hour = 1 second at 1x)
##   Visual Clock: slow day/night cycle (1 full day ~10 min at 1x)
##
## Events emitted on EventBus:
##   visitor_tick   — Every 5 sim seconds (drives visitor behavior)
##   sim_day_passed  — Every sim day (24 hours)
##   sim_month_passed — Every 30 sim days
##
## This is NOT an autoload — instantiated as a child of main_game.tscn.
class_name TimeManager
extends Node


## Emitted locally and forwarded to EventBus.
signal visitor_tick
signal sim_day_passed(day: int)
signal sim_month_passed(month: int)


# ── Constants ──────────────────────────────────────────────────────────

## Simulated seconds per day (24 hours × 3600 seconds).
const SIM_SECONDS_PER_DAY: float = 86400.0

## Real-time seconds per visual day (10 minutes).
const VISUAL_SECONDS_PER_DAY: float = 600.0

## Visitor behavior tick interval in sim seconds.
const VISITOR_TICK_INTERVAL: float = 5.0

## Visual-to-simulation time ratio.
const VISUAL_TO_SIM_RATIO: float = VISUAL_SECONDS_PER_DAY / SIM_SECONDS_PER_DAY

## Number of sim days per month.
const DAYS_PER_MONTH: int = 30


# ── State ──────────────────────────────────────────────────────────────

## Accumulated simulation time in seconds.
var sim_time: float = 0.0

## Accumulated visual time in seconds.
var visual_time: float = 0.0

## Current simulation speed (0=pause, 1-3). Proxied from GameManager.
var speed: int = 0

## Current sim day (1-based).
var sim_day: int = 1

## Current sim month (1-based).
var sim_month: int = 1


# ── Internal trackers for event emission ───────────────────────────────

var _last_visitor_tick: int = 0
var _last_sim_day: int = 0
var _last_sim_month: int = 0


func _process(delta: float) -> void:
	if speed == 0:
		return

	var effective_delta := delta * float(speed)
	sim_time += effective_delta
	visual_time += effective_delta * VISUAL_TO_SIM_RATIO

	_detect_events()


# ── Event Detection ────────────────────────────────────────────────────

func _detect_events() -> void:
	# Visitor tick (local only — VisitorManager connects directly).
	var current_tick: int = int(sim_time / VISITOR_TICK_INTERVAL)
	if current_tick > _last_visitor_tick:
		_last_visitor_tick = current_tick
		visitor_tick.emit()

	# Sim day passed.
	var current_day: int = int(sim_time / SIM_SECONDS_PER_DAY) + 1
	if current_day > _last_sim_day:
		_last_sim_day = current_day
		sim_day = current_day
		sim_day_passed.emit(sim_day)
		EventBus.sim_day_passed.emit(sim_day)

	# Sim month passed.
	var current_month: int = int(sim_day / DAYS_PER_MONTH) + 1
	if current_month > _last_sim_month:
		_last_sim_month = current_month
		sim_month = current_month
		sim_month_passed.emit(sim_month)
		EventBus.sim_month_passed.emit(sim_month)


# ── Speed Control ──────────────────────────────────────────────────────

## Set the simulation speed directly.
func set_speed(new_speed: int) -> void:
	speed = clampi(new_speed, 0, 3)


# ── Time Queries ───────────────────────────────────────────────────────

## Get the current visual time of day (0.0–24.0 hours).
func get_visual_hour() -> float:
	var total_seconds := fmod(visual_time, VISUAL_SECONDS_PER_DAY)
	return (total_seconds / VISUAL_SECONDS_PER_DAY) * 24.0


## Get the current visual season (0=Spring, 1=Summer, 2=Autumn, 3=Winter).
## POST-MVP: seasonal cycle driven by visual calendar (10 visual days per season).
func get_visual_season() -> int:
	var total_days := visual_time / VISUAL_SECONDS_PER_DAY
	return int(total_days / 10.0) % 4


## Get visual clock display string (e.g., "14:30 — Summer").
func get_visual_clock_string() -> String:
	var hour := int(get_visual_hour())
	var minute := int(fmod(get_visual_hour(), 1.0) * 60.0)
	var season_names: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
	var season := season_names[get_visual_season()]
	return "%02d:%02d — %s" % [hour, minute, season]


# ── Serialization ──────────────────────────────────────────────────────

func serialize() -> Dictionary:
	return {
		"sim_time": sim_time,
		"visual_time": visual_time,
	}


func deserialize(data: Dictionary) -> void:
	sim_time = data.get("sim_time", 0.0)
	visual_time = data.get("visual_time", 0.0)
	_last_visitor_tick = int(sim_time / VISITOR_TICK_INTERVAL)
	_last_sim_day = int(sim_time / SIM_SECONDS_PER_DAY) + 1
	_last_sim_month = int(sim_day / DAYS_PER_MONTH) + 1


# ── Internal ────────────────────────────────────────────────────────────
