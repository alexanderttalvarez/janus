class_name DistrictLayoutValidator
extends RefCounted

## H1 validator for normalized district-layout definition records.
## The validator is pure: it never reads the scene tree, filesystem, clock, or RNG.

const MAX_SAFE_INTEGER: int = 9007199254740991
const MIN_SAFE_INTEGER: int = -9007199254740991
const REQUIRED_ROOT_KEYS: Array[String] = [
	"definition_schema_version",
	"layout_definition_version",
	"canonical_schema_version",
	"resolver_schema_version",
	"layout",
	"template_catalog",
	"variant_catalog",
	"fixed_block_catalog",
	"road_profile_catalog",
]
const REQUIRED_LAYOUT_KEYS: Array[String] = [
	"layout_id",
	"physical_elevation_range",
	"row_tracks",
	"column_tracks",
	"horizontal_boundaries",
	"vertical_boundaries",
	"slots",
	"outer_ring",
	"arrival_sources",
]
const ROLES: Array[String] = ["PLOT", "DECORATIVE_FIXED", "PARK", "PUBLIC_PLAZA", "UNAVAILABLE"]
const SOURCE_MODES: Array[String] = ["PEDESTRIAN"]
const DIRECTIONS: Array[String] = ["FORWARD", "REVERSE"]


func normalize_and_validate(input: Variant) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var normalized: Variant = _normalize_value(input, "$", diagnostics)
	if diagnostics.is_empty():
		_validate_root(normalized, diagnostics)
	return {
		"valid": diagnostics.is_empty(),
		"record": normalized if normalized is Dictionary else {},
		"diagnostics": diagnostics,
	}


func _normalize_value(value: Variant, path: String, diagnostics: Array[Dictionary]) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL:
			return value
		TYPE_INT:
			var integer_value: int = int(value)
			if integer_value < MIN_SAFE_INTEGER or integer_value > MAX_SAFE_INTEGER:
				_add(diagnostics, "INTEGER_OUT_OF_RANGE", path, "semantic integer exceeds the I-JSON safe range")
			return integer_value
		TYPE_FLOAT:
			_add(diagnostics, "FLOAT_FORBIDDEN", path, "semantic values cannot contain floating-point numbers")
			return null
		TYPE_STRING:
			return _normalize_nfc(String(value))
		TYPE_ARRAY:
			var normalized_array: Array = []
			for index: int in range(value.size()):
				normalized_array.append(_normalize_value(value[index], "%s[%d]" % [path, index], diagnostics))
			return normalized_array
		TYPE_DICTIONARY:
			var normalized_dictionary: Dictionary = {}
			for raw_key: Variant in value.keys():
				if typeof(raw_key) != TYPE_STRING:
					_add(diagnostics, "KEY_NOT_STRING", path, "semantic object keys must be strings")
					continue
				var key: String = _normalize_nfc(String(raw_key))
				if normalized_dictionary.has(key):
					_add(diagnostics, "DUPLICATE_KEY", path, "normalized object keys must be unique")
				else:
					normalized_dictionary[key] = _normalize_value(value[raw_key], "%s.%s" % [path, key], diagnostics)
			return normalized_dictionary
		_:
			_add(diagnostics, "UNSUPPORTED_VALUE", path, "semantic values must be integer, string, boolean, null, array, or object")
			return null


func _normalize_nfc(value: String) -> String:
	# Godot stores valid Unicode strings, but does not expose a portable NFC API
	# across the supported 4.x versions. Compose the Unicode combining marks used
	# by authored IDs and labels; already-composed code points pass through intact.
	var codepoints: Array[int] = []
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if _is_combining_mark(codepoint) and not codepoints.is_empty():
			var composed: int = _compose_pair(codepoints[codepoints.size() - 1], codepoint)
			if composed != -1:
				codepoints[codepoints.size() - 1] = composed
				continue
		codepoints.append(codepoint)
	var result: String = ""
	for codepoint: int in codepoints:
		result += String.chr(codepoint)
	return result


func _is_combining_mark(codepoint: int) -> bool:
	return codepoint == 0x0300 or codepoint == 0x0301 or codepoint == 0x0302 or codepoint == 0x0303 or codepoint == 0x0308 or codepoint == 0x0327


func _compose_pair(base: int, mark: int) -> int:
	var composed: Dictionary = {
		"65:768": 0x00C0, "65:769": 0x00C1, "65:770": 0x00C2, "65:771": 0x00C3, "65:776": 0x00C4, "65:807": 0x00C7,
		"69:768": 0x00C8, "69:769": 0x00C9, "69:770": 0x00CA, "69:776": 0x00CB,
		"73:768": 0x00CC, "73:769": 0x00CD, "73:770": 0x00CE, "73:776": 0x00CF,
		"78:771": 0x00D1, "79:768": 0x00D2, "79:769": 0x00D3, "79:770": 0x00D4, "79:771": 0x00D5, "79:776": 0x00D6,
		"85:768": 0x00D9, "85:769": 0x00DA, "85:770": 0x00DB, "85:776": 0x00DC,
		"97:768": 0x00E0, "97:769": 0x00E1, "97:770": 0x00E2, "97:771": 0x00E3, "97:776": 0x00E4, "97:807": 0x00E7,
		"101:768": 0x00E8, "101:769": 0x00E9, "101:770": 0x00EA, "101:776": 0x00EB,
		"105:768": 0x00EC, "105:769": 0x00ED, "105:770": 0x00EE, "105:776": 0x00EF,
		"110:771": 0x00F1, "111:768": 0x00F2, "111:769": 0x00F3, "111:770": 0x00F4, "111:771": 0x00F5, "111:776": 0x00F6,
		"117:768": 0x00F9, "117:769": 0x00FA, "117:770": 0x00FB, "117:776": 0x00FC,
	}
	return int(composed.get("%d:%d" % [base, mark], -1))


