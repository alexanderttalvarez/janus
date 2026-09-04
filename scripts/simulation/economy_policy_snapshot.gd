class_name EconomyPolicySnapshot
extends RefCounted

## Immutable H2 price-policy value object consumed by Economy quotes.
## Callers receive detached dictionaries and cannot mutate this instance through
## the public API.

const SCHEMA_VERSION: int = 1
const DEFAULT_PLOT_SECTION_COST_PER_TILE: int = 1000
const DEFAULT_STREET_CORRIDOR_COST_PER_TILE: int = 3000
const DEFAULT_DEMOLITION_COST: int = 20

var revision: int = 1
var plot_section_cost_per_tile: int = DEFAULT_PLOT_SECTION_COST_PER_TILE
var street_corridor_cost_per_tile: int = DEFAULT_STREET_CORRIDOR_COST_PER_TILE
var demolition_cost: int = DEFAULT_DEMOLITION_COST
var floor_tile_costs: Dictionary = {}


func _init() -> void:
	floor_tile_costs = {
		0: 1000,
		1: 1200,
		2: 1400,
		3: 1600,
		4: 1800,
		5: 2000,
		6: 2200,
		7: 2400,
		8: 2600,
		9: 2800,
		-1: 1200,
		-2: 1400,
		-3: 1600,
		-4: 1800,
		-5: 2000,
	}


func initialize(policy_revision: int, values: Dictionary = {}) -> void:
	revision = policy_revision
	plot_section_cost_per_tile = int(values.get("plot_section_cost_per_tile", DEFAULT_PLOT_SECTION_COST_PER_TILE))
	street_corridor_cost_per_tile = int(values.get("street_corridor_cost_per_tile", DEFAULT_STREET_CORRIDOR_COST_PER_TILE))
	demolition_cost = int(values.get("demolition_cost", DEFAULT_DEMOLITION_COST))
	var configured_floor_costs: Variant = values.get("floor_tile_costs", floor_tile_costs)
	if configured_floor_costs is Dictionary:
		floor_tile_costs = configured_floor_costs.duplicate(true)


func duplicate_value() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"revision": revision,
		"plot_section_cost_per_tile": plot_section_cost_per_tile,
		"street_corridor_cost_per_tile": street_corridor_cost_per_tile,
		"demolition_cost": demolition_cost,
		"floor_tile_costs": floor_tile_costs.duplicate(true),
	}


func quote(category: String, intent: Dictionary) -> Dictionary:
	var value: int = -1
	match category:
		"PLOT_SECTION":
			var section_tile_count: int = int(intent.get("section_tile_count", 0))
			if section_tile_count <= 0:
				return _failure("POLICY_INPUT_INVALID", "Plot Section quote requires a positive complete section tile count")
			value = section_tile_count * plot_section_cost_per_tile
		"VERTICAL_SPACE":
			var elevation: int = int(intent.get("elevation", 999))
			var tile_count: int = int(intent.get("tile_count", 0))
			if tile_count <= 0 or not floor_tile_costs.has(elevation):
				return _failure("POLICY_INPUT_INVALID", "vertical-space quote requires an approved elevation and positive tile count")
			value = tile_count * int(floor_tile_costs[elevation])
		"STREET_CONVERSION":
			var corridor_tile_count: int = int(intent.get("street_corridor_tile_count", 0))
			if corridor_tile_count <= 0:
				return _failure("POLICY_INPUT_INVALID", "Street Segment quote requires the complete corridor tile count")
			value = corridor_tile_count * street_corridor_cost_per_tile
		"FIXED_DEMOLITION":
			value = demolition_cost
		"NO_CHARGE":
			value = 0
		_:
			return _failure("POLICY_UNAVAILABLE", "no approved economy policy exists for charge category %s" % category)
	return {"accepted": true, "value": value, "charge_category": category, "economy_policy_revision": revision, "diagnostics": []}


func _failure(code: String, message: String) -> Dictionary:
	return {"accepted": false, "diagnostics": [{"code": code, "message": message}]}
