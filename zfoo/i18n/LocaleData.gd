class_name LocaleData
extends Object

## Loads nested JSON locale files, validates that every locale has the same leaf keys,
## and registers both dot-joined and space-joined message IDs with TranslationServer.
##
## Supported JSON format (all leaf values must be strings):
## [codeblock]
## {
##   "locale": "en-US",
##   "workflow": {
##     "window_title": "Skills Workflow — {}",
##     "toolbar": {
##       "save": "Save"
##     }
##   }
## }
## [/codeblock]

var locale: String
var data: Dictionary[String, String]


func _init(locale_name: String, data_map: Dictionary[String, String]) -> void:
	locale = locale_name
	data = data_map
	pass


## Parses one nested JSON locale file into normalized locale data.
static func parse_json_file(path: String) -> LocaleData:
	var content := FileUtils.read_file_to_string(path)
	if content.is_empty():
		Log.error("translation json is missing or empty:[{}]", path)
		return null
	var json := JSON.new()
	var error := json.parse(content)
	if error != OK:
		Log.error("translation json parse failed path:[{}] line:[{}] error:[{}]", path, json.get_error_line(), json.get_error_message())
		return null
	if not json.data is Dictionary:
		Log.error("translation json root is not an object:[{}]", path)
		return null
	var document := json.data as Dictionary
	var locale_name := TranslationServer.standardize_locale(str(document.get("locale", "")))
	if locale_name.is_empty():
		Log.error("translation locale is missing path:[{}]", path)
		return null
	var data_map: Dictionary[String, String] = {}
	if flatten_data(document, [], data_map) != OK:
		return null
	return LocaleData.new(locale_name, data_map)


static func flatten_data(value: Dictionary, path_parts: Array[String], data_map: Dictionary[String, String]) -> Error:
	for raw_key: Variant in value:
		var key := str(raw_key)
		if path_parts.is_empty() and key == "locale":
			continue
		var next_parts := path_parts.duplicate()
		next_parts.append(key)
		var child: Variant = value[raw_key]
		if child is Dictionary:
			var error := flatten_data(child as Dictionary, next_parts, data_map)
			if error != OK:
				return error
			continue
		if not child is String:
			Log.error("translation value must be a string key:[{}]", ".".join(next_parts))
			return ERR_INVALID_DATA
		var dot_key := ".".join(next_parts)
		if data_map.has(dot_key):
			Log.error("duplicate translation key:[{}]", dot_key)
			return ERR_ALREADY_EXISTS
		data_map[dot_key] = child
		var space_key := " ".join(next_parts)
		if space_key == dot_key:
			continue
		if data_map.has(space_key):
			Log.error("duplicate translation key:[{}]", space_key)
			return ERR_ALREADY_EXISTS
		data_map[space_key] = child
	return OK
