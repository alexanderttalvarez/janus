## SynergyManager — Zone relationship tracking, proximity calculation, effects on tenants/prestige.
class_name SynergyManager
extends Node


## Synergy types and values.
enum SynergyType { COMPLEMENTARY = 5, NEUTRAL = 0, CANNIBALIZATION = -3, CONFLICTING = -5 }

## Zone type pairs → synergy type.
const SYNERGY_MATRIX: Dictionary = {
	"Retail+Food & Beverage": SynergyType.COMPLEMENTARY,
	"Retail+Entertainment": SynergyType.COMPLEMENTARY,
	"Food & Beverage+Entertainment": SynergyType.COMPLEMENTARY,
	"Retail+Services": SynergyType.NEUTRAL,
	"Food & Beverage+Services": SynergyType.NEUTRAL,
	"Entertainment+Services": SynergyType.CANNIBALIZATION,
	"Retail+Retail": SynergyType.CANNIBALIZATION,
	"Food & Beverage+Food & Beverage": SynergyType.CANNIBALIZATION,
	"Entertainment+Entertainment": SynergyType.CANNIBALIZATION,
	"Services+Services": SynergyType.CANNIBALIZATION,
	"Anchor+Retail": SynergyType.COMPLEMENTARY,
	"Anchor+Food & Beverage": SynergyType.COMPLEMENTARY,
	"Anchor+Entertainment": SynergyType.COMPLEMENTARY,
}

## Proximity threshold in tiles (boundary-to-boundary).
const PROXIMITY_RANGE: int = 5

## Zone synergy scores: zone_id -> int.
var zone_scores: Dictionary = {}

var _zone_manager: ZoneManager
var _grid_manager: GridManager


func initialize(zm: ZoneManager, gm: GridManager) -> void:
	_zone_manager = zm
	_grid_manager = gm


## Recalculate all zone synergies.
func recalculate() -> void:
	zone_scores.clear()
	var zone_list: Array[ZoneData] = []
	for zid: String in _zone_manager.zones:
		zone_list.append(_zone_manager.zones[zid])

	for i in range(zone_list.size()):
		for j in range(i + 1, zone_list.size()):
			var zone_a: ZoneData = zone_list[i]
			var zone_b: ZoneData = zone_list[j]
			# Only same-floor zones matter.
			if zone_a.floor != zone_b.floor:
				continue
			if _are_zones_in_range(zone_a, zone_b):
				var synergy := _get_synergy(zone_a.type, zone_b.type)
				_add_synergy(zone_a.id, zone_b.id, synergy)

	EventBus.synergy_recalculated.emit(zone_scores.duplicate())


func _are_zones_in_range(a: ZoneData, b: ZoneData) -> bool:
	for ta: Vector2i in a.tiles:
		for tb: Vector2i in b.tiles:
			if ta.distance_to(tb) <= PROXIMITY_RANGE:
				return true
	return false


func _get_synergy(type_a: String, type_b: String) -> int:
	var key1 := type_a + "+" + type_b
	var key2 := type_b + "+" + type_a
	if SYNERGY_MATRIX.has(key1):
		return SYNERGY_MATRIX[key1]
	if SYNERGY_MATRIX.has(key2):
		return SYNERGY_MATRIX[key2]
	return SynergyType.NEUTRAL


func _add_synergy(zone_a: String, zone_b: String, value: int) -> void:
	zone_scores[zone_a] = zone_scores.get(zone_a, 0) + value
	zone_scores[zone_b] = zone_scores.get(zone_b, 0) + value
	EventBus.synergy_changed.emit(zone_a, zone_b, 0, value)


func serialize() -> Dictionary:
	return {"zone_scores": zone_scores.duplicate()}


func deserialize(data: Dictionary) -> void:
	zone_scores = data.get("zone_scores", {})
