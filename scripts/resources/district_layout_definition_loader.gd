class_name DistrictLayoutDefinitionLoader
extends RefCounted

## Parses a definition asset, then delegates normalization and validation to H1.
## File I/O is kept outside the Resource and validator so proof tests can remain pure.


func load_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("FILE_OPEN_FAILED", "$", "definition asset could not be opened")
	var text: String = file.get_as_text()
	file.close()
	return parse_text(text)


func parse_text(text: String) -> Dictionary:
	var parser := JSON.new()
	var parse_error: Error = parser.parse(text)
	if parse_error != OK:
		return _failure("JSON_PARSE_FAILED", "$", parser.get_error_message())
	var json_value: Variant = _coerce_integral_json_numbers(parser.data, "$", [])
	if json_value == null:
		return _failure("JSON_NUMBER_INVALID", "$", "JSON contains a non-integral, non-finite, or unsafe semantic number")
	var validation: Dictionary = DistrictLayoutValidator.new().normalize_and_validate(json_value)
	if not bool(validation.get("valid", false)):
		return {
			"valid": false,
			"definition": null,
			"record": validation.get("record", {}),
			"diagnostics": validation.get("diagnostics", []),
		}
	var definition: DistrictLayoutDefinition = load_definition(validation.get("record", {}))
	return {
		"valid": definition.is_published(),
		"definition": definition if definition.is_published() else null,
		"record": definition.get_semantic_record(),
		"diagnostics": definition.get_diagnostics(),
	}


func _coerce_integral_json_numbers(value: Variant, path: String, errors: Array) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number: float = float(value)
			if not is_finite(number) or floor(number) != number or number < DistrictLayoutValidator.MIN_SAFE_INTEGER or number > DistrictLayoutValidator.MAX_SAFE_INTEGER:
				errors.append(path)
				return null
			return int(number)
		TYPE_ARRAY:
			var result: Array = []
			for index: int in range(value.size()):
				var item: Variant = _coerce_integral_json_numbers(value[index], "%s[%d]" % [path, index], errors)
				if not errors.is_empty():
					return null
				result.append(item)
			return result
		TYPE_DICTIONARY:
			var result_dictionary: Dictionary = {}
			for key: Variant in value.keys():
				var item: Variant = _coerce_integral_json_numbers(value[key], "%s.%s" % [path, String(key)], errors)
				if not errors.is_empty():
					return null
				result_dictionary[key] = item
			return result_dictionary
		_:
			return value


func load_definition(record: Dictionary) -> DistrictLayoutDefinition:
	var definition: DistrictLayoutDefinition = DistrictLayoutDefinition.new()
	definition.initialize(record)
	return definition


func _failure(code: String, path: String, message: String) -> Dictionary:
	return {
		"valid": false,
		"definition": null,
		"record": {},
		"diagnostics": [{"code": code, "path": path, "message": message}],
	}
