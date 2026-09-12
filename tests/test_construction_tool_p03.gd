## P03 normal-play ground acquisition/corridor and ADR 38 invalidation tests.
extends SceneTree

class FakePresentation extends RefCounted:
	var gateway: UIIntentGateway

	func _init(value: UIIntentGateway) -> void:
		gateway = value

	func submit_intent_preview(request: Dictionary) -> Dictionary:
		return gateway.submit_preview(request)

	func submit_intent_confirm(request: Dictionary) -> Dictionary:
		return gateway.submit_confirm(request)


class FakeProgression extends DistrictRuntimePorts.DistrictProgressionPort:
	func get_policy_snapshot() -> Dictionary:
		return {
			"schema_version": 1,
			"revision": 1,
			"elevation_eligibility": [0],
			"construction_capabilities": ["corridor"],
			"selected_plot_ids": [],
			"god_mode": false,
		}


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_invalidation_matrix()
	_test_normal_play_ground_flow()
	print("ConstructionTool P03 tests: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		push_error("[FAIL] %s" % message)


func _test_invalidation_matrix() -> void:
	var acquire: String = DistrictRuntime.OP_ACQUIRE_SPACE
	_assert(not ProjectionCoordinator.invalidates_district_operation(acquire), "acquisition does not replace the base H4 root")
	_assert(PublicRealmProjection.invalidation_for_operation(acquire) == PublicRealmProjection.InvalidationScope.NONE, "acquisition does not rebuild H5 geometry or traversal")
	_assert(not CameraGatewayProjection.invalidates_district_operation(acquire), "acquisition does not rebuild H6 camera/gateway facts")
	_assert(not TrafficTopology.invalidates_district_operation(acquire), "acquisition does not rebuild H7 traffic")
	_assert(not WallManager.invalidates_district_operation(acquire), "acquisition does not rebuild walls")
	_assert(PublicRealmProjection.invalidation_for_operation(DistrictRuntime.OP_ACQUIRE_SECTION) == PublicRealmProjection.InvalidationScope.GEOMETRY and PublicRealmProjection.invalidation_for_operation(DistrictRuntime.OP_CONVERT_STREET) == PublicRealmProjection.InvalidationScope.GEOMETRY, "H5 geometry invalidation is limited to ownership and street conversion")
	_assert(PublicRealmProjection.invalidation_for_operation(DistrictRuntime.OP_CONSTRUCT) == PublicRealmProjection.InvalidationScope.TOPOLOGY, "corridor construction refreshes H5 traversal without geometry replacement")
	_assert(CameraGatewayProjection.invalidates_district_operation(DistrictRuntime.OP_CONSTRUCT) and not TrafficTopology.invalidates_district_operation(DistrictRuntime.OP_CONSTRUCT), "construction refreshes H6 topology consumers but not H7 road topology")
	_assert(WallManager.invalidates_district_operation(DistrictRuntime.OP_CONSTRUCT), "construction invalidates configured-floor walls")


func _test_normal_play_ground_flow() -> void:
	var resolver: RefCounted = load("res://scripts/resources/district_layout_resolver.gd").new()
	var definition: ProductionDistrictDefinition = ProductionDistrictDefinition.new()
	var resolution: Dictionary = resolver.resolve(definition.get_raw_record())
	_assert(bool(resolution.get("valid", false)), "production district content resolves for the normal-play flow")
	if not bool(resolution.get("valid", false)):
		return
	var snapshot: ResolvedDistrictSnapshot = resolution.get("snapshot") as ResolvedDistrictSnapshot
	var plot: Dictionary = snapshot.get_data().get("plots", [])[0]
	var floor: Dictionary = _floor_at(snapshot, String(plot.get("id", "")), 0)
	var cell_value: Array = plot.get("buildability_mask", [])[0]
	var cell := Vector2i(int(cell_value[0]), int(cell_value[1]))

	var economy: EconomyManager = EconomyManager.new()
	root.add_child(economy)
	_assert(bool(economy.set_policy_snapshot(EconomyPolicySnapshot.approved_values()).get("valid", false)), "normal-play flow uses the approved Economy policy")
	var zone_manager: ZoneManager = ZoneManager.new()
	root.add_child(zone_manager)
	var ports: DistrictRuntimePorts.DistrictRuntimePortsBundle = DistrictRuntimePorts.DistrictRuntimePortsBundle.new()
	var economy_port: DistrictRuntimePorts.EconomyManagerPort = DistrictRuntimePorts.EconomyManagerPort.new()
	var zone_port: DistrictRuntimePorts.ZoneManagerPort = DistrictRuntimePorts.ZoneManagerPort.new()
	economy_port.initialize(economy)
	zone_port.initialize(zone_manager)
	ports.initialize(economy_port, zone_port, FakeProgression.new())

	var runtime: DistrictRuntime = DistrictRuntime.new()
	root.add_child(runtime)
	_assert(bool(runtime.configure_session_gate(SessionMutationGate.new()).get("valid", false)), "normal-play runtime owns one session gate")
	runtime.configure_ports(ports)
	_assert(bool(runtime.create_session(snapshot).get("valid", false)), "production session starts with sparse acquired/constructed state")

	var owner: ConstructionIntentGateway = ConstructionIntentGateway.new()
	_assert(bool(owner.initialize(runtime).get("valid", false)), "construction owner adapter initializes against production DistrictRuntime")
	var ui_gateway: UIIntentGateway = UIIntentGateway.new()
	ui_gateway.register_owner(ConstructionIntentGateway.OWNER_ID, owner)
	var presentation: FakePresentation = FakePresentation.new(ui_gateway)
	var projection: ProjectionCoordinator = ProjectionCoordinator.new()
	var tool: ConstructionTool = ConstructionTool.new()
	var address: Dictionary = {
		"runtime_plot_id": String(plot.get("id", "")),
		"floor_id": String(floor.get("id", "")),
		"elevation": 0,
	}
	_assert(bool(tool.configure(runtime, projection, presentation, address).get("valid", false)), "ConstructionTool receives explicit production dependencies and G address")

	var initial_balance: int = economy.balance
	tool.activate(ConstructionTool.MODE_ACQUIRE)
	var acquire_preview: Dictionary = tool.select_cell(cell)
	_assert(bool(acquire_preview.get("valid", false)) and int(acquire_preview.get("quote", {}).get("value", -1)) == 1000, "Acquire Ground Space preview exposes the source-backed 1,000-Kred quote")
	_assert(runtime.get_revision() == 0 and economy.balance == initial_balance, "acquisition preview has no committed side effect")
	var acquire_confirm: Dictionary = tool.confirm_selected()
	_assert(bool(acquire_confirm.get("valid", false)) and runtime.get_revision() == 1 and economy.balance == initial_balance - 1000, "acquisition confirm commits once through UIIntentGateway and Economy")
	var acquired_floor: Dictionary = _floor_state(runtime.get_state(), String(floor.get("id", "")))
	_assert(acquired_floor.get("acquired_cells", []).has([cell.x, cell.y]) and acquired_floor.get("constructed_cells", []).is_empty() and acquired_floor.get("explicit_circulation_cells", []).is_empty(), "acquisition changes sparse rights without fabricating construction or circulation")
	_assert(not runtime.get_gate().is_held(), "acquisition returns with the synchronous session gate released")
	_assert(tool.get_selected_cell() == cell and not tool.can_confirm() and tool.get_status_text().contains("Committed"), "successful acquisition retains non-confirmable transient feedback")

	tool.activate(ConstructionTool.MODE_CORRIDOR)
	var corridor_preview: Dictionary = tool.select_cell(cell)
	_assert(bool(corridor_preview.get("valid", false)) and int(corridor_preview.get("quote", {}).get("value", -1)) == 0, "Build Corridor preview uses the approved zero-Kred policy path")
	var corridor_confirm: Dictionary = tool.confirm_selected()
	_assert(bool(corridor_confirm.get("valid", false)) and runtime.get_revision() == 2 and economy.balance == initial_balance - 1000, "corridor confirm revalidates and commits without an additional charge")
	_assert(String(corridor_confirm.get("envelope", {}).get("delta", {}).get("operation", "")) == DistrictRuntime.OP_CONSTRUCT, "corridor commit publishes the canonical CONSTRUCT operation for affected-scope dispatch")
	var constructed_floor: Dictionary = _floor_state(runtime.get_state(), String(floor.get("id", "")))
	_assert(constructed_floor.get("constructed_cells", []).has([cell.x, cell.y]) and constructed_floor.get("explicit_circulation_cells", []).has([cell.x, cell.y]), "corridor commit creates constructed and explicit-circulation membership")
	_assert(runtime.get_state().get("construction_records", []).is_empty(), "corridor persists no duplicate construction record")
	_assert(not runtime.get_gate().is_held(), "corridor returns with the synchronous session gate released")

	var preview_cell_value: Array = plot.get("buildability_mask", [])[1]
	var competing_cell_value: Array = plot.get("buildability_mask", [])[2]
	var preview_cell := Vector2i(int(preview_cell_value[0]), int(preview_cell_value[1]))
	var competing_cell := Vector2i(int(competing_cell_value[0]), int(competing_cell_value[1]))
	tool.activate(ConstructionTool.MODE_ACQUIRE)
	_assert(bool(tool.select_cell(preview_cell).get("valid", false)), "ConstructionTool captures a confirmable preview revision")
	var competing_commit: Dictionary = runtime.commit_transaction({
		"operation": DistrictRuntime.OP_ACQUIRE_SPACE,
		"expected_district_revision": runtime.get_revision(),
		"runtime_plot_id": String(plot.get("id", "")),
		"floor_id": String(floor.get("id", "")),
		"elevation": 0,
		"cells": [[competing_cell.x, competing_cell.y]],
	})
	_assert(bool(competing_commit.get("valid", false)), "an intervening transaction advances District after tool preview")
	var stale_confirm: Dictionary = tool.confirm_selected()
	_assert(not bool(stale_confirm.get("valid", false)) and _has_code(stale_confirm.get("diagnostics", []), "STALE_DISTRICT_REVISION"), "ConstructionTool confirm preserves the preview revision and rejects stale confirmation")

	var rectangle_cells: Array[Vector2i] = ConstructionTool.rectangle_cells(Vector2i(3, 3), Vector2i(4, 5))
	_assert(rectangle_cells.size() == 6 and rectangle_cells[0] == Vector2i(3, 3) and rectangle_cells[5] == Vector2i(4, 5), "ConstructionTool produces a canonical inclusive rectangle")
	tool.activate(ConstructionTool.MODE_ACQUIRE)
	var rectangle_preview: Dictionary = tool.select_cells(rectangle_cells)
	_assert(bool(rectangle_preview.get("valid", false)) and tool.get_selected_cells().size() == 6 and int(rectangle_preview.get("quote", {}).get("value", -1)) == 6000, "rectangle acquisition previews the complete atomic per-cell quote")
	var rectangle_commit: Dictionary = tool.confirm_selected()
	_assert(bool(rectangle_commit.get("valid", false)) and runtime.get_revision() == 4 and economy.balance == initial_balance - 8000, "rectangle acquisition commits all cells and charges once")
	var rectangle_state: Dictionary = runtime.get_state()
	var rectangle_floor: Dictionary = _floor_state(rectangle_state, String(floor.get("id", "")))
	_assert(rectangle_floor.get("acquired_cells", []).has([3, 3]) and rectangle_floor.get("acquired_cells", []).has([4, 5]), "rectangle acquisition persists every selected sparse right")
	tool.activate(ConstructionTool.MODE_CORRIDOR)
	var corridor_rectangle_preview: Dictionary = tool.select_cells(rectangle_cells)
	_assert(bool(corridor_rectangle_preview.get("valid", false)) and int(corridor_rectangle_preview.get("quote", {}).get("value", -1)) == 0, "rectangle corridor previews the complete zero-cost operation")
	var corridor_rectangle_commit: Dictionary = tool.confirm_selected()
	_assert(bool(corridor_rectangle_commit.get("valid", false)) and runtime.get_revision() == 5 and economy.balance == initial_balance - 8000, "rectangle corridor commits atomically without an additional charge")
	var corridor_rectangle_floor: Dictionary = _floor_state(runtime.get_state(), String(floor.get("id", "")))
	_assert(corridor_rectangle_floor.get("constructed_cells", []).has([3, 3]) and corridor_rectangle_floor.get("constructed_cells", []).has([4, 5]) and corridor_rectangle_floor.get("explicit_circulation_cells", []).has([3, 3]), "rectangle corridor persists every constructed circulation cell")

	tool.free()
	projection.free()
	runtime.free()
	zone_manager.free()
	economy.free()


func _floor_at(snapshot: ResolvedDistrictSnapshot, plot_id: String, elevation: int) -> Dictionary:
	for floor: Dictionary in snapshot.get_data().get("floors", []):
		if String(floor.get("plot_id", "")) == plot_id and int(floor.get("elevation", 999)) == elevation:
			return floor
	return {}


func _floor_state(state: Dictionary, floor_id: String) -> Dictionary:
	for plot_state: Dictionary in state.get("plot_states", []):
		for floor_state: Dictionary in plot_state.get("floor_states", []):
			if String(floor_state.get("floor_id", "")) == floor_id:
				return floor_state
	return {}


func _has_code(diagnostics: Array, code: String) -> bool:
	for diagnostic: Variant in diagnostics:
		if diagnostic is Dictionary and String(diagnostic.get("code", "")) == code:
			return true
	return false
