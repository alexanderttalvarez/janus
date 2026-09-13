## Pure detached H2 core/annex formation and H1 feasibility orchestration.
class_name TenantParcelFormationPlanner
extends RefCounted

const STATUS_VALID: String = "VALID"
const STATUS_INDETERMINATE: String = "SEARCH_INDETERMINATE"


func plan(intent: Dictionary, base: Dictionary, spatial: DistrictZoneSpatialSnapshot, public_access: PublicBandAccessSnapshot, queue_input: QueueResolutionSnapshot, content: CompiledTenantInteriorContent, formation_policy: ParcelFormationPolicy, queue_policy: QueueGeometryPolicy) -> Dictionary:
	var snapshot_validation := _validate_injected_snapshots(intent, base, spatial, public_access)
	if not bool(snapshot_validation.get("valid", false)): return snapshot_validation
	if content == null or not content.validate_integrity() or formation_policy == null or not formation_policy.validate_revision_one() or queue_policy == null or not queue_policy.validate_revision_one(): return _failure("CONTENT_INVALID")
	var graph: ProspectivePedestrianGraphSnapshot = base.get("prospective_graph") as ProspectivePedestrianGraphSnapshot
	var queue_result := QueueEnvelopeResolver.new().resolve(base.get("selected_doors", []), graph, queue_input, queue_policy)
	if queue_result.get("status") != "VALID": return {"status":queue_result.get("status"),"parcels":[],"diagnostics":queue_result.get("diagnostics",[])}
	var cells := _ordered_cells(base.get("tenant_cells", []))
	if cells.is_empty() or not _connected(cells): return _failure("INVALID_ZONE_GEOMETRY")
	var zone_type := String(intent.get("zone_type", base.get("zone_type", "")))
	var formed := _form_parcels(cells, base.get("frontage_edges", []), zone_type, String(intent.get("zone_plan_key", "")), formation_policy)
	if formed.get("status") != STATUS_VALID: return formed
	var envelopes_by_door: Dictionary = {}
	for envelope: Dictionary in queue_result["candidate_envelopes"]: envelopes_by_door[envelope["door_semantic_key"]] = envelope
	var planned: Array[Dictionary] = []; var suitability_records: Array[Dictionary] = []
	for parcel: Dictionary in formed["parcels"]:
		var core_options := _core_options(parcel["cells"], content.get_content().get("operational_profiles", []), zone_type, parcel["parcel_key"])
		var doors := _door_options(parcel["cells"], base.get("selected_doors", []), envelopes_by_door, queue_policy)
		if core_options.is_empty() or doors.is_empty():
			parcel["suitability"] = "UNSUITABLE"; parcel["feasible_profile_ids"] = []; planned.append(parcel)
			suitability_records.append(_suitability(parcel["parcel_key"], "AVAILABLE", "UNSUITABLE", 0, ["MISSING_CORE_OR_DOOR"])); continue
		var provisional_core: Dictionary = core_options[0]
		var request := _phase_a_request(parcel, provisional_core, core_options, doors, zone_type)
		var phase_a := InteriorLayoutPlanner.new().plan_phase_a(request, content)
		if phase_a.get("status") == InteriorLayoutPlanner.STATUS_INDETERMINATE:
			return {"status":STATUS_INDETERMINATE,"parcels":[],"residual_decoration_cells":[],"diagnostics":phase_a.get("diagnostics",[])}
		var feasible_ids: Array[String] = []
		for result: Dictionary in phase_a.get("feasible_profiles", []): feasible_ids.append(String(result["operational_profile_id"]))
		parcel["feasible_profile_ids"] = feasible_ids
		parcel["suitability"] = "SUITABLE" if not feasible_ids.is_empty() else "UNSUITABLE"
		parcel["formation_core"] = _select_formation_core(core_options, phase_a.get("feasible_profiles", []))
		parcel["annex_cells"] = _difference(parcel["cells"], parcel["formation_core"].get("cells", []))
		parcel["geometry_fingerprint"] = _fingerprint({"cells":parcel["cells"],"formation_core":parcel["formation_core"]}, "JANUS_TENANT_PARCEL_GEOMETRY")
		parcel["phase_a"] = phase_a
		planned.append(parcel); suitability_records.append(_suitability(parcel["parcel_key"], "AVAILABLE", parcel["suitability"], feasible_ids.size(), [] if not feasible_ids.is_empty() else ["NO_CONCLUSIVE_FEASIBLE_PROFILE"]))
	var pool_witnesses: Array[Dictionary] = []
	for parcel: Dictionary in planned:
		pool_witnesses.append({"parcel_key":parcel["parcel_key"],"feasible_pool_fingerprint":parcel.get("phase_a",{}).get("feasible_pool_fingerprint","")})
	var pool_fingerprint := _fingerprint(pool_witnesses, "JANUS_TENANT_INTERIOR_FEASIBLE_POOL")
	var selected_edges: Array = []
	for door: Dictionary in base.get("selected_doors", []): selected_edges.append(door["edge"])
	var parity_result := PhaseAParityRecord.create({"formation_policy_id":formation_policy.policy_id,"formation_policy_revision":formation_policy.policy_revision,"queue_policy_id":queue_policy.policy_id,"queue_policy_revision":queue_policy.policy_revision,"selected_door_edges":selected_edges,"prospective_graph_fingerprint":graph.duplicate_value().get("topology_fingerprint"),"queue_input_fingerprint":queue_result["queue_input_fingerprint"],"queue_envelopes":queue_result["candidate_envelopes"],"feasible_pool_fingerprint":pool_fingerprint})
	if not bool(parity_result.get("valid", false)): return {"status":"CONTENT_INVALID","parcels":[],"diagnostics":parity_result.get("diagnostics",[])}
	for parcel: Dictionary in planned: parcel["phase_a_parity"] = parity_result["record"].duplicate(true)
	for record: Dictionary in suitability_records: record["source_parity_fingerprint"] = parity_result["record"]["parity_fingerprint"]
	var suitable_count: int = 0
	for parcel: Dictionary in planned:
		if parcel.get("suitability") == "SUITABLE": suitable_count += 1
	var status := STATUS_VALID if suitable_count > 0 else "NO_CONCLUSIVE_FEASIBLE_PARCEL"
	return {"status":status,"parcels":planned,"residual_decoration_cells":formed["residual_decoration_cells"],"queue_envelopes":queue_result["candidate_envelopes"],"queue_input_fingerprint":queue_result["queue_input_fingerprint"],"queue_envelopes_fingerprint":queue_result["queue_envelopes_fingerprint"],"graph_fingerprint":graph.duplicate_value().get("topology_fingerprint"),"phase_a_parity":parity_result["record"],"suitability_records":suitability_records,"diagnostics":[]}


