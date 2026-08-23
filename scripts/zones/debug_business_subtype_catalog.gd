## DebugBusinessSubtypeCatalog — Immutable Handoff 02 debug subtype content.
class_name DebugBusinessSubtypeCatalog
extends RefCounted


const UNBOUNDED_MAX_TILES: int = -1

## Entries are ordered by their canonical debug_priority.
const ENTRIES_BY_ZONE_TYPE: Dictionary = {
	"Retail": [
		{"id": "retail.fashion", "display_name": "Fashion", "zone_type": "Retail", "min_tiles": 6, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 0},
		{"id": "retail.electronics", "display_name": "Electronics", "zone_type": "Retail", "min_tiles": 6, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 1},
		{"id": "retail.home_goods", "display_name": "Home Goods", "zone_type": "Retail", "min_tiles": 6, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 2},
		{"id": "retail.jewelry", "display_name": "Jewelry", "zone_type": "Retail", "min_tiles": 6, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 3},
		{"id": "retail.bookstore", "display_name": "Bookstore", "zone_type": "Retail", "min_tiles": 6, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 4},
	],
	"Food & Beverage": [
		{"id": "food.sushi_restaurant", "display_name": "Sushi Restaurant", "zone_type": "Food & Beverage", "min_tiles": 8, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 0},
		{"id": "food.italian_restaurant", "display_name": "Italian Restaurant", "zone_type": "Food & Beverage", "min_tiles": 8, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 1},
		{"id": "food.cafe", "display_name": "Cafe", "zone_type": "Food & Beverage", "min_tiles": 8, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 2},
		{"id": "food.mexican_restaurant", "display_name": "Mexican Restaurant", "zone_type": "Food & Beverage", "min_tiles": 8, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 3},
		{"id": "food.local_food", "display_name": "Local Food", "zone_type": "Food & Beverage", "min_tiles": 8, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 4},
	],
	"Entertainment": [
		{"id": "entertainment.cinema", "display_name": "Cinema", "zone_type": "Entertainment", "min_tiles": 12, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 0},
		{"id": "entertainment.arcade", "display_name": "Arcade", "zone_type": "Entertainment", "min_tiles": 12, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 1},
		{"id": "entertainment.bowling_alley", "display_name": "Bowling Alley", "zone_type": "Entertainment", "min_tiles": 12, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 2},
		{"id": "entertainment.escape_room", "display_name": "Escape Room", "zone_type": "Entertainment", "min_tiles": 12, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 3},
		{"id": "entertainment.vr_experience", "display_name": "VR Experience", "zone_type": "Entertainment", "min_tiles": 12, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 4},
	],
	"Services": [
		{"id": "services.bank", "display_name": "Bank", "zone_type": "Services", "min_tiles": 5, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 0},
		{"id": "services.hair_salon", "display_name": "Hair Salon", "zone_type": "Services", "min_tiles": 5, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 1},
		{"id": "services.repair_shop", "display_name": "Repair Shop", "zone_type": "Services", "min_tiles": 5, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 2},
		{"id": "services.clinic", "display_name": "Clinic", "zone_type": "Services", "min_tiles": 5, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 3},
		{"id": "services.travel_agency", "display_name": "Travel Agency", "zone_type": "Services", "min_tiles": 5, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 4},
	],
	"Anchor": [
		{"id": "anchor.department_store", "display_name": "Department Store", "zone_type": "Anchor", "min_tiles": 30, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 0},
		{"id": "anchor.supermarket", "display_name": "Supermarket", "zone_type": "Anchor", "min_tiles": 30, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 1},
		{"id": "anchor.gym", "display_name": "Gym", "zone_type": "Anchor", "min_tiles": 30, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 2},
		{"id": "anchor.food_court", "display_name": "Food Court", "zone_type": "Anchor", "min_tiles": 30, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 3},
		{"id": "anchor.exhibition_hall", "display_name": "Exhibition Hall", "zone_type": "Anchor", "min_tiles": 30, "max_tiles": UNBOUNDED_MAX_TILES, "debug_priority": 4},
	],
}


static func snapshot_for_zone_type(zone_type: String) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	var entries: Variant = ENTRIES_BY_ZONE_TYPE.get(zone_type, [])
	if not entries is Array:
		return snapshot
	for entry: Dictionary in entries:
		snapshot.append(entry.duplicate(true))
	return snapshot


static func display_name_for(subtype_id: String) -> String:
	for entries: Variant in ENTRIES_BY_ZONE_TYPE.values():
		if not entries is Array:
			continue
		for entry: Dictionary in entries:
			if entry.get("id", "") == subtype_id:
				return entry.get("display_name", "")
	return ""
