class_name JsonDeserializer
extends Object

static func json_to_object(json: String, type: Variant) -> Variant:
	if StringUtils.is_blank(json):
		return null
	var parser := JSON.new()
	if parser.parse(json) != OK:
		Log.error("JSON object parse failed line:[{}] message:[{}] length:[{}]", parser.get_error_line(), parser.get_error_message(), json.length())
		return null
	if typeof(parser.data) != TYPE_DICTIONARY:
		Log.error("JSON object root type invalid actual_type:[{}] length:[{}]", type_string(typeof(parser.data)), json.length())
		return null
	return dict_to_object(parser.data, type)


static func json_to_object_array(json: String, element_type: Variant) -> Array:
	if StringUtils.is_blank(json):
		return []
	var parser := JSON.new()
	if parser.parse(json) != OK:
		Log.error("JSON array parse failed line:[{}] message:[{}] length:[{}]", parser.get_error_line(), parser.get_error_message(), json.length())
		return []
	if typeof(parser.data) != TYPE_ARRAY:
		Log.error("JSON array root type invalid actual_type:[{}] length:[{}]", type_string(typeof(parser.data)), json.length())
		return []
	var result: Array = []
	for value: Variant in parser.data:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var element: Variant = dict_to_object(value, element_type)
		if element != null:
			result.append(element)
	return result


static func dict_to_object(data: Dictionary, type: Variant) -> Variant:
	if !ReflectionUtils.has_empty_constructor(type):
		return null
	var obj: Variant = type.new()
	if obj is IJsonSerializable:
		return obj.deserialize(data)
	var property_map := ReflectionUtils.get_script_property_map(obj)
	for key in data.keys():
		var value: Variant = data[key]
		if property_map.has(key):
			value = convert_json_value(property_map[key], value, obj)
			obj.set(key, value)
	return obj


static func convert_json_value(property: Dictionary, value: Variant, obj: Object) -> Variant:
	if value == null:
		return null
	var property_type: int = property.type
	var hint: int = property.hint
	var hint_string: String = property.get("hint_string", "")
	var property_name := property.name as String
	if hint == PROPERTY_HINT_ARRAY_TYPE or property_type == TYPE_ARRAY:
		return convert_json_array(hint_string, value, obj, property_name)
	if hint == PROPERTY_HINT_DICTIONARY_TYPE or property_type == TYPE_DICTIONARY:
		return convert_json_dictionary(value, obj, property_name)
	match property_type:
		TYPE_BOOL:
			return bool(value)
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_STRING:
			return str(value)
		TYPE_OBJECT:
			if typeof(value) != TYPE_DICTIONARY:
				return value
			var current: Variant = obj.get(property_name)
			if current is Object and current.get_script() != null:
				return dict_to_object(value, current.get_script())
			return value
		_:
			return value


static func convert_json_dictionary(value: Variant, obj: Object, property_name: String) -> Variant:
	var typed_dict: Dictionary = obj.get(property_name)
	var key_type := typed_dict.get_typed_key_builtin()
	var value_type := typed_dict.get_typed_value_builtin()
	if key_type == TYPE_NIL || value_type == TYPE_NIL:
		return value
	var result: Dictionary = {}
	for key in value:
		result[convert_dictionary_key(key, typed_dict)] = convert_dictionary_value(value[key], typed_dict)
	return Dictionary(result, key_type, typed_dict.get_typed_key_class_name(), typed_dict.get_typed_key_script(), value_type, typed_dict.get_typed_value_class_name(), typed_dict.get_typed_value_script())


static func convert_dictionary_key(key: Variant, typed_dict: Dictionary) -> Variant:
	match typed_dict.get_typed_key_builtin():
		TYPE_STRING:
			return str(key)
		TYPE_INT:
			return int(key)
		TYPE_FLOAT:
			return float(key)
		TYPE_BOOL:
			return bool(key)
		_:
			return key


static func convert_dictionary_value(item: Variant, typed_dict: Dictionary) -> Variant:
	var value_script: Variant = typed_dict.get_typed_value_script()
	if value_script is Script:
		if typeof(item) == TYPE_DICTIONARY:
			var element: Variant = dict_to_object(item, value_script)
			if element != null:
				return element
		return item
	match typed_dict.get_typed_value_builtin():
		TYPE_STRING:
			return str(item)
		TYPE_INT:
			return int(item)
		TYPE_FLOAT:
			return float(item)
		TYPE_BOOL:
			return bool(item)
		_:
			return item


static func convert_json_array(element_type_name: String, value: Variant, obj: Object, property_name: String) -> Variant:
	var element_script = obj.get(property_name).get_typed_script()
	if element_script != null:
		return convert_json_object_array(value, element_script)
	match element_type_name:
		"String":
			var result: Array[String] = []
			for item in value:
				result.append(str(item))
			return result
		"int":
			var result: Array[int] = []
			for item in value:
				result.append(int(item))
			return result
		"float":
			var result: Array[float] = []
			for item in value:
				result.append(float(item))
			return result
		"bool":
			var result: Array[bool] = []
			for item in value:
				result.append(bool(item))
			return result
		_:
			return value


static func convert_json_object_array(value: Variant, element_script: Script) -> Array:
	var result: Array = []
	for item in value:
		if typeof(item) == TYPE_DICTIONARY:
			var element: Variant = dict_to_object(item, element_script)
			if element != null:
				result.append(element)
		else:
			result.append(item)
	var base_type := element_script.get_instance_base_type()
	return Array(result, TYPE_OBJECT, base_type, element_script)
