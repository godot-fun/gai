class_name JsonUtils
extends Object

static func json_to_object(json: String, type: Variant) -> Variant:
	if StringUtils.is_blank(json):
		return
	var data = JSON.parse_string(json)
	if data == null:
		Log.error("Json pars error:[{}]", json)
		return
	if typeof(data) != TYPE_DICTIONARY:
		Log.error("Json root type error:[{}]", json)
		return
	return dict_to_object(data, type)


static func dict_to_object(data: Dictionary, type: Variant) -> Variant:
	if !ReflectionUtils.has_empty_constructor(type):
		return
	var obj = type.new()
	var property_map := ReflectionUtils.get_script_property_map(obj)
	for key in data.keys():
		var value = data[key]
		if property_map.has(key):
			value = convert_json_value(property_map[key], value, obj)
		obj.set(key, value)
	return obj


static func object_to_json(obj: Variant) -> String:
	var type := typeof(obj)
	match type:
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return str(obj)
		TYPE_INT:
			return str(obj)
		TYPE_FLOAT:
			return str(obj)
		TYPE_STRING:
			# Must escape control chars / quotes; raw concatenation breaks JSON APIs.
			return quote_json_string(obj as String)
		TYPE_ARRAY:
			var builder := StringBuilder.new()
			for element in obj:
				builder.append(object_to_json(element))
			return "[" + builder.build_joined(",") + "]"
		TYPE_DICTIONARY:
			var builder := StringBuilder.new()
			for key in obj:
				var value = obj.get(key)
				# JSON object keys must be strings (e.g. int key 1 -> "1")
				builder.append(object_to_json(str(key)) + ": " + object_to_json(value))
			return "{" + builder.build_joined(", ") + "}"
		TYPE_OBJECT:
			var builder := StringBuilder.new()
			for property in ReflectionUtils.get_script_property_map(obj).values():
				var property_name := property.name as String
				var value = obj.get(property_name)
				builder.append("\"" + property_name + "\": " + object_to_json(value))
			return "{" + builder.build_joined(", ") + "}"
		_:
			Log.error("unknow type:[{}]", type)
	return ""


## JSON string literal. Godot [method JSON.stringify] / [method String.json_escape] leave raw C0
## controls (ESC, …) and emit non-standard `\v`; strict JSON / OpenAI APIs need `\u00xx`.
static func quote_json_string(text: String) -> String:
	var quoted := JSON.stringify(text)
	var needs_fix := false
	var i := 0
	while i < quoted.length():
		var code := quoted.unicode_at(i)
		if code < 0x20:
			needs_fix = true
			break
		# json_escape() turns VT into `\v`, which JSON.parse rejects (not in RFC 8259).
		if code == 0x5C and i + 1 < quoted.length() and quoted.unicode_at(i + 1) == 0x76:
			needs_fix = true
			break
		i += 1
	if not needs_fix:
		return quoted
	var builder := StringBuilder.new()
	i = 0
	while i < quoted.length():
		var code := quoted.unicode_at(i)
		if code == 0x5C and i + 1 < quoted.length() and quoted.unicode_at(i + 1) == 0x76:
			builder.append("\\u000b")
			i += 2
			continue
		if code < 0x20:
			builder.append("\\u%04x" % code)
		else:
			builder.append(char(code))
		i += 1
	return builder.build_string()


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
			var current = obj.get(property_name)
			if current is Object and current.get_script() != null:
				return dict_to_object(value, current.get_script())
			return value
		_:
			return value

