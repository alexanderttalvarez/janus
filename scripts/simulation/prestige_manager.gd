## PrestigeManager — Core progression metric: Scale × Quality.
## Recalculated monthly. Drives mall level advancement and tech points.
class_name PrestigeManager
extends Node


signal prestige_recalculated(new_prestige: int, scale: int, quality: int)


## Mall levels with evocative names.
enum MallLevel { LOCAL_SHOPPING, NEIGHBORHOOD_CENTER, COMMUNITY_MALL, REGIONAL_MALL, MEGACITY_MALL }
const MALL_LEVEL_NAMES: Array[String] = [
	"Local Shopping Building", "Neighborhood Center", "Community Mall", "Regional Mall", "Megacity Mall"
]
## Prestige thresholds for each mall level.
const LEVEL_THRESHOLDS: Array[int] = [0, 500, 2000, 5000, 15000]


## Current prestige score.
var prestige: int = 0

## Scale score (0-100) — based on zone count, floor count, tile count.
var scale: int = 0

## Quality score (0-100) — weighted average of 6 factors.
var quality: int = 0

## Current mall level tier.
var current_level: MallLevel = MallLevel.LOCAL_SHOPPING

## Prestige trend: positive = growing, negative = declining.
var trend: int = 0

## Tech points earned.
var tech_points: int = 0

## Loan default multiplier (0.0-1.0, reduces quality).
var loan_default_multiplier: float = 1.0

## References for data queries.
var _zone_manager: ZoneManager
var _tenant_manager: TenantManager
var _visitor_manager: VisitorManager


func initialize(zm: ZoneManager, tm: TenantManager, vm: VisitorManager) -> void:
	_zone_manager = zm
	_tenant_manager = tm
	_visitor_manager = vm


## Recalculate prestige on sim_month_passed.
func recalculate() -> void:
	var old_prestige := prestige
	scale = _calculate_scale()
	quality = int(float(_calculate_quality()) * loan_default_multiplier)
	prestige = scale * quality

	# Check mall level advancement.
	var new_level := _determine_level(prestige)
	var previous_level := current_level
	current_level = new_level

	trend = prestige - old_prestige

	# Award tech points on level up.
	if new_level > previous_level:
		var points := (new_level - previous_level) * 3
		tech_points += points
		EventBus.mall_level_up.emit(MALL_LEVEL_NAMES[new_level], points)

	prestige_recalculated.emit(prestige, scale, quality)
	EventBus.prestige_recalculated.emit(prestige, scale, quality)


func _calculate_scale() -> int:
	var score: int = 0
	# Zone count: up to 40 points.
	if _zone_manager:
		score += mini(_zone_manager.zones.size() * 4, 40)
	# Tenant count: up to 30 points.
	if _tenant_manager:
		var active := 0
		for t: TenantData in _tenant_manager.all_tenants:
			if t.is_active:
				active += 1
		score += mini(active * 5, 30)
	# Visitor count: up to 30 points.
	if _visitor_manager:
		score += mini(_visitor_manager.all_visitors.size() / 2, 30)
	return clampi(score, 0, 100)


func _calculate_quality() -> int:
	var factors: Array[int] = [
		_q_tenant_quality(),   # max 25
		_q_satisfaction(),     # max 15
		_q_visitor_volume(),   # max 15
		_q_design(),           # max 20
		_q_accessibility(),    # max 15
		_q_loan(),             # max 10
	]
	var total: int = 0
	for f: int in factors:
		total += f
	return clampi(total, 0, 100)


func _q_tenant_quality() -> int:
	if _tenant_manager == null:
		return 0
	var active := 0
	var tier_sum: int = 0
	for t: TenantData in _tenant_manager.all_tenants:
		if t.is_active:
			active += 1
			tier_sum += t.tier
	if active == 0:
		return 0
	var avg := float(tier_sum) / float(active)
	return mini(int(avg * 5), 25)


func _q_satisfaction() -> int:
	if _visitor_manager == null:
		return 0
	var total := _visitor_manager.all_visitors.size()
	if total == 0:
		return 5
	var sat_sum: int = 0
	for v: VisitorData in _visitor_manager.all_visitors:
		sat_sum += v.satisfaction
	return mini(sat_sum / (total * 5), 15)


func _q_visitor_volume() -> int:
	if _visitor_manager == null:
		return 0
	return mini(_visitor_manager.all_visitors.size() / 4, 15)


func _q_design() -> int:
	if _zone_manager == null:
		return 0
	var zones := _zone_manager.zones.size()
	return mini(zones * 3, 20)


func _q_accessibility() -> int:
	return 10  # Placeholder: floor connectivity score (stairs, elevators) — Post-MVP.


func _q_loan() -> int:
	if loan_default_multiplier >= 1.0:
		return 10
	return mini(int(10.0 * loan_default_multiplier), 10)


func _determine_level(p: int) -> MallLevel:
	for i in range(LEVEL_THRESHOLDS.size() - 1, -1, -1):
		if p >= LEVEL_THRESHOLDS[i]:
			return i as MallLevel
	return MallLevel.LOCAL_SHOPPING


func serialize() -> Dictionary:
	return {"prestige": prestige, "scale": scale, "quality": quality, "tech_points": tech_points,
		"loan_multiplier": loan_default_multiplier}


func deserialize(data: Dictionary) -> void:
	prestige = data.get("prestige", 0); scale = data.get("scale", 0)
	quality = data.get("quality", 0); tech_points = data.get("tech_points", 0)
	loan_default_multiplier = data.get("loan_multiplier", 1.0)
	current_level = _determine_level(prestige)
