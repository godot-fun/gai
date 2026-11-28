class_name ModelSetting
extends RefCounted

## Encrypted OpenAI-compatible model profiles — the configured models, the active one, and the
## reasoning effort. Each profile owns its endpoint and credential, so this is also the only place
## credentials are stored (encrypted, in the synced cloud folder).

const DEFAULT_API_URL := "https://api.deepseek.com/chat/completions"
const DEFAULT_MODEL := "deepseek-flash"
const REASONING_EFFORT_LOW := "low"
const REASONING_EFFORT_HIGH := "high"
const REASONING_EFFORT_MAX := "max"
const DEFAULT_REASONING_EFFORT := REASONING_EFFORT_LOW
const REASONING_EFFORTS: Array[String] = [REASONING_EFFORT_LOW, REASONING_EFFORT_HIGH, REASONING_EFFORT_MAX]
## File name inside the synced cloud folder, so models and credentials follow the user.
const CONFIG_FILE_PATH := "model.dat"

static var config: ApiConfig = load_config()

# ----------------------------------------------------------------------------------------------------------------------
# Data models

class ApiConfig:
	extends RefCounted

	var profiles: Array[ApiModelProfile] = []
	var active_model: String = ""
	var reasoning_effort: String = DEFAULT_REASONING_EFFORT
	pass

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

# ----------------------------------------------------------------------------------------------------------------------
# Model queries

static func get_models() -> Array[String]:
	var result: Array[String] = []
	for profile in config.profiles:
		result.append(profile.model)
	return result


static func get_profiles() -> Array[ApiModelProfile]:
	var result: Array[ApiModelProfile] = []
	result.assign(config.profiles)
	return result


static func get_active_profile() -> ApiModelProfile:
	var index := find_profile_index(config.active_model)
	return config.profiles[index]


static func get_reasoning_effort() -> String:
	return config.reasoning_effort


# ----------------------------------------------------------------------------------------------------------------------
# Model mutations

## Adds one complete model profile without changing the default model.
static func add_model(model: String, api_url: String, api_token: String) -> bool:
	var profile := ApiModelProfile.new(model, api_url, api_token)
	if not profile.is_valid() or find_profile_index(profile.model) >= 0:
		return false
	config.profiles.append(profile)
	save_config()
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
	return true


static func set_active_model(model: String) -> bool:
	if find_profile_index(model) < 0 or config.active_model == model:
		return false
	config.active_model = model
	save_config()
	return true


static func set_reasoning_effort(reasoning_effort: String) -> bool:
	if config.reasoning_effort == reasoning_effort:
		return false
	config.reasoning_effort = reasoning_effort
	save_config()
	return true


# ----------------------------------------------------------------------------------------------------------------------
# Client

static func get_client(model: String = "") -> OpenAiClient:
	var index := find_profile_index(model)
	var profile := config.profiles[index] if index >= 0 else get_active_profile()
	return OpenAiClient.new(profile.api_token, profile.api_url, profile.model)


# ----------------------------------------------------------------------------------------------------------------------
# Internal lookup

static func find_profile_index(model: String) -> int:
	var normalized := model.strip_edges()
	for index in range(config.profiles.size()):
		if config.profiles[index].model == normalized:
			return index
	return -1


# ----------------------------------------------------------------------------------------------------------------------
# Encrypted storage

static func load_config() -> ApiConfig:
	var path := AgentDataDir.get_dir_path(CONFIG_FILE_PATH, AgentDataDir.Scope.CLOUD)
	if not FileAccess.file_exists(path):
		return create_default_config()
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, "gai_godot_zfoo")
	if file == null:
		Log.error("load encrypted API config failed path:[{}] error:[{}]", path, FileAccess.get_open_error())
		return create_default_config()
	var json_text := file.get_as_text()
	file.close()
	var loaded: ApiConfig = JsonUtils.json_to_object(json_text, ApiConfig)
	if loaded == null:
		Log.error("load encrypted API config failed path:[{}] invalid JSON structure", path)
		return create_default_config()
	return loaded


static func save_config() -> void:
	var path := AgentDataDir.get_dir_path(CONFIG_FILE_PATH, AgentDataDir.Scope.CLOUD)
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, "gai_godot_zfoo")
	if file == null:
		Log.error("save encrypted API config failed path:[{}] error:[{}]", path, FileAccess.get_open_error())
		return
	file.store_string(JsonUtils.object_to_json(config))
	file.close()
	AgentEvents.events.model_settings_changed.emit()
	pass



# ----------------------------------------------------------------------------------------------------------------------
# Default config

## Builds the first-run config and imports credentials from common OpenAI-compatible providers.
static func create_default_config() -> ApiConfig:
	var result := ApiConfig.new()
	result.profiles.append(ApiModelProfile.new(DEFAULT_MODEL, DEFAULT_API_URL, OS.get_environment("DEEPSEEK_API_KEY")))
	append_environment_profile(result, "gpt-5", "https://api.openai.com/v1/chat/completions", "OPENAI_API_KEY")
	append_environment_profile(result, "gemini-2.5-flash", "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions", "GEMINI_API_KEY")
	append_environment_profile(result, "openrouter/auto", "https://openrouter.ai/api/v1/chat/completions", "OPENROUTER_API_KEY")
	append_environment_profile(result, "qwen-plus", "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", "DASHSCOPE_API_KEY")
	result.active_model = DEFAULT_MODEL
	return result


static func append_environment_profile(result: ApiConfig, model: String, api_url: String, environment_name: String) -> void:
	var api_token := OS.get_environment(environment_name).strip_edges()
	if not api_token.is_empty():
		result.profiles.append(ApiModelProfile.new(model, api_url, api_token))
	pass
