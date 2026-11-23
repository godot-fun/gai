extends RefCounted


static func config_deserialization_test() -> void:
	var stored := ApiSetting.ApiConfig.new()
	stored.profiles.append(ApiSetting.ApiModelProfile.new("model-a", "https://a.example.com/chat", "token-a"))
	stored.profiles.append(ApiSetting.ApiModelProfile.new("model-b", "https://b.example.com/chat", "token-b"))
	stored.active_model = "model-b"
	var loaded: ApiSetting.ApiConfig = JsonUtils.json_to_object(JsonUtils.object_to_json(stored), ApiSetting.ApiConfig)
	assert(loaded != null)
	assert(loaded.profiles.size() == 2)
	assert(loaded.active_model == "model-b")
	assert(loaded.profiles[1].api_token == "token-b")
	pass


static func default_config_has_default_model_test() -> void:
	var created := ApiSetting.ApiConfig.default()
	assert(created.profiles.size() == 1)
	assert(created.profiles[0].model == ApiSetting.DEFAULT_MODEL)
	assert(created.profiles[0].api_url == ApiSetting.DEFAULT_API_URL)
	assert(created.active_model == ApiSetting.DEFAULT_MODEL)
	pass
