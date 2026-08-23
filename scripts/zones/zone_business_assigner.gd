## ZoneBusinessAssigner — Pure deterministic debug subtype graph-coloring.
class_name ZoneBusinessAssigner
extends RefCounted


## Return assignments and parcel-level diagnostics without mutating parcel data.
static func assign(
	parcels: Array[Parcel],
	zone_type: String,
	catalog_snapshot: Array[Dictionary]
) -> BusinessAssignmentResult:
	var result := BusinessAssignmentResult.new()
	var ordered_parcels := _sorted_parcels(parcels)
	var ordered_catalog := _sorted_catalog_entries(catalog_snapshot)
	var adjacency := _build_adjacency(ordered_parcels)
	var domains: Dictionary = {}  # Dictionary[String, Array[Dictionary]]
	var assigned: Dictionary = {}  # Dictionary[String, String]
	var use_counts: Dictionary = {}  # Dictionary[String, int]

	for parcel: Parcel in ordered_parcels:
		var domain := _eligible_entries(parcel, zone_type, ordered_catalog)
		domains[parcel.id] = domain
		if domain.is_empty():
			result.leave_unassigned(parcel.id, BusinessAssignmentResult.NO_ELIGIBLE_SUBTYPE)

	while true:
		var next_parcel := _select_next_parcel(ordered_parcels, adjacency, assigned, result)
		if next_parcel == null:
			break
		var selected_entry := _select_least_used_legal_entry(
			next_parcel.id,
			adjacency,
			domains,
			assigned,
			use_counts
		)
		if not selected_entry.is_empty():
			var subtype_id: String = selected_entry.get("id", "")
			assigned[next_parcel.id] = subtype_id
			_increment_use_count(use_counts, subtype_id)
			result.assign(next_parcel.id, subtype_id)
		elif not _try_single_recolor(
			next_parcel,
			adjacency,
			domains,
			assigned,
			use_counts,
			result
		):
			result.leave_unassigned(next_parcel.id, BusinessAssignmentResult.NO_LEGAL_SUBTYPE)

	return result


static func _sorted_parcels(parcels: Array[Parcel]) -> Array[Parcel]:
	var ordered: Array[Parcel] = parcels.duplicate()
	ordered.sort_custom(_compare_parcels)
	return ordered


static func _compare_parcels(first: Parcel, second: Parcel) -> bool:
	if first.id != second.id:
		return first.id < second.id
	var first_bounds := [first.bounds.position.y, first.bounds.position.x, first.bounds.size.y, first.bounds.size.x]
	var second_bounds := [second.bounds.position.y, second.bounds.position.x, second.bounds.size.y, second.bounds.size.x]
	for index: int in range(first_bounds.size()):
		if first_bounds[index] != second_bounds[index]:
			return first_bounds[index] < second_bounds[index]
	return false


static func _sorted_catalog_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var ordered: Array[Dictionary] = []
	for entry: Dictionary in entries:
		ordered.append(entry.duplicate(true))
	ordered.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_priority: int = first.get("debug_priority", 0)
		var second_priority: int = second.get("debug_priority", 0)
		if first_priority != second_priority:
			return first_priority < second_priority
		return first.get("id", "") < second.get("id", "")
	)
	return ordered


static func _eligible_entries(
	parcel: Parcel,
	zone_type: String,
	ordered_catalog: Array[Dictionary]
) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for entry: Dictionary in ordered_catalog:
		var minimum_tiles: int = entry.get("min_tiles", 0)
		var maximum_tiles: int = entry.get("max_tiles", -1)
		if entry.get("zone_type", "") != zone_type:
			continue
		if parcel.area < minimum_tiles:
			continue
		if maximum_tiles >= 0 and parcel.area > maximum_tiles:
			continue
		eligible.append(entry)
	return eligible


static func _build_adjacency(parcels: Array[Parcel]) -> Dictionary:
	var adjacency: Dictionary = {}  # Dictionary[String, Array[String]]
	var tile_owner: Dictionary = {}  # Dictionary[Vector2i, String]
	for parcel: Parcel in parcels:
		adjacency[parcel.id] = []
		for tile_pos: Vector2i in parcel.tiles:
			tile_owner[tile_pos] = parcel.id

	for parcel: Parcel in parcels:
		var neighbor_ids: Dictionary = {}
		for tile_pos: Vector2i in parcel.tiles:
			for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var neighbor_id: String = tile_owner.get(tile_pos + offset, "")
				if not neighbor_id.is_empty() and neighbor_id != parcel.id:
					neighbor_ids[neighbor_id] = true
		var sorted_neighbors: Array[String] = []
		for neighbor_id: String in neighbor_ids:
			sorted_neighbors.append(neighbor_id)
		sorted_neighbors.sort()
		adjacency[parcel.id] = sorted_neighbors
	return adjacency


