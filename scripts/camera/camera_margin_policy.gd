class_name CameraMarginPolicy
extends RefCounted

## H6 selected policy: road-profile-relative camera infrastructure margin.
## No fixed legacy radius or purchased-tile count participates in this policy.

const POLICY_ID: String = "ROAD_PROFILE_RELATIVE_V1"


func calculate(road_profile: Dictionary, grid_unit_size: float) -> Dictionary:
	var segments: Array = road_profile.get("segments", [])
	if segments.is_empty() or grid_unit_size <= 0.0:
		return {"valid": false, "policy_id": POLICY_ID, "diagnostics": [{"code": "ROAD_PROFILE_REQUIRED", "message": "road-profile-relative camera margin requires a committed road profile"}]}
	var margin_quarter: float = 0.0
	for segment: Dictionary in segments:
		var orientation: String = String(segment.get("orientation", ""))
		var carriageway: Dictionary = segment.get("carriageway", {})
		var carriageway_depth: float = _cross_axis_depth(carriageway.get("rect_quarter", {}), orientation)
		for band: Dictionary in segment.get("pedestrian_bands", []):
			var band_depth: float = _cross_axis_depth(band.get("rect_quarter", {}), orientation)
			# One complete public-band depth plus half the carriageway depth keeps
			# the camera envelope clear of the selected road profile on either side.
			margin_quarter = maxf(margin_quarter, band_depth + carriageway_depth * 0.5)
	if margin_quarter <= 0.0:
		return {"valid": false, "policy_id": POLICY_ID, "diagnostics": [{"code": "ROAD_PROFILE_INVALID", "message": "committed road profile contains no positive cross-axis width"}]}
	return {
		"valid": true,
		"policy_id": POLICY_ID,
		"margin_quarter": margin_quarter,
		"margin": margin_quarter * grid_unit_size / 4.0,
		"diagnostics": [],
	}


func _cross_axis_depth(rectangle: Dictionary, orientation: String) -> float:
	if orientation == "HORIZONTAL":
		return maxf(0.0, float(rectangle.get("maximum_z4", 0.0)) - float(rectangle.get("minimum_z4", 0.0)))
	if orientation == "VERTICAL":
		return maxf(0.0, float(rectangle.get("maximum_x4", 0.0)) - float(rectangle.get("minimum_x4", 0.0)))
	return 0.0
