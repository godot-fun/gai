class_name ApiSetting
extends RefCounted

## Encrypted OpenAI-compatible model profiles. Each model owns its endpoint and credential.

const DEFAULT_API_URL := "https://api.deepseek.com/chat/completions"
const DEFAULT_MODEL := "deepseek-flash"
const API_KEY_ENV := "OPENAI_API_KEY"
const CONFIG_FILE_PATH := "user://api.dat"
const PROXY_ADDRESS_KEY := "proxy_address"

static var config: ApiConfig = load_config()


static func get_api_url() -> String:
	return get_active_profile().api_url


static func get_api_token() -> String:
	var token := get_active_profile().api_token
	return token if not token.is_empty() else OS.get_environment(API_KEY_ENV)


static func get_model() -> String:
	return get_active_profile().model


static func get_models() -> Array[String]:
	var result: Array[String] = []
	for profile in config.profiles:
		result.append(profile.model)
	return result


static func get_profiles() -> Array[ApiModelProfile]:
	var result: Array[ApiModelProfile] = []
	result.assign(config.profiles)
	return result


static func get_proxy_address() -> String:
	return Setting.get_string(PROXY_ADDRESS_KEY).strip_edges()


## Adds one complete model profile without changing the default model.
static func add_model(model: String, api_url: String, api_token: String) -> bool:
	var profile := ApiModelProfile.new(model, api_url, api_token)
	if not profile.is_valid() or find_profile_index(profile.model) >= 0:
		return false
	config.profiles.append(profile)
	save_config()
	AgentEvents.events.api_models_changed.emit()
	return true


static func remove_model(model: String) -> bool:
	if config.profiles.size() <= 1:
		return false
	var index := find_profile_index(model)
	if index < 0:
		return false
	config.profiles.remove_at(index)
	if config.active_model == model:
		config.active_model = config.profiles[min(index, config.profiles.size() - 1)].model
	save_config()
	AgentEvents.events.api_models_changed.emit()
	return true


static func set_active_model(model: String) -> bool:
	if find_profile_index(model) < 0 or config.active_model == model:
		return false
	config.active_model = model
	save_config()
	AgentEvents.events.api_models_changed.emit()
	return true


static func save_proxy_address(proxy_address: String) -> void:
	var normalized_proxy_address := proxy_address.strip_edges()
	if normalized_proxy_address != get_proxy_address():
		Setting.set_string(PROXY_ADDRESS_KEY, normalized_proxy_address)
		Setting.save()
		AgentEvents.events.proxy_address_changed.emit()
	pass


static func get_client(model: String = "") -> OpenAiClient:
	var index := find_profile_index(model)
	var profile := config.profiles[index] if index >= 0 else get_active_profile()
	var token := profile.api_token if not profile.api_token.is_empty() else OS.get_environment(API_KEY_ENV)
	return OpenAiClient.new(token, profile.api_url, profile.model)


static func get_active_profile() -> ApiModelProfile:
	var index := find_profile_index(config.active_model)
	return config.profiles[index]


static func find_profile_index(model: String) -> int:
	var normalized := model.strip_edges()
	for index in range(config.profiles.size()):
		if config.profiles[index].model == normalized:
			return index
	return -1


# ----------------------------------------------------------------------------------------------------------------------
# Encrypted storage

static func load_config() -> ApiConfig:
	if not FileAccess.file_exists(CONFIG_FILE_PATH):
		return ApiConfig.default()
	var file := FileAccess.open_encrypted_with_pass(CONFIG_FILE_PATH, FileAccess.READ, "zfoo")
	if file == null:
		Log.error("load encrypted API config failed path:[{}] error:[{}]", CONFIG_FILE_PATH, FileAccess.get_open_error())
		return ApiConfig.default()
	var json_text := file.get_as_text()
	file.close()
	var loaded: ApiConfig = JsonUtils.json_to_object(json_text, ApiConfig)
	if loaded == null:
		Log.error("load encrypted API config failed path:[{}] invalid JSON structure", CONFIG_FILE_PATH)
		return ApiConfig.default()
	return loaded


static func save_config() -> void:
	var file := FileAccess.open_encrypted_with_pass(CONFIG_FILE_PATH, FileAccess.WRITE, "zfoo")
	if file == null:
		Log.error("save encrypted API config failed path:[{}] error:[{}]", CONFIG_FILE_PATH, FileAccess.get_open_error())
		return
	file.store_string(JsonUtils.object_to_json(config))
	file.close()
	pass


class ApiConfig:
	extends RefCounted

	var profiles: Array[ApiModelProfile] = []
	var active_model: String = ""


	static func default() -> ApiConfig:
		var result := ApiConfig.new()
		result.profiles.append(ApiModelProfile.new(DEFAULT_MODEL, DEFAULT_API_URL, ""))
		result.active_model = DEFAULT_MODEL
		return result


class ApiModelProfile:
	extends RefCounted

	var model: String = ""
	var api_url: String = ""
	var api_token: String = ""


	func _init(p_model: String = "", p_api_url: String = "", p_api_token: String = "") -> void:
		model = p_model.strip_edges()
		api_url = p_api_url.strip_edges()
		api_token = p_api_token.strip_edges()
		pass


	func is_valid() -> bool:
		return not model.is_empty() and HttpUtils.is_valid_http_url(api_url)
