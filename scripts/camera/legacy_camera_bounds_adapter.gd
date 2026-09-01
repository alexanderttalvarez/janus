class_name LegacyCameraBoundsAdapter
extends RefCounted

## H6 migration seam for legacy bootstrap data. It exposes canonical Active
## Plot rectangles only; the removed radial/purchased-tile rule is not applied.


func get_active_plot_records(snapshot: ResolvedDistrictSnapshot, state: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if snapshot == null:
		return records
	for plot: Dictionary in snapshot.get_data().get("plots", []):
		if is_plot_active(snapshot, state, String(plot.get("id", ""))):
			records.append(plot)
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("id", "")) < String(right.get("id", "")))
	return records


func is_plot_active(snapshot: ResolvedDistrictSnapshot, state: Dictionary, plot_id: String) -> bool:
	if snapshot == null:
		return false
	for section: Dictionary in snapshot.get_data().get("sections", []):
		if String(section.get("plot_id", "")) != plot_id:
			continue
		var default_owned: bool = bool(section.get("initially_owned", false))
		var owned: bool = default_owned
		for plot_state: Dictionary in state.get("plot_states", []):
			for override: Dictionary in plot_state.get("section_state_overrides", []):
				if String(override.get("runtime_section_id", "")) == String(section.get("id", "")):
					owned = bool(override.get("owned", default_owned))
		if owned:
			return true
	return false
