class_name DistrictLegacyAdapters
extends RefCounted

## H3 migration adapters. Each adapter isolates one legacy boundary and keeps
## District Runtime independent from fixed-grid implementation details.


class LegacyLayoutBootstrapAdapter extends RefCounted:
	func create_legacy_snapshot() -> Dictionary:
		var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
		var resolver: RefCounted = load("res://scripts/resources/district_layout_resolver.gd").new()
		var resolution: Dictionary = resolver.resolve(factory.build_fixture("A"))
		if not bool(resolution.get("valid", false)):
			return {"valid": false, "diagnostics": resolution.get("diagnostics", [])}
		return {"valid": true, "snapshot": resolution.get("snapshot"), "diagnostics": []}


class LegacyFloorIdAdapter extends RefCounted:
	func to_elevation(floor_id: String) -> Dictionary:
		if floor_id == "G":
			return {"valid": true, "elevation": 0, "diagnostics": []}
		if floor_id.length() < 2 or (floor_id[0] != "F" and floor_id[0] != "B") or not floor_id.substr(1).is_valid_int():
			return {"valid": false, "diagnostics": [{"code": "LEGACY_FLOOR_ID_INVALID", "message": "legacy floor ID must be G, F<n>, or B<n>"}]}
		var magnitude: int = floor_id.substr(1).to_int()
		if magnitude <= 0:
			return {"valid": false, "diagnostics": [{"code": "LEGACY_FLOOR_ID_INVALID", "message": "legacy floor magnitude must be positive"}]}
		return {"valid": true, "elevation": magnitude if floor_id[0] == "F" else -magnitude, "diagnostics": []}

	func to_legacy_floor(elevation: int) -> String:
		if elevation == 0:
			return "G"
		return "F%d" % elevation if elevation > 0 else "B%d" % absi(elevation)


class LegacyDefaultPlotSelectionAdapter extends RefCounted:
	func normalize_plot_id(plot_id: String) -> String:
		return "plot_0" if plot_id.is_empty() else plot_id

	func normalize_floor_id(floor_id: String) -> String:
		return "G" if floor_id.is_empty() else floor_id

	func normalize_address(plot_id: String, floor_id: String) -> Dictionary:
		return {"plot_id": normalize_plot_id(plot_id), "floor_id": normalize_floor_id(floor_id)}


class LegacyGridProjectionAdapter extends RefCounted:
	var grid_manager: GridManager
	var snapshot: ResolvedDistrictSnapshot
	var default_selection: LegacyDefaultPlotSelectionAdapter = LegacyDefaultPlotSelectionAdapter.new()
	var floor_ids: LegacyFloorIdAdapter = LegacyFloorIdAdapter.new()

	func initialize(manager: GridManager, district_snapshot: ResolvedDistrictSnapshot) -> void:
		grid_manager = manager
		snapshot = district_snapshot

	func on_district_committed(envelope: Dictionary) -> Dictionary:
		if snapshot != null:
			project_state(envelope.get("state", {}), snapshot)
		return {"ok": true}

	func project_state(state: Dictionary, snapshot: ResolvedDistrictSnapshot) -> void:
		if grid_manager == null or snapshot == null:
			return
		var data: Dictionary = snapshot.get_data()
		for plot_state: Dictionary in state.get("plot_states", []):
			var plot_id: String = String(plot_state.get("runtime_plot_id", ""))
			var legacy_plot_id: String = default_selection.normalize_plot_id(plot_id if plot_id == "plot_0" else "plot_0")
			for floor_state: Dictionary in plot_state.get("floor_states", []):
				var elevation: int = int(floor_state.get("elevation", 0))
				var legacy_floor: String = floor_ids.to_legacy_floor(elevation)
				var acquired: Dictionary = {}
				for cell: Array in floor_state.get("acquired_cells", []):
					acquired["%d:%d" % [int(cell[0]), int(cell[1])]] = true
				for cell: Array in floor_state.get("constructed_cells", []):
					acquired["%d:%d" % [int(cell[0]), int(cell[1])]] = true
				for key: String in acquired:
					var parts: PackedStringArray = key.split(":")
					var tile: GridTile = grid_manager.get_tile(int(parts[0]), int(parts[1]), legacy_plot_id, legacy_floor)
					if tile == null:
						continue
					tile.owned = true
					tile.floor_built = _contains_cell(floor_state.get("constructed_cells", []), [int(parts[0]), int(parts[1])])
					if tile.floor_built:
						tile.condition = 100

	func _contains_cell(cells: Array, expected: Array) -> bool:
		for cell: Variant in cells:
			if cell is Array and int(cell[0]) == int(expected[0]) and int(cell[1]) == int(expected[1]):
				return true
		return false


class LegacyExteriorAccessAdapter extends RefCounted:
	var grid_manager: GridManager

	func initialize(manager: GridManager) -> void:
		grid_manager = manager

	func preserve_frontage(plot_id: String = "plot_0", floor_id: String = "G") -> void:
		if grid_manager == null:
			return
		var floor_grid: FloorGrid = grid_manager.get_floor_grid(plot_id, floor_id)
		if floor_grid == null or floor_grid.width <= 0 or floor_grid.height <= 0:
			return
		var x_mid: int = floor_grid.width / 2
		var y_mid: int = floor_grid.height / 2
		grid_manager.set_tile_door(x_mid, 0, GridTile.DoorSide.NORTH, true, plot_id, floor_id)
		grid_manager.set_tile_door(x_mid, floor_grid.height - 1, GridTile.DoorSide.SOUTH, true, plot_id, floor_id)
		grid_manager.set_tile_door(0, y_mid, GridTile.DoorSide.WEST, true, plot_id, floor_id)
		grid_manager.set_tile_door(floor_grid.width - 1, y_mid, GridTile.DoorSide.EAST, true, plot_id, floor_id)
