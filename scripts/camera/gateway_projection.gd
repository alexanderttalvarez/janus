class_name GatewayProjection
extends RefCounted

## H2 attachment/pose pass-through. H6 never resolves or mutates these values.

var arrival_source_id: String = ""
var authored_selector: Dictionary = {}
var topology_attachment_id: String = ""
var baseline_pose: Dictionary = {}
var attachment_owner: String = "H2"
var pose_owner: String = "H2"


func initialize(attachment: Dictionary) -> void:
	arrival_source_id = String(attachment.get("authored_id", ""))
	authored_selector = attachment.get("selector", {}).duplicate(true)
	topology_attachment_id = String(attachment.get("resolved_target_topology_id", ""))
	baseline_pose = attachment.get("pose", {}).duplicate(true)


func duplicate_value() -> GatewayProjection:
	var copy: GatewayProjection = load("res://scripts/camera/gateway_projection.gd").new() as GatewayProjection
	copy.arrival_source_id = arrival_source_id
	copy.authored_selector = authored_selector.duplicate(true)
	copy.topology_attachment_id = topology_attachment_id
	copy.baseline_pose = baseline_pose.duplicate(true)
	copy.attachment_owner = attachment_owner
	copy.pose_owner = pose_owner
	return copy


func value() -> Dictionary:
	return {
		"arrival_source_id": arrival_source_id,
		"authored_selector": authored_selector.duplicate(true),
		"topology_attachment_id": topology_attachment_id,
		"baseline_pose": baseline_pose.duplicate(true),
		"attachment_owner": attachment_owner,
		"pose_owner": pose_owner,
	}
