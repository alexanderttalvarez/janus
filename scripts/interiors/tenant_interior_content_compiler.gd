## Compiles typed tenant-interior Resources into validated, deeply detached H1 values.
class_name TenantInteriorContentCompiler
extends RefCounted

const CONTENT_SCHEMA_VERSION: int = 1
const FINGERPRINT_DOMAIN: String = "JANUS_TENANT_INTERIOR_CONTENT"
const VALID_ROTATIONS: Array[int] = [0, 90, 180, 270]
const REQUIRED_SUBTYPE_IDS: Array[String] = [
	"arcade", "bank", "bookstore", "bowling_alley", "cafe", "cinema", "clinic", "department_store",
	"drinks_snack_kiosk", "electronics", "escape_room", "exhibition_hall", "fashion", "food_court", "gym",
	"hair_salon", "home_goods", "jewelry", "repair_shop", "sit_down_restaurant", "supermarket", "takeaway_food",
	"travel_agency", "vr_experience",
]
const VALID_TYPOLOGIES: Array[String] = [
	"HOST_SEATING", "COUNTER", "BROWSE_CHECKOUT", "SERVICE_BAY", "SCHEDULED_BATCH",
	"DEVICE_POOL", "COHORT_DEVICE_POOL", "OPEN_FLOW", "COUNTER_THEN_SEATING",
]