func _validate_injected_snapshots(intent: Dictionary, base: Dictionary, spatial: DistrictZoneSpatialSnapshot, public_access: PublicBandAccessSnapshot) -> Dictionary:
	if spatial == null: return _input_failure("DISTRICT_ZONE_SPATIAL_UNAVAILABLE")
	if public_access == null: return _input_failure("PUBLIC_BAND_ACCESS_UNAVAILABLE")
	var spatial_value := spatial.duplicate_value()
	var spatial_validation := DistrictZoneSpatialSnapshot.validate_value(spatial_value)
	if not bool(spatial_validation.get("valid", false)):
		return {"status":"INVALID_INPUT","parcels":[],"residual_decoration_cells":[],"diagnostics":spatial_validation.get("diagnostics",[])}
	var public_value := public_access.duplicate_value()
	var public_validation := PublicBandAccessSnapshot.validate_value(public_value)
	if not bool(public_validation.get("valid", false)):
		return {"status":"INVALID_INPUT","parcels":[],"residual_decoration_cells":[],"diagnostics":public_validation.get("diagnostics",[])}
	var graph := base.get("prospective_graph") as ProspectivePedestrianGraphSnapshot
	if graph == null: return _input_failure("PROSPECTIVE_GRAPH_UNAVAILABLE")
	var graph_value := graph.duplicate_value()
	var expected_layout: Dictionary = graph_value.get("layout_ref", {})
	var expected_revision: int = int(graph_value.get("district_revision", -1))
	if spatial_value.get("layout_ref") != expected_layout or int(spatial_value.get("district_revision", -2)) != expected_revision:
		return _input_failure("DISTRICT_ZONE_SPATIAL_STALE")
	if public_value.get("layout_ref") != expected_layout or int(public_value.get("district_revision", -2)) != expected_revision:
		return _input_failure("PUBLIC_BAND_ACCESS_STALE")
	var scope: Dictionary = spatial_value.get("floor_scope", {})
	if String(scope.get("runtime_plot_id", "")) != String(intent.get("runtime_plot_id", "")) or String(scope.get("floor_id", "")) != String(intent.get("floor_id", "")) or int(scope.get("signed_elevation", 999999)) != int(intent.get("signed_elevation", -999999)):
		return _input_failure("DISTRICT_ZONE_SPATIAL_SCOPE_MISMATCH")
	return {"valid":true,"diagnostics":[]}


