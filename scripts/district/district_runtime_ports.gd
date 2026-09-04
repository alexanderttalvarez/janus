class_name DistrictRuntimePorts
extends RefCounted

## Narrow H3 authority ports. Production authorities implement these contracts;
## tests inject deterministic fakes. No port mutates District Runtime state.


class DistrictEconomyPort extends RefCounted:
	func get_revision() -> int:
		return 0

	func get_policy_snapshot() -> Dictionary:
		return {}

	func quote(intent: Dictionary, candidate_state: Dictionary) -> Dictionary:
		return {"accepted": false, "diagnostics": [{"code": "ECONOMY_PORT_UNIMPLEMENTED", "message": "Economy quote is not available"}]}

	func reserve(quote_result: Dictionary) -> Dictionary:
		return {"accepted": false, "diagnostics": [{"code": "ECONOMY_PORT_UNIMPLEMENTED", "message": "Economy reservation is not available"}]}

	func guarantee_capture(reservation: Dictionary) -> Dictionary:
		return {"accepted": false, "diagnostics": [{"code": "ECONOMY_PORT_UNIMPLEMENTED", "message": "Guaranteed capture is not available"}]}

	func capture(guaranteed_token: Dictionary) -> Dictionary:
		return {"accepted": false, "diagnostics": [{"code": "ECONOMY_PORT_UNIMPLEMENTED", "message": "Economy capture is not available"}]}

	func cancel(reservation: Dictionary) -> Dictionary:
		return {"accepted": true, "diagnostics": []}

	func flush_notifications() -> Array[Dictionary]:
		return []


class EconomyManagerPort extends DistrictEconomyPort:
	var manager: Node

	func initialize(economy_manager: Node) -> void:
		manager = economy_manager

	func get_revision() -> int:
		return 0 if manager == null else int(manager.call("get_district_revision"))

	func get_policy_snapshot() -> Dictionary:
		return {} if manager == null else manager.call("get_policy_snapshot")

	func quote(transaction: Dictionary, _candidate_state: Dictionary) -> Dictionary:
		if manager == null:
			return {"accepted": false, "diagnostics": [{"code": "ECONOMY_MANAGER_REQUIRED", "message": "EconomyManager is required"}]}
		return manager.call("district_quote", transaction)

	func reserve(quote_result: Dictionary) -> Dictionary:
		return manager.call("reserve_quote", quote_result)

	func guarantee_capture(reservation: Dictionary) -> Dictionary:
		return manager.call("district_guarantee_capture", reservation)

	func capture(guaranteed_token: Dictionary) -> Dictionary:
		return manager.call("district_capture", guaranteed_token)

	func cancel(reservation: Dictionary) -> Dictionary:
		return manager.call("district_cancel", reservation)

	func flush_notifications() -> Array[Dictionary]:
		return manager.call("flush_district_notifications")


class DistrictZonePort extends RefCounted:
	func get_revision() -> int:
		return 0

	func preview(intent: Dictionary, candidate_state: Dictionary) -> Dictionary:
		return {"accepted": true, "preview": null, "diagnostics": []}

	func prepare(intent: Dictionary, candidate_state: Dictionary) -> Dictionary:
		return {"accepted": true, "prepare_token": {"candidate": candidate_state.duplicate(true)}, "diagnostics": []}

	func commit(prepare_token: Dictionary) -> Dictionary:
		return {"accepted": true, "diagnostics": []}

	func undo(prepare_token: Dictionary) -> Dictionary:
		return {"accepted": true, "diagnostics": []}

	func flush_notifications() -> Array[Dictionary]:
		return []


class ZoneManagerPort extends DistrictZonePort:
	var manager: Node

	func initialize(zone_manager: Node) -> void:
		manager = zone_manager

	func get_revision() -> int:
		return 0 if manager == null else int(manager.call("get_district_revision"))

	func preview(intent: Dictionary, candidate_state: Dictionary) -> Dictionary:
		if manager == null:
			return {"accepted": false, "diagnostics": [{"code": "ZONE_MANAGER_REQUIRED", "message": "ZoneManager is required"}]}
		return manager.call("preview_district_candidate", intent, candidate_state)

	func prepare(intent: Dictionary, candidate_state: Dictionary) -> Dictionary:
		if manager == null:
			return {"accepted": false, "diagnostics": [{"code": "ZONE_MANAGER_REQUIRED", "message": "ZoneManager is required"}]}
		return manager.call("prepare_district_candidate", intent, candidate_state)

	func commit(prepare_token: Dictionary) -> Dictionary:
		return manager.call("commit_district_candidate", prepare_token)

	func undo(prepare_token: Dictionary) -> Dictionary:
		return manager.call("undo_district_candidate", prepare_token)

	func flush_notifications() -> Array[Dictionary]:
		return manager.call("flush_district_notifications")


class DistrictProgressionPort extends RefCounted:
	func get_policy_snapshot() -> Dictionary:
		return {}


class ProgressionManagerPort extends DistrictProgressionPort:
	var prestige_manager: Node
	var tech_tree_manager: Node
	var minimum_elevation: int = -5
	var maximum_elevation: int = 9

	func initialize(prestige: Node, tech_tree: Node) -> void:
		prestige_manager = prestige
		tech_tree_manager = tech_tree
		if tech_tree_manager != null and tech_tree_manager.has_method("set_prestige_manager"):
			tech_tree_manager.call("set_prestige_manager", prestige_manager)

	func get_policy_snapshot() -> Dictionary:
		if tech_tree_manager == null:
			return {}
		var snapshot: Dictionary = tech_tree_manager.call("get_policy_snapshot")
		if snapshot.is_empty():
			return snapshot
		return snapshot


class DistrictRuntimePortsBundle extends RefCounted:
	var economy: DistrictEconomyPort
	var zone: DistrictZonePort
	var progression: DistrictProgressionPort

	func initialize(
		economy_port: DistrictEconomyPort,
		zone_port: DistrictZonePort,
		progression_port: DistrictProgressionPort
	) -> void:
		economy = economy_port
		zone = zone_port
		progression = progression_port