func compile(bundle: TenantInteriorContentBundle, require_production_paths: bool = true, require_complete_catalog: bool = false) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	if bundle == null:
		return _failure([_diagnostic("CONTENT_UNAVAILABLE", "$", {})])
	_validate_identity(bundle.bundle_id, bundle.revision, "$.bundle", diagnostics)
	var fixture_records: Array[Dictionary] = []
	var fixture_by_id: Dictionary = {}
	for index: int in range(bundle.fixtures.size()):
		var fixture: InteriorFixtureDefinition = bundle.fixtures[index]
		if fixture == null:
			diagnostics.append(_diagnostic("CONTENT_UNAVAILABLE", "$.fixtures[%d]" % index, {}))
			continue
		var record: Dictionary = fixture.to_record()
		_validate_fixture(fixture, record, "$.fixtures[%d]" % index, require_production_paths, diagnostics)
		_register_unique(fixture.fixture_id, record, fixture_by_id, "$.fixtures[%d].fixture_id" % index, diagnostics)
		fixture_records.append(record)
	var service_records: Array[Dictionary] = []
	var service_by_id: Dictionary = {}
	for index: int in range(bundle.service_policies.size()):
		var policy: ServicePolicyDefinition = bundle.service_policies[index]
		if policy == null:
			diagnostics.append(_diagnostic("CONTENT_UNAVAILABLE", "$.service_policies[%d]" % index, {}))
			continue
		var record: Dictionary = policy.to_record()
		_validate_service_policy(record, "$.service_policies[%d]" % index, diagnostics)
		_register_unique(policy.service_policy_id, record, service_by_id, "$.service_policies[%d].service_policy_id" % index, diagnostics)
		service_records.append(record)
	var profile_records: Array[Dictionary] = []
	var profile_by_id: Dictionary = {}
	for index: int in range(bundle.operational_profiles.size()):
		var profile: OperationalProfileDefinition = bundle.operational_profiles[index]
		if profile == null:
			diagnostics.append(_diagnostic("CONTENT_UNAVAILABLE", "$.operational_profiles[%d]" % index, {}))
			continue
		var record: Dictionary = profile.to_record()
		_validate_operational_profile(record, fixture_by_id, service_by_id, "$.operational_profiles[%d]" % index, diagnostics)
		_register_unique(profile.operational_profile_id, record, profile_by_id, "$.operational_profiles[%d].operational_profile_id" % index, diagnostics)
		profile_records.append(record)
	var tenant_records: Array[Dictionary] = []
	var tenant_by_id: Dictionary = {}
	for index: int in range(bundle.tenant_profiles.size()):
		var tenant_profile: InteriorTenantProfileDefinition = bundle.tenant_profiles[index]
		if tenant_profile == null:
			diagnostics.append(_diagnostic("CONTENT_UNAVAILABLE", "$.tenant_profiles[%d]" % index, {}))
			continue
		var record: Dictionary = tenant_profile.to_record()
		_validate_tenant_profile(record, profile_by_id, "$.tenant_profiles[%d]" % index, diagnostics)
		_register_unique(tenant_profile.profile_id, record, tenant_by_id, "$.tenant_profiles[%d].profile_id" % index, diagnostics)
		tenant_records.append(record)
	if bundle.visitor_policy == null:
		diagnostics.append(_diagnostic("CONTENT_UNAVAILABLE", "$.visitor_policy", {}))
	if bundle.planning_policy == null:
		diagnostics.append(_diagnostic("CONTENT_UNAVAILABLE", "$.planning_policy", {}))
	var visitor_record: Dictionary = bundle.visitor_policy.to_record() if bundle.visitor_policy != null else {}
	var planning_record: Dictionary = bundle.planning_policy.to_record() if bundle.planning_policy != null else {}
	_validate_visitor_policy(visitor_record, "$.visitor_policy", diagnostics)
	_validate_planning_policy(planning_record, "$.planning_policy", diagnostics)
	if require_complete_catalog:
		_validate_catalog_completeness(profile_records, tenant_records, diagnostics)
	fixture_records.sort_custom(_compare_fixture_records)
	service_records.sort_custom(_compare_service_records)
	profile_records.sort_custom(_compare_profile_records)
	tenant_records.sort_custom(_compare_tenant_records)
	if not diagnostics.is_empty():
		return _failure(diagnostics)
	var semantic: Dictionary = {
		"schema_version": CONTENT_SCHEMA_VERSION,
		"bundle_id": bundle.bundle_id,
		"revision": bundle.revision,
		"fixtures": fixture_records,
		"service_policies": service_records,
		"operational_profiles": profile_records,
		"tenant_profiles": tenant_records,
		"visitor_policy": visitor_record,
		"planning_policy": planning_record,
	}
	var hash_result: Dictionary = CanonicalJsonFingerprint.new().fingerprint(semantic, FINGERPRINT_DOMAIN, CONTENT_SCHEMA_VERSION)
	if not bool(hash_result.get("valid", false)):
		return _failure(hash_result.get("diagnostics", []))
	var snapshot: CompiledTenantInteriorContent = CompiledTenantInteriorContent.new()
	if not snapshot.initialize(semantic, String(hash_result["canonical_json"]), String(hash_result["fingerprint"])):
		return _failure([_diagnostic("CONTENT_SNAPSHOT_INVALID", "$", {})])
	var feasibility_diagnostics: Array[Dictionary] = _validate_minimum_program_feasibility(semantic)
	if not feasibility_diagnostics.is_empty():
		return _failure(feasibility_diagnostics)
	return {
		"valid": true,
		"snapshot": snapshot,
		"content": snapshot.get_content(),
		"canonical_json": snapshot.get_canonical_json(),
		"fingerprint": snapshot.get_fingerprint(),
		"diagnostics": [],
	}