func _input_failure(code: String) -> Dictionary:
	return {"valid":false,"status":"INVALID_INPUT","parcels":[],"residual_decoration_cells":[],"diagnostics":[{"code":code,"path":"$","values":{}}]}


func _form_parcels(cells: Array[Array], frontage_edges: Array, zone_type: String, zone_key: String, policy: ParcelFormationPolicy) -> Dictionary:
	if zone_type == "Anchor":
		return {"status":STATUS_VALID,"parcels":[{"parcel_key":_parcel_key(zone_key,cells[0],0),"cells":cells.duplicate(true),"scale_class":"LARGE"}],"residual_decoration_cells":[],"work_used":1}
	var remaining := _cell_set(cells); var parcels: Array[Dictionary] = []; var work := 0; var slot := 0
	while not remaining.is_empty():
		var origin: Array = _first_cell(remaining)
		var selected: Array[Array] = []
		for scale: String in _fallback_scales(policy.scale_slot_cycle[slot % policy.scale_slot_cycle.size()]):
			var band := _band(policy, scale)
			selected = _best_rectangle(origin, remaining, frontage_edges, band, policy, work)
			work += int(selected.size() > 0)
			if work > policy.formation_work_budget: return _failure(STATUS_INDETERMINATE)
			if not selected.is_empty(): break
		if selected.is_empty(): break
		var key := _parcel_key(zone_key, selected[0], parcels.size())
		parcels.append({"parcel_key":key,"cells":selected,"scale_class":policy.scale_for_area(selected.size())})
		for cell: Array in selected: remaining.erase(_key(cell))
		slot += 1
	var leftovers: Array[Array] = []
	for cell_key: String in remaining.keys(): leftovers.append(_parse_key(cell_key))
	leftovers = _ordered_cells(leftovers)
	for cell: Array in leftovers:
		var candidates: Array[Dictionary] = []
		for parcel: Dictionary in parcels:
			if _adjacent(cell, parcel["cells"]): candidates.append(parcel)
		candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return String(a["parcel_key"]) < String(b["parcel_key"]))
		if candidates.is_empty(): continue
		candidates[0]["cells"].append(cell); candidates[0]["cells"] = _ordered_cells(candidates[0]["cells"]); remaining.erase(_key(cell)); work += 1
		if work > policy.formation_work_budget: return _failure(STATUS_INDETERMINATE)
	var residual: Array[Array] = []
	for cell_key: String in remaining.keys(): residual.append(_parse_key(cell_key))
	return {"status":STATUS_VALID,"parcels":parcels,"residual_decoration_cells":_ordered_cells(residual),"work_used":work}


func _best_rectangle(origin: Array, remaining: Dictionary, frontage_edges: Array, band: Array[int], policy: ParcelFormationPolicy, _work: int) -> Array[Array]:
	var best: Array[Array] = []
	for depth: int in range(1, band[1] + 1):
		for width: int in range(1, band[1] + 1):
			var area := width * depth
			if area < band[0] or area > band[1]: continue
			var candidate: Array[Array] = []; var valid := true
			for y: int in range(depth):
				for x: int in range(width):
					var cell: Array[int] = [origin[0] + x, origin[1] + y]
					if not remaining.has(_key(cell)): valid = false; break
					candidate.append(cell)
				if not valid: break
			if valid and _has_frontage(candidate, frontage_edges) and (candidate.size() > best.size() or (candidate.size() == best.size() and _compactness(candidate) < _compactness(best))): best = candidate
	return _ordered_cells(best)


