class_name OpenAiToolDef
extends RefCounted

## OpenAI function tool definition (`tools[]` entry in chat requests).


class PropertyDef:
	var type: String = "string"
	var description: String = ""
	pass


class ArrayPropertyDef extends PropertyDef:
	var items: PropertyDef = PropertyDef.new()
	pass


class Parameters:
	var type: String = "object"
	var properties: Dictionary[String, PropertyDef] = {}
	var required: Array[String] = []

	static func object(required_fields: Array[String] = []) -> Parameters:
		var params := Parameters.new()
		params.required = required_fields
		return params

	func string_prop(field_name: String, description: String, required_field: bool = false) -> Parameters:
		var prop := PropertyDef.new()
		prop.description = description
		properties[field_name] = prop
		if required_field:
			required.append(field_name)
		return self


	func boolean_prop(field_name: String, description: String, required_field: bool = false) -> Parameters:
		var prop := PropertyDef.new()
		prop.type = "boolean"
		prop.description = description
		properties[field_name] = prop
		if required_field:
			required.append(field_name)
		return self


	func integer_prop(field_name: String, description: String, required_field: bool = false) -> Parameters:
		var prop := PropertyDef.new()
		prop.type = "integer"
		prop.description = description
		properties[field_name] = prop
		if required_field:
			required.append(field_name)
		return self


	func number_prop(field_name: String, description: String, required_field: bool = false) -> Parameters:
		var prop := PropertyDef.new()
		prop.type = "number"
		prop.description = description
		properties[field_name] = prop
		if required_field:
			required.append(field_name)
		return self


	func array_prop(field_name: String, item_type: String, description: String, required_field: bool = false) -> Parameters:
		var prop := ArrayPropertyDef.new()
		prop.type = "array"
		prop.description = description
		prop.items.type = item_type
		properties[field_name] = prop
		if required_field:
			required.append(field_name)
		return self


class FunctionDef:
	var name: String = ""
	var description: String = ""
	var parameters: Parameters = Parameters.new()


var type: String = "function"
var function: FunctionDef = FunctionDef.new()