func validate_visual(visual: FixtureVisualDefinition, path: String = "$.visual", require_production_path: bool = true) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if visual == null:
		return [_diagnostic("CONTENT_UNAVAILABLE", path, {})]
	_validate_identity(visual.visual_id, visual.revision, path, diagnostics)
	if visual.scene == null:
		diagnostics.append(_diagnostic("VISUAL_DEFAULT_MISSING", path + ".scene", {}))
		return diagnostics
	if require_production_path and not visual.scene.resource_path.begins_with("res://"):
		diagnostics.append(_diagnostic("VISUAL_NOT_PRODUCTION_RESOURCE", path + ".scene", {"resource_path": visual.scene.resource_path}))
	var minimum: Vector3i = visual.envelope_min_millimeters
	var maximum: Vector3i = visual.envelope_max_millimeters
	if minimum.x >= maximum.x or minimum.y >= maximum.y or minimum.z >= maximum.z:
		diagnostics.append(_diagnostic("VISUAL_ENVELOPE_INVALID", path, {}))
	var packed_diagnostics: Array[Dictionary] = _validate_packed_scene_state(visual.scene.get_state(), path + ".scene")
	diagnostics.append_array(packed_diagnostics)
	if not packed_diagnostics.is_empty():
		return diagnostics
	var root: Node = visual.scene.instantiate()
	if not root is Node3D:
		diagnostics.append(_diagnostic("VISUAL_ROOT_INVALID", path + ".scene", {"type": root.get_class()}))
		root.free()
		return diagnostics
	var visual_count: int = 0
	for node: Node in _walk_nodes(root):
		if node.get_script() != null:
			diagnostics.append(_diagnostic("VISUAL_SCRIPT_FORBIDDEN", path + ".scene", {"node": String(node.name)}))
		if node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D or node is NavigationLink3D or node is NavigationObstacle3D:
			diagnostics.append(_diagnostic("VISUAL_BEHAVIOR_FORBIDDEN", path + ".scene", {"node": String(node.name), "type": node.get_class()}))
		if node is MeshInstance3D:
			visual_count += 1
			_validate_mesh_bounds(node as MeshInstance3D, root as Node3D, minimum, maximum, path, diagnostics)
	if visual_count == 0:
		diagnostics.append(_diagnostic("VISUAL_GEOMETRY_MISSING", path + ".scene", {}))
	root.free()
	return diagnostics


func _validate_fixture(fixture: InteriorFixtureDefinition, record: Dictionary, path: String, require_production_paths: bool, diagnostics: Array[Dictionary]) -> void:
	_validate_identity(fixture.fixture_id, fixture.revision, path, diagnostics)
	_validate_cells(record["occupied_cells"], path + ".occupied_cells", true, diagnostics)
	_validate_cells(record["clearance_cells"], path + ".clearance_cells", false, diagnostics)
	var occupied_keys: Dictionary = {}
	for occupied_cell: Array in record["occupied_cells"]:
		occupied_keys["%d,%d" % [occupied_cell[0], occupied_cell[1]]] = true
	for clearance_cell: Array in record["clearance_cells"]:
		if occupied_keys.has("%d,%d" % [clearance_cell[0], clearance_cell[1]]):
			diagnostics.append(_diagnostic("FIXTURE_CLEARANCE_OVERLAP", path + ".clearance_cells", {"cell": clearance_cell}))
	_validate_rotations(record["allowed_rotations"], path + ".allowed_rotations", diagnostics)
	if String(record["interaction_face"]).is_empty() or String(record["placement_rule"]).is_empty():
		diagnostics.append(_diagnostic("FIXTURE_RULE_INVALID", path, {}))
	if int(record["capacity"]) > 0 and String(record["capacity_token"]) == "NONE":
		diagnostics.append(_diagnostic("FIXTURE_CAPACITY_TOKEN_MISSING", path + ".capacity_token", {}))
	diagnostics.append_array(validate_visual(fixture.default_visual, path + ".default_visual", require_production_paths))
	var visual_ids: Dictionary = {}
	if fixture.default_visual != null:
		visual_ids[fixture.default_visual.visual_id] = true
	for index: int in range(fixture.visual_variants.size()):
		var variant: FixtureVisualDefinition = fixture.visual_variants[index]
		diagnostics.append_array(validate_visual(variant, "%s.visual_variants[%d]" % [path, index], require_production_paths))
		if variant != null and visual_ids.has(variant.visual_id):
			diagnostics.append(_diagnostic("DUPLICATE_ID", "%s.visual_variants[%d].visual_id" % [path, index], {"id": variant.visual_id}))
		elif variant != null:
			visual_ids[variant.visual_id] = true


