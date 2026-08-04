## ZoneBusinessAssigner — Static class for assigning business subtypes to parcels.
## Uses simple graph coloring to prevent adjacent parcels from having the same subtype.
## Pure GDScript — no Godot dependencies.
class_name ZoneBusinessAssigner
extends RefCounted


## Business subtypes per zone type. Index matches the subtypes available for each ZoneType.
const BUSINESS_SUBTYPES: Dictionary = {
	ZoneData.ZONE_TYPE_NAMES[0]: ["Clothing", "Electronics", "Books", "Home Goods", "Specialty"],
	ZoneData.ZONE_TYPE_NAMES[1]: ["Restaurant", "Cafe", "Fast Food", "Bakery", "Juice Bar"],
	ZoneData.ZONE_TYPE_NAMES[2]: ["Cinema", "Arcade", "Bowling", "Karaoke", "VR Center"],
	ZoneData.ZONE_TYPE_NAMES[3]: ["Bank", "Pharmacy", "Laundry", "Post Office", "Clinic"],
	ZoneData.ZONE_TYPE_NAMES[4]: ["Department Store", "Supermarket", "Fitness Center", "Library"],
}


## Assign business subtypes to parcels in a zone.
## Uses simple graph coloring to avoid adjacent duplicates.
static func assign(zone: ZoneData) -> void:
	var subtypes_raw: Variant = BUSINESS_SUBTYPES.get(zone.type, [])
	if not subtypes_raw is Array:
		return
	var subtypes: Array[String] = []
	for s in subtypes_raw:
		subtypes.append(s)
	if subtypes.is_empty():
		return

	# Build adjacency map: which parcels share a border?
	var adjacency: Dictionary = _build_adjacency(zone.parcels)

	# Assign subtypes using greedy coloring.
	var assigned: Dictionary = {}  # parcel_id -> subtype_index
	for parcel: Parcel in zone.parcels:
		var used_indices: Dictionary = {}
		# Check neighbors' assigned subtypes.
		var neighbors: Array = adjacency.get(parcel.id, [])
		for neighbor_id: String in neighbors:
			if assigned.has(neighbor_id):
				used_indices[assigned[neighbor_id]] = true

		# Pick first available subtype.
		var chosen_idx: int = 0
		for i in range(subtypes.size()):
			if not used_indices.has(i):
				chosen_idx = i
				break

		assigned[parcel.id] = chosen_idx
		parcel.business_type = subtypes[chosen_idx]

	# Store the first subtype as the zone's overall subtype.
	if not zone.parcels.is_empty():
		zone.subtype = zone.parcels[0].business_type


## Build adjacency map of parcels that share a border (edge-neighbors).
static func _build_adjacency(parcels: Array[Parcel]) -> Dictionary:
	var result: Dictionary = {}  # parcel_id -> Array[parcel_id]

	for p: Parcel in parcels:
		result[p.id] = []
		# Build a set of neighboring positions for this parcel.
		var neighbors: Array[Vector2i] = []
		for tile_pos: Vector2i in p.tiles:
			for offset: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				neighbors.append(Vector2i(tile_pos.x + offset.x, tile_pos.y + offset.y))

		# Check other parcels.
		for other: Parcel in parcels:
			if other.id == p.id:
				continue
			var is_adjacent: bool = false
			for np: Vector2i in neighbors:
				if other.tiles.has(np):
					is_adjacent = true
					break
			if is_adjacent:
				result[p.id].append(other.id)

	return result