static func _select_next_parcel(
	ordered_parcels: Array[Parcel],
	adjacency: Dictionary,
	assigned: Dictionary,
	result: BusinessAssignmentResult
) -> Parcel:
	var selected: Parcel = null
	var best_saturation: int = -1
	var best_degree: int = -1
	for parcel: Parcel in ordered_parcels:
		if assigned.has(parcel.id) or result.diagnostics.has(parcel.id):
			continue
		var neighbor_subtypes := _assigned_neighbor_subtypes(parcel.id, adjacency, assigned)
		var saturation := neighbor_subtypes.size()
		var degree: int = (adjacency.get(parcel.id, []) as Array).size()
		if saturation > best_saturation or (saturation == best_saturation and degree > best_degree):
			selected = parcel
			best_saturation = saturation
			best_degree = degree
	return selected


static func _select_least_used_legal_entry(
	parcel_id: String,
	adjacency: Dictionary,
	domains: Dictionary,
	assigned: Dictionary,
	use_counts: Dictionary
) -> Dictionary:
	var used_neighbor_subtypes := _assigned_neighbor_subtypes(parcel_id, adjacency, assigned)
	var selected: Dictionary = {}
	var selected_use_count: int = 0
	for entry: Dictionary in domains.get(parcel_id, []):
		var subtype_id: String = entry.get("id", "")
		if subtype_id.is_empty() or used_neighbor_subtypes.has(subtype_id):
			continue
		var use_count: int = use_counts.get(subtype_id, 0)
		if selected.is_empty() or use_count < selected_use_count:
			selected = entry
			selected_use_count = use_count
	return selected


static func _try_single_recolor(
	parcel: Parcel,
	adjacency: Dictionary,
	domains: Dictionary,
	assigned: Dictionary,
	use_counts: Dictionary,
	result: BusinessAssignmentResult
) -> bool:
	for requested_entry: Dictionary in domains.get(parcel.id, []):
		var requested_subtype: String = requested_entry.get("id", "")
		var blockers: Array[String] = []
		for neighbor_id: String in adjacency.get(parcel.id, []):
			if assigned.get(neighbor_id, "") == requested_subtype:
				blockers.append(neighbor_id)
		if blockers.size() != 1:
			continue
		var blocker_id: String = blockers[0]
		for alternative_entry: Dictionary in domains.get(blocker_id, []):
			var alternative_subtype: String = alternative_entry.get("id", "")
			if alternative_subtype.is_empty() or alternative_subtype == requested_subtype:
				continue
			if not _is_legal_for_neighbors(blocker_id, alternative_subtype, adjacency, assigned):
				continue
			var old_subtype: String = assigned[blocker_id]
			assigned[blocker_id] = alternative_subtype
			_decrement_use_count(use_counts, old_subtype)
			_increment_use_count(use_counts, alternative_subtype)
			assigned[parcel.id] = requested_subtype
			_increment_use_count(use_counts, requested_subtype)
			result.assign(blocker_id, alternative_subtype)
			result.assign(parcel.id, requested_subtype)
			return true
	return false


static func _is_legal_for_neighbors(
	parcel_id: String,
	subtype_id: String,
	adjacency: Dictionary,
	assigned: Dictionary
) -> bool:
	for neighbor_id: String in adjacency.get(parcel_id, []):
		if assigned.get(neighbor_id, "") == subtype_id:
			return false
	return true


static func _assigned_neighbor_subtypes(parcel_id: String, adjacency: Dictionary, assigned: Dictionary) -> Dictionary:
	var subtype_ids: Dictionary = {}
	for neighbor_id: String in adjacency.get(parcel_id, []):
		var subtype_id: String = assigned.get(neighbor_id, "")
		if not subtype_id.is_empty():
			subtype_ids[subtype_id] = true
	return subtype_ids


static func _increment_use_count(use_counts: Dictionary, subtype_id: String) -> void:
	use_counts[subtype_id] = int(use_counts.get(subtype_id, 0)) + 1


static func _decrement_use_count(use_counts: Dictionary, subtype_id: String) -> void:
	var remaining: int = int(use_counts.get(subtype_id, 0)) - 1
	if remaining <= 0:
		use_counts.erase(subtype_id)
	else:
		use_counts[subtype_id] = remaining