func _validate_service_policy(record: Dictionary, path: String, diagnostics: Array[Dictionary]) -> void:
	_validate_identity(String(record.get("service_policy_id", "")), int(record.get("revision", 0)), path, diagnostics)
	if not VALID_TYPOLOGIES.has(String(record.get("typology", ""))):
		diagnostics.append(_diagnostic("SERVICE_TYPOLOGY_INVALID", path + ".typology", {"typology": record.get("typology", "")}))
	var total_duration: int = int(record.get("turnover_ticks", 0))
	var stages: Array = record.get("stages", [])
	if stages.is_empty():
		diagnostics.append(_diagnostic("SERVICE_STAGE_INVALID", path + ".stages", {}))
	for index: int in range(stages.size()):
		var stage: Dictionary = stages[index]
		if String(stage.get("stage_id", "")).is_empty() or int(stage.get("duration_ticks", 0)) <= 0:
			diagnostics.append(_diagnostic("SERVICE_STAGE_INVALID", "%s.stages[%d]" % [path, index], {}))
		total_duration += int(stage.get("duration_ticks", 0))
	if String(record.get("typology", "")) == "SCHEDULED_BATCH" and (int(record.get("cadence_ticks", 0)) <= 0 or total_duration > int(record.get("cadence_ticks", 0))):
		diagnostics.append(_diagnostic("SERVICE_CADENCE_INVALID", path, {"work_ticks": total_duration, "cadence_ticks": record.get("cadence_ticks", 0)}))
	if int(record.get("queue_cap", -1)) < 0 or (record.get("capacity_tokens", []) as Array).is_empty():
		diagnostics.append(_diagnostic("SERVICE_CAPACITY_INVALID", path, {}))


func _validate_operational_profile(record: Dictionary, fixtures: Dictionary, services: Dictionary, path: String, diagnostics: Array[Dictionary]) -> void:
	_validate_identity(String(record.get("operational_profile_id", "")), int(record.get("revision", 0)), path, diagnostics)
	if String(record.get("subtype_id", "")).is_empty() or String(record.get("zone_type", "")).is_empty():
		diagnostics.append(_diagnostic("PROFILE_IDENTITY_INVALID", path, {}))
	var minimum_area: int = int(record.get("minimum_area", 0))
	var core_area: int = int(record.get("core_width", 0)) * int(record.get("core_depth", 0))
	if minimum_area <= 0 or core_area <= 0 or minimum_area < core_area or int(record.get("target_area_min", 0)) < minimum_area or int(record.get("target_area_max", 0)) < int(record.get("target_area_min", 0)):
		diagnostics.append(_diagnostic("PROFILE_AREA_CORE_INVALID", path, {}))
	_validate_rotations(record.get("core_rotations", []), path + ".core_rotations", diagnostics)
	if not services.has(String(record.get("service_policy_id", ""))):
		diagnostics.append(_diagnostic("REFERENCE_MISSING", path + ".service_policy_id", {"id": record.get("service_policy_id", "")}))
	var mandatory_area: int = 0
	var mandatory_capacity: int = 0
	var service_tokens: Array = (services.get(String(record.get("service_policy_id", "")), {}) as Dictionary).get("capacity_tokens", [])
	var program: Array = record.get("fixture_program", [])
	if program.is_empty():
		diagnostics.append(_diagnostic("MANDATORY_FIXTURE_FAILURE", path + ".fixture_program", {}))
	for index: int in range(program.size()):
		var entry: Dictionary = program[index]
		var fixture_id: String = String(entry.get("fixture_id", ""))
		var count: int = int(entry.get("count", 0))
		if not fixtures.has(fixture_id) or count <= 0:
			diagnostics.append(_diagnostic("REFERENCE_MISSING", "%s.fixture_program[%d]" % [path, index], {"id": fixture_id}))
			continue
		var fixture: Dictionary = fixtures[fixture_id]
		if String(entry.get("kind", "")) != "REPEATABLE":
			mandatory_area += (fixture.get("occupied_cells", []) as Array).size() * count
			mandatory_capacity += int(fixture.get("capacity", 0)) * count
		if int(fixture.get("capacity", 0)) > 0 and not service_tokens.has(fixture.get("capacity_token", "")):
			diagnostics.append(_diagnostic("SERVICE_TOKEN_MISMATCH", "%s.fixture_program[%d]" % [path, index], {"token": fixture.get("capacity_token", "")}))
	if mandatory_area > minimum_area:
		diagnostics.append(_diagnostic("MANDATORY_FIXTURE_FAILURE", path, {"mandatory_area": mandatory_area, "minimum_area": minimum_area}))
	if mandatory_capacity <= 0:
		diagnostics.append(_diagnostic("SERVICE_CAPACITY_INVALID", path, {"mandatory_capacity": mandatory_capacity}))
	if services.has(String(record.get("service_policy_id", ""))) and int(record.get("queue_cap", 0)) != int((services[record["service_policy_id"]] as Dictionary).get("queue_cap", -1)):
		diagnostics.append(_diagnostic("SERVICE_QUEUE_POLICY_MISMATCH", path, {}))


