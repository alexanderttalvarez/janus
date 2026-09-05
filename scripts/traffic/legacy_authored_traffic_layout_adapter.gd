class_name LegacyAuthoredTrafficLayoutAdapter
extends RefCounted

## H7 compatibility-only validator for the old traffic scene. Runtime graph
## authority never calls this adapter and never derives identity from its data.

const EXPECTED_LANES: Array[String] = [
	"Lane_North_Eastbound",
	"Lane_North_Westbound",
	"Lane_East_Southbound",
	"Lane_East_Northbound",
	"Lane_South_Westbound",
	"Lane_South_Eastbound",
	"Lane_West_Northbound",
	"Lane_West_Southbound",
]
const EXPECTED_MARKERS: Array[String] = ["Spawn", "StopLine", "Exit", "SourceClear", "IntersectionHold", "IntersectionClear"]
const EXPECTED_CROSSWALKS: Array[String] = ["Crosswalk_North", "Crosswalk_East", "Crosswalk_South", "Crosswalk_West"]
const EXPECTED_RESERVATION_ZONES: Array[String] = ["NW", "NE", "SW", "SE"]


func validate(root: Node) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var layout: Node = root.get_node_or_null("TrafficLayout") if root != null else null
	if layout == null and root != null:
		layout = root.get_node_or_null("World/TrafficLayout")
	if root != null and root.name == "TrafficLayout":
		layout = root
	if layout == null:
		return _failure("LEGACY_TRAFFIC_LAYOUT_MISSING", "legacy TrafficLayout is required")
	var lanes_root: Node = layout.get_node_or_null("Lanes")
	var crosswalk_root: Node = layout.get_node_or_null("Crosswalks")
	var zones_root: Node = layout.get_node_or_null("IntersectionZones")
	if lanes_root == null or crosswalk_root == null or zones_root == null:
		return _failure("LEGACY_TRAFFIC_LAYOUT_INCOMPLETE", "legacy lanes, crosswalks, and reservation zones are required")
	var lane_records: Array[Dictionary] = []
	for lane_id: String in EXPECTED_LANES:
		var lane: Node = lanes_root.get_node_or_null(lane_id)
		if lane == null:
			diagnostics.append({"code": "LEGACY_LANE_MISSING", "lane_id": lane_id})
			continue
		var markers: Array[String] = []
		for marker_name: String in EXPECTED_MARKERS:
			if lane.get_node_or_null(marker_name) == null:
				diagnostics.append({"code": "LEGACY_MARKER_MISSING", "lane_id": lane_id, "marker": marker_name})
			else:
				markers.append(marker_name)
		lane_records.append({"id": lane_id, "markers": markers})
	for crosswalk_name: String in EXPECTED_CROSSWALKS:
		if crosswalk_root.get_node_or_null(crosswalk_name) == null:
			diagnostics.append({"code": "LEGACY_CROSSWALK_MISSING", "crosswalk": crosswalk_name})
	for zone_name: String in EXPECTED_RESERVATION_ZONES:
		if zones_root.get_node_or_null(zone_name) == null:
			diagnostics.append({"code": "LEGACY_RESERVATION_ZONE_MISSING", "zone": zone_name})
	lane_records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("id", "")) < String(right.get("id", "")))
	return {
		"valid": diagnostics.is_empty(),
		"lanes": lane_records,
		"marker_families": EXPECTED_MARKERS.duplicate(),
		"crosswalks": EXPECTED_CROSSWALKS.duplicate(),
		"reservation_zones": EXPECTED_RESERVATION_ZONES.duplicate(),
		"diagnostics": diagnostics,
	}


func adapt(root: Node) -> Dictionary:
	return validate(root)


func _failure(code: String, message: String) -> Dictionary:
	return {"valid": false, "lanes": [], "marker_families": EXPECTED_MARKERS.duplicate(), "crosswalks": EXPECTED_CROSSWALKS.duplicate(), "reservation_zones": EXPECTED_RESERVATION_ZONES.duplicate(), "diagnostics": [{"code": code, "message": message}]}