func _core_options(parcel_cells: Array, profiles: Array, zone_type: String, parcel_key: String) -> Array[Dictionary]:
	var options: Dictionary = {}; var parcel_set := _cell_set(parcel_cells)
	for profile: Dictionary in profiles:
		if profile.get("zone_type") != zone_type: continue
		for rotation: int in profile.get("core_rotations", []):
			var width := int(profile["core_depth"]) if rotation in [90,270] else int(profile["core_width"]); var depth := int(profile["core_width"]) if rotation in [90,270] else int(profile["core_depth"])
			for origin: Array in _ordered_cells(parcel_cells):
				var cells: Array[Array] = []; var valid := true
				for y: int in range(depth):
					for x: int in range(width):
						var cell: Array[int] = [origin[0]+x,origin[1]+y]
						if not parcel_set.has(_key(cell)): valid=false; break
						cells.append(cell)
					if not valid: break
				if valid:
					var key := "jplan1/core/%s/%d/%d/%d/%d" % [_encode(parcel_key),origin[1],origin[0],depth,width]
					options[key]={"core_key":key,"cells":_ordered_cells(cells),"width":width,"depth":depth}
	var result: Array[Dictionary] = []
	for key: String in options.keys():
		result.append(options[key])
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["core_key"]) < String(b["core_key"]))
	return result


func _select_formation_core(options: Array, feasible: Array) -> Dictionary:
	var witnesses: Dictionary = {}; for result: Dictionary in feasible: witnesses[result.get("selected_core_key","")] = int(witnesses.get(result.get("selected_core_key",""),0))+1
	var ranked: Array = options.duplicate(true); ranked.sort_custom(func(a:Dictionary,b:Dictionary)->bool: var aw:=int(witnesses.get(a["core_key"],0)); var bw:=int(witnesses.get(b["core_key"],0)); return aw>bw or (aw==bw and (a["cells"].size()>b["cells"].size() or (a["cells"].size()==b["cells"].size() and String(a["core_key"])<String(b["core_key"])))))
	return ranked[0].duplicate(true) if not ranked.is_empty() else {}


func _door_options(parcel_cells: Array, selected_doors: Array, envelopes: Dictionary, policy: QueueGeometryPolicy) -> Array[Dictionary]:
	var cells:=_cell_set(parcel_cells); var result:Array[Dictionary]=[]
	for door: Dictionary in selected_doors:
		var edge: Dictionary=door["edge"]; var point: Dictionary=edge["parcel_cell"]
		if not cells.has(_key([point["x"],point["y"]])): continue
		var envelope: Dictionary=envelopes.get(door["door_semantic_key"],{})
		result.append({"door_semantic_key":door["door_semantic_key"],"door_id":door.get("door_id"),"edge":edge,"entrance_cell":[point["x"],point["y"]],"queue_envelope_key":door["queue_envelope_key"],"queue_envelope_id":door.get("queue_envelope_id"),"queue_positions":envelope.get("positions",[]),"queue_policy_id":policy.policy_id,"queue_policy_revision":policy.policy_revision})
	result.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return String(a["door_semantic_key"])<String(b["door_semantic_key"])); return result


func _phase_a_request(parcel: Dictionary, formation_core: Dictionary, core_options: Array, doors: Array, zone_type: String) -> Dictionary:
	var frontage:Array=[]; for door: Dictionary in doors: frontage.append(door["edge"])
	return {"schema_id":"interior_phase_a_request","schema_version":2,"identity_mode":"PLAN_LOCAL","plan_local_parcel_key":parcel["parcel_key"],"parcel_id":null,"zone_type":zone_type,"usable_cells":parcel["cells"],"formation_core":formation_core,"profile_core_options":core_options,"frontage_edges":frontage,"wall_cells":_wall_cells(parcel["cells"]),"operational_door_options":doors,"operational_profile_ids":[],"zone_revision":null,"door_revision":null,"queue_revision":null}