func _validate_minimum_program_feasibility(semantic: Dictionary) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var proof_content: Dictionary = semantic.duplicate(true)
	(proof_content["planning_policy"] as Dictionary)["placement_validation_budget"] = 1000000
	var proof_hash: Dictionary = CanonicalJsonFingerprint.new().fingerprint(proof_content, FINGERPRINT_DOMAIN, CONTENT_SCHEMA_VERSION)
	if not bool(proof_hash.get("valid", false)):
		return proof_hash.get("diagnostics", [])
	var proof_snapshot: CompiledTenantInteriorContent = CompiledTenantInteriorContent.new()
	if not proof_snapshot.initialize(proof_content, String(proof_hash["canonical_json"]), String(proof_hash["fingerprint"])):
		return [_diagnostic("CONTENT_SNAPSHOT_INVALID", "$", {})]
	var planner: InteriorLayoutPlanner = InteriorLayoutPlanner.new()
	for index: int in range((semantic.get("operational_profiles", []) as Array).size()):
		var profile: Dictionary = semantic["operational_profiles"][index]
		var width: int = int(profile.get("core_width", 0))
		var depth: int = maxi(int(profile.get("core_depth", 0)), ceili(float(int(profile.get("minimum_area", 0))) / float(maxi(width, 1))))
		if width * depth > int(profile.get("target_area_max", 0)):
			diagnostics.append(_diagnostic("MANDATORY_FIXTURE_FAILURE", "$.operational_profiles[%d]" % index, {"reason": "minimum_rectangle_exceeds_target"}))
			continue
		var usable: Array[Array] = []
		var core: Array[Array] = []
		var frontage: Array[Array] = []
		var walls: Array[Array] = []
		for y: int in range(depth):
			for x: int in range(width):
				usable.append([x, y])
				if x < int(profile.get("core_width", 0)) and y < int(profile.get("core_depth", 0)):
					core.append([x, y])
				if x == 0:
					frontage.append([x, y])
				if x == 0 or y == 0 or x == width - 1 or y == depth - 1:
					walls.append([x, y])
		var door: Array[int] = [0, depth - 1]
		var queue: Array = [[-1, depth - 1]] if bool(profile.get("queue_required", false)) else []
		var door_edge: Dictionary = {"parcel_cell":{"x":door[0],"y":door[1]},"direction":"WEST","access_kind":"EXPLICIT_CIRCULATION","access_cell":{"x":-1,"y":door[1]},"public_band_access_edge_id":null}
		var frontage_edges: Array[Dictionary] = []
		for frontage_cell: Array in frontage:
			frontage_edges.append({"parcel_cell":{"x":frontage_cell[0],"y":frontage_cell[1]},"direction":"WEST","access_kind":"EXPLICIT_CIRCULATION","access_cell":{"x":-1,"y":frontage_cell[1]},"public_band_access_edge_id":null})
		var core_record: Dictionary = {"core_key":"content-proof/core","cells":core,"width":profile.get("core_width",0),"depth":profile.get("core_depth",0)}
		var request: Dictionary = {
			"schema_id":"interior_phase_a_request","schema_version":2,"identity_mode":"PLAN_LOCAL",
			"plan_local_parcel_key": "content-proof/%s" % profile.get("operational_profile_id", ""), "parcel_id":null,
			"zone_type": profile.get("zone_type", ""), "usable_cells": usable,
			"formation_core":core_record,"profile_core_options":[core_record],"frontage_edges":frontage_edges,"wall_cells":walls,
			"operational_door_options":[{"door_semantic_key":"content-proof/door","door_id":null,"edge":door_edge,"entrance_cell":door,"queue_envelope_key":"content-proof/envelope","queue_envelope_id":null,"queue_positions":[{"position_id":"content-proof/position"}] if bool(profile.get("queue_required",false)) else [],"queue_policy_id":"tenant_exterior_queue_geometry","queue_policy_revision":1}],
			"operational_profile_ids": [profile.get("operational_profile_id", "")], "zone_revision":null,"door_revision":null,"queue_revision":null,
		}
		var proof: Dictionary = planner.plan_phase_a(request, proof_snapshot)
		if String(proof.get("status", "")) != InteriorLayoutPlanner.STATUS_VALID:
			diagnostics.append(_diagnostic("MANDATORY_FIXTURE_FAILURE", "$.operational_profiles[%d]" % index, {"status": proof.get("status", ""), "diagnostics": proof.get("diagnostics", [])}))
	return diagnostics


