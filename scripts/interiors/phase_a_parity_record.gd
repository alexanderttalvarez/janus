## Builds and compares the complete detached publication parity witness for H2.
class_name PhaseAParityRecord
extends RefCounted

const SCHEMA_ID: String = "tenant_phase_a_parity"
const SCHEMA_VERSION: int = 1
const PARITY_DOMAIN: String = "JANUS_TENANT_PHASE_A_PARITY"
const DOOR_DOMAIN: String = "JANUS_TENANT_PHASE_A_DOORS"
const ENVELOPE_DOMAIN: String = "JANUS_TENANT_QUEUE_ENVELOPES"


static func create(components: Dictionary) -> Dictionary:
	var required: Array[String] = ["formation_policy_id", "formation_policy_revision", "queue_policy_id", "queue_policy_revision", "selected_door_edges", "prospective_graph_fingerprint", "queue_input_fingerprint", "queue_envelopes", "feasible_pool_fingerprint"]
	if not _exact_keys(components, required): return {"valid":false,"diagnostics":[_d("PHASE_A_PARITY_INPUT_INVALID", "$", {})]}
	var door_hash := CanonicalJsonFingerprint.new().fingerprint(components["selected_door_edges"], DOOR_DOMAIN, 1)
	var envelope_hash := CanonicalJsonFingerprint.new().fingerprint(components["queue_envelopes"], ENVELOPE_DOMAIN, 1)
	if not bool(door_hash.get("valid", false)) or not bool(envelope_hash.get("valid", false)): return {"valid":false,"diagnostics":door_hash.get("diagnostics", []) + envelope_hash.get("diagnostics", [])}
	var record := {
		"schema_id": SCHEMA_ID, "schema_version": SCHEMA_VERSION, "parity_revision": 1,
		"formation_policy_id": components["formation_policy_id"], "formation_policy_revision": components["formation_policy_revision"],
		"queue_policy_id": components["queue_policy_id"], "queue_policy_revision": components["queue_policy_revision"],
		"selected_door_edges_fingerprint": door_hash["fingerprint"], "prospective_graph_fingerprint": components["prospective_graph_fingerprint"],
		"queue_input_fingerprint": components["queue_input_fingerprint"], "queue_envelopes_fingerprint": envelope_hash["fingerprint"],
		"feasible_pool_fingerprint": components["feasible_pool_fingerprint"],
	}
	var hash := CanonicalJsonFingerprint.new().fingerprint(record, PARITY_DOMAIN, 1)
	if not bool(hash.get("valid", false)): return {"valid":false,"diagnostics":hash.get("diagnostics", [])}
	record["parity_fingerprint"] = hash["fingerprint"]
	return {"valid":true,"record":record,"diagnostics":[]}


static func compare(expected: Dictionary, actual: Dictionary) -> Dictionary:
	var checks: Array[Array] = [
		["formation_policy_id", "PHASE_A_POLICY_MISMATCH"], ["formation_policy_revision", "PHASE_A_POLICY_MISMATCH"],
		["queue_policy_id", "PHASE_A_POLICY_MISMATCH"], ["queue_policy_revision", "PHASE_A_POLICY_MISMATCH"],
		["selected_door_edges_fingerprint", "PHASE_A_DOOR_MISMATCH"], ["prospective_graph_fingerprint", "PHASE_A_GRAPH_MISMATCH"],
		["queue_input_fingerprint", "PHASE_A_QUEUE_INPUT_MISMATCH"], ["queue_envelopes_fingerprint", "PHASE_A_ENVELOPE_MISMATCH"],
		["feasible_pool_fingerprint", "PHASE_A_POOL_MISMATCH"],
	]
	for check: Array in checks:
		if expected.get(check[0]) != actual.get(check[0]): return {"valid":false,"diagnostics":[_d(check[1], "$.%s" % check[0], {})]}
	if expected.get("parity_fingerprint") != actual.get("parity_fingerprint"): return {"valid":false,"diagnostics":[_d("PHASE_A_PARITY_MISMATCH", "$.parity_fingerprint", {})]}
	return {"valid":true,"diagnostics":[]}


static func _exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	var actual: Array[String] = []; for key: Variant in value.keys(): actual.append(String(key))
	actual.sort(); var wanted := expected.duplicate(); wanted.sort(); return actual == wanted


static func _d(code: String, path: String, values: Dictionary) -> Dictionary:
	return {"code":code,"path":path,"values":values.duplicate(true)}
