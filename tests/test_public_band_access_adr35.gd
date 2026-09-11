## ADR 35 contract tests for transient public access and durable selected-door provenance.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	var resolver := DistrictLayoutResolver.new()
	var resolution: Dictionary = resolver.resolve(factory.build_fixture("A"))
	_assert(bool(resolution.get("valid", false)), "ADR35 fixture resolves")
	var district: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	var records := DistrictStateRecords.new()
	var state: Dictionary = records.create_baseline(district)
	var derived: Dictionary = PublicBandAccessSnapshot.derive(district, state, 0)
	_assert(bool(derived.get("valid", false)), "public-band access derives from immutable layout and District candidate")
	var snapshot: PublicBandAccessSnapshot = derived.get("snapshot") as PublicBandAccessSnapshot
	_assert(snapshot != null and not snapshot.access_edges.is_empty(), "active owned Plot emits public-band boundary edges")
	var value: Dictionary = snapshot.duplicate_value()
	_assert(bool(PublicBandAccessSnapshot.validate_value(value).get("valid", false)), "exact detached snapshot validates")
	var ordered: bool = true
	for index: int in range(1, snapshot.access_edges.size()):
		ordered = ordered and String(snapshot.access_edges[index - 1]["access_edge_id"]) < String(snapshot.access_edges[index]["access_edge_id"])
	_assert(ordered, "access edges are duplicate-free stable-ID ascending")
	var first: Dictionary = snapshot.access_edges[0]
	_assert(String(first["access_edge_id"]).begins_with("jid1/public_band_access/"), "access identity uses jid1 public_band_access framing")
	_assert(int(first["parcel_endpoint"]["signed_elevation"]) == 0, "public-band access is ground-level only")
	var malformed: Dictionary = value.duplicate(true)
	malformed["unknown"] = true
	_assert(not bool(PublicBandAccessSnapshot.validate_value(malformed).get("valid", false)), "unknown snapshot fields reject")
	var stale: Dictionary = PublicBandAccessSnapshot.derive(district, state, 1)
	_assert(not bool(stale.get("valid", false)) and _code(stale) == "PUBLIC_BAND_ACCESS_STALE", "District revision mismatch rejects as stale")

	var endpoint: Dictionary = first["parcel_endpoint"]
	var cell: Dictionary = endpoint["local_cell"]
	var parcel := Parcel.new()
	parcel.id = "parcel_1"
	parcel.set_geometry([Vector2i(int(cell["x"]), int(cell["y"]))], [])
	parcel.set_core_geometry(parcel.tiles)
	parcel.selected_door_edges = [{
		"tile": Vector2i(int(cell["x"]), int(cell["y"])),
		"direction": _direction(String(first["outward_direction"])),
		"access": Vector2i(int(cell["x"]), int(cell["y"])) + _direction(String(first["outward_direction"])),
		"access_kind": "public_band",
		"public_band_access_edge_id": String(first["access_edge_id"]),
	}]
	var serialized: Dictionary = parcel.serialize()
	var selected: Dictionary = serialized["selected_door_edges"][0]
	_assert(selected.keys().size() == 5 and selected["access_kind"] == "PUBLIC_BAND" and selected["access_cell"] == null and selected["public_band_access_edge_id"] == first["access_edge_id"], "selected public door persists exact ADR35 representation")
	_assert(bool(Parcel.validate_serialized_selected_door_edges(serialized["selected_door_edges"]).get("valid", false)), "persisted public door provenance validates")
	var restored := Parcel.deserialize(serialized)
	_assert(restored.selected_door_edges.size() == 1 and restored.selected_door_edges[0]["public_band_access_edge_id"] == first["access_edge_id"], "stable public access-edge ID round-trips")
	var invalid_selected: Array = serialized["selected_door_edges"].duplicate(true)
	invalid_selected[0]["access_cell"] = {"x": 0, "y": 0}
	_assert(not bool(Parcel.validate_serialized_selected_door_edges(invalid_selected).get("valid", false)), "invalid PUBLIC_BAND null pairing rejects")

	var manager := ZoneManager.new()
	var zone := ZoneData.new()
	zone.id = "zone_public"
	zone.plot_id = String(endpoint["runtime_plot_id"])
	zone.floor = "G"
	zone.type = "Retail"
	zone.tiles = parcel.tiles.duplicate()
	zone.parcels = [restored]
	manager.zones[zone.id] = zone
	_assert(bool(manager._validate_retained_public_band_doors(snapshot).get("valid", false)), "Zone validation preserves a retained public-band door with matching injected provenance")
	var missing_value: Dictionary = value.duplicate(true)
	missing_value["access_edges"] = []
	var missing_snapshot := PublicBandAccessSnapshot.new()
	_assert(bool(missing_snapshot.configure(missing_value).get("valid", false)), "empty public-band comparison snapshot remains structurally valid")
	_assert(not bool(manager._validate_retained_public_band_doors(missing_snapshot).get("valid", false)), "Zone validation rejects removal of retained public-band door provenance")
	manager.free()

	print("ADR35 public-band access tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _direction(name: String) -> Vector2i:
	match name:
		"NORTH": return Vector2i.UP
		"EAST": return Vector2i.RIGHT
		"SOUTH": return Vector2i.DOWN
		"WEST": return Vector2i.LEFT
	return Vector2i.ZERO


func _code(result: Dictionary) -> String:
	var diagnostics: Array = result.get("diagnostics", [])
	return String(diagnostics[0].get("code", "")) if not diagnostics.is_empty() else ""


func _assert(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % label)
	else:
		_failed += 1
		push_error("[FAIL] %s" % label)