func _validate_catalog_completeness(profiles: Array[Dictionary], tenant_profiles: Array[Dictionary], diagnostics: Array[Dictionary]) -> void:
	var operational_subtypes: Dictionary = {}
	for profile: Dictionary in profiles:
		operational_subtypes[String(profile.get("subtype_id", ""))] = true
	var tier_one_subtypes: Dictionary = {}
	for profile: Dictionary in tenant_profiles:
		if int(profile.get("tier", 0)) == 1:
			tier_one_subtypes[String(profile.get("subtype_id", ""))] = true
	for subtype_id: String in REQUIRED_SUBTYPE_IDS:
		if not operational_subtypes.has(subtype_id):
			diagnostics.append(_diagnostic("REQUIRED_SUBTYPE_MISSING", "$.operational_profiles", {"subtype_id": subtype_id}))
		if not tier_one_subtypes.has(subtype_id):
			diagnostics.append(_diagnostic("TIER_ONE_CANDIDATE_MISSING", "$.tenant_profiles", {"subtype_id": subtype_id}))


func _validate_tenant_profile(record: Dictionary, profiles: Dictionary, path: String, diagnostics: Array[Dictionary]) -> void:
	_validate_identity(String(record.get("profile_id", "")), int(record.get("candidate_revision", 0)), path, diagnostics)
	var operational_id: String = String(record.get("operational_profile_id", ""))
	if not profiles.has(operational_id):
		diagnostics.append(_diagnostic("REFERENCE_MISSING", path + ".operational_profile_id", {"id": operational_id}))
		return
	var operational: Dictionary = profiles[operational_id]
	if String(record.get("subtype_id", "")) != String(operational.get("subtype_id", "")) or String(record.get("zone_type", "")) != String(operational.get("zone_type", "")):
		diagnostics.append(_diagnostic("PROFILE_ZONE_SUBTYPE_MISMATCH", path, {}))
	if String(record.get("theme_id", "")).is_empty() or int(record.get("tier", 0)) <= 0:
		diagnostics.append(_diagnostic("PROFILE_IDENTITY_INVALID", path, {}))