func _validate_root(value: Variant, diagnostics: Array[Dictionary]) -> void:
	if not value is Dictionary:
		_add(diagnostics, "ROOT_NOT_OBJECT", "$", "definition root must be an object")
		return
	var root: Dictionary = value
	_require_keys(root, REQUIRED_ROOT_KEYS, "$", diagnostics)
	_reject_unknown_keys(root, REQUIRED_ROOT_KEYS, "$", diagnostics)
	for key: String in ["definition_schema_version", "layout_definition_version", "canonical_schema_version", "resolver_schema_version"]:
		_require_int(root, key, "$", diagnostics)
	_validate_layout(root.get("layout", null), diagnostics)
	_validate_catalogs(root, diagnostics)
	if root.get("layout", null) is Dictionary:
		_validate_slot_bindings(root["layout"], root.get("variant_catalog", []), diagnostics)


func _validate_layout(value: Variant, diagnostics: Array[Dictionary]) -> void:
	if not value is Dictionary:
		_add(diagnostics, "LAYOUT_NOT_OBJECT", "$.layout", "layout must be an object")
		return
	var layout: Dictionary = value
	_require_keys(layout, REQUIRED_LAYOUT_KEYS, "$.layout", diagnostics)
	_reject_unknown_keys(layout, REQUIRED_LAYOUT_KEYS, "$.layout", diagnostics)
	_require_string(layout, "layout_id", "$.layout", diagnostics)
	_validate_range(layout.get("physical_elevation_range", null), "$.layout.physical_elevation_range", diagnostics, -5, 9)
	_validate_tracks(layout.get("row_tracks", null), "row", "$.layout.row_tracks", diagnostics)
	_validate_tracks(layout.get("column_tracks", null), "col", "$.layout.column_tracks", diagnostics)
	_validate_boundaries(layout.get("horizontal_boundaries", null), "h", "$.layout.horizontal_boundaries", diagnostics)
	_validate_boundaries(layout.get("vertical_boundaries", null), "v", "$.layout.vertical_boundaries", diagnostics)
	_validate_slots(layout, diagnostics)
	_validate_outer_ring(layout.get("outer_ring", null), diagnostics)
	_validate_sources(layout.get("arrival_sources", null), diagnostics)


func _validate_tracks(value: Variant, prefix: String, path: String, diagnostics: Array[Dictionary]) -> void:
	if not value is Array or value.is_empty():
		_add(diagnostics, "TRACKS_INVALID", path, "tracks must be a non-empty array")
		return
	var ids: Dictionary = {}
	for index: int in range(value.size()):
		var track: Variant = value[index]
		if not track is Dictionary:
			_add(diagnostics, "TRACK_INVALID", "%s[%d]" % [path, index], "track must be an object")
			continue
		var track_path: String = "%s[%d]" % [path, index]
		_require_keys(track, ["track_id", "ordinal", "size"], track_path, diagnostics)
		_require_string(track, "track_id", track_path, diagnostics)
		_require_int(track, "ordinal", track_path, diagnostics)
		_require_int(track, "size", track_path, diagnostics)
		if int(track.get("ordinal", -1)) != index:
			_add(diagnostics, "ORDINAL_MISMATCH", track_path, "track ordinal must match authored position")
		if int(track.get("size", 0)) < 18:
			_add(diagnostics, "TRACK_SIZE_INVALID", track_path, "row and column tracks must be at least 18 tiles")
		var track_id: String = String(track.get("track_id", ""))
		if ids.has(track_id):
			_add(diagnostics, "DUPLICATE_ID", track_path, "track IDs must be unique")
		ids[track_id] = true
		if track_id != "%s_%d" % [prefix, index]:
			_add(diagnostics, "TRACK_ID_INVALID", track_path, "proof and authored track IDs must use their stable ID, not position inference")


func _validate_boundaries(value: Variant, prefix: String, path: String, diagnostics: Array[Dictionary]) -> void:
	if not value is Array or value.is_empty():
		_add(diagnostics, "BOUNDARIES_INVALID", path, "boundaries must be a non-empty array")
		return
	var ids: Dictionary = {}
	for index: int in range(value.size()):
		var boundary: Variant = value[index]
		var boundary_path: String = "%s[%d]" % [path, index]
		if not boundary is Dictionary:
			_add(diagnostics, "BOUNDARY_INVALID", boundary_path, "boundary must be an object")
			continue
		_require_keys(boundary, ["boundary_id", "ordinal"], boundary_path, diagnostics)
		_require_string(boundary, "boundary_id", boundary_path, diagnostics)
		_require_int(boundary, "ordinal", boundary_path, diagnostics)
		if int(boundary.get("ordinal", -1)) != index:
			_add(diagnostics, "ORDINAL_MISMATCH", boundary_path, "boundary ordinal must match authored position")
		var boundary_id: String = String(boundary.get("boundary_id", ""))
		if ids.has(boundary_id):
			_add(diagnostics, "DUPLICATE_ID", boundary_path, "boundary IDs must be unique")
		ids[boundary_id] = true
		if boundary_id != "%s%d" % [prefix, index]:
			_add(diagnostics, "BOUNDARY_ID_INVALID", boundary_path, "boundary IDs must be authored as h0/v0/... in the proof contract")


