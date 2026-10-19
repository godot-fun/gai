class_name ApiSetting
extends RefCounted

## Encrypted OpenAI-compatible connection history and its active connection.

const DEFAULT_API_URL := "https://api.deepseek.com/chat/completions"
const DEFAULT_MODEL := "deepseek-flash"
const API_KEY_ENV := "OPENAI_API_KEY"
const CONNECTION_HISTORY_FILE_PATH := "user://api.dat"
const MAX_CONNECTION_HISTORY := 10
const PROXY_ADDRESS_KEY := "proxy_address"

static var connection_history: Array[ApiModelConfig] = load_connection_history()


# ----------------------------------------------------------------------------------------------------------------------
# Active connection

## Returns the endpoint currently used by the OpenAI-compatible client.
static func get_api_url() -> String:
	var connection := get_active_connection()
	return connection.api_url if connection != null else DEFAULT_API_URL


static func get_api_token() -> String:
	var connection := get_active_connection()
	return connection.api_token if connection != null else OS.get_environment(API_KEY_ENV)


static func get_model() -> String:
	var connection := get_active_connection()
	return connection.model if connection != null else DEFAULT_MODEL


static func get_proxy_address() -> String:
	return Setting.get_string(PROXY_ADDRESS_KEY).strip_edges()


## Persists the edited connection as the active history entry and saves the non-secret proxy setting.
static func save(api_url: String, model: String, api_token: String, proxy_address: String) -> void:
	set_active_connection(ApiModelConfig.new(api_url, model, api_token))
	var normalized_proxy_address := proxy_address.strip_edges()
	if normalized_proxy_address != get_proxy_address():
		Setting.set_string(PROXY_ADDRESS_KEY, normalized_proxy_address)
		Setting.save()
		AgentEvents.events.proxy_address_changed.emit()
	pass


## Creates a client from the active connection; request callers apply the proxy separately.
static func get_client() -> OpenAiClient:
	return OpenAiClient.new(get_api_token(), get_api_url(), get_model())


static func get_active_connection() -> ApiModelConfig:
	return connection_history.front() if not connection_history.is_empty() else null


static func set_active_connection(connection: ApiModelConfig) -> void:
	if not connection.is_valid():
		return
	if connection_history.is_empty():
		connection_history.append(connection)
	else:
		connection_history[0] = connection
	remove_duplicate_connections(connection, 1)
	trim_and_save_connection_history()
	pass


# ----------------------------------------------------------------------------------------------------------------------
# Connection history

## Returns a shallow copy of the most-recent-first connection history cached in memory.
static func get_connection_history() -> Array[ApiModelConfig]:
	var result: Array[ApiModelConfig] = []
	result.assign(connection_history)
	return result


## Moves an equal connection to the front or inserts it as the active connection.
static func remember_connection(api_url: String, api_token: String, model: String) -> void:
	var connection := ApiModelConfig.new(api_url, model, api_token)
	if not connection.is_valid():
		return
	remove_duplicate_connections(connection)
	connection_history.push_front(connection)
	trim_and_save_connection_history()
	pass


## Makes an existing history entry active without duplicating it.
static func activate_connection(connection: ApiModelConfig) -> void:
	remember_connection(connection.api_url, connection.api_token, connection.model)
	pass


## Removes one entry; the next entry becomes active when the first entry is removed.
static func remove_connection_at(index: int) -> void:
	if index < 0 or index >= connection_history.size():
		return
	connection_history.remove_at(index)
	save_connection_history()
	pass


static func remove_duplicate_connections(connection: ApiModelConfig, minimum_index: int = 0) -> void:
	for index in range(connection_history.size() - 1, minimum_index - 1, -1):
		if connection_history[index].matches_connection(connection):
			connection_history.remove_at(index)
	pass


# ----------------------------------------------------------------------------------------------------------------------
# Encrypted history storage

static func load_connection_history() -> Array[ApiModelConfig]:
	var result: Array[ApiModelConfig] = []
	if not FileAccess.file_exists(CONNECTION_HISTORY_FILE_PATH):
		return result
	var file := FileAccess.open_encrypted_with_pass(CONNECTION_HISTORY_FILE_PATH, FileAccess.READ, "zfoo")
	if file == null:
		Log.error("load encrypted API connection history failed path:[{}] error:[{}]", CONNECTION_HISTORY_FILE_PATH, FileAccess.get_open_error())
		return result
	var parsed := JsonUtils.json_to_object_array(file.get_as_text(), ApiModelConfig)
	for value: Variant in parsed:
		var connection := value as ApiModelConfig
		if connection != null and connection.is_valid():
			result.append(connection)
	if result.size() > MAX_CONNECTION_HISTORY:
		result.resize(MAX_CONNECTION_HISTORY)
	return result


static func trim_and_save_connection_history() -> void:
	if connection_history.size() > MAX_CONNECTION_HISTORY:
		connection_history.resize(MAX_CONNECTION_HISTORY)
	save_connection_history()
	pass


static func save_connection_history() -> void:
	var file := FileAccess.open_encrypted_with_pass(CONNECTION_HISTORY_FILE_PATH, FileAccess.WRITE, "zfoo")
	if file == null:
		Log.error("save encrypted API connection history failed path:[{}] error:[{}]", CONNECTION_HISTORY_FILE_PATH, FileAccess.get_open_error())
		return
	file.store_string(JsonUtils.object_to_json(connection_history))
	pass


# ----------------------------------------------------------------------------------------------------------------------
# Stored connection model

## Serializable API endpoint, model, and credential combination.
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
