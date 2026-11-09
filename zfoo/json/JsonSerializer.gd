class_name JsonSerializer
extends Object

static func object_to_json(obj: Variant) -> String:
	var type := typeof(obj)
	match type:
		TYPE_NIL:
			return "null"
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return str(obj)
		TYPE_STRING:
			return quote_json_string(obj as String)
		TYPE_ARRAY:
			var builder := StringBuilder.new()
			for element in obj:
				builder.append(object_to_json(element))
			return "[" + builder.build_joined(",") + "]"
		TYPE_DICTIONARY:
			var builder := StringBuilder.new()
			for key in obj:
				var value: Variant = obj.get(key)
				builder.append(object_to_json(str(key)) + ": " + object_to_json(value))
			return "{" + builder.build_joined(", ") + "}"
		TYPE_OBJECT:
			if obj is IJsonSerializable:
				return obj.to_json()
			var builder := StringBuilder.new()
			for property in ReflectionUtils.get_script_property_map(obj).values():
				var property_name := property.name as String
				var value: Variant = obj.get(property_name)
				builder.append("\"" + property_name + "\": " + object_to_json(value))
			return "{" + builder.build_joined(", ") + "}"
		_:
			Log.error("unknow type:[{}]", type)
	return ""


## JSON string literal. Godot [method JSON.stringify] / [method String.json_escape] leave raw C0
## controls and emit non-standard `\v`; strict JSON / OpenAI APIs need `\u00xx`.
static func quote_json_string(text: String) -> String:
	var quoted := JSON.stringify(text)
	var needs_fix := false
	var i := 0
	while i < quoted.length():
		var code := quoted.unicode_at(i)
		if code < 0x20:
			needs_fix = true
			break
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
			builder.append(r"\u000b")
			i += 2
			continue
		if code < 0x20:
			builder.append(r"\u%04x" % code)
		else:
			builder.append(char(code))
		i += 1
	return builder.build_string()