func _validate_slots(layout: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var slots: Variant = layout.get("slots", null)
	var rows: Array = layout.get("row_tracks", [])
	var columns: Array = layout.get("column_tracks", [])
	if not slots is Array or slots.is_empty():
		_add(diagnostics, "SLOTS_INVALID", "$.layout.slots", "slots must be a non-empty array")
		return
	var ids: Dictionary = {}
	for index: int in range(slots.size()):
		var slot: Variant = slots[index]
		var path: String = "$.layout.slots[%d]" % index
		if not slot is Dictionary:
			_add(diagnostics, "SLOT_INVALID", path, "slot must be an object")
			continue
		_require_keys(slot, ["slot_id", "ordinal", "row_track_id", "column_track_id", "role", "template_id", "selected_variant_id", "fixed_block_definition_id", "sections", "buildability_mask", "fixed_occupants", "physical_elevation_cap_override"], path, diagnostics)
		_require_string(slot, "slot_id", path, diagnostics)
		_require_int(slot, "ordinal", path, diagnostics)
		_require_string(slot, "row_track_id", path, diagnostics)
		_require_string(slot, "column_track_id", path, diagnostics)
		_require_string(slot, "role", path, diagnostics)
		if int(slot.get("ordinal", -1)) != index:
			_add(diagnostics, "ORDINAL_MISMATCH", path, "slot ordinal must match authored row-major order")
		if not ROLES.has(String(slot.get("role", ""))):
			_add(diagnostics, "ROLE_INVALID", path, "unsupported slot role")
		var row_id: String = String(slot.get("row_track_id", ""))
		var column_id: String = String(slot.get("column_track_id", ""))
		if not _contains_id(rows, "track_id", row_id) or not _contains_id(columns, "track_id", column_id):
			_add(diagnostics, "TRACK_REFERENCE_INVALID", path, "slot references an unknown track")
		if ids.has(String(slot.get("slot_id", ""))):
			_add(diagnostics, "DUPLICATE_ID", path, "slot IDs must be unique")
		ids[String(slot.get("slot_id", ""))] = true
		_validate_slot_layers(slot, path, diagnostics, _track_size(columns, column_id), _track_size(rows, row_id))
		_validate_cap(slot.get("physical_elevation_cap_override", null), "%s.physical_elevation_cap_override" % path, diagnostics)


func _validate_slot_layers(slot: Dictionary, path: String, diagnostics: Array[Dictionary], width: int, depth: int) -> void:
	var role: String = String(slot.get("role", ""))
	var sections: Variant = slot.get("sections", null)
	var buildability: Variant = slot.get("buildability_mask", null)
	var occupants: Variant = slot.get("fixed_occupants", null)
	if not sections is Array or not buildability is Array or not occupants is Array:
		_add(diagnostics, "LAYER_INVALID", path, "sections, buildability_mask, and fixed_occupants must be arrays")
		return
	if role != "PLOT":
		if not sections.is_empty() or not buildability.is_empty():
			_add(diagnostics, "NON_PLOT_BUILDABILITY", path, "non-Plot slots must have empty sections and buildability")
		return
	var seen: Dictionary = {}
	var union: Dictionary = {}
	for index: int in range(sections.size()):
		var section: Variant = sections[index]
		var section_path: String = "%s.sections[%d]" % [path, index]
		if not section is Dictionary:
			_add(diagnostics, "SECTION_INVALID", section_path, "section must be an object")
			continue
		_require_keys(section, ["section_id", "section_role", "ordinal", "mask", "initially_owned", "initially_available", "initially_entry_eligible"], section_path, diagnostics)
		_require_string(section, "section_id", section_path, diagnostics)
		_require_string(section, "section_role", section_path, diagnostics)
		_require_int(section, "ordinal", section_path, diagnostics)
		if int(section.get("ordinal", -1)) != index:
			_add(diagnostics, "ORDINAL_MISMATCH", section_path, "section ordinal must match the authored slot order")
		_validate_bool(section, "initially_owned", section_path, diagnostics)
		_validate_bool(section, "initially_available", section_path, diagnostics)
		_validate_bool(section, "initially_entry_eligible", section_path, diagnostics)
		var section_id: String = String(section.get("section_id", ""))
		if seen.has(section_id):
			_add(diagnostics, "DUPLICATE_ID", section_path, "section IDs must be unique within a slot")
		seen[section_id] = true
		var mask_result: Dictionary = _validate_mask(section.get("mask", null), "%s.mask" % section_path, slot, diagnostics, width, depth)
		for cell: Array in mask_result.get("cells", []):
			var cell_key: String = _cell_key(cell)
			if union.has(cell_key):
				_add(diagnostics, "SECTION_OVERLAP", section_path, "section masks may not overlap")
			union[cell_key] = cell
	var expected: Array = _sorted_cells_from_dictionary(union)
	var build_result: Dictionary = _validate_mask(buildability, "%s.buildability_mask" % path, slot, diagnostics, width, depth)
	if expected != build_result.get("cells", []):
		_add(diagnostics, "BUILDABILITY_MISMATCH", path, "PLOT buildability must equal the union of section masks")
	_validate_occupants(occupants, "%s.fixed_occupants" % path, slot, diagnostics, width, depth)


func _validate_occupants(value: Array, path: String, slot: Dictionary, diagnostics: Array[Dictionary], width: int, depth: int) -> void:
	var ids: Dictionary = {}
	for index: int in range(value.size()):
		var occupant: Variant = value[index]
		var occupant_path: String = "%s[%d]" % [path, index]
		if not occupant is Dictionary:
			_add(diagnostics, "OCCUPANT_INVALID", occupant_path, "occupant must be an object")
			continue
		_require_keys(occupant, ["occupant_id", "ordinal", "elevation_masks"], occupant_path, diagnostics)
		_require_string(occupant, "occupant_id", occupant_path, diagnostics)
		_require_int(occupant, "ordinal", occupant_path, diagnostics)
		if int(occupant.get("ordinal", -1)) != index:
			_add(diagnostics, "ORDINAL_MISMATCH", occupant_path, "occupant ordinal must match authored position")
		var occupant_id: String = String(occupant.get("occupant_id", ""))
		if ids.has(occupant_id):
			_add(diagnostics, "DUPLICATE_ID", occupant_path, "occupant IDs must be unique within a slot")
		ids[occupant_id] = true
		var masks: Variant = occupant.get("elevation_masks", null)
		if not masks is Array:
			_add(diagnostics, "ELEVATION_MASKS_INVALID", occupant_path, "elevation_masks must be an array")
			continue
		var prior_elevation: int = -100
		for elevation_index: int in range(masks.size()):
			var elevation_mask: Variant = masks[elevation_index]
			var elevation_path: String = "%s.elevation_masks[%d]" % [occupant_path, elevation_index]
			if not elevation_mask is Dictionary:
				_add(diagnostics, "ELEVATION_MASK_INVALID", elevation_path, "elevation mask must be an object")
				continue
			_require_keys(elevation_mask, ["elevation", "mask"], elevation_path, diagnostics)
			_require_int(elevation_mask, "elevation", elevation_path, diagnostics)
			var elevation: int = int(elevation_mask.get("elevation", 0))
			if elevation <= prior_elevation:
				_add(diagnostics, "ELEVATION_ORDER_INVALID", elevation_path, "elevation masks must be strictly signed-ascending")
			prior_elevation = elevation
			_validate_mask(elevation_mask.get("mask", null), "%s.mask" % elevation_path, slot, diagnostics, width, depth)


func _validate_mask(value: Variant, path: String, slot: Dictionary, diagnostics: Array[Dictionary], expected_width: int = 0, expected_depth: int = 0) -> Dictionary:
	if not value is Array:
		_add(diagnostics, "MASK_INVALID", path, "mask must be an ordered array of [x,y] cells")
		return {"cells": []}
	var width: int = 0
	var depth: int = 0
	var row_id: String = String(slot.get("row_track_id", ""))
	var column_id: String = String(slot.get("column_track_id", ""))
	# Dimensions are resolved from the referenced authored tracks by the caller's
	# manifest builder; validation derives conservative bounds from cell maxima.
	for cell: Variant in value:
		if cell is Array and cell.size() == 2 and typeof(cell[0]) == TYPE_INT and typeof(cell[1]) == TYPE_INT:
			width = maxi(width, int(cell[0]) + 1)
			depth = maxi(depth, int(cell[1]) + 1)
	# The exact slot dimensions are validated by section/catalog equality tests;
	# this local pass enforces shape, ordering, uniqueness, and non-negative cells.
	var cells: Array = []
	var previous: Array = [-1, -1]
	var seen: Dictionary = {}
	for index: int in range(value.size()):
		var cell: Variant = value[index]
		if not cell is Array or cell.size() != 2 or typeof(cell[0]) != TYPE_INT or typeof(cell[1]) != TYPE_INT:
			_add(diagnostics, "CELL_INVALID", "%s[%d]" % [path, index], "cell must be [x,y] integer pair")
			continue
		var normalized_cell: Array = [int(cell[0]), int(cell[1])]
		if normalized_cell[0] < 0 or normalized_cell[1] < 0 or (expected_width > 0 and normalized_cell[0] >= expected_width) or (expected_depth > 0 and normalized_cell[1] >= expected_depth):
			_add(diagnostics, "CELL_OUT_OF_BOUNDS", "%s[%d]" % [path, index], "cell coordinates must be inside the owning slot or variant dimensions")
		var key: String = _cell_key(normalized_cell)
		if seen.has(key):
			_add(diagnostics, "DUPLICATE_CELL", "%s[%d]" % [path, index], "mask cells must be unique")
		seen[key] = true
		if index > 0 and (normalized_cell[1] < previous[1] or (normalized_cell[1] == previous[1] and normalized_cell[0] <= previous[0])):
			_add(diagnostics, "CELL_ORDER_INVALID", "%s[%d]" % [path, index], "mask cells must be row-major ascending by (y,x)")
		previous = normalized_cell
		cells.append(normalized_cell)
	if not cells.is_empty() and not _is_four_connected(cells):
		_add(diagnostics, "MASK_DISCONNECTED", path, "section and fixed-occupancy masks must be four-connected")
	return {"cells": cells, "width": width, "depth": depth, "row_id": row_id, "column_id": column_id}


func _validate_catalogs(root: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var layout: Dictionary = root.get("layout", {})
	var template_catalog: Variant = root.get("template_catalog", null)
	var variant_catalog: Variant = root.get("variant_catalog", null)
	var fixed_catalog: Variant = root.get("fixed_block_catalog", null)
	var road_catalog: Variant = root.get("road_profile_catalog", null)
	if not template_catalog is Array or not variant_catalog is Array or not fixed_catalog is Array or not road_catalog is Array:
		_add(diagnostics, "CATALOG_INVALID", "$.template_catalog", "all catalogs must be arrays")
		return
	var template_ids: Dictionary = _catalog_ids(template_catalog, "template_id", "$.template_catalog", diagnostics)
	var variant_ids: Dictionary = _catalog_ids(variant_catalog, "variant_id", "$.variant_catalog", diagnostics)
	_catalog_ids(fixed_catalog, "fixed_block_definition_id", "$.fixed_block_catalog", diagnostics)
	var road_ids: Dictionary = _catalog_ids(road_catalog, "road_profile_id", "$.road_profile_catalog", diagnostics)
	for index: int in range(template_catalog.size()):
		var template: Variant = template_catalog[index]
		var path: String = "$.template_catalog[%d]" % index
		if not template is Dictionary:
			continue
		_require_keys(template, ["template_id", "template_version", "physical_elevation_cap", "variant_ids"], path, diagnostics)
		_require_string(template, "template_id", path, diagnostics)
		_require_int(template, "template_version", path, diagnostics)
		_validate_cap(template.get("physical_elevation_cap", null), "%s.physical_elevation_cap" % path, diagnostics)
		if not template.get("variant_ids", null) is Array:
			_add(diagnostics, "VARIANT_IDS_INVALID", path, "variant_ids must be an array")
		for variant_id: Variant in template.get("variant_ids", []):
			if not variant_ids.has(String(variant_id)):
				_add(diagnostics, "REFERENCE_INVALID", path, "template references an unknown variant")
	for index: int in range(variant_catalog.size()):
		var variant: Variant = variant_catalog[index]
		var path: String = "$.variant_catalog[%d]" % index
		if not variant is Dictionary:
			continue
		_require_keys(variant, ["variant_id", "template_id", "template_version", "width", "depth", "section_mappings"], path, diagnostics)
		_require_string(variant, "variant_id", path, diagnostics)
		_require_string(variant, "template_id", path, diagnostics)
		_require_int(variant, "template_version", path, diagnostics)
		_require_int(variant, "width", path, diagnostics)
		_require_int(variant, "depth", path, diagnostics)
		if not template_ids.has(String(variant.get("template_id", ""))):
			_add(diagnostics, "REFERENCE_INVALID", path, "variant references an unknown template")
		_validate_mappings(variant.get("section_mappings", null), path, diagnostics, int(variant.get("width", 0)), int(variant.get("depth", 0)))
	for index: int in range(road_catalog.size()):
		_validate_road_profile(road_catalog[index], "$.road_profile_catalog[%d]" % index, diagnostics)
	for slot: Dictionary in layout.get("slots", []):
		var slot_path: String = "$.layout.slots[%d]" % int(slot.get("ordinal", 0))
		var template_id: Variant = slot.get("template_id", null)
		var variant_id: Variant = slot.get("selected_variant_id", null)
		if template_id != null and not template_ids.has(String(template_id)):
			_add(diagnostics, "REFERENCE_INVALID", slot_path, "slot references an unknown template")
		if variant_id != null and not variant_ids.has(String(variant_id)):
			_add(diagnostics, "REFERENCE_INVALID", slot_path, "slot references an unknown variant")
		if slot.get("role", "") == "PLOT" and (template_id == null or variant_id == null):
			_add(diagnostics, "PLOT_REFERENCE_MISSING", slot_path, "Plot slots require template and selected variant references")
		if variant_id != null:
			var selected_variant: Dictionary = _find_record(variant_catalog, "variant_id", String(variant_id))
			if not selected_variant.is_empty() and String(selected_variant.get("template_id", "")) != String(template_id):
				_add(diagnostics, "VARIANT_TEMPLATE_MISMATCH", slot_path, "selected variant must belong to the slot template")
			var slot_width: int = _track_size(layout.get("column_tracks", []), String(slot.get("column_track_id", "")))
			var slot_depth: int = _track_size(layout.get("row_tracks", []), String(slot.get("row_track_id", "")))
			if not selected_variant.is_empty() and (int(selected_variant.get("width", 0)) != slot_width or int(selected_variant.get("depth", 0)) != slot_depth):
				_add(diagnostics, "VARIANT_DIMENSION_MISMATCH", slot_path, "selected variant dimensions must match the referenced row and column tracks")
		var override_value: Variant = slot.get("physical_elevation_cap_override", null)
		if override_value != null:
			_validate_cap(override_value, "%s.physical_elevation_cap_override" % slot_path, diagnostics)
	var outer_ring: Dictionary = layout.get("outer_ring", {})
	if not road_ids.has(String(outer_ring.get("road_profile_id", ""))):
		_add(diagnostics, "REFERENCE_INVALID", "$.layout.outer_ring", "outer ring references an unknown road profile")


func _validate_slot_bindings(layout: Dictionary, variants: Array, diagnostics: Array[Dictionary]) -> void:
	for slot: Dictionary in layout.get("slots", []):
		if String(slot.get("role", "")) != "PLOT":
			continue
		var variant: Dictionary = _find_record(variants, "variant_id", String(slot.get("selected_variant_id", "")))
		if variant.is_empty():
			continue
		var sections: Array = slot.get("sections", [])
		var mappings: Array = variant.get("section_mappings", [])
		var slot_path: String = "$.layout.slots[%d]" % int(slot.get("ordinal", 0))
		if sections.size() != mappings.size():
			_add(diagnostics, "MAPPING_COUNT_MISMATCH", slot_path, "slot sections must match selected variant mapping count")
		for section: Dictionary in sections:
			var mapping: Dictionary = {}
			for candidate: Dictionary in mappings:
				if String(candidate.get("section_role", "")) == String(section.get("section_role", "")):
					mapping = candidate
					break
			if mapping.is_empty():
				_add(diagnostics, "SECTION_ROLE_UNBOUND", slot_path, "every slot section role must bind to the selected variant")
				continue
			if int(section.get("ordinal", -1)) != int(mapping.get("ordinal", -2)) or section.get("mask", []) != mapping.get("mask", []):
				_add(diagnostics, "SECTION_MAPPING_MISMATCH", slot_path, "slot section ordinal and mask must equal its selected variant mapping")


func _find_record(records: Array, key: String, expected: String) -> Dictionary:
	for record: Variant in records:
		if record is Dictionary and String(record.get(key, "")) == expected:
			return record
	return {}


func _track_size(records: Array, expected_id: String) -> int:
	for record: Variant in records:
		if record is Dictionary and String(record.get("track_id", "")) == expected_id:
			return int(record.get("size", 0))
	return 0


func _validate_mappings(value: Variant, path: String, diagnostics: Array[Dictionary], variant_width: int = 0, variant_depth: int = 0) -> void:
	if not value is Array or value.is_empty():
		_add(diagnostics, "MAPPINGS_INVALID", path, "variant section_mappings must be non-empty")
		return
	for index: int in range(value.size()):
		var mapping: Variant = value[index]
		var mapping_path: String = "%s.section_mappings[%d]" % [path, index]
		if not mapping is Dictionary:
			_add(diagnostics, "MAPPING_INVALID", mapping_path, "mapping must be an object")
			continue
		_require_keys(mapping, ["section_role", "ordinal", "mask"], mapping_path, diagnostics)
		_require_string(mapping, "section_role", mapping_path, diagnostics)
		_require_int(mapping, "ordinal", mapping_path, diagnostics)
		if int(mapping.get("ordinal", -1)) != index:
			_add(diagnostics, "ORDINAL_MISMATCH", mapping_path, "mapping ordinal must match authored order")
		_validate_mask(mapping.get("mask", null), "%s.mask" % mapping_path, {"row_track_id": "", "column_track_id": ""}, diagnostics, int(variant_width), int(variant_depth))


func _validate_road_profile(value: Variant, path: String, diagnostics: Array[Dictionary]) -> void:
	if not value is Dictionary:
		_add(diagnostics, "ROAD_PROFILE_INVALID", path, "road profile must be an object")
		return
	var profile: Dictionary = value
	_require_keys(profile, ["road_profile_id", "road_profile_version", "pedestrian_width", "carriageways"], path, diagnostics)
	_require_string(profile, "road_profile_id", path, diagnostics)
	_require_int(profile, "road_profile_version", path, diagnostics)
	_require_int(profile, "pedestrian_width", path, diagnostics)
	var pedestrian_width: int = int(profile.get("pedestrian_width", 0))
	if pedestrian_width < 5 or pedestrian_width > 10:
		_add(diagnostics, "PEDESTRIAN_WIDTH_INVALID", path, "pedestrian width must be 5-10 tiles")
	var carriageways: Variant = profile.get("carriageways", null)
	if not carriageways is Array or carriageways.is_empty():
		_add(diagnostics, "CARRIAGEWAYS_INVALID", path, "road profile requires carriageways")
		return
	var lane_count: int = 0
	var direction_counts: Dictionary = {}
	var direction_groups: Array[String] = []
	var last_direction: String = ""
	for carriageway_index: int in range(carriageways.size()):
		var carriageway: Variant = carriageways[carriageway_index]
		var carriageway_path: String = "%s.carriageways[%d]" % [path, carriageway_index]
		if not carriageway is Dictionary:
			_add(diagnostics, "CARRIAGEWAY_INVALID", carriageway_path, "carriageway must be an object")
			continue
		_require_keys(carriageway, ["ordinal", "lanes"], carriageway_path, diagnostics)
		_require_int(carriageway, "ordinal", carriageway_path, diagnostics)
		if int(carriageway.get("ordinal", -1)) != carriageway_index:
			_add(diagnostics, "ORDINAL_MISMATCH", carriageway_path, "carriageway ordinal must match authored order")
		var lanes: Variant = carriageway.get("lanes", null)
		if not lanes is Array:
			_add(diagnostics, "LANES_INVALID", carriageway_path, "lanes must be an array")
			continue
		for lane_index: int in range(lanes.size()):
			var lane: Variant = lanes[lane_index]
			var lane_path: String = "%s.lanes[%d]" % [carriageway_path, lane_index]
			if not lane is Dictionary:
				_add(diagnostics, "LANE_INVALID", lane_path, "lane must be an object")
				continue
			_require_keys(lane, ["ordinal", "direction", "width"], lane_path, diagnostics)
			_require_int(lane, "ordinal", lane_path, diagnostics)
			_require_string(lane, "direction", lane_path, diagnostics)
			_require_int(lane, "width", lane_path, diagnostics)
			if int(lane.get("ordinal", -1)) != lane_index:
				_add(diagnostics, "ORDINAL_MISMATCH", lane_path, "lane ordinal must match authored order")
			if not DIRECTIONS.has(String(lane.get("direction", ""))):
				_add(diagnostics, "LANE_DIRECTION_INVALID", lane_path, "lane direction must be FORWARD or REVERSE")
			if int(lane.get("width", 0)) != 3:
				_add(diagnostics, "LANE_WIDTH_INVALID", lane_path, "every traffic lane is exactly 3 tiles wide")
			var direction: String = String(lane.get("direction", ""))
			if DIRECTIONS.has(direction):
				if direction != last_direction:
					if direction_groups.has(direction):
						_add(diagnostics, "LANE_GROUP_NOT_CONTIGUOUS", lane_path, "same-direction lanes must form contiguous groups")
					direction_groups.append(direction)
					last_direction = direction
			lane_count += 1
			direction_counts[direction] = int(direction_counts.get(direction, 0)) + 1
	if lane_count < 2 or lane_count > 6:
		_add(diagnostics, "LANE_COUNT_INVALID", path, "road requires 2-6 total lanes")
	if int(direction_counts.get("FORWARD", 0)) < 1 or int(direction_counts.get("REVERSE", 0)) < 1:
		_add(diagnostics, "LANE_DIRECTION_COVERAGE", path, "road requires at least one lane in each direction")


func _validate_outer_ring(value: Variant, diagnostics: Array[Dictionary]) -> void:
	if not value is Dictionary:
		_add(diagnostics, "OUTER_RING_INVALID", "$.layout.outer_ring", "outer_ring must be an object")
		return
	var ring: Dictionary = value
	_require_keys(ring, ["complete", "permanent", "road_profile_id"], "$.layout.outer_ring", diagnostics)
	_validate_bool(ring, "complete", "$.layout.outer_ring", diagnostics)
	_validate_bool(ring, "permanent", "$.layout.outer_ring", diagnostics)
	if ring.get("complete", false) != true or ring.get("permanent", false) != true:
		_add(diagnostics, "OUTER_RING_NOT_PERMANENT", "$.layout.outer_ring", "outer ring must be complete and permanent")
	_require_string(ring, "road_profile_id", "$.layout.outer_ring", diagnostics)


func _validate_sources(value: Variant, diagnostics: Array[Dictionary]) -> void:
	if not value is Array:
		_add(diagnostics, "SOURCES_INVALID", "$.layout.arrival_sources", "arrival_sources must be an array")
		return
	var ids: Dictionary = {}
	for index: int in range(value.size()):
		var source: Variant = value[index]
		var path: String = "$.layout.arrival_sources[%d]" % index
		if not source is Dictionary:
			_add(diagnostics, "SOURCE_INVALID", path, "arrival source must be an object")
			continue
		_require_keys(source, ["arrival_source_id", "mode", "selector", "initially_enabled", "capacity", "weight", "schedule", "presentation"], path, diagnostics)
		_require_string(source, "arrival_source_id", path, diagnostics)
		_require_string(source, "mode", path, diagnostics)
		_validate_bool(source, "initially_enabled", path, diagnostics)
		if not SOURCE_MODES.has(String(source.get("mode", ""))):
			_add(diagnostics, "SOURCE_MODE_INVALID", path, "proof sources use PEDESTRIAN mode")
		var source_id: String = String(source.get("arrival_source_id", ""))
		if ids.has(source_id):
			_add(diagnostics, "DUPLICATE_ID", path, "arrival source IDs must be unique")
		ids[source_id] = true
		if source.get("capacity", null) != null or source.get("weight", null) != null or not source.get("schedule", []) is Array or not source.get("presentation", {}) is Dictionary:
			_add(diagnostics, "SOURCE_POLICY_FORBIDDEN", path, "proof sources have null capacity/weight and empty schedule/presentation")
		var selector: Variant = source.get("selector", null)
		if not selector is Dictionary:
			_add(diagnostics, "SELECTOR_INVALID", path, "source selector must be an object")
			continue
		_require_keys(selector, ["kind", "slot_id", "side"], "%s.selector" % path, diagnostics)
		_require_string(selector, "kind", "%s.selector" % path, diagnostics)
		_require_string(selector, "slot_id", "%s.selector" % path, diagnostics)
		_require_string(selector, "side", "%s.selector" % path, diagnostics)


func _validate_range(value: Variant, path: String, diagnostics: Array[Dictionary], expected_minimum: int, expected_maximum: int) -> void:
	if not value is Dictionary:
		_add(diagnostics, "RANGE_INVALID", path, "range must be a non-null object")
		return
	_require_keys(value, ["minimum_elevation", "maximum_elevation"], path, diagnostics)
	_require_int(value, "minimum_elevation", path, diagnostics)
	_require_int(value, "maximum_elevation", path, diagnostics)
	if int(value.get("minimum_elevation", 0)) != expected_minimum or int(value.get("maximum_elevation", 0)) != expected_maximum:
		_add(diagnostics, "RANGE_INVALID", path, "proof layouts use the root physical range -5..+9")


func _validate_cap(value: Variant, path: String, diagnostics: Array[Dictionary]) -> void:
	if value == null:
		return
	if not value is Dictionary:
		_add(diagnostics, "CAP_INVALID", path, "cap must be null or a complete object")
		return
	_require_keys(value, ["minimum_elevation", "maximum_elevation"], path, diagnostics)
	_require_int(value, "minimum_elevation", path, diagnostics)
	_require_int(value, "maximum_elevation", path, diagnostics)
	if int(value.get("minimum_elevation", 0)) > int(value.get("maximum_elevation", 0)):
		_add(diagnostics, "CAP_INVALID", path, "cap minimum cannot exceed maximum")


func _catalog_ids(value: Array, key: String, path: String, diagnostics: Array[Dictionary]) -> Dictionary:
	var ids: Dictionary = {}
	for index: int in range(value.size()):
		var record: Variant = value[index]
		var record_path: String = "%s[%d]" % [path, index]
		if not record is Dictionary:
			_add(diagnostics, "CATALOG_RECORD_INVALID", record_path, "catalog records must be objects")
			continue
		if not record.has(key) or typeof(record[key]) != TYPE_STRING:
			_add(diagnostics, "ID_MISSING", record_path, "catalog record requires a string ID")
			continue
		var id: String = String(record[key])
		if ids.has(id):
			_add(diagnostics, "DUPLICATE_ID", record_path, "catalog IDs must be unique")
		ids[id] = true
	return ids


func _contains_id(records: Array, key: String, expected: String) -> bool:
	for record: Variant in records:
		if record is Dictionary and String(record.get(key, "")) == expected:
			return true
	return false


func _require_keys(value: Dictionary, keys: Array[String], path: String, diagnostics: Array[Dictionary]) -> void:
	for key: String in keys:
		if not value.has(key):
			_add(diagnostics, "FIELD_MISSING", "%s.%s" % [path, key], "required semantic field is missing")


func _reject_unknown_keys(value: Dictionary, keys: Array[String], path: String, diagnostics: Array[Dictionary]) -> void:
	for key: Variant in value.keys():
		if not keys.has(String(key)):
			_add(diagnostics, "UNKNOWN_FIELD", "%s.%s" % [path, String(key)], "unknown semantic field is not allowed")


func _require_string(value: Dictionary, key: String, path: String, diagnostics: Array[Dictionary]) -> void:
	if value.has(key) and typeof(value[key]) != TYPE_STRING:
		_add(diagnostics, "TYPE_INVALID", "%s.%s" % [path, key], "field must be a string")


func _require_int(value: Dictionary, key: String, path: String, diagnostics: Array[Dictionary]) -> void:
	if value.has(key) and typeof(value[key]) != TYPE_INT:
		_add(diagnostics, "TYPE_INVALID", "%s.%s" % [path, key], "field must be an integer")


func _validate_bool(value: Dictionary, key: String, path: String, diagnostics: Array[Dictionary]) -> void:
	if value.has(key) and typeof(value[key]) != TYPE_BOOL:
		_add(diagnostics, "TYPE_INVALID", "%s.%s" % [path, key], "field must be a boolean")


func _is_four_connected(cells: Array) -> bool:
	if cells.size() <= 1:
		return true
	var remaining: Dictionary = {}
	for cell: Array in cells:
		remaining[_cell_key(cell)] = cell
	var queue: Array = [cells[0]]
	var visited: Dictionary = {}
	while not queue.is_empty():
		var current: Array = queue.pop_front()
		var current_key: String = _cell_key(current)
		if visited.has(current_key):
			continue
		visited[current_key] = true
		for offset: Array in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var neighbor: Array = [int(current[0]) + int(offset[0]), int(current[1]) + int(offset[1])]
			if remaining.has(_cell_key(neighbor)) and not visited.has(_cell_key(neighbor)):
				queue.append(neighbor)
	return visited.size() == cells.size()


func _sorted_cells_from_dictionary(cells: Dictionary) -> Array:
	var result: Array = cells.values()
	result.sort_custom(func(a: Array, b: Array) -> bool:
		return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0])
	)
	return result


func _cell_key(cell: Array) -> String:
	return "%d,%d" % [int(cell[0]), int(cell[1])]


func _add(diagnostics: Array[Dictionary], code: String, path: String, message: String) -> void:
	diagnostics.append({"code": code, "path": path, "message": message})