func _suitability(key:String,freshness:String,suitability:String,count:int,codes:Array)->Dictionary:return {"parcel_key":key,"freshness":freshness,"suitability":suitability,"source_parity_fingerprint":null,"feasible_profile_count":count,"diagnostic_codes":codes}
func _fallback_scales(scale: String) -> Array[String]:
	match scale:
		"STANDARD": return ["STANDARD", "COMPACT", "LARGE"]
		"COMPACT": return ["COMPACT", "STANDARD", "LARGE"]
		_: return ["LARGE", "STANDARD", "COMPACT"]
func _band(policy:ParcelFormationPolicy,scale:String)->Array[int]:return policy.compact_area if scale=="COMPACT" else (policy.standard_area if scale=="STANDARD" else policy.large_area)
func _has_frontage(cells: Array, edges: Array) -> bool:
	var set := _cell_set(cells)
	for edge: Dictionary in edges:
		var point: Dictionary = edge.get("parcel_cell", {})
		if set.has(_key([point.get("x"), point.get("y")])):
			return true
	return false
func _wall_cells(cells: Array) -> Array[Array]:
	var set := _cell_set(cells)
	var result: Array[Array] = []
	for cell: Array in _ordered_cells(cells):
		for offset: Array in [[0,-1],[-1,0],[1,0],[0,1]]:
			if not set.has(_key([cell[0] + offset[0], cell[1] + offset[1]])):
				result.append(cell)
				break
	return result
func _compactness(cells: Array) -> int:
	var set := _cell_set(cells)
	var perimeter: int = 0
	for cell: Array in cells:
		for offset: Array in [[0,-1],[-1,0],[1,0],[0,1]]:
			if not set.has(_key([cell[0] + offset[0], cell[1] + offset[1]])):
				perimeter += 1
	return perimeter * perimeter * 100 / maxi(cells.size(), 1)
func _connected(cells: Array) -> bool:
	if cells.is_empty():
		return false
	var set := _cell_set(cells)
	var seen: Dictionary = {_key(cells[0]): true}
	var pending: Array = [cells[0]]
	while not pending.is_empty():
		var cell: Array = pending.pop_front()
		for offset: Array in [[0,-1],[-1,0],[1,0],[0,1]]:
			var neighbor: Array = [cell[0] + offset[0], cell[1] + offset[1]]
			var key := _key(neighbor)
			if set.has(key) and not seen.has(key):
				seen[key] = true
				pending.append(neighbor)
	return seen.size() == cells.size()
func _adjacent(cell: Array, cells: Array) -> bool:
	var set := _cell_set(cells)
	for offset: Array in [[0,-1],[-1,0],[1,0],[0,1]]:
		if set.has(_key([cell[0] + offset[0], cell[1] + offset[1]])):
			return true
	return false
func _difference(all_cells: Array, excluded: Array) -> Array[Array]:
	var set := _cell_set(excluded)
	var result: Array[Array] = []
	for cell: Array in _ordered_cells(all_cells):
		if not set.has(_key(cell)):
			result.append(cell)
	return result
func _first_cell(set: Dictionary) -> Array:
	var cells: Array[Array] = []
	for key: String in set.keys():
		cells.append(_parse_key(key))
	return _ordered_cells(cells)[0]
func _cell_set(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for cell: Variant in cells:
		result[_key(cell)] = true
	return result
func _key(cell:Variant)->String:return "%d,%d"%[int(cell[0]),int(cell[1])]
func _parse_key(key:String)->Array[int]:var p:=key.split(",");return [p[0].to_int(),p[1].to_int()]
func _ordered_cells(value: Array) -> Array[Array]:
	var result: Array[Array] = []
	for cell: Variant in value:
		result.append([int(cell[0]), int(cell[1])])
	result.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0]))
	return result
func _parcel_key(zone:String,origin:Array,ordinal:int)->String:return "jplan1/parcel/%s/%d/%d/%d"%[_encode(zone),origin[1],origin[0],ordinal]
func _encode(value:String)->String:return value.uri_encode().replace("/","%2F")
func _fingerprint(value:Variant,domain:String)->String:return String(CanonicalJsonFingerprint.new().fingerprint(value,domain,1).get("fingerprint",""))
func _failure(status:String)->Dictionary:return {"status":status,"parcels":[],"residual_decoration_cells":[],"diagnostics":[{"code":status,"path":"$","values":{}}]}