func _validate_visitor_policy(record: Dictionary, path: String, diagnostics: Array[Dictionary]) -> void:
	if record.is_empty():
		return
	_validate_identity(String(record.get("visitor_policy_id", "")), int(record.get("revision", 0)), path, diagnostics)
	if record.get("goal_count_weights", []) != [40, 45, 15] or not bool(record.get("draws_with_replacement", false)):
		diagnostics.append(_diagnostic("VISITOR_DISTRIBUTION_INVALID", path, {}))
	if int(record.get("wait_tolerance_min_ticks", 0)) != 2 or int(record.get("wait_tolerance_max_ticks", 0)) != 8:
		diagnostics.append(_diagnostic("VISITOR_WAIT_POLICY_INVALID", path, {}))
	if String(record.get("empty_category_goal_id", "")) != "BROWSING" or String(record.get("leaving_goal_id", "")) != "LEAVING":
		diagnostics.append(_diagnostic("VISITOR_GOAL_POLICY_INVALID", path, {}))


func _validate_planning_policy(record: Dictionary, path: String, diagnostics: Array[Dictionary]) -> void:
	if record.is_empty():
		return
	_validate_identity(String(record.get("planning_policy_id", "")), int(record.get("revision", 0)), path, diagnostics)
	var revision: int = int(record.get("revision", 0))
	if int(record.get("placement_validation_budget", 0)) <= 0 or int(record.get("occupied_area_ceiling_percent", 0)) <= 0 or int(record.get("occupied_area_ceiling_percent", 0)) > 100 or int(record.get("comfort_extra_modules", -1)) < 0:
		diagnostics.append(_diagnostic("PLANNING_POLICY_INVALID", path, {}))
	if int(record.get("excellent_tickets", 0)) <= 0 or int(record.get("good_tickets", 0)) <= 0 or int(record.get("acceptable_tickets", 0)) <= 0 or record.get("rotation_order", []) != [0, 90, 180, 270]:
		diagnostics.append(_diagnostic("PLANNING_POLICY_INVALID", path, {}))
	if revision == 1 and (int(record.get("placement_validation_budget", 0)) != 10000 or int(record.get("occupied_area_ceiling_percent", 0)) != 75 or int(record.get("comfort_extra_modules", 0)) != 2 or int(record.get("excellent_tickets", 0)) != 6 or int(record.get("good_tickets", 0)) != 3 or int(record.get("acceptable_tickets", 0)) != 1):
		diagnostics.append(_diagnostic("PLANNING_POLICY_REVISION_MISMATCH", path, {}))


func _validate_cells(cells: Array, path: String, required: bool, diagnostics: Array[Dictionary]) -> void:
	if required and cells.is_empty():
		diagnostics.append(_diagnostic("FIXTURE_MASK_INVALID", path, {}))
	var seen: Dictionary = {}
	for index: int in range(cells.size()):
		var cell: Array = cells[index]
		if cell.size() != 2:
			diagnostics.append(_diagnostic("FIXTURE_MASK_INVALID", "%s[%d]" % [path, index], {}))
			continue
		var key: String = "%d,%d" % [int(cell[0]), int(cell[1])]
		if seen.has(key):
			diagnostics.append(_diagnostic("FIXTURE_MASK_INVALID", "%s[%d]" % [path, index], {"duplicate": key}))
		seen[key] = true


func _validate_rotations(rotations: Array, path: String, diagnostics: Array[Dictionary]) -> void:
	if rotations.is_empty():
		diagnostics.append(_diagnostic("ROTATION_INVALID", path, {}))
	var seen: Dictionary = {}
	for rotation: Variant in rotations:
		if not rotation is int or not VALID_ROTATIONS.has(int(rotation)) or seen.has(int(rotation)):
			diagnostics.append(_diagnostic("ROTATION_INVALID", path, {"rotation": rotation}))
		seen[int(rotation)] = true


func _validate_identity(id: String, revision: int, path: String, diagnostics: Array[Dictionary]) -> void:
	if id.is_empty() or id != id.strip_edges() or revision <= 0:
		diagnostics.append(_diagnostic("CONTENT_IDENTITY_INVALID", path, {"id": id, "revision": revision}))


func _register_unique(id: String, record: Dictionary, catalog: Dictionary, path: String, diagnostics: Array[Dictionary]) -> void:
	if catalog.has(id):
		diagnostics.append(_diagnostic("DUPLICATE_ID", path, {"id": id}))
	else:
		catalog[id] = record.duplicate(true)


