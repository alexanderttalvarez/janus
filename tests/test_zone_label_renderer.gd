## ZoneLabelRendererTest — Committed zone label projection and lifecycle checks.
## Run with: godot --headless --path . -s res://tests/test_zone_label_renderer.gd
extends Node


var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_run_tests()


func _run_tests() -> void:
	var debug_manager: Node = get_tree().root.get_node("DebugManager")
	var previous_visibility: bool = bool(debug_manager.get("show_zone_labels"))
	debug_manager.call("set_show_zone_labels", true)
	_test_centroid_uses_transformed_floor_conversion()
	_test_text_fallback_and_visibility_lifecycle()
	_test_committed_events_refresh_without_duplicates()
	debug_manager.call("set_show_zone_labels", previous_visibility)
	print("ZoneLabelRenderer tests: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _test_centroid_uses_transformed_floor_conversion() -> void:
	var context: Dictionary = _make_context()
	var floor: Floor = context.get("ground_floor") as Floor
	var label: Label3D = _get_name_label(floor, "zone_alpha")
	var centroid := Vector2(1.5, 1.0)
	var expected_local: Vector3 = floor.grid_coordinate_to_local(centroid) + Vector3(0.0, ZoneLabelRenderer.ZONE_LABEL_Y_OFFSET, 0.0)
	_assert(label != null, "active committed zone creates exactly one name label")
	if label != null:
		_assert(label.position.distance_to(expected_local) < 0.0001, "label uses the mathematical tile-footprint centroid")
		_assert(label.global_position.distance_to(floor.to_global(expected_local)) < 0.0001, "label preserves the transformed floor projection")
		_assert(label.font_size > ParcelLabelRenderer.NAME_FONT_SIZE, "zone label uses the larger font tier")
		_assert(absf(label.position.y - ZoneLabelRenderer.ZONE_LABEL_Y_OFFSET) < 0.0001, "zone label uses the higher vertical label tier")
	_cleanup_context(context)


func _test_text_fallback_and_visibility_lifecycle() -> void:
	var context: Dictionary = _make_context()
	var ground_floor: Floor = context.get("ground_floor") as Floor
	var upper_floor: Floor = context.get("upper_floor") as Floor
	var ground_label: Label3D = _get_name_label(ground_floor, "zone_alpha")
	_assert(ground_label != null and ground_label.text == "Retail", "empty zone name falls back to committed zone type")

	var renderer: ZoneLabelRenderer = context.get("renderer") as ZoneLabelRenderer
	renderer._on_floor_changed("F1")
	_assert(ground_floor.get_node("ZoneLabelContainer").get_child_count() == 0, "active-floor change clears labels from the previous floor")
	_assert(upper_floor.get_node("ZoneLabelContainer").get_child_count() == 1, "active-floor change hydrates only the active floor")

	var debug_manager: Node = get_tree().root.get_node("DebugManager")
	debug_manager.call("set_show_zone_labels", false)
	_assert(ground_floor.get_node("ZoneLabelContainer").get_child_count() == 0, "disabling visibility clears ground-floor labels")
	_assert(upper_floor.get_node("ZoneLabelContainer").get_child_count() == 0, "disabling visibility clears active-floor labels")
	debug_manager.call("set_show_zone_labels", true)
	_assert(upper_floor.get_node("ZoneLabelContainer").get_child_count() == 1, "enabling visibility hydrates the active floor")
	_cleanup_context(context)


func _test_committed_events_refresh_without_duplicates() -> void:
	var context: Dictionary = _make_context()
	var zone_manager: ZoneManager = context.get("zone_manager") as ZoneManager
	var floor: Floor = context.get("ground_floor") as Floor
	var renderer: ZoneLabelRenderer = context.get("renderer") as ZoneLabelRenderer
	var event_bus: Node = get_tree().root.get_node("EventBus")
	var container: Node3D = floor.get_node("ZoneLabelContainer") as Node3D

	var zone: ZoneData = zone_manager.zones.get("zone_alpha", null) as ZoneData
	zone.zone_name = "Updated Zone"
	event_bus.emit_signal("zone_modified", zone.id)
	_assert(container.get_child_count() == 1, "committed modification refreshes one surviving zone group")
	_assert(_get_name_label(floor, zone.id).text == "Updated Zone", "modified committed zone refreshes its text")

	var created: ZoneData = _make_zone("zone_created", "Entertainment", "", "G", [Vector2i(4, 4)])
	zone_manager.zones[created.id] = created
	event_bus.emit_signal("zone_created", created.id, created.type, created.tiles.size())
	_assert(container.get_child_count() == 2, "committed creation adds one label group")
	renderer.hydrate_active_floor()
	_assert(container.get_child_count() == 2, "repeated hydration does not duplicate committed labels")

	var before_rejected_refresh: Node3D = container.get_node("zone_created") as Node3D
	event_bus.emit_signal("zone_modified", "rejected_zone")
	_assert(container.get_node_or_null("zone_created") == before_rejected_refresh, "unknown transaction events do not mutate labels")
	var rejected: ZoneData = zone_manager.create_zone("Retail", [Vector2i(8, 8)], "G", "source_plot")
	_assert(rejected == null, "rejected ZoneManager transaction creates no zone")
	_assert(container.get_child_count() == 2, "rejected ZoneManager transaction leaves committed labels unchanged")
	_assert(container.get_node_or_null("zone_created") == before_rejected_refresh, "rejected ZoneManager transaction preserves the existing label group")

	zone_manager.zones.erase(created.id)
	event_bus.emit_signal("zone_deleted", created.id)
	_assert(container.get_child_count() == 1, "committed deletion removes the retired zone group")

	var merged: ZoneData = _make_zone("zone_retired", "Retail", "Retired", "G", [Vector2i(5, 5)])
	zone_manager.zones[merged.id] = merged
	event_bus.emit_signal("zone_created", merged.id, merged.type, merged.tiles.size())
	zone_manager.zones.erase(merged.id)
	zone.tiles.append(Vector2i(3, 3))
	event_bus.emit_signal("zone_modified", zone.id)
	event_bus.emit_signal("zone_deleted", merged.id)
	_assert(container.get_child_count() == 1, "merge and removal events retain only the surviving committed zone label")
	_assert(_get_name_label(floor, zone.id).text == "Updated Zone", "surviving merge label remains committed state")
	_cleanup_context(context)


func _make_context() -> Dictionary:
	var world := Node3D.new()
	world.name = "World"
	get_tree().root.add_child(world)

	var coordinator := ProjectionCoordinator.new()
	coordinator.name = "ProjectionCoordinator"
	world.add_child(coordinator)
	var projection_root := Node3D.new()
	projection_root.name = "GeneratedProjection"
	var ground_floor := _make_floor("projected_plot", "G", Vector3(10.0, 2.0, 20.0), 90.0)
	var upper_floor := _make_floor("projected_plot", "F1", Vector3(10.0, 5.0, 20.0), 90.0)
	projection_root.add_child(ground_floor)
	projection_root.add_child(upper_floor)
	coordinator._active_root = projection_root
	coordinator.add_child(projection_root)

	var grid_manager := GridManager.new()
	grid_manager.name = "GridManager"
	var plot := grid_manager.create_plot("source_plot", 10, 10)
	var floor_grid: FloorGrid = plot.get_floor(GridManager.GROUND_FLOOR)
	for x: int in range(floor_grid.width):
		for y: int in range(floor_grid.height):
			var tile: GridTile = floor_grid.get_tile(x, y)
			tile.owned = true
			tile.floor_built = true
	world.add_child(grid_manager)

	var zone_manager := ZoneManager.new()
	zone_manager.name = "ZoneManager"
	zone_manager.zones["zone_alpha"] = _make_zone("zone_alpha", "Retail", "", "G", [Vector2i(0, 0), Vector2i(2, 1)])
	zone_manager.zones["zone_upper"] = _make_zone("zone_upper", "Services", "Upper Zone", "F1", [Vector2i(1, 1)])
	world.add_child(zone_manager)

	var renderer := ZoneLabelRenderer.new()
	renderer.name = "ZoneLabelRenderer"
	renderer.zone_manager = zone_manager
	renderer.configure_plot_mapping("source_plot", "projected_plot")
	world.add_child(renderer)
	return {
		"world": world,
		"projection_root": projection_root,
		"zone_manager": zone_manager,
		"renderer": renderer,
		"ground_floor": ground_floor,
		"upper_floor": upper_floor,
	}


func _make_floor(plot_id: String, floor_level: String, floor_position: Vector3, rotation_degrees: float) -> Floor:
	var floor := Floor.new()
	floor.name = "floor_%s_%s" % [plot_id, floor_level]
	floor.plot_id = plot_id
	floor.floor_level = floor_level
	floor.tile_size = 2.5
	floor.position = floor_position
	floor.rotation.y = deg_to_rad(rotation_degrees)
	var grid_origin := Marker3D.new()
	grid_origin.name = "GridOrigin"
	grid_origin.position = Vector3(3.0, 0.0, -4.0)
	floor.add_child(grid_origin)
	return floor


func _make_zone(id: String, zone_type: String, zone_name: String, floor: String, tiles: Array[Vector2i]) -> ZoneData:
	var zone := ZoneData.new()
	zone.id = id
	zone.plot_id = "source_plot"
	zone.type = zone_type
	zone.zone_name = zone_name
	zone.floor = floor
	zone.tiles = tiles
	return zone


func _get_name_label(floor: Floor, zone_id: String) -> Label3D:
	var group := floor.get_node_or_null("ZoneLabelContainer/%s" % zone_id) as Node3D
	return null if group == null else group.get_node_or_null("Name") as Label3D


func _cleanup_context(context: Dictionary) -> void:
	var renderer: ZoneLabelRenderer = context.get("renderer") as ZoneLabelRenderer
	var projection_root: Node3D = context.get("projection_root") as Node3D
	var world: Node3D = context.get("world") as Node3D
	if renderer != null and is_instance_valid(renderer):
		renderer.free()
	if projection_root != null and is_instance_valid(projection_root):
		projection_root.free()
	if world != null and is_instance_valid(world):
		world.free()
