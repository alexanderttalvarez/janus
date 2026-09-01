## DistrictLayoutDefinitionTest — H1 proof fixtures and validator contract tests.
## Run with: godot --headless --path . -s res://tests/test_district_layout_definition.gd
extends SceneTree


var _passed: int = 0
var _failed: int = 0
var _factory: RefCounted
var _validator: RefCounted


func _init() -> void:
	_factory = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	_validator = load("res://scripts/resources/district_layout_validator.gd").new()
	_test_fixture_a()
	_test_fixture_b()
	_test_fixture_c()
	_test_addendum_limits()
	_test_manifest_is_complete()
	_test_immutable_definition_boundary()
	_test_safe_integer_boundary()
	_test_float_and_unknown_field_rejection()
	_test_mask_order_and_buildability_rejection()
	_test_non_plot_layer_rejection()
	_test_parser_boundary()
	print("DistrictLayoutDefinition tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _valid_fixture(fixture_id: String) -> Dictionary:
	var record: Dictionary = _factory.build_fixture(fixture_id)
	var result: Dictionary = _validator.normalize_and_validate(record)
	_assert(bool(result.get("valid", false)), "%s validates without diagnostics" % fixture_id)
	if not bool(result.get("valid", false)):
		print(result.get("diagnostics", []))
	return result.get("record", {})


func _test_fixture_a() -> void:
	var record: Dictionary = _valid_fixture("A")
	var definition: DistrictLayoutDefinition = load("res://scripts/resources/district_layout_definition.gd").new()
	var diagnostics: Array[Dictionary] = definition.initialize(record)
	_assert(diagnostics.is_empty(), "fixture A publishes as a definition resource")
	_assert(definition.get_layout_id() == "fixture.legacy_25_single", "fixture A has the legacy proof layout ID")
	_assert(definition.get_slot_count() == 1, "fixture A has one slot")
	_assert(definition.get_section_count() == 1, "fixture A has one section")
	_assert(definition.get_sources().size() == 4, "fixture A has four pedestrian sources")


func _test_fixture_b() -> void:
	var record: Dictionary = _valid_fixture("B")
	var layout: Dictionary = record["layout"]
	_assert(layout["row_tracks"][0]["size"] == 40, "fixture B preserves row depth 40")
	_assert(layout["column_tracks"][0]["size"] == 30, "fixture B preserves column width 30")
	_assert(layout["slots"][0]["sections"].size() == 3, "fixture B has three sections")
	_assert(layout["arrival_sources"].is_empty(), "fixture B has no arrival sources")
	var slot: Dictionary = layout["slots"][0]
	_assert(slot["physical_elevation_cap_override"] == {"minimum_elevation": -1, "maximum_elevation": 4}, "fixture B keeps the stricter slot cap")


func _test_fixture_c() -> void:
	var record: Dictionary = _valid_fixture("C")
	var layout: Dictionary = record["layout"]
	_assert(layout["slots"].size() == 9, "fixture C has nine slots")
	var section_count: int = 0
	var occupant_count: int = 0
	for slot: Dictionary in layout["slots"]:
		section_count += slot["sections"].size()
		occupant_count += slot["fixed_occupants"].size()
	_assert(section_count == 16, "fixture C has sixteen sections")
	_assert(occupant_count == 2, "fixture C has two slot-local occupants")
	_assert(layout["arrival_sources"].size() == 4, "fixture C has four pedestrian sources")
	_assert(record["fixed_block_catalog"][0]["fixed_occupants"].size() == 1, "fixture C has one fixed-block occupant")
	_assert(record["template_catalog"].size() == 3, "fixture C has three templates")
	_assert(record["variant_catalog"].size() == 7, "fixture C has seven authored variants")
	_assert(record["road_profile_catalog"][0]["pedestrian_width"] == 6, "fixture C uses pedestrian width six")


func _test_addendum_limits() -> void:
	var undersized: Dictionary = _factory.build_fixture("A")
	undersized["layout"]["row_tracks"][0]["size"] = 17
	var undersized_result: Dictionary = _validator.normalize_and_validate(undersized)
	_assert(not bool(undersized_result.get("valid", false)) and _has_code(undersized_result.get("diagnostics", []), "TRACK_SIZE_INVALID"), "road addendum rejects row tracks below 18 tiles")
	var six_lanes: Dictionary = _factory.build_fixture("A")
	var valid_lanes: Array = []
	for index: int in range(6):
		valid_lanes.append({"ordinal": index, "direction": "FORWARD" if index < 3 else "REVERSE", "width": 3})
	six_lanes["road_profile_catalog"][0]["carriageways"][0]["lanes"] = valid_lanes
	var six_result: Dictionary = _validator.normalize_and_validate(six_lanes)
	_assert(bool(six_result.get("valid", false)), "road addendum accepts six total lanes with contiguous direction groups")
	var seven_lanes: Dictionary = _factory.build_fixture("A")
	var invalid_lanes: Array = valid_lanes.duplicate(true)
	invalid_lanes.append({"ordinal": 6, "direction": "REVERSE", "width": 3})
	seven_lanes["road_profile_catalog"][0]["carriageways"][0]["lanes"] = invalid_lanes
	var seven_result: Dictionary = _validator.normalize_and_validate(seven_lanes)
	_assert(not bool(seven_result.get("valid", false)) and _has_code(seven_result.get("diagnostics", []), "LANE_COUNT_INVALID"), "road addendum rejects more than six total lanes")
	var split_groups: Dictionary = _factory.build_fixture("A")
	split_groups["road_profile_catalog"][0]["carriageways"][0]["lanes"] = [
		{"ordinal": 0, "direction": "FORWARD", "width": 3},
		{"ordinal": 1, "direction": "REVERSE", "width": 3},
		{"ordinal": 2, "direction": "FORWARD", "width": 3},
		{"ordinal": 3, "direction": "REVERSE", "width": 3},
	]
	var split_result: Dictionary = _validator.normalize_and_validate(split_groups)
	_assert(not bool(split_result.get("valid", false)) and _has_code(split_result.get("diagnostics", []), "LANE_GROUP_NOT_CONTIGUOUS"), "road addendum rejects split same-direction lane groups")


func _test_manifest_is_complete() -> void:
	var record: Dictionary = _factory.build_fixture("A")
	var root_keys: Array[String] = ["definition_schema_version", "layout_definition_version", "canonical_schema_version", "resolver_schema_version", "layout", "template_catalog", "variant_catalog", "fixed_block_catalog", "road_profile_catalog"]
	for key: String in root_keys:
		_assert(record.has(key), "fixture A manifest includes root field %s" % key)
	var source: Dictionary = record["layout"]["arrival_sources"][0]
	for key: String in ["capacity", "weight", "schedule", "presentation", "initially_enabled"]:
		_assert(source.has(key), "source includes explicit field %s" % key)
	var missing: Dictionary = record.duplicate(true)
	missing.erase("variant_catalog")
	var result: Dictionary = _validator.normalize_and_validate(missing)
	_assert(not bool(result.get("valid", false)), "missing required catalog is rejected")
	_assert(_has_code(result.get("diagnostics", []), "FIELD_MISSING"), "missing catalog reports FIELD_MISSING")


func _test_immutable_definition_boundary() -> void:
	var definition: DistrictLayoutDefinition = load("res://scripts/resources/district_layout_definition.gd").new()
	definition.initialize(_factory.build_fixture("A"))
	var returned: Dictionary = definition.get_semantic_record()
	returned["layout"]["layout_id"] = "mutated"
	_assert(definition.get_layout_id() == "fixture.legacy_25_single", "definition returns defensive copies")
	_assert(definition.is_published(), "valid definition remains published after external mutation")


func _test_safe_integer_boundary() -> void:
	var valid: Dictionary = _factory.build_fixture("A")
	valid["layout"]["row_tracks"][0]["size"] = 9007199254740991
	var accepted: Dictionary = _validator.normalize_and_validate(valid)
	_assert(not _has_code(accepted.get("diagnostics", []), "INTEGER_OUT_OF_RANGE"), "maximum I-JSON integer is accepted by representation validation")
	var invalid: Dictionary = _factory.build_fixture("A")
	invalid["layout"]["row_tracks"][0]["size"] = 9007199254740992
	var rejected: Dictionary = _validator.normalize_and_validate(invalid)
	_assert(not bool(rejected.get("valid", false)), "integer immediately above I-JSON range is rejected")
	_assert(_has_code(rejected.get("diagnostics", []), "INTEGER_OUT_OF_RANGE"), "out-of-range integer reports INTEGER_OUT_OF_RANGE")


func _test_float_and_unknown_field_rejection() -> void:
	var floating: Dictionary = _factory.build_fixture("A")
	floating["layout"]["row_tracks"][0]["size"] = 25.0
	var float_result: Dictionary = _validator.normalize_and_validate(floating)
	_assert(not bool(float_result.get("valid", false)), "semantic floats are rejected")
	_assert(_has_code(float_result.get("diagnostics", []), "FLOAT_FORBIDDEN"), "semantic float reports FLOAT_FORBIDDEN")
	var unknown: Dictionary = _factory.build_fixture("A")
	unknown["runtime_state"] = {}
	var unknown_result: Dictionary = _validator.normalize_and_validate(unknown)
	_assert(not bool(unknown_result.get("valid", false)), "runtime fields are rejected")
	_assert(_has_code(unknown_result.get("diagnostics", []), "UNKNOWN_FIELD"), "runtime field reports UNKNOWN_FIELD")


func _test_mask_order_and_buildability_rejection() -> void:
	var unordered: Dictionary = _factory.build_fixture("A")
	unordered["layout"]["slots"][0]["sections"][0]["mask"] = [[1, 0], [0, 0]]
	unordered["layout"]["slots"][0]["buildability_mask"] = [[1, 0], [0, 0]]
	var order_result: Dictionary = _validator.normalize_and_validate(unordered)
	_assert(not bool(order_result.get("valid", false)), "non-row-major masks are rejected")
	_assert(_has_code(order_result.get("diagnostics", []), "CELL_ORDER_INVALID"), "unordered mask reports CELL_ORDER_INVALID")
	var mismatch: Dictionary = _factory.build_fixture("A")
	mismatch["layout"]["slots"][0]["buildability_mask"] = []
	var mismatch_result: Dictionary = _validator.normalize_and_validate(mismatch)
	_assert(not bool(mismatch_result.get("valid", false)), "buildability mismatch is rejected")
	_assert(_has_code(mismatch_result.get("diagnostics", []), "BUILDABILITY_MISMATCH"), "buildability mismatch reports BUILDABILITY_MISMATCH")


func _test_non_plot_layer_rejection() -> void:
	var record: Dictionary = _factory.build_fixture("C")
	record["layout"]["slots"][1]["buildability_mask"] = [[0, 0]]
	var result: Dictionary = _validator.normalize_and_validate(record)
	_assert(not bool(result.get("valid", false)), "non-Plot buildability is rejected")
	_assert(_has_code(result.get("diagnostics", []), "NON_PLOT_BUILDABILITY"), "non-Plot layer reports NON_PLOT_BUILDABILITY")


func _test_parser_boundary() -> void:
	var loader: DistrictLayoutDefinitionLoader = load("res://scripts/resources/district_layout_definition_loader.gd").new()
	var valid_text: String = JSON.stringify(_factory.build_fixture("A"))
	var valid_result: Dictionary = loader.parse_text(valid_text)
	_assert(bool(valid_result.get("valid", false)), "valid JSON publishes through the parser boundary")
	_assert(valid_result.get("definition") is DistrictLayoutDefinition, "parser returns a DistrictLayoutDefinition")
	var invalid_result: Dictionary = loader.parse_text("{not-json}")
	_assert(not bool(invalid_result.get("valid", false)), "malformed JSON is rejected before validation")
	_assert(_has_code(invalid_result.get("diagnostics", []), "JSON_PARSE_FAILED"), "malformed JSON reports JSON_PARSE_FAILED")


func _has_code(diagnostics: Array, code: String) -> bool:
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary and diagnostic.get("code", "") == code:
			return true
	return false
