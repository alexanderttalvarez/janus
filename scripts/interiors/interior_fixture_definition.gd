## Immutable authored gameplay footprint for one tenant-interior fixture.
class_name InteriorFixtureDefinition
extends Resource

enum ProgramRole { MANDATORY_SERVICE, MANDATORY_CAPACITY, BACK_OF_HOUSE, REPEATABLE, OPTIONAL }

@export var fixture_id: String = ""
@export_range(1, 2147483647, 1) var revision: int = 1
@export var occupied_cells: Array[Vector2i] = [Vector2i.ZERO]
@export var clearance_cells: Array[Vector2i] = []
@export var allowed_rotations: Array[int] = [0]
@export var interaction_face: String = "NONE"
@export var placement_rule: String = "FREESTANDING"
@export var tags: Array[String] = []
@export var incompatible_neighbor_tags: Array[String] = []
@export_range(0, 2147483647, 1) var capacity: int = 0
@export var capacity_token: String = "NONE"
@export var program_role: ProgramRole = ProgramRole.OPTIONAL
@export_range(0, 2147483647, 1) var placement_priority: int = 0
@export var default_visual: FixtureVisualDefinition
@export var visual_variants: Array[FixtureVisualDefinition] = []


func to_record() -> Dictionary:
	var rotations: Array[int] = allowed_rotations.duplicate()
	rotations.sort()
	var ordered_tags: Array[String] = tags.duplicate()
	ordered_tags.sort()
	var ordered_incompatible_tags: Array[String] = incompatible_neighbor_tags.duplicate()
	ordered_incompatible_tags.sort()
	return {
		"fixture_id": fixture_id,
		"revision": revision,
		"occupied_cells": _cells_to_arrays(occupied_cells),
		"clearance_cells": _cells_to_arrays(clearance_cells),
		"allowed_rotations": rotations,
		"interaction_face": interaction_face,
		"placement_rule": placement_rule,
		"tags": ordered_tags,
		"incompatible_neighbor_tags": ordered_incompatible_tags,
		"capacity": capacity,
		"capacity_token": capacity_token,
		"program_role": ProgramRole.keys()[program_role],
		"placement_priority": placement_priority,
		"default_visual": default_visual.to_record() if default_visual != null else null,
		"visual_variants": _visual_records(),
	}


func _cells_to_arrays(cells: Array[Vector2i]) -> Array[Array]:
	var values: Array[Array] = []
	for cell: Vector2i in cells:
		values.append([cell.x, cell.y])
	values.sort_custom(func(left: Array, right: Array) -> bool: return left[1] < right[1] or (left[1] == right[1] and left[0] < right[0]))
	return values


func _visual_records() -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for visual: FixtureVisualDefinition in visual_variants:
		if visual != null:
			values.append(visual.to_record())
	values.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left["visual_id"]) < String(right["visual_id"]))
	return values
