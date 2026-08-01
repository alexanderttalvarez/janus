## TenantManager — Lifecycle management, application evaluation, viability tracking.
## Tenants apply to vacant zones, construct, operate, and may close.
## Wired to TimeManager for daily evaluation and EconomyManager for rent.
class_name TenantManager
extends Node


## All tenants, active or closed.
var all_tenants: Array[TenantData] = []

## Tenant ID counter.
var _tenant_counter: int = 0

## Reference to ZoneManager for zone queries.
var _zone_manager: ZoneManager


func _ready() -> void:
	pass  # Initialized by main_game.


## Set reference to ZoneManager (wire after scene loads).
func initialize(zone_manager: ZoneManager) -> void:
	_zone_manager = zone_manager


# ── Application System ─────────────────────────────────────────────────

## Called on sim_day_passed to evaluate vacant zones and construction progress.
func on_sim_day_passed(sim_day: int) -> void:
	_evaluate_vacant_zones()
	_update_construction(sim_day)
	_check_viability()


## Evaluate all vacant zones and potentially generate a tenant application.
func _evaluate_vacant_zones() -> void:
	if _zone_manager == null:
		return
	for zone_id: String in _zone_manager.zones:
		var zone: ZoneData = _zone_manager.zones[zone_id]
		if zone.parcels.is_empty():
			continue
		for parcel: Parcel in zone.parcels:
			if not parcel.has_tenant and randi() % 3 == 0:  # ~33% chance per day.
				_generate_application(zone, parcel)


## Generate a tenant application for a parcel.
func _generate_application(zone: ZoneData, parcel: Parcel) -> void:
	var tenant := TenantData.new()
	var tier := _calculate_tenant_tier()
	tenant.initialize(_next_id(), zone.id, parcel.id, tier)

	# Calculate application score.
	var score := _calculate_application_score(tenant, zone, parcel)
	if score >= 50:  # Threshold for acceptance.
		parcel.has_tenant = true
		parcel.tenant_id = tenant.id
		tenant.current_state = TenantData.TenantState.EXCLUSIVITY_LOCK
		all_tenants.append(tenant)
		EventBus.tenant_applied.emit(zone.id, tenant.id, tier)


## Calculate what tier of tenant the district supports.
func _calculate_tenant_tier() -> TenantData.Tier:
	var r := randi() % 10
	if r < 4:
		return TenantData.Tier.BASIC
	if r < 7:
		return TenantData.Tier.STANDARD
	if r < 9:
		return TenantData.Tier.PREMIUM
	return TenantData.Tier.LUXURY


## Calculate application score (simplified MVP version).
func _calculate_application_score(tenant: TenantData, zone: ZoneData, _parcel: Parcel) -> int:
	var score: int = 50  # Base.

	# Tier bonus.
	score += int(tenant.tier) * 5

	# Zone type match bonus.
	if zone.type == ZoneData.ZONE_TYPE_NAMES[ZoneData.ZoneType.RETAIL]:
		score += 10
	elif zone.type == ZoneData.ZONE_TYPE_NAMES[ZoneData.ZoneType.FOOD_BEVERAGE]:
		score += 5

	# Tile count bonus (bigger = better).
	score += mini(zone.tiles.size(), 20)

	return score


# ── Construction ───────────────────────────────────────────────────────

## Update construction progress for all constructing tenants.
func _update_construction(sim_day: int) -> void:
	for t: TenantData in all_tenants:
		if t.current_state == TenantData.TenantState.EXCLUSIVITY_LOCK:
			# Start construction after 1-week exclusivity.
			t.start_construction(sim_day, 4)  # Assume 4 tiles per parcel.
			EventBus.tenant_construction_started.emit(t.zone_id, t.id)
		elif t.current_state == TenantData.TenantState.CONSTRUCTING:
			var prev_progress := t.construction_progress
			t.update_construction(sim_day)
			if t.current_state == TenantData.TenantState.OPERATING and prev_progress < 0.99:
				EventBus.tenant_opened.emit(t.zone_id, t.id)


# ── Viability ──────────────────────────────────────────────────────────

## Check viability for all operating tenants.
func _check_viability() -> void:
	for t: TenantData in all_tenants:
		if t.current_state == TenantData.TenantState.OPERATING or t.current_state == TenantData.TenantState.CRITICAL:
			# Simulate revenue based on tier.
			t.monthly_revenue = int(t.tier) * randi_range(80, 150)
			t.monthly_rent = int(t.tier) * 100 + randi_range(-20, 20)

			var viable := t.check_viability()
			if not viable:
				EventBus.tenant_viability_changed.emit(t.id, "Closing" if t.current_state == TenantData.TenantState.CLOSING else "Critical")
				if t.current_state == TenantData.TenantState.CLOSING:
					_close_tenant(t)


## Close a tenant (eviction + cleanup).
func _close_tenant(tenant: TenantData) -> void:
	tenant.current_state = TenantData.TenantState.CLOSED
	tenant.is_active = false

	# Clear the parcel.
	if _zone_manager:
		var zone: ZoneData = _zone_manager.zones.get(tenant.zone_id, null)
		if zone:
			for parcel: Parcel in zone.parcels:
				if parcel.tenant_id == tenant.id:
					parcel.has_tenant = false
					parcel.tenant_id = ""

	EventBus.tenant_closed.emit(tenant.zone_id, tenant.id)


# ── Serialization ──────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var data: Array[Dictionary] = []
	for t: TenantData in all_tenants:
		data.append({
			"id": t.id, "tier": t.tier, "name": t.name,
			"zone_id": t.zone_id, "parcel_id": t.parcel_id,
			"current_state": t.current_state, "is_active": t.is_active,
			"construction_progress": t.construction_progress,
		})
	return {"tenants": data, "counter": _tenant_counter}


func deserialize(data: Dictionary) -> void:
	all_tenants.clear()
	_tenant_counter = data.get("counter", 0)
	for td: Dictionary in data.get("tenants", []):
		var t := TenantData.new()
		t.id = td["id"]; t.tier = td["tier"]; t.name = td.get("name", "")
		t.zone_id = td.get("zone_id", ""); t.parcel_id = td.get("parcel_id", "")
		t.current_state = td.get("current_state", 0); t.is_active = td.get("is_active", false)
		t.construction_progress = td.get("construction_progress", 0.0)
		all_tenants.append(t)


func _next_id() -> String:
	_tenant_counter += 1
	return "tenant_%d" % _tenant_counter
