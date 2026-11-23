extends RefCounted


static func config_deserialization_test() -> void:
	var stored := {
		"profiles": [
			{"model": "model-a", "api_url": "https://a.example.com/chat", "api_token": "token-a"},
			{"model": "model-b", "api_url": "https://b.example.com/chat", "api_token": "token-b"},
		],
		"active_model": "model-b",
	}
	var loaded := ApiSetting.config_from_json(stored)
	assert(loaded != null)
	ApiSetting.ensure_valid_config(loaded)
	assert(loaded.profiles.size() == 2)
	assert(loaded.active_model == "model-b")
	assert(loaded.profiles[1].api_token == "token-b")
	pass


static func invalid_active_model_falls_back_test() -> void:
	var loaded := ApiSetting.ApiConfig.new()
	loaded.profiles.append(ApiSetting.ApiModelProfile.new("model-a", "https://api.example.com", ""))
	loaded.active_model = "missing"
	ApiSetting.ensure_valid_config(loaded)
	assert(loaded.active_model == "model-a")
	pass
