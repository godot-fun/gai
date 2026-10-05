@abstract
class_name VisualEffect
extends Control

## Effect contract used by [VisualControl]. Override the hooks needed by an effect.


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.NONE


func set_visual_visible(_show: bool, _animated: bool) -> void:
	pass


func reset_visual() -> void:
	pass


func on_agent_start(_session_id: int) -> void:
	pass


func on_agent_end(_error_message: String) -> float:
	return 0.0


func on_turn_start() -> void:
	pass


func on_turn_end() -> void:
	pass


func on_message_update(_chunk: String, _stream_kind: String) -> void:
	pass


func on_message_complete(_usage: OpenAiUsage) -> void:
	pass


func on_tool_execution_start(_tool_call_id: String, _tool_name: String, _args: Dictionary[String, Variant]) -> void:
	pass


func on_tool_execution_end(_tool_call_id: String, _tool_name: String, _agent_tool_result: AgentToolResult) -> void:
	pass


func on_chat_entry_add(_entry: ChatEntry) -> void:
	pass


func on_theme_changed() -> void:
	pass
