## Unit coverage for persisted per-session drafts and pending message order.

static func session_queue_json_round_trip_test() -> void:
	var session := AgentSession.new(42)
	session.draft_text = "unfinished draft"
	session.pending_messages.append("second turn")
	session.pending_messages.append("third turn")
	var json := JsonUtils.object_to_json(session)
	var restored: AgentSession = JsonUtils.json_to_object(json, AgentSession)
	assert(restored != null)
	assert(restored.draft_text == "unfinished draft")
	assert(restored.pending_messages.size() == 2)
	assert(restored.pending_messages[0] == "second turn")
	assert(restored.pending_messages[1] == "third turn")
	pass


static func pending_message_delete_keeps_fifo_order_test() -> void:
	var session := AgentSession.new(42)
	session.pending_messages.append("one")
	session.pending_messages.append("two")
	session.pending_messages.append("three")
	session.pending_messages.remove_at(session.pending_messages.find("two"))
	assert(session.pending_messages.size() == 2)
	assert(session.pending_messages[0] == "one")
	assert(session.pending_messages[1] == "three")
	pass


static func duplicate_message_delete_removes_first_match_test() -> void:
	var pending: Array[String] = ["same", "middle", "same"]
	pending.remove_at(pending.find("same"))
	assert(pending == ["middle", "same"])
	pass
