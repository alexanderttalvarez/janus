class_name EconomyPolicySnapshot
extends RefCounted

## Immutable H2 price-policy value object. It is configured exactly once from
## complete approved content and only exposes detached copies.

const SCHEMA_VERSION: int = 1
const POLICY_REVISION: int = 1
const MAX_TRANSACTION_VALUE: int = 9_007_199_254_740_991
const APPROVED_FLOOR_TILE_COSTS: Dictionary = {
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

var _revision: int = 0
var _plot_section_cost_per_tile: int = 0
var _street_corridor_cost_per_tile: int = 0
var _demolition_cost: int = 0
var _floor_tile_costs: Dictionary = {}
var _configured: bool = false


static func approved_values() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"revision": POLICY_REVISION,
		"plot_section_cost_per_tile": 1000,
		"street_corridor_cost_per_tile": 3000,
		"demolition_cost": 20,
		"floor_tile_costs": APPROVED_FLOOR_TILE_COSTS.duplicate(true),
	}


func configure(values: Dictionary) -> Dictionary:
	if _configured:
		return _failure("ECONOMY_POLICY_SEALED", "Economy policy is already configured")
	var validation: Dictionary = validate_values(values)
	if not bool(validation.get("valid", false)):
		return validation
	_revision = int(values["revision"])
	_plot_section_cost_per_tile = int(values["plot_section_cost_per_tile"])
	_street_corridor_cost_per_tile = int(values["street_corridor_cost_per_tile"])
	_demolition_cost = int(values["demolition_cost"])
	_floor_tile_costs = values["floor_tile_costs"].duplicate(true)
	_configured = true
	return {"valid": true, "diagnostics": []}


func validate_values(values: Dictionary) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var required_fields: Array[String] = [
		"schema_version",
		"revision",
		"plot_section_cost_per_tile",
		"street_corridor_cost_per_tile",
		"demolition_cost",
		"floor_tile_costs",
	]
	for field: String in required_fields:
		if not values.has(field):
			diagnostics.append(_diagnostic("ECONOMY_POLICY_FIELD_MISSING", field, "approved Economy policy field is required"))
	for field: Variant in values.keys():
		if not required_fields.has(String(field)):
			diagnostics.append(_diagnostic("ECONOMY_POLICY_FIELD_UNKNOWN", String(field), "unknown Economy policy field is forbidden"))
	if typeof(values.get("schema_version", null)) != TYPE_INT or int(values.get("schema_version", -1)) != SCHEMA_VERSION:
		diagnostics.append(_diagnostic("ECONOMY_POLICY_SCHEMA_INVALID", "schema_version", "Economy policy schema is unsupported"))
	if typeof(values.get("revision", null)) != TYPE_INT or int(values.get("revision", 0)) <= 0:
		diagnostics.append(_diagnostic("ECONOMY_POLICY_REVISION_INVALID", "revision", "Economy policy revision must be positive"))
	for field: String in ["plot_section_cost_per_tile", "street_corridor_cost_per_tile", "demolition_cost"]:
		if typeof(values.get(field, null)) != TYPE_INT or int(values.get(field, 0)) <= 0 or int(values.get(field, 0)) > MAX_TRANSACTION_VALUE:
			diagnostics.append(_diagnostic("ECONOMY_POLICY_VALUE_INVALID", field, "Economy policy costs must be positive safe integers"))
	var floor_costs: Variant = values.get("floor_tile_costs", null)
	if not floor_costs is Dictionary:
		diagnostics.append(_diagnostic("ECONOMY_POLICY_FLOOR_COSTS_INVALID", "floor_tile_costs", "floor costs must be an explicit table"))
	else:
		var expected_elevations: Array = APPROVED_FLOOR_TILE_COSTS.keys()
		if floor_costs.size() != expected_elevations.size():
			diagnostics.append(_diagnostic("ECONOMY_POLICY_FLOOR_COSTS_INCOMPLETE", "floor_tile_costs", "floor costs must cover exactly G, F1-F9, and U1-U5"))
		for elevation: int in expected_elevations:
			if not floor_costs.has(elevation) or typeof(floor_costs[elevation]) != TYPE_INT or int(floor_costs[elevation]) <= 0 or int(floor_costs[elevation]) > MAX_TRANSACTION_VALUE:
				diagnostics.append(_diagnostic("ECONOMY_POLICY_FLOOR_COST_INVALID", str(elevation), "floor cost is missing or invalid"))
	return {"valid": diagnostics.is_empty(), "diagnostics": diagnostics}


func is_ready() -> bool:
	return _configured


func get_revision() -> int:
	return _revision


func duplicate_value() -> Dictionary:
	if not _configured:
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"revision": _revision,
		"plot_section_cost_per_tile": _plot_section_cost_per_tile,
		"street_corridor_cost_per_tile": _street_corridor_cost_per_tile,
		"demolition_cost": _demolition_cost,
		"floor_tile_costs": _floor_tile_costs.duplicate(true),
	}


func quote(category: String, intent: Dictionary) -> Dictionary:
	if not _configured:
		return _failure("POLICY_UNAVAILABLE", "Economy policy has not been configured")
	match category:
		"PLOT_SECTION":
			return _multiply_quote(category, intent.get("section_tile_count", null), _plot_section_cost_per_tile)
		"VERTICAL_SPACE":
			var elevation_value: Variant = intent.get("elevation", null)
			if typeof(elevation_value) != TYPE_INT or not _floor_tile_costs.has(int(elevation_value)):
				return _failure("POLICY_INPUT_INVALID", "vertical-space quote requires an approved signed elevation")
			return _multiply_quote(category, intent.get("tile_count", null), int(_floor_tile_costs[int(elevation_value)]))
		"STREET_CONVERSION":
			return _multiply_quote(category, intent.get("street_corridor_tile_count", null), _street_corridor_cost_per_tile)
		"FIXED_DEMOLITION":
			return _quote_result(category, _demolition_cost)
		"NO_CHARGE":
			return _quote_result(category, 0)
		_:
			return _failure("POLICY_UNAVAILABLE", "no approved Economy policy exists for charge category %s" % category)


func _multiply_quote(category: String, count_value: Variant, unit_cost: int) -> Dictionary:
	if typeof(count_value) != TYPE_INT or int(count_value) <= 0:
		return _failure("POLICY_INPUT_INVALID", "Economy quote requires a positive integer quantity")
	var count: int = int(count_value)
	if count > MAX_TRANSACTION_VALUE / unit_cost:
		return _failure("POLICY_VALUE_OVERFLOW", "Economy quote exceeds the supported integer domain")
	return _quote_result(category, count * unit_cost)


func _quote_result(category: String, value: int) -> Dictionary:
	return {
		"accepted": true,
		"value": value,
		"charge_category": category,
		"economy_policy_revision": _revision,
		"diagnostics": [],
	}


func _diagnostic(code: String, field: String, message: String) -> Dictionary:
	return {"code": code, "path": "$.economy.%s" % field, "message": message}


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "accepted": false, "diagnostics": [_diagnostic(code, "policy", message)]}
