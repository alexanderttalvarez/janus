## Authored H1 content graph. Compilation produces detached immutable semantic values.
class_name TenantInteriorContentBundle
extends Resource

@export var bundle_id: String = ""
@export_range(1, 2147483647, 1) var revision: int = 1
@export var fixtures: Array[InteriorFixtureDefinition] = []
@export var service_policies: Array[ServicePolicyDefinition] = []
@export var operational_profiles: Array[OperationalProfileDefinition] = []
@export var tenant_profiles: Array[InteriorTenantProfileDefinition] = []
@export var visitor_policy: VisitorServicePolicyDefinition
@export var planning_policy: InteriorPlanningPolicy
