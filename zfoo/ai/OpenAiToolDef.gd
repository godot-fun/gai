class_name OpenAiToolDef
extends RefCounted

## OpenAI function tool definition (`tools[]` entry in chat requests).

var type: String = "function"
var function: FunctionDef = FunctionDef.new()


# ----------------------------------------------------------------------------------------------------------------------
# Function definition

class FunctionDef:
	var name: String = ""
	var description: String = ""
	var parameters: Parameters = Parameters.new()


# ----------------------------------------------------------------------------------------------------------------------
# Property definitions

class PropertyDef extends IJsonSerializable:
	var type: String = "string"
	var description: String = ""
	pass


class EnumPropertyDef extends PropertyDef:
	var enum_values: Array[String] = []

	func serialize() -> String:
		return JsonUtils.object_to_json({"type": type, "enum": enum_values, "description": description})


class ArrayPropertyDef extends PropertyDef:
	var items: PropertyDef = PropertyDef.new()
	pass


class ObjectPropertyDef extends PropertyDef:
	var properties: Dictionary[String, PropertyDef] = {}
	var required: Array[String] = []
	pass


# ----------------------------------------------------------------------------------------------------------------------
# Parameters builder

class Parameters:
	var type: String = "object"
	var properties: Dictionary[String, PropertyDef] = {}
	var required: Array[String] = []

	func add_property(field_name: String, prop: PropertyDef, required_field: bool) -> void:
		properties[field_name] = prop
		if required_field and not required.has(field_name):
			required.append(field_name)
		pass

	func string_prop(field_name: String, description: String, required_field: bool = false) -> Parameters:
		var prop := PropertyDef.new()
		prop.description = description
		add_property(field_name, prop, required_field)
		return self


	func boolean_prop(field_name: String, description: String, required_field: bool = false) -> Parameters:
		var prop := PropertyDef.new()
		prop.type = "boolean"
		prop.description = description
		add_property(field_name, prop, required_field)
		return self


	func integer_prop(field_name: String, description: String, required_field: bool = false) -> Parameters:
		var prop := PropertyDef.new()
		prop.type = "integer"
		prop.description = description
		add_property(field_name, prop, required_field)
		return self


	func number_prop(field_name: String, description: String, required_field: bool = false) -> Parameters:
		var prop := PropertyDef.new()
		prop.type = "number"
		prop.description = description
		add_property(field_name, prop, required_field)
		return self


	func array_prop(field_name: String, item_type: String, description: String, required_field: bool = false) -> Parameters:
		var prop := ArrayPropertyDef.new()
		prop.type = "array"
		prop.description = description
		prop.items.type = item_type
		add_property(field_name, prop, required_field)
		return self


	func object_prop(field_name: String, object_parameters: Parameters, description: String, required_field: bool = false) -> Parameters:
		var prop := ObjectPropertyDef.new()
		prop.type = "object"
		prop.description = description
		prop.properties = object_parameters.properties
		prop.required = object_parameters.required
		add_property(field_name, prop, required_field)
		return self


	func enum_prop(field_name: String, enum_values: Array[String], description: String, required_field: bool = false) -> Parameters:
		var prop := EnumPropertyDef.new()
		prop.enum_values = enum_values
		prop.description = description
		add_property(field_name, prop, required_field)
		return self
