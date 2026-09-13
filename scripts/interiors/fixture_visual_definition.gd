## Immutable authoring record for one restricted tenant-fixture visual.
class_name FixtureVisualDefinition
extends Resource

@export var visual_id: String = ""
@export_range(1, 2147483647, 1) var revision: int = 1
@export var scene: PackedScene
@export var envelope_min_millimeters: Vector3i = Vector3i.ZERO
@export var envelope_max_millimeters: Vector3i = Vector3i(1000, 1000, 1000)


func to_record() -> Dictionary:
	return {
		"visual_id": visual_id,
		"revision": revision,
		"scene_path": scene.resource_path if scene != null else "",
		"envelope_min_millimeters": [envelope_min_millimeters.x, envelope_min_millimeters.y, envelope_min_millimeters.z],
		"envelope_max_millimeters": [envelope_max_millimeters.x, envelope_max_millimeters.y, envelope_max_millimeters.z],
	}
