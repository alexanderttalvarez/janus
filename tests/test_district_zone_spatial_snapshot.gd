## ADR 36 contract tests for the immutable floor-scoped District-to-Zone value.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_masked_signed_floor_derivation()
	_test_strict_value_and_scope_rejection()
	print("DistrictZoneSpatialSnapshot tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _test_masked_signed_floor_derivation() -> void:
	var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	var resolver: RefCounted = load("res://scripts/resources/district_layout_resolver.gd").new()
	var resolution: Dictionary = resolver.resolve(factory.build_fixture("B"))
	_assert(bool(resolution.get("valid", false)), "masked fixture B resolves")
	if not bool(resolution.get("valid", false)):
		return
	var snapshot: ResolvedDistrictSnapshot = resolution["snapshot"] as ResolvedDistrictSnapshot
	var data: Dictionary = snapshot.get_data()
	var section: Dictionary = _owned_available_section(data.get("sections", []))
	var plot_id: String = String(section.get("plot_id", ""))
	var floor: Dictionary = _signed_floor(data.get("floors", []), plot_id)
	var cells: Array = _section_floor_cells(data.get("cells", []), section, String(floor.get("id", "")))
	_assert(not section.is_empty() and not floor.is_empty() and cells.size() >= 3, "fixture supplies an owned masked signed-floor sample")
	if section.is_empty() or floor.is_empty() or cells.size() < 3:
		return
	var state: Dictionary = DistrictStateRecords.new().create_baseline(snapshot)
	state["plot_states"] = [{
		"runtime_plot_id": plot_id,
		"section_state_overrides": [],
		"floor_states": [{
			"floor_id": floor["id"],
			"elevation": floor["elevation"],
			"acquired_cells": [cells[0], cells[1], cells[2]],
			"constructed_cells": [cells[0], cells[1]],
			"explicit_circulation_cells": [cells[0]],
		}],
	}]
	var derived: Dictionary = DistrictZoneSpatialSnapshot.derive(snapshot, state, {
		"floor_id": floor["id"],
		"runtime_plot_id": plot_id,
		"signed_elevation": floor["elevation"],
	})
	_assert(bool(derived.get("valid", false)), "signed-elevation snapshot derives from resolved layout and DistrictState")
	if not bool(derived.get("valid", false)):
		return
	var value: DistrictZoneSpatialSnapshot = derived["snapshot"] as DistrictZoneSpatialSnapshot
	_assert(int(value.get_floor_scope()["signed_elevation"]) != 0, "snapshot preserves an explicit non-ground signed elevation")
	_assert(value.get_cells("acquired_cells").size() == 3, "acquired cells remain distinct from broader validity")
	_assert(value.get_cells("constructed_cells").size() == 2, "constructed cells remain a strict acquired subset")
	_assert(value.get_cells("zone_eligible_cells").size() == 2, "Zone eligibility contains only eligible constructed cells")
	_assert(value.get_cells("explicit_circulation_cells").size() == 1, "generic constructed space is not inferred as circulation")
	var resolved_floor_cells: Array = _all_floor_cells(data.get("cells", []), String(floor["id"]))
	_assert(value.get_cells("valid_cells").size() == resolved_floor_cells.size(), "masked Plot validity exactly matches resolved floor cells without implicit expansion")


func _test_strict_value_and_scope_rejection() -> void:
	var value: Dictionary = {
		"schema_id": DistrictZoneSpatialSnapshot.SCHEMA_ID,
		"schema_version": DistrictZoneSpatialSnapshot.SCHEMA_VERSION,
		"layout_ref": {"layout_id": "layout", "layout_definition_version": 1, "definition_fingerprint": "0".repeat(64)},
		"district_revision": 0,
		"floor_scope": {"floor_id": "floor", "runtime_plot_id": "plot", "signed_elevation": -1},
		"valid_cells": [{"x": 0, "y": 0}],
		"acquired_cells": [{"x": 0, "y": 0}],
		"constructed_cells": [{"x": 0, "y": 0}],
		"zone_eligible_cells": [{"x": 0, "y": 0}],
		"explicit_circulation_cells": [],
		"manual_door_edges": [],
	}
	_assert(bool(DistrictZoneSpatialSnapshot.validate_value(value).get("valid", false)), "exact ADR 36 value validates")
	var malformed: Dictionary = value.duplicate(true)
	malformed["unknown"] = true
	_assert(not bool(DistrictZoneSpatialSnapshot.validate_value(malformed).get("valid", false)), "unknown snapshot fields reject")
	var invalid_subset: Dictionary = value.duplicate(true)
	invalid_subset["explicit_circulation_cells"] = [{"x": 1, "y": 0}]
	_assert(not bool(DistrictZoneSpatialSnapshot.validate_value(invalid_subset).get("valid", false)), "circulation outside eligible constructed space rejects")
	var invalid_scope: Dictionary = value.duplicate(true)
	invalid_scope["floor_scope"] = {"floor_id": "floor", "runtime_plot_id": "plot"}
	_assert(not bool(DistrictZoneSpatialSnapshot.validate_value(invalid_scope).get("valid", false)), "implicit or incomplete floor scope rejects")


func _owned_available_section(sections: Array) -> Dictionary:
	for section: Dictionary in sections:
		if bool(section.get("initially_owned", false)) and bool(section.get("initially_available", false)):
			return section
	return {}


func _signed_floor(floors: Array, plot_id: String) -> Dictionary:
	for floor: Dictionary in floors:
		if String(floor.get("plot_id", "")) == plot_id and int(floor.get("elevation", 0)) != 0:
			return floor
	return {}


func _section_floor_cells(records: Array, section: Dictionary, floor_id: String) -> Array:
	var allowed: Dictionary = {}
	for pair: Array in section.get("mask", []):
		allowed["%d,%d" % [int(pair[0]), int(pair[1])]] = true
	var result: Array = []
	for cell: Dictionary in records:
		var key: String = "%d,%d" % [int(cell.get("x", -1)), int(cell.get("y", -1))]
		if String(cell.get("floor_id", "")) == floor_id and bool(cell.get("buildable", true)) and allowed.has(key):
			result.append([int(cell["x"]), int(cell["y"])])
	result.sort_custom(func(left: Array, right: Array) -> bool: return int(left[1]) < int(right[1]) or (int(left[1]) == int(right[1]) and int(left[0]) < int(right[0])))
	return result


func _all_floor_cells(records: Array, floor_id: String) -> Array:
	var result: Array = []
	for cell: Dictionary in records:
		if String(cell.get("floor_id", "")) == floor_id:
			result.append([int(cell["x"]), int(cell["y"])])
	return result
