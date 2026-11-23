static func session_model_round_trip_test() -> void:
	var session := AgentSession.new(42)
	assert(session.model.is_empty())
	session.model = "deepseek-chat"
	var json := JsonUtils.object_to_json(session)
	var restored: AgentSession = JsonUtils.json_to_object(json, AgentSession)

	assert(restored != null)
	assert(restored.id == 42)
	assert(restored.model == "deepseek-chat")
	assert(session.deep_clone().model == "deepseek-chat")
	pass
