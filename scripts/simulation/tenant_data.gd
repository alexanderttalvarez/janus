## TenantData — All state for a single tenant business.
## Tenants have a lifecycle: vacant → applying → exclusivity_lock → constructing → operating → critical → closing → closed.
class_name TenantData
extends RefCounted


## Tenant tiers (brand prestige).
enum Tier { BASIC = 1, STANDARD = 2, PREMIUM = 3, LUXURY = 4, EXCLUSIVE = 5 }

## Tenant states matching the state machine architecture.
enum TenantState { VACANT, APPLYING, EXCLUSIVITY_LOCK, CONSTRUCTING, OPERATING, CRITICAL, CLOSING, CLOSED }


## Unique identifier.
var id: String = ""

## Tenant tier (1-5).
var tier: Tier = Tier.BASIC

## Tenant display name.
var name: String = ""

## Zone ID this tenant occupies.
var zone_id: String = ""

## Parcel ID within the zone.
var parcel_id: String = ""

## Current state.
var current_state: TenantState = TenantState.VACANT

## Monthly revenue generated.
var monthly_revenue: int = 0

## Monthly rent paid.
var monthly_rent: int = 0

## Construction progress (0.0 - 1.0).
var construction_progress: float = 0.0

## Sim day when construction completes.
var construction_end_day: int = 0

## Viability check state: consecutive failing periods.
var viability_fail_count: int = 0

## Maximum grace periods before forced closure.
const MAX_GRACE_PERIODS: int = 3

## Whether this tenant is currently active.
var is_active: bool = false


## Initialize a new tenant.
func initialize(p_id: String, p_zone_id: String, p_parcel_id: String, p_tier: Tier = Tier.BASIC) -> void:
	id = p_id
	zone_id = p_zone_id
	parcel_id = p_parcel_id
	tier = p_tier
	name = _generate_name()
	current_state = TenantState.APPLYING


## Start construction phase.
func start_construction(sim_day: int, tile_count: int) -> void:
	current_state = TenantState.CONSTRUCTING
	construction_progress = 0.0
	# Duration: 0.3 sim weeks × tile count → in sim days.
	var duration: float = 0.3 * 7.0 * float(tile_count)
	construction_end_day = sim_day + int(duration)


## Update construction progress based on current sim day.
func update_construction(sim_day: int) -> void:
	if current_state != TenantState.CONSTRUCTING:
		return
	if construction_end_day <= 0:
		return
	var total := float(construction_end_day - (construction_end_day - int(0.3 * 7.0)))
	# Simple linear progress.
	var remaining := float(construction_end_day - sim_day)
	if remaining <= 0:
		construction_progress = 1.0
		current_state = TenantState.OPERATING
		is_active = true
	else:
		construction_progress = 1.0 - (remaining / (0.3 * 7.0 * 4.0))  # Approximate.
		construction_progress = clampf(construction_progress, 0.0, 1.0)


## Check viability (revenue vs rent + 20% margin).
func check_viability() -> bool:
	var margin := int(float(monthly_rent) * 0.2)
	if monthly_revenue < monthly_rent + margin:
		viability_fail_count += 1
		if viability_fail_count >= MAX_GRACE_PERIODS:
			current_state = TenantState.CLOSING
			is_active = false
			return false
		current_state = TenantState.CRITICAL
		return false
	viability_fail_count = 0
	current_state = TenantState.OPERATING
	return true


func _generate_name() -> String:
	var prefixes := ["Apex", "Urban", "Metro", "Zen", "Cloud", "Peak", "Vista", "Luxe", "Nova", "Atlas"]
	var suffixes := ["Goods", "Market", "Shops", "Retail", "Store", "Boutique", "Galleria", "Trading"]
	return "%s %s" % [prefixes[randi() % prefixes.size()], suffixes[randi() % suffixes.size()]]
