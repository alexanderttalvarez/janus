class_name LegacyLayoutBootstrapAdapter
extends RefCounted

## Explicit H3 compatibility boundary for the legacy fixed-grid bootstrap.
## It produces a resolved snapshot only; District Runtime remains the writer.


func resolve_fixture(fixture_id: String) -> ResolvedDistrictSnapshot:
	var factory: RefCounted = load("res://scripts/resources/district_layout_fixture_factory.gd").new()
	var resolver: RefCounted = load("res://scripts/resources/district_layout_resolver.gd").new()
	var result: Dictionary = resolver.resolve(factory.build_fixture(fixture_id))
	return result.get("snapshot") as ResolvedDistrictSnapshot if bool(result.get("valid", false)) else null
