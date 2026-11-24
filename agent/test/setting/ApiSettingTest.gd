extends RefCounted


static func config_deserialization_test() -> void:
	var stored := ApiSetting.ApiConfig.new()
	stored.profiles.append(ApiSetting.ApiModelProfile.new("model-a", "https://a.example.com/chat", "token-a"))
	stored.profiles.append(ApiSetting.ApiModelProfile.new("model-b", "https://b.example.com/chat", "token-b"))
	stored.active_model = "model-b"
	stored.reasoning_effort = "max"
	var loaded: ApiSetting.ApiConfig = JsonUtils.json_to_object(JsonUtils.object_to_json(stored), ApiSetting.ApiConfig)
	assert(loaded != null)
	assert(loaded.profiles.size() == 2)
	assert(loaded.active_model == "model-b")
	assert(loaded.reasoning_effort == "max")
	assert(loaded.profiles[1].api_token == "token-b")
	pass


static func default_config_has_default_model_test() -> void:
	var created := ApiSetting.create_default_config()
	assert(not created.profiles.is_empty())
	assert(created.profiles[0].model == ApiSetting.DEFAULT_MODEL)
	assert(created.profiles[0].api_url == ApiSetting.DEFAULT_API_URL)
	assert(created.active_model == ApiSetting.DEFAULT_MODEL)
	assert(created.reasoning_effort == ApiSetting.DEFAULT_REASONING_EFFORT)
	pass


static func default_config_imports_environment_profiles_test() -> void:
	var previous_token := OS.get_environment("DASHSCOPE_API_KEY")
	OS.set_environment("DASHSCOPE_API_KEY", "dashscope-test-token")
	var created := ApiSetting.create_default_config()
	if previous_token.is_empty():
		OS.unset_environment("DASHSCOPE_API_KEY")
	else:
		OS.set_environment("DASHSCOPE_API_KEY", previous_token)
	var qwen_profile: ApiSetting.ApiModelProfile = null
	for profile in created.profiles:
		if profile.model == "qwen-plus":
			qwen_profile = profile
			break
	assert(qwen_profile != null)
	assert(qwen_profile.api_token == "dashscope-test-token")
	pass
