class_name LegacyAuthoredTrafficLayoutAdapter
extends RefCounted

## H7 compatibility adapter. It validates the legacy authored layout but does
## not provide topology authority to TrafficTopology.

const LEGACY_LANE_IDS: Array[String] = [
	"Lane_North_Eastbound", "Lane_North_Westbound",
	"Lane_East_Southbound", "Lane_East_Northbound",
	"Lane_South_Westbound", "Lane_South_Eastbound",
	"Lane_West_Northbound", "Lane_West_Southbound",
]
const MARKER_FAMILIES: Array[String] = ["Spawn", "StopLine", "Exit", "SourceClear", "IntersectionHold", "IntersectionClear"]
const RESERVATION_ZONES: Array[String] = ["NW", "NE", "SW", "SE"]


func validate(traffic_layout: Node3D) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if traffic_layout == null:
		return {"valid": false, "lane_count": 0, "marker_family_count": 0, "reservation_zone_count": 0, "diagnostics": [{"code": "LEGACY_TRAFFIC_LAYOUT_REQUIRED", "message": "legacy traffic layout is required"}]}
	var lanes_root: Node3D = traffic_layout.get_node_or_null("Lanes") as Node3D
	var zones_root: Node3D = traffic_layout.get_node_or_null("IntersectionZones") as Node3D
	if lanes_root == null:
		diagnostics.append({"code": "LEGACY_LANES_ROOT_MISSING", "message": "legacy Lanes root is missing"})
	if zones_root == null:
		diagnostics.append({"code": "LEGACY_ZONES_ROOT_MISSING", "message": "legacy IntersectionZones root is missing"})
	var lane_count: int = 0
	var marker_families: Dictionary = {}
	if lanes_root != null:
		for lane_id: String in LEGACY_LANE_IDS:
			var lane: Node3D = lanes_root.get_node_or_null(lane_id) as Node3D
			if lane == null:
				diagnostics.append({"code": "LEGACY_LANE_MISSING", "lane_id": lane_id})
				continue
			lane_count += 1
			for marker_name: String in MARKER_FAMILIES:
				if lane.get_node_or_null(marker_name) == null:
					diagnostics.append({"code": "LEGACY_MARKER_MISSING", "lane_id": lane_id, "marker": marker_name})
				else:
					marker_families[marker_name] = true
	var zone_count: int = 0
	if zones_root != null:
		for zone_name: String in RESERVATION_ZONES:
			if zones_root.get_node_or_null(zone_name) == null:
				diagnostics.append({"code": "LEGACY_RESERVATION_ZONE_MISSING", "zone_id": zone_name})
			else:
				zone_count += 1
	return {"valid": diagnostics.is_empty(), "lane_count": lane_count, "marker_family_count": marker_families.size(), "reservation_zone_count": zone_count, "diagnostics": diagnostics}
