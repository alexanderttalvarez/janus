class_name ConstructionTopologyProjection
extends RefCounted

## Detached topology facts derived only from committed construction records.


func build(snapshot: ResolvedDistrictSnapshot, state: Dictionary, zone_revision: int, commit_id: String) -> Dictionary:
	if snapshot == null:
		return {"valid": false, "diagnostics": [{"code": "CONSTRUCTION_SNAPSHOT_REQUIRED", "message": "topology requires a District snapshot"}]}
	var vertical_links: Array[Dictionary] = []
	var corridor_cells: Dictionary = {}
	var facts_by_floor: Dictionary = {}
	for plot_state: Dictionary in state.get("plot_states", []):
		var plot_id: String = String(plot_state.get("runtime_plot_id", ""))
		for floor_state: Dictionary in plot_state.get("floor_states", []):
			var floor_id: String = String(floor_state.get("floor_id", ""))
			var elevation: int = int(floor_state.get("elevation", 0))
			for pair: Array in floor_state.get("explicit_circulation_cells", []):
				var cell: Dictionary = {"plot_id": plot_id, "floor_id": floor_id, "elevation": elevation, "x": int(pair[0]), "y": int(pair[1])}
				corridor_cells[_cell_key(cell)] = cell
	for record: Dictionary in state.get("construction_records", []):
		var kind: String = String(record.get("kind", ""))
		if kind == "stairs":
			var cells: Array = record.get("cells", [])
			var by_floor: Dictionary = _first_cell_by_floor(cells)
			var floor_ids: Array = by_floor.keys()
			floor_ids.sort()
			if floor_ids.size() == 2:
				vertical_links.append(_link_record(record, "stairs", by_floor[floor_ids[0]], by_floor[floor_ids[1]], state, commit_id))
				_add_floor_fact(facts_by_floor, by_floor[floor_ids[0]], "stairs")
				_add_floor_fact(facts_by_floor, by_floor[floor_ids[1]], "stairs")
		elif kind == "elevator":
			var shaft_by_floor: Dictionary = _first_cell_by_floor(record.get("shaft_cells", record.get("cells", [])))
			var stops: Array = shaft_by_floor.keys()
			stops.sort_custom(func(left: String, right: String) -> bool: return int(shaft_by_floor[left].get("elevation", 0)) < int(shaft_by_floor[right].get("elevation", 0)))
			for index: int in range(1, stops.size()):
				var from_cell: Dictionary = shaft_by_floor[stops[index - 1]]
				var to_cell: Dictionary = shaft_by_floor[stops[index]]
				vertical_links.append(_link_record(record, "elevator", from_cell, to_cell, state, commit_id))
			for floor_id: String in stops:
				_add_floor_fact(facts_by_floor, shaft_by_floor[floor_id], "elevator")

	var floor_edges: Array[Dictionary] = []
	for key: String in corridor_cells:
		var cell: Dictionary = corridor_cells[key]
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor: Dictionary = cell.duplicate(true)
			neighbor["x"] = int(cell.get("x", 0)) + direction.x
			neighbor["y"] = int(cell.get("y", 0)) + direction.y
			if corridor_cells.has(_cell_key(neighbor)):
				var from_id: String = _cell_id(cell)
				var to_id: String = _cell_id(neighbor)
				floor_edges.append({"edge_id": "corridor/%s/%s" % [from_id, to_id], "from_cell_id": from_id, "to_cell_id": to_id, "kind": "corridor"})
		floor_edges.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["edge_id"]) < String(right["edge_id"]))
	vertical_links.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["link_id"]) < String(right["link_id"]))
	var vertical_facts: Array[Dictionary] = []
	for floor_key: String in facts_by_floor:
		var fact: Dictionary = facts_by_floor[floor_key]
		fact["source_construction_revision"] = int(state.get("construction_revision", 0))
		fact["commit_id"] = commit_id
		fact["valid_public_route_result"] = "UNAVAILABLE"
		vertical_facts.append(fact)
	vertical_facts.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["floor_id"]) < String(right["floor_id"]))
	return {
		"valid": true,
		"district_revision": int(state.get("district_revision", 0)),
		"zone_revision": zone_revision,
		"construction_revision": int(state.get("construction_revision", 0)),
		"commit_id": commit_id,
		"floor_circulation_edges": floor_edges,
		"vertical_links": vertical_links,
		"vertical_link_facts": vertical_facts,
		"operations_room_facts": _operations_room_facts(state),
		"diagnostics": [],
	}


func _link_record(record: Dictionary, kind: String, from_cell: Dictionary, to_cell: Dictionary, state: Dictionary, commit_id: String) -> Dictionary:
	return {
		"link_id": "%s/%s/%s" % [String(record.get("construction_id", "")), kind, String(to_cell.get("floor_id", ""))],
		"from_floor_id": String(from_cell.get("floor_id", "")),
		"from_cell_id": _cell_id(from_cell),
		"to_floor_id": String(to_cell.get("floor_id", "")),
		"to_cell_id": _cell_id(to_cell),
		"kind": kind,
		"construction_revision": int(state.get("construction_revision", 0)),
		"commit_id": commit_id,
	}


func _first_cell_by_floor(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for cell: Variant in cells:
		if cell is Dictionary:
			var floor_id: String = String(cell.get("floor_id", ""))
			if not result.has(floor_id):
				result[floor_id] = cell
	return result


func _add_floor_fact(facts: Dictionary, cell: Dictionary, kind: String) -> void:
	var floor_id: String = String(cell.get("floor_id", ""))
	if not facts.has(floor_id):
		facts[floor_id] = {"floor_id": floor_id, "elevation": int(cell.get("elevation", 0)), "stairs_count": 0, "elevators_count": 0}
	var count_key: String = "elevators_count" if kind == "elevator" else "%s_count" % kind
	facts[floor_id][count_key] = int(facts[floor_id].get(count_key, 0)) + 1


func _operations_room_facts(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in state.get("construction_records", []):
		if String(record.get("kind", "")) != "operations_room":
			continue
		var cells: Array = record.get("cells", [])
		if cells.is_empty():
			continue
		result.append({"operations_room_id": String(record.get("construction_id", "")), "building_id": String(record.get("plot_id", "")), "floor_id": String(cells[0].get("floor_id", "")), "construction_revision": int(state.get("construction_revision", 0)), "committed_valid_for_staffing": true})
	return result


func _cell_id(cell: Dictionary) -> String:
	return "%s:%d:%d" % [String(cell.get("floor_id", "")), int(cell.get("x", 0)), int(cell.get("y", 0))]


func _cell_key(cell: Dictionary) -> String:
	return "%s:%d:%d:%d" % [String(cell.get("floor_id", "")), int(cell.get("elevation", 0)), int(cell.get("x", 0)), int(cell.get("y", 0))]
