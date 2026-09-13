## Immutable revisioned geometry rules for detached exterior queue planning.
class_name QueueGeometryPolicy
extends Resource

const SCHEMA_ID: String = "queue_geometry_policy"
const SCHEMA_VERSION: int = 1

@export var policy_id: String = "tenant_exterior_queue_geometry"
@export_range(1, 2147483647, 1) var policy_revision: int = 1
@export var coordinate_unit: String = "QUARTER_TILE"
@export var position_offsets: Array[Dictionary] = [
	{"frontage_offset4": -1, "outward_offset4": -1},
	{"frontage_offset4": 1, "outward_offset4": -1},
]
@export_range(0, 64, 1) var position_reservation_half_extent4: int = 1
@export_range(0, 64, 1) var minimum_position_separation4: int = 2
@export_range(0, 64, 1) var minimum_public_cell_edge_clearance4: int = 1
@export var door_approach_mask: Array[Dictionary] = [{"frontage_delta_tiles": 0, "outward_depth_tiles": 0}]
@export var forbidden_cell_facts: Array[String] = ["NONPUBLIC_CELL", "VERTICAL_LINK", "SOURCE_ANCHOR", "INTERSECTION_RESERVATION", "CROSSWALK_RESERVATION", "STRUCTURAL_DOOR_APPROACH", "MANUAL_DOOR_APPROACH", "FIXED_OCCUPANCY"]
@export var door_grouping: String = "PER_OPERATIONAL_DOOR"
@export var queue_orientation: String = "FRONTAGE_PARALLEL_BIDIRECTIONAL"
@export var scan_order: String = "DISTANCE_ASC_NEGATIVE_TANGENT_FIRST"
@export_range(1, 1024, 1) var max_scan_distance_tiles: int = 8
@export var conflict_key_mode: String = "OVERLAPPED_QUARTER_CELLS"
@export var public_centerline_rule: String = "OUTER_HALF_REMAINS_UNRESERVED"


func to_record() -> Dictionary:
	return {
		"schema_id": SCHEMA_ID, "schema_version": SCHEMA_VERSION,
		"policy_id": policy_id, "policy_revision": policy_revision,
		"coordinate_unit": coordinate_unit, "position_offsets": position_offsets.duplicate(true),
		"position_reservation_half_extent4": position_reservation_half_extent4,
		"minimum_position_separation4": minimum_position_separation4,
		"minimum_public_cell_edge_clearance4": minimum_public_cell_edge_clearance4,
		"door_approach_mask": door_approach_mask.duplicate(true),
		"forbidden_cell_facts": forbidden_cell_facts.duplicate(),
		"door_grouping": door_grouping, "queue_orientation": queue_orientation,
		"scan_order": scan_order, "max_scan_distance_tiles": max_scan_distance_tiles,
		"conflict_key_mode": conflict_key_mode, "public_centerline_rule": public_centerline_rule,
	}


func validate_revision_one() -> bool:
	var expected := QueueGeometryPolicy.new()
	return to_record() == expected.to_record()