func _validate_packed_scene_state(state: SceneState, path: String) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var allowed_types: Array[StringName] = [&"Node3D", &"MeshInstance3D"]
	for node_index: int in range(state.get_node_count()):
		var node_type: StringName = state.get_node_type(node_index)
		if not allowed_types.has(node_type):
			diagnostics.append(_diagnostic("VISUAL_BEHAVIOR_FORBIDDEN", path, {"node": String(state.get_node_name(node_index)), "type": String(node_type)}))
		for property_index: int in range(state.get_node_property_count(node_index)):
			var property_name: StringName = state.get_node_property_name(node_index, property_index)
			var property_value: Variant = state.get_node_property_value(node_index, property_index)
			if property_name == &"script" and property_value != null:
				diagnostics.append(_diagnostic("VISUAL_SCRIPT_FORBIDDEN", path, {"node": String(state.get_node_name(node_index))}))
			if node_index == 0 and property_name == &"transform" and property_value is Transform3D and property_value != Transform3D.IDENTITY:
				diagnostics.append(_diagnostic("VISUAL_ROOT_TRANSFORM_INVALID", path, {}))
	return diagnostics


func _walk_nodes(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]
	var index: int = 0
	while index < nodes.size():
		for child: Node in nodes[index].get_children():
			nodes.append(child)
		index += 1
	return nodes


func _validate_mesh_bounds(mesh_instance: MeshInstance3D, root: Node3D, minimum: Vector3i, maximum: Vector3i, path: String, diagnostics: Array[Dictionary]) -> void:
	if mesh_instance.mesh == null:
		diagnostics.append(_diagnostic("VISUAL_GEOMETRY_MISSING", path, {"node": String(mesh_instance.name)}))
		return
	var relative: Transform3D = mesh_instance.transform
	var parent: Node = mesh_instance.get_parent()
	while parent != null and parent != root:
		if parent is Node3D:
			relative = (parent as Node3D).transform * relative
		parent = parent.get_parent()
	var bounds: AABB = mesh_instance.mesh.get_aabb()
	for x_index: int in range(2):
		for y_index: int in range(2):
			for z_index: int in range(2):
				var point: Vector3 = bounds.position + Vector3(bounds.size.x * x_index, bounds.size.y * y_index, bounds.size.z * z_index)
				var transformed: Vector3 = relative * point
				var millimeters: Vector3i = Vector3i(roundi(transformed.x * 1000.0), roundi(transformed.y * 1000.0), roundi(transformed.z * 1000.0))
				if millimeters.x < minimum.x or millimeters.y < minimum.y or millimeters.z < minimum.z or millimeters.x > maximum.x or millimeters.y > maximum.y or millimeters.z > maximum.z:
					diagnostics.append(_diagnostic("VISUAL_BOUNDS_EXCEEDED", path, {"node": String(mesh_instance.name), "point_millimeters": [millimeters.x, millimeters.y, millimeters.z]}))
					return


func _failure(diagnostics: Array) -> Dictionary:
	return {"valid": false, "snapshot": null, "content": {}, "canonical_json": "", "fingerprint": "", "diagnostics": diagnostics.duplicate(true)}


func _diagnostic(code: String, path: String, values: Dictionary) -> Dictionary:
	return {"code": code, "path": path, "values": values.duplicate(true)}


func _compare_fixture_records(left: Dictionary, right: Dictionary) -> bool:
	return String(left["fixture_id"]) < String(right["fixture_id"])


func _compare_service_records(left: Dictionary, right: Dictionary) -> bool:
	return String(left["service_policy_id"]) < String(right["service_policy_id"])


func _compare_profile_records(left: Dictionary, right: Dictionary) -> bool:
	return String(left["operational_profile_id"]) < String(right["operational_profile_id"])


func _compare_tenant_records(left: Dictionary, right: Dictionary) -> bool:
	return String(left["profile_id"]) < String(right["profile_id"])
