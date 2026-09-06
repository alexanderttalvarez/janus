## H10 executable legacy removal tests.
## Run with: godot --headless --path . -s res://tests/test_h10_legacy_removal.gd
extends SceneTree


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_adapter_files_absent()
	_test_forbidden_names_absent_from_runtime_files()
	_test_production_bootstrap_boundary()
	print("H10 legacy removal tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_adapter_files_absent() -> void:
	var adapter_paths: Array[String] = [
		"scripts/district/legacy_footprint_layer_adapter.gd",
		"scripts/district/legacy_layout_bootstrap_adapter.gd",
		"scripts/district/legacy_floor_id_adapter.gd",
		"scripts/district/legacy_grid_projection_adapter.gd",
		"scripts/district/legacy_default_plot_selection_adapter.gd",
		"scripts/district/legacy_exterior_access_adapter.gd",
		"scripts/camera/legacy_camera_bounds_adapter.gd",
		"scripts/simulation/legacy_corner_spawn_adapter.gd",
		"scripts/traffic/legacy_authored_traffic_layout_adapter.gd",
		"scripts/simulation/legacy_visitor_spawn_adapter.gd",
	]
	for relative_path: String in adapter_paths:
		_assert(not FileAccess.file_exists("res://%s" % relative_path), "executable adapter file is absent: %s" % relative_path)


func _test_forbidden_names_absent_from_runtime_files() -> void:
	var forbidden: Array[String] = [
		"Legacy" + "FootprintLayerAdapter",
		"Legacy" + "LayoutBootstrapAdapter",
		"Legacy" + "FloorIdAdapter",
		"Legacy" + "GridProjectionAdapter",
		"Legacy" + "DefaultPlotSelectionAdapter",
		"Legacy" + "ExteriorAccessAdapter",
		"Legacy" + "CameraBoundsAdapter",
		"Legacy" + "CornerSpawnAdapter",
		"Legacy" + "AuthoredTrafficLayoutAdapter",
		"Legacy" + "VisitorSpawnAdapter",
		"Legacy" + "25LayoutAdapter",
		"Legacy" + "PlotIdAdapter",
		"Legacy" + "PedestrianRingAdapter",
		"Legacy" + "RoadSceneAdapter",
		"Legacy" + "TrafficMarkerAdapter",
		"Legacy" + "CornerArrivalAdapter",
		"Legacy" + "ZoneCoordinateAdapter",
		"Legacy" + "DistrictSaveAdapter",
	]
	var hits: Array[String] = []
	_scan_runtime_files("res://", forbidden, hits)
	_assert(hits.is_empty(), "canonical adapter names and stale aliases are absent from runtime files")


func _test_production_bootstrap_boundary() -> void:
	var scene_file: FileAccess = FileAccess.open("res://scenes/levels/main_game.tscn", FileAccess.READ)
	var main_script: FileAccess = FileAccess.open("res://scripts/levels/main_game.gd", FileAccess.READ)
	_assert(scene_file != null and not scene_file.get_as_text().contains("GridManager"), "production scene excludes retired grid authority")
	_assert(main_script != null and main_script.get_as_text().contains("initialize_production_catalog"), "MainGame selects the explicit production catalog")
	_assert(main_script != null and not main_script.get_as_text().contains("initialize_fixture_catalog"), "MainGame does not bootstrap fixture content")
	_assert(FileAccess.file_exists("res://resources/districts/district_initial.tres"), "district.initial production definition is packaged")
	_assert(FileAccess.file_exists("res://resources/districts/production_district_bootstrap.tres"), "production bootstrap configuration is packaged")


func _scan_runtime_files(path: String, forbidden: Array[String], hits: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var entry: String = directory.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == ".." or entry == ".godot":
			continue
		var child_path: String = path.path_join(entry)
		if directory.current_is_dir():
			_scan_runtime_files(child_path, forbidden, hits)
			continue
		if not _is_runtime_file(child_path):
			continue
		var file: FileAccess = FileAccess.open(child_path, FileAccess.READ)
		if file == null:
			continue
		var content: String = file.get_as_text()
		for name: String in forbidden:
			if content.contains(name):
				hits.append("%s:%s" % [child_path, name])
	directory.list_dir_end()


func _is_runtime_file(path: String) -> bool:
	return (
		path == "res://project.godot"
		or path.ends_with(".gd")
		or path.ends_with(".tscn")
		or path.ends_with(".tres")
		or path.ends_with(".res")
		or path.ends_with(".cfg")
		or path.ends_with(".import")
		or path.ends_with(".bak")
	)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)
