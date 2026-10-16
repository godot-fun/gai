class_name ApiSetting
extends RefCounted

## Persisted OpenAI-compatible API connection settings.

# ----------------------------------------------------------------------------------------------------------------------
# Storage keys and defaults

const API_URL_KEY := "agent_ai_api_url"
const API_TOKEN_KEY := "agent_ai_api_token"
const PROXY_ADDRESS_KEY := "agent_ai_proxy_address"
const MODEL_KEY := "agent_ai_model"


const DEFAULT_API_URL := "https://api.deepseek.com/chat/completions"
const DEFAULT_MODEL := "deepseek-v4-flash"
const API_KEY_ENV := "OPENAI_API_KEY"


# ----------------------------------------------------------------------------------------------------------------------
# Active connection

## Returns the endpoint currently used by the OpenAI-compatible client.
static func get_api_url() -> String:
	return Setting.get_string(API_URL_KEY, DEFAULT_API_URL)


static func get_api_token() -> String:
	return Setting.get_string(API_TOKEN_KEY, OS.get_environment(API_KEY_ENV))


static func get_model() -> String:
	return Setting.get_string(MODEL_KEY, DEFAULT_MODEL)


static func get_proxy_address() -> String:
	return Setting.get_string(PROXY_ADDRESS_KEY).strip_edges()


## Persists the active connection and proxy independently from the reusable history list.
static func save(api_url: String, api_token: String, model: String, proxy_address: String) -> void:
	Setting.set_string(API_URL_KEY, api_url.strip_edges())
	Setting.set_string(API_TOKEN_KEY, api_token.strip_edges())
	Setting.set_string(MODEL_KEY, model.strip_edges())
	Setting.set_string(PROXY_ADDRESS_KEY, proxy_address.strip_edges())
	Setting.save()
	pass


# ----------------------------------------------------------------------------------------------------------------------
# Client factory

## Creates a client from the active connection; proxy selection is applied by request callers.
static func get_client() -> OpenAiClient:
	return OpenAiClient.new(get_api_token(), get_api_url(), get_model())


# ----------------------------------------------------------------------------------------------------------------------
# Connection history

const CONNECTION_HISTORY_FILE_PATH := "user://api_connection_history.json"
const MAX_CONNECTION_HISTORY := 10


## Most-recent-first API/model/token groups. Invalid legacy data is ignored; equal URLs remain
## distinct because they may use different models or credentials.
static func get_connection_history() -> Array[ApiModelConfig]:
	if not FileAccess.file_exists(CONNECTION_HISTORY_FILE_PATH):
		return []
	var text := FileAccess.get_file_as_string(CONNECTION_HISTORY_FILE_PATH)
	var parsed := JsonUtils.json_to_object_array(text, ApiModelConfig)
	var result: Array[ApiModelConfig] = []
	for value: Variant in parsed:
		var entry := value as ApiModelConfig
		if entry != null and entry.is_valid():
			result.append(entry)
	return result


## Moves an existing configuration to the front or inserts it, keeping the history bounded.
static func remember_connection(api_url: String, api_token: String, model: String) -> void:
	var connection := ApiModelConfig.new(api_url, model, api_token)
	if not connection.is_valid():
		return
	var history := get_connection_history()
	for index in range(history.size() - 1, -1, -1):
		if history[index].matches_connection(connection):
			history.remove_at(index)
	history.push_front(connection)
	if history.size() > MAX_CONNECTION_HISTORY:
		history.resize(MAX_CONNECTION_HISTORY)
	save_connection_history(history)
	pass


## Removes exactly one saved array entry without changing the active connection fields.
static func remove_connection_at(index: int) -> void:
	var history := get_connection_history()
	if index < 0 or index >= history.size():
		return
	history.remove_at(index)
	save_connection_history(history)
	pass


## Writes the complete bounded history; callers mutate an in-memory copy before replacing the file.
static func save_connection_history(history: Array[ApiModelConfig]) -> void:
	var json := JsonUtils.object_to_json(history)
	if FileAccess.file_exists(CONNECTION_HISTORY_FILE_PATH) and FileAccess.get_file_as_string(CONNECTION_HISTORY_FILE_PATH) == json:
		return
	var file := FileAccess.open(CONNECTION_HISTORY_FILE_PATH, FileAccess.WRITE)
	if file == null:
		Log.error("save API connection history failed path:[{}] error:[{}]", CONNECTION_HISTORY_FILE_PATH, FileAccess.get_open_error())
		return
	file.store_string(json)
	pass

## Serializable API endpoint, model, and credential combination used by connection history.
class ApiModelConfig:
	extends RefCounted

	var api_url: String = ""
	var model: String = ""
	var api_token: String = ""


	func _init(p_api_url: String = "", p_model: String = "", p_api_token: String = "") -> void:
		api_url = p_api_url.strip_edges()
		model = p_model.strip_edges()
		api_token = p_api_token.strip_edges()
		pass


	func is_valid() -> bool:
		return not api_url.is_empty() and not model.is_empty()


	func matches_connection(other: ApiModelConfig) -> bool:
		return api_url == other.api_url and model == other.model and api_token == other.api_token
