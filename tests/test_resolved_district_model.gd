## H2 proof tests: deterministic resolution, exact grid geometry, IDs, and canonical bytes.
extends SceneTree

var _passed: int = 0
var _failed: int = 0
const GOLDEN_FINGERPRINT_A: String = "9a8a657a4c5da09621650aafb2b2689e0e1572f4ca43f62c0a31c62f02f07126"
const GOLDEN_FINGERPRINT_B: String = "0ca79ef020dd34dc807914a4c89cbdaf497452d456910f30cbbc7fc686f0f4d3"
const GOLDEN_FINGERPRINT_C: String = "83be5e720d216c205b05166cde998b7532f0f98cd2338769be59d39ccbd608c6"
var _factory: RefCounted
var _resolver: RefCounted


func _init() -> void:
	_factory = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	_resolver = load("res://scripts/resources/district_layout_resolver.gd").new()
	_test_fixture_a()
	_test_fixture_b()
	_test_fixture_c()
	_test_ids_and_nested_escaping()
	_test_canonical_encoding()
	_test_source_rejection()
	_test_state_boundary()
	_test_snapshot_immutability()
	print("ResolvedDistrictModel tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _resolve(fixture_id: String) -> ResolvedDistrictSnapshot:
	var result: Dictionary = _resolver.resolve(_factory.build_fixture(fixture_id))
	_assert(bool(result.get("valid", false)), "%s resolves without diagnostics" % fixture_id)
	if not bool(result.get("valid", false)):
		print(result.get("diagnostics", []))
		return null
	return result.get("snapshot") as ResolvedDistrictSnapshot


func _test_fixture_a() -> void:
	var snapshot: ResolvedDistrictSnapshot = _resolve("A")
	if snapshot == null:
		return
	var data: Dictionary = snapshot.get_data()
	_assert(snapshot.get_fingerprint() == GOLDEN_FINGERPRINT_A, "fixture A fingerprint matches the frozen H1/H2 golden")
	_assert(data["district_rect_quarter"] == {"minimum_x4": 0, "minimum_z4": 0, "maximum_x4": 228, "maximum_z4": 228}, "fixture A district bounds are exact")
	_assert(data["grid"]["horizontal_boundary_starts_quarter"] == [0, 164], "fixture A horizontal boundary starts are exact")
	_assert(data["grid"]["vertical_boundary_starts_quarter"] == [0, 164], "fixture A vertical boundary starts are exact")
	_assert(data["slots"][0]["rect_quarter"] == {"minimum_x4": 64, "minimum_z4": 64, "maximum_x4": 164, "maximum_z4": 164}, "fixture A slot bounds are exact")
	_assert(data["slots"][0]["pose"] == {"x4": 64, "z4": 64, "elevation": 0, "facing": "NONE"}, "fixture A slot pose is its northwest minimum")
	_assert(snapshot.get_counts()["street_segments"] == 4, "fixture A has four generated street segments")
	_assert(snapshot.get_counts()["intersections"] == 4, "fixture A has four generated intersections")
	_assert(snapshot.get_counts()["pedestrian_bands"] == 8, "fixture A has two bands per street segment")
	_assert(snapshot.get_counts()["lanes"] == 8, "fixture A has two lanes per street segment")
	var source: Dictionary = data["arrival_source_attachments"][0]
	_assert(source["resolved_target_topology_id"] == "jid1/ped_band/jid1%2Fstreet_h%2Ffixture.legacy_25_single%2Fh0%2Fcol_0/POSITIVE", "fixture A north source resolves to the exact band ID")
	_assert(source["pose"] == {"x4": 114, "z4": 54, "elevation": 0, "facing": "SOUTH"}, "fixture A north source pose is exact")


func _test_fixture_b() -> void:
	var snapshot: ResolvedDistrictSnapshot = _resolve("B")
	if snapshot == null:
		return
	var data: Dictionary = snapshot.get_data()
	_assert(snapshot.get_fingerprint() == GOLDEN_FINGERPRINT_B, "fixture B fingerprint matches the frozen H1/H2 golden")
	_assert(data["district_rect_quarter"] == {"minimum_x4": 0, "minimum_z4": 0, "maximum_x4": 248, "maximum_z4": 288}, "fixture B district bounds are exact")
	_assert(data["slots"][0]["rect_quarter"] == {"minimum_x4": 64, "minimum_z4": 64, "maximum_x4": 184, "maximum_z4": 224}, "fixture B slot bounds are exact")
	_assert(data["plots"][0]["physical_elevation_cap"] == {"minimum_elevation": -1, "maximum_elevation": 4}, "fixture B resolves strict template and slot cap intersection")
	_assert(snapshot.get_counts()["floors"] == 6, "fixture B creates exactly six effective floors")
	_assert(snapshot.get_counts()["arrival_source_attachments"] == 0, "fixture B has no source attachments")


func _test_fixture_c() -> void:
	var snapshot: ResolvedDistrictSnapshot = _resolve("C")
	if snapshot == null:
		return
	var data: Dictionary = snapshot.get_data()
	_assert(snapshot.get_fingerprint() == GOLDEN_FINGERPRINT_C, "fixture C fingerprint matches the frozen H1/H2 golden")
	var initially_owned: Array[String] = []
	for section: Dictionary in data["sections"]:
		if bool(section.get("initially_owned", false)):
			initially_owned.append(String(section.get("authored_id", "")))
	initially_owned.sort()
	_assert(initially_owned == ["garden_entry", "market_entry", "station_entry"], "fixture C initial ownership is exactly market_entry, station_entry, garden_entry")
	_assert(data["district_rect_quarter"] == {"minimum_x4": 0, "minimum_z4": 0, "maximum_x4": 624, "maximum_z4": 576}, "fixture C district bounds are exact")
	_assert(data["grid"]["horizontal_boundary_starts_quarter"] == [0, 144, 312, 504], "fixture C horizontal boundary starts are exact")
	_assert(data["grid"]["vertical_boundary_starts_quarter"] == [0, 152, 336, 552], "fixture C vertical boundary starts are exact")
	var expected_rects: Array[Dictionary] = [
		{"minimum_x4": 72, "minimum_z4": 72, "maximum_x4": 152, "maximum_z4": 144},
		{"minimum_x4": 224, "minimum_z4": 72, "maximum_x4": 336, "maximum_z4": 144},
		{"minimum_x4": 408, "minimum_z4": 72, "maximum_x4": 552, "maximum_z4": 144},
		{"minimum_x4": 72, "minimum_z4": 216, "maximum_x4": 152, "maximum_z4": 312},
		{"minimum_x4": 224, "minimum_z4": 216, "maximum_x4": 336, "maximum_z4": 312},
		{"minimum_x4": 408, "minimum_z4": 216, "maximum_x4": 552, "maximum_z4": 312},
		{"minimum_x4": 72, "minimum_z4": 384, "maximum_x4": 152, "maximum_z4": 504},
		{"minimum_x4": 224, "minimum_z4": 384, "maximum_x4": 336, "maximum_z4": 504},
		{"minimum_x4": 408, "minimum_z4": 384, "maximum_x4": 552, "maximum_z4": 504},
	]
	for index: int in range(expected_rects.size()):
		_assert(data["slots"][index]["rect_quarter"] == expected_rects[index], "fixture C slot %d bounds are exact" % index)
	_assert(snapshot.get_counts()["street_segments"] == 24, "fixture C has twenty-four street segments")
	_assert(snapshot.get_counts()["intersections"] == 16, "fixture C has sixteen intersections")
	_assert(snapshot.get_counts()["pedestrian_bands"] == 48, "fixture C has forty-eight pedestrian bands")
	_assert(snapshot.get_counts()["carriageways"] == 24, "fixture C has twenty-four carriageways")
	_assert(snapshot.get_counts()["lanes"] == 48, "fixture C has forty-eight lanes")
	_assert(data["street_segments"][0]["rect_quarter"] == {"minimum_x4": 72, "minimum_z4": 0, "maximum_x4": 152, "maximum_z4": 72}, "fixture C first horizontal segment bounds are exact")
	_assert(data["pedestrian_bands"][0]["rect_quarter"] == {"minimum_x4": 72, "minimum_z4": 0, "maximum_x4": 152, "maximum_z4": 24}, "fixture C negative pedestrian band bounds are exact")
	_assert(data["carriageways"][0]["rect_quarter"] == {"minimum_x4": 72, "minimum_z4": 24, "maximum_x4": 152, "maximum_z4": 48}, "fixture C carriageway bounds are exact")
	_assert(data["lanes"][0]["rect_quarter"] == {"minimum_x4": 72, "minimum_z4": 24, "maximum_x4": 152, "maximum_z4": 36}, "fixture C forward lane packs from the negative band")
	_assert(data["lanes"][1]["rect_quarter"] == {"minimum_x4": 72, "minimum_z4": 36, "maximum_x4": 152, "maximum_z4": 48}, "fixture C reverse lane packs from the positive band")
	_assert(snapshot.get_counts()["fixed_occupants"] == 3, "fixture C resolves all three fixed occupants")
	var sources: Array = data["arrival_source_attachments"]
	_assert(sources[0]["pose"] == {"x4": 112, "z4": 60, "elevation": 0, "facing": "SOUTH"}, "fixture C market source pose is exact")
	_assert(sources[1]["pose"] == {"x4": 564, "z4": 108, "elevation": 0, "facing": "WEST"}, "fixture C canal source pose is exact")
	_assert(sources[2]["pose"] == {"x4": 480, "z4": 516, "elevation": 0, "facing": "NORTH"}, "fixture C tower source pose is exact")
	_assert(sources[3]["pose"] == {"x4": 60, "z4": 444, "elevation": 0, "facing": "EAST"}, "fixture C workshop source pose is exact")


func _test_ids_and_nested_escaping() -> void:
	var snapshot: ResolvedDistrictSnapshot = _resolve("A")
	if snapshot == null:
		return
	var data: Dictionary = snapshot.get_data()
	_assert(data["slots"][0]["id"] == "jid1/slot/fixture.legacy_25_single/legacy_anchor/0", "runtime Slot ID uses the exact tuple")
	_assert(data["plots"][0]["id"] == "jid1/plot/fixture.legacy_25_single/jid1%2Fslot%2Ffixture.legacy_25_single%2Flegacy_anchor%2F0/0", "runtime Plot ID escapes its nested Slot ID")
	_assert(data["sections"][0]["id"] == "jid1/section/jid1%2Fplot%2Ffixture.legacy_25_single%2Fjid1%252Fslot%252Ffixture.legacy_25_single%252Flegacy_anchor%252F0%2F0/whole_plot/0", "runtime Section ID escapes nested Plot ID")
	_assert(data["cells"][0]["id"].begins_with("jid1/cell/jid1%2Ffloor%2F"), "runtime Cell ID escapes its nested Floor ID")
	var occupant_snapshot: ResolvedDistrictSnapshot = _resolve("C")
	if occupant_snapshot != null:
		_assert(occupant_snapshot.get_data()["fixed_occupants"][0]["id"].begins_with("jid1/fixed_occupant/"), "fixed occupant uses the literal fixed_occupant tag")


func _test_canonical_encoding() -> void:
	var encoder: RefCounted = load("res://scripts/resources/district_layout_canonical_encoder.gd").new()
	var first: Dictionary = encoder.encode({"b": 2, "a": 1, "nested": [true, null, "é"]}, 1)
	var second: Dictionary = encoder.encode({"nested": [true, null, "é"], "a": 1, "b": 2}, 1)
	_assert(bool(first["valid"]) and bool(second["valid"]), "canonical encoder accepts closed values")
	_assert(first["canonical_json"] == "{\"a\":1,\"b\":2,\"nested\":[true,null,\"é\"]}", "canonical encoder sorts object keys and preserves array order")
	_assert(first["bytes"] == second["bytes"], "equivalent dictionary insertion order produces identical bytes")
	_assert(first["fingerprint"] == second["fingerprint"] and String(first["fingerprint"]).length() == 64, "canonical fingerprint is stable lowercase SHA-256")
	var too_large: Dictionary = encoder.encode({"n": 9007199254740992}, 1)
	_assert(not bool(too_large["valid"]) and _has_code(too_large.get("diagnostics", []), "INTEGER_OUT_OF_RANGE"), "canonical encoding rejects out-of-range integers before hashing")


func _has_code(diagnostics: Array, code: String) -> bool:
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary and diagnostic.get("code", "") == code:
			return true
	return false


func _test_source_rejection() -> void:
	var record: Dictionary = _factory.build_fixture("A")
	record["layout"]["arrival_sources"][0]["selector"]["side"] = "CENTER"
	var result: Dictionary = _resolver.resolve(record)
	_assert(not bool(result.get("valid", false)), "unresolvable source selector rejects the snapshot")
	_assert(result.get("snapshot", null) == null, "source rejection returns no partial snapshot")


func _test_state_boundary() -> void:
	var snapshot: ResolvedDistrictSnapshot = _resolve("C")
	if snapshot == null:
		return
	var records: RefCounted = load("res://scripts/resources/district_state_records.gd").new()
	var baseline: Dictionary = records.create_baseline(snapshot)
	var baseline_result: Dictionary = records.validate(baseline, snapshot)
	_assert(bool(baseline_result.get("valid", false)), "empty sparse district state validates")
	var data: Dictionary = snapshot.get_data()
	var section: Dictionary = data["sections"][0]
	var plot: Dictionary = data["plots"][0]
	var floor: Dictionary = data["floors"][0]
	var cell: Dictionary = data["cells"][0]
	var changed: Dictionary = baseline.duplicate(true)
	changed["plot_states"] = [{"runtime_plot_id": plot["id"], "section_state_overrides": [{"runtime_section_id": section["id"], "owned": not bool(section["initially_owned"]), "available": bool(section["initially_available"])}], "floor_states": [{"floor_id": floor["id"], "elevation": floor["elevation"], "acquired_cells": [[cell["x"], cell["y"]]], "constructed_cells": []}]}]
	var changed_result: Dictionary = records.validate(changed, snapshot)
	_assert(bool(changed_result.get("valid", false)), "nonempty sparse Plot state validates")
	var forbidden: Dictionary = changed.duplicate(true)
	forbidden["plot_states"][0]["floor_states"][0]["constructed_cells"] = [[cell["x"], cell["y"] + 1]]
	var forbidden_result: Dictionary = records.validate(forbidden, snapshot)
	_assert(not bool(forbidden_result.get("valid", false)), "construction without acquired rights is rejected")
	var unknown: Dictionary = baseline.duplicate(true)
	unknown["unknown"] = true
	var unknown_result: Dictionary = records.validate(unknown, snapshot)
	_assert(not bool(unknown_result.get("valid", false)), "unknown sparse state fields are rejected")
	var invalid_revision: Dictionary = baseline.duplicate(true)
	invalid_revision["district_revision"] = -1
	var revision_result: Dictionary = records.validate(invalid_revision, snapshot)
	_assert(not bool(revision_result.get("valid", false)), "negative district revisions are rejected")


func _test_snapshot_immutability() -> void:
	var snapshot: ResolvedDistrictSnapshot = _resolve("A")
	if snapshot == null:
		return
	var copy: Dictionary = snapshot.get_data()
	copy["layout_id"] = "mutated"
	copy["slots"][0]["id"] = "mutated"
	_assert(snapshot.get_layout_id() == "fixture.legacy_25_single", "snapshot returns a defensive data copy")
	_assert(snapshot.get_data()["slots"][0]["id"] != "mutated", "nested snapshot data cannot be mutated through a returned copy")
	var bytes: PackedByteArray = snapshot.get_canonical_bytes()
	bytes[0] = 0
	_assert(snapshot.get_canonical_bytes()[0] != 0, "canonical bytes are defensively copied")
