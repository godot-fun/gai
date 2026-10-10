class_name RuntimeState
extends RefCounted


var stop_requested: bool = false
var step_thinking_entry: ChatEntry = null
var step_agent_entry: ChatEntry = null

var cancel_scope: CancelScope = CancelScope.new()
