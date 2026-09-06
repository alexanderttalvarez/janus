extends SceneTree

## Session H1 tests for explicit content, calendar delivery, and readiness barriers.



var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_content_registry()
	_test_calendar_order_and_catch_up()
	_test_speed_and_pause()
	_test_readiness_barrier()
	print("Session H1 tests: %d passed, %d failed" % [_passed, _failed])
	call_deferred("quit", 0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _registry() -> RefCounted:
	var registry: RefCounted = load("res://scripts/session/content_registry.gd").new()
	var production_entries: Array[Dictionary] = [{
		"layout_id": "district.initial",
		"definition_path": "res://resources/districts/district_initial.tres",
	}]
	var result: Dictionary = registry.initialize_production_catalog(production_entries)
	_assert(bool(result.get("valid", false)), "approved layout catalog seals successfully")
	return registry


func _test_content_registry() -> void:
	var registry: RefCounted = _registry()
	var selected: Dictionary = registry.resolve_layout("district.initial")
	_assert(bool(selected.get("valid", false)), "explicit production layout selection resolves")
	_assert(selected.get("layout_ref", {}).get("layout_id", "") == "district.initial", "selection returns the selected stable identity")
	_assert(registry.get_layout_ids().size() == 1, "registry exposes only the explicitly configured production identity")
	var missing: Dictionary = registry.resolve_layout("")
	_assert(not bool(missing.get("valid", false)) and _has_code(missing.get("diagnostics", []), "LAYOUT_ID_REQUIRED"), "missing selection is rejected without a default")
	var unknown: Dictionary = registry.resolve_layout("fixture.not_registered")
	_assert(not bool(unknown.get("valid", false)) and _has_code(unknown.get("diagnostics", []), "LAYOUT_ID_UNKNOWN"), "unknown selection is rejected")
	var wrong_version: Dictionary = registry.resolve_layout("district.initial", 99)
	_assert(not bool(wrong_version.get("valid", false)) and _has_code(wrong_version.get("diagnostics", []), "LAYOUT_DEFINITION_VERSION_MISMATCH"), "mismatched definition version is rejected")
	var wrong_fingerprint: Dictionary = registry.resolve_layout("district.initial", -1, "f".repeat(64))
	_assert(not bool(wrong_fingerprint.get("valid", false)) and _has_code(wrong_fingerprint.get("diagnostics", []), "LAYOUT_FINGERPRINT_MISMATCH"), "mismatched fingerprint is rejected")
	var valid_ref: Dictionary = registry.validate_layout_ref(selected.get("layout_ref", {}))
	_assert(bool(valid_ref.get("valid", false)), "a registry-issued layout reference validates")
	var alias_registry: RefCounted = load("res://scripts/session/content_registry.gd").new()
	var alias_entries: Array[Dictionary] = [{
		"layout_id": "A",
		"definition_path": "res://resources/districts/district_initial.tres",
	}]
	var alias_result: Dictionary = alias_registry.initialize_production_catalog(alias_entries)
	_assert(not bool(alias_result.get("valid", false)) and _has_code(alias_result.get("diagnostics", []), "LAYOUT_ID_MISMATCH"), "legacy shorthand cannot become a registry identity")


func _test_calendar_order_and_catch_up() -> void:
	var time_manager: TimeManager = load("res://scripts/simulation/time_manager.gd").new()
	var events: Array[String] = []
	time_manager.visitor_tick.connect(func(tick: int) -> void: events.append("visitor:%d" % tick))
	time_manager.sim_hour_passed.connect(func(hour: int) -> void: events.append("hour:%d" % hour))
	time_manager.sim_day_passed.connect(func(day: int) -> void: events.append("day:%d" % day))
	time_manager.sim_week_passed.connect(func(week: int) -> void: events.append("week:%d" % week))
	time_manager.sim_month_passed.connect(func(month: int) -> void: events.append("month:%d" % month))
	time_manager.set_speed(1)
	time_manager._process(720.0)
	_assert(time_manager.sim_time == 720.0 and time_manager.visual_time == 720.0, "simulation and visual clocks advance by the same speed-scaled delta")
	_assert(events.size() == 899, "catch-up emits every crossed visitor, hour, day, week, and month boundary")
	_assert(_count_prefix(events, "visitor:") == 144, "visitor ticks are emitted once per crossed five-second boundary")
	_assert(_count_prefix(events, "hour:") == 720, "hours are emitted once per crossed simulation hour")
	_assert(_count_prefix(events, "day:") == 30, "days are emitted once per crossed simulation day")
	_assert(_count_prefix(events, "week:") == 4, "weeks are emitted once per crossed simulation week")
	_assert(_count_prefix(events, "month:") == 1, "months are emitted once per crossed simulation month")
	var week_index: int = events.find("week:1")
	_assert(week_index >= 2 and events[week_index - 2] == "hour:168" and events[week_index - 1] == "day:7", "same-instant hour/day/week boundaries preserve chronological priority")
	var month_index: int = events.find("month:1")
	_assert(month_index >= 3 and events[month_index - 3] == "visitor:144" and events[month_index - 2] == "hour:720" and events[month_index - 1] == "day:30", "same-instant visitor/hour/day/month boundaries preserve contract order")
	time_manager.free()


func _test_speed_and_pause() -> void:
	var time_manager: TimeManager = load("res://scripts/simulation/time_manager.gd").new()
	time_manager.set_speed(0)
	time_manager._process(100.0)
	_assert(time_manager.sim_time == 0.0 and time_manager.visual_time == 0.0, "pause advances neither clock")
	time_manager.set_speed(2)
	time_manager._process(0.5)
	_assert(time_manager.sim_time == 1.0 and time_manager.visual_time == 1.0, "2x speed applies immediately to both clocks")
	time_manager.set_speed(3)
	time_manager._process(1.0)
	_assert(time_manager.sim_time == 4.0 and time_manager.visual_time == 4.0, "3x speed applies without timer recalculation")
	time_manager.free()


func _test_readiness_barrier() -> void:
	var registry: RefCounted = _registry()
	var coordinator: RefCounted = load("res://scripts/session/session_bootstrap_coordinator.gd").new()
	var ready_events: Array[String] = []
	coordinator.session_ready.connect(func(layout_id: String) -> void: ready_events.append(layout_id))
	var begin: Dictionary = coordinator.begin("district.initial", registry)
	_assert(bool(begin.get("valid", false)) and coordinator.get_phase() == "STAGING", "valid content enters private staging")
	_assert(not coordinator.can_accept_input(), "staging does not accept gameplay input")
	var early_commit: Dictionary = coordinator.commit_ready()
	_assert(not bool(early_commit.get("valid", false)) and _has_code(early_commit.get("diagnostics", []), "AUTHORITIES_NOT_READY"), "commit is blocked before authority readiness")
	coordinator.mark_projections_ready()
	_assert(not coordinator.can_accept_input(), "projection readiness alone does not open the gate")
	coordinator.mark_authorities_ready()
	var committed: Dictionary = coordinator.commit_ready()
	_assert(bool(committed.get("valid", false)) and coordinator.is_ready(), "ready opens only after both barriers")
	_assert(coordinator.can_accept_input() and ready_events == ["district.initial"], "session-ready publishes once after the barrier")
	coordinator.dispose()
	_assert(coordinator.get_phase() == "IDLE" and not coordinator.can_accept_input(), "dispose closes the session readiness gate")
	var failed_coordinator: RefCounted = load("res://scripts/session/session_bootstrap_coordinator.gd").new()
	var failed_begin: Dictionary = failed_coordinator.begin("", registry)
	_assert(not bool(failed_begin.get("valid", false)) and failed_coordinator.get_phase() == "FAILED", "empty content selection fails before staging")
	_assert(not failed_coordinator.can_accept_input() and failed_coordinator.get_selected_layout_id().is_empty(), "failed selection exposes no staged session")


func _has_code(diagnostics: Array, code: String) -> bool:
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary and String(diagnostic.get("code", "")) == code:
			return true
	return false


func _count_prefix(values: Array[String], prefix: String) -> int:
	var count: int = 0
	for value: String in values:
		if value.begins_with(prefix):
			count += 1
	return count