# ----------------------------------------------------------------------------------------------------------------------
static func convert_json_dictionary(value: Variant, obj: Object, property_name: String) -> Variant:
	var typed_dict: Dictionary = obj.get(property_name)
	var key_type := typed_dict.get_typed_key_builtin()
	var value_type := typed_dict.get_typed_value_builtin()
	if key_type == TYPE_NIL || value_type == TYPE_NIL:
		return value
	var result: Dictionary = {}
	for key in value:
		result[convert_dictionary_key(key, typed_dict)] = convert_dictionary_value(value[key], typed_dict)
	return Dictionary(
		result,
		key_type,
		typed_dict.get_typed_key_class_name(),
		typed_dict.get_typed_key_script(),
		value_type,
		typed_dict.get_typed_value_class_name(),
		typed_dict.get_typed_value_script()
	)


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
	var value_script = typed_dict.get_typed_value_script()
	if value_script is Script:
		if typeof(item) == TYPE_DICTIONARY:
			var element = dict_to_object(item, value_script)
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

# ---------------------------------------------------------------------------------------------------------------------
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
			var element = dict_to_object(item, element_script)
			if element != null:
				result.append(element)
		else:
			result.append(item)
	var base_type := element_script.get_instance_base_type()
	return Array(result, TYPE_OBJECT, base_type, element_script)


# ----------------------------------------------------------------------------------------------------------------------
# Lenient / near-JSON parsing (LLM replies, trailing commas, prose-wrapped objects).
# Strict typed JSON stays above; these helpers tolerate imperfect model output.

## Best-effort object parse for LLM / near-JSON text. Slices to the first `{` … last `}`,
## tries silent [method JSON.parse], then extracts `"key":"value"` string fields.
## Uses [method JSON.parse] (not [method JSON.parse_string]) so invalid near-JSON does not log ERR_FAIL.
## When [param keys] is non-empty, the extraction fallback only fills those keys; a successful
## strict parse still returns the full dictionary.
static func parse_object_lenient(text: String, keys: PackedStringArray = PackedStringArray()) -> Dictionary:
	if StringUtils.is_blank(text):
		return {}
	var start := text.find("{")
	var end := text.rfind("}")
	if start < 0 or end <= start:
		return {}
	var body := text.substr(start, end - start + 1)
	var json := JSON.new()
	if json.parse(body) == OK and typeof(json.data) == TYPE_DICTIONARY:
		return json.data
	var parsed := {}
	if keys.is_empty():
		return parsed
	for key in keys:
		var value := extract_string_field(body, key)
		if StringUtils.is_not_blank(value):
			parsed[key] = value
	return parsed


## Reads one `"key":"value"` string field without full JSON parsing (tolerates trailing commas / extra keys).
static func extract_string_field(body: String, key: String) -> String:
	if StringUtils.is_blank(body) or StringUtils.is_blank(key):
		return StringUtils.EMPTY
	var needle := "\"%s\"" % key
	var key_pos := body.find(needle)
	if key_pos < 0:
		return StringUtils.EMPTY
	var i := key_pos + needle.length()
	while i < body.length() and body.unicode_at(i) in [0x20, 0x09, 0x0A, 0x0D]:
		i += 1
	if i >= body.length() or body[i] != ":":
		return StringUtils.EMPTY
	i += 1
	while i < body.length() and body.unicode_at(i) in [0x20, 0x09, 0x0A, 0x0D]:
		i += 1
	if i >= body.length() or body[i] != "\"":
		return StringUtils.EMPTY
	i += 1
	var builder := StringBuilder.new()
	while i < body.length():
		var code := body.unicode_at(i)
		if code == 0x5C:
			if i + 1 >= body.length():
				break
			var next := body.unicode_at(i + 1)
			match next:
				0x22, 0x5C, 0x2F:
					builder.append(char(next))
					i += 2
				0x6E:
					builder.append("\n")
					i += 2
				0x72:
					builder.append("\r")
					i += 2
				0x74:
					builder.append("\t")
					i += 2
				0x75:
					if i + 5 >= body.length():
						return StringUtils.EMPTY
					builder.append(String.chr(body.substr(i + 2, 4).hex_to_int()))
					i += 6
				_:
					builder.append(char(next))
					i += 2
			continue
		if code == 0x22:
			return builder.build_string().strip_edges()
		builder.append(char(code))
		i += 1
	return StringUtils.EMPTY
