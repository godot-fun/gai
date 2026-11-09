class_name JsonUtils
extends Object

## Converts a JSON object into [param type]. Returns [code]null[/code] when parsing or construction fails.
static func json_to_object(json: String, type: Variant) -> Variant:
	return JsonDeserializer.json_to_object(json, type)


static func json_to_object_array(json: String, element_type: Variant) -> Array:
	return JsonDeserializer.json_to_object_array(json, element_type)


## Converts [param data] into [param type]. Returns [code]null[/code] when the type has no empty constructor.
static func dict_to_object(data: Dictionary, type: Variant) -> Variant:
	return JsonDeserializer.dict_to_object(data, type)


static func object_to_json(obj: Variant) -> String:
	return JsonSerializer.object_to_json(obj)


## JSON string literal. Godot [method JSON.stringify] / [method String.json_escape] leave raw C0
## controls and emit non-standard `\v`; strict JSON / OpenAI APIs need `\u00xx`.
static func quote_json_string(text: String) -> String:
	return JsonSerializer.quote_json_string(text)


# ----------------------------------------------------------------------------------------------------------------------
# Lenient / near-JSON parsing (LLM replies, trailing commas, prose-wrapped objects).

## Best-effort object parse for LLM / near-JSON text. Slices to the first `{` through last `}`,
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
