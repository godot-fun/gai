class_name VisualControl
extends Control

## Single global event bridge for the visual overlay. All active sessions feed one shared
## effect, so their animation events may interleave. The overlay begins with the first
## active run and finishes only after the last run stops; it is not a per-session view.


var current_effect: VisualEffect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AgentEvents.events.agent_start.connect(on_agent_start)
	AgentEvents.events.session_stop.connect(on_session_stop)
	AgentEvents.events.turn_start.connect(on_turn_start)
	AgentEvents.events.turn_end.connect(on_turn_end)
	AgentEvents.events.message_update.connect(on_message_update)
	AgentEvents.events.message_complete.connect(on_message_complete)
	AgentEvents.events.tool_execution_start.connect(on_tool_execution_start)
	AgentEvents.events.tool_execution_end.connect(on_tool_execution_end)
	AgentEvents.events.chat_entry_add.connect(on_chat_entry_add)
	pass


static func create_effect(visual_type: VisualType.Type) -> VisualEffect:
	match visual_type:
		VisualType.Type.JARVIS:
			return JarvisControl.new()
		VisualType.Type.TRANSFORMER:
			return TransformerController.new()
		VisualType.Type.REASONING_TREE:
			return ReasoningTree.new()
		VisualType.Type.TOOL_CONSTELLATION:
			return ToolConstellation.new()
		VisualType.Type.CONTEXT_MEMORY_RIVER:
			return ContextMemoryRiver.new()
		VisualType.Type.NEURAL_AURORA:
			return NeuralAurora.new()
		VisualType.Type.SEMANTIC_BLACK_HOLE:
			return SemanticBlackHole.new()
		VisualType.Type.CYBER_COMMAND_DECK:
			return CyberCommandDeck.new()
		VisualType.Type.QUANTUM_CIRCUIT:
			return QuantumCircuit.new()
		VisualType.Type.DESKTOP_CAT:
			return DesktopCat.new()
		VisualType.Type.GEOMETRIC_GENESIS:
			return GeometricGenesis.new()
		VisualType.Type.MATRIX_RAIN:
			return MatrixRain.new()
		VisualType.Type.FILTER_CAROUSEL:
			return FilterCarousel.new()
		VisualType.Type.INK_LANDSCAPE:
			return InkLandscape.new()
		VisualType.Type.TAI_CHI:
			return TaiChi.new()
	return null

func on_agent_start(session_id: int) -> void:
	ChatEntryCursor.remove_session(session_id)
	var effect := prepare_effect()
	# A visible effect already represents another active run. Its later events are still
	# forwarded below, but it is deliberately not reset for each concurrent session.
	if effect == null or effect.visible:
		return
	effect.on_agent_start(session_id)
	effect.set_visual_visible(true, true)
	pass


func prepare_effect() -> VisualEffect:
	if current_effect != null:
		if current_effect.visible:
			return current_effect
		current_effect.queue_free()
		current_effect = null
	var effect := create_effect(AgentSetting.get_visual_type())
	if effect == null:
		return null
	current_effect = effect
	add_child(effect)
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return current_effect


func on_session_stop(session_id: int, error_message: String) -> void:
	ChatEntryCursor.remove_session(session_id)
	# Keep the global overlay alive while any other session is still running.
	if not RuntimeManager.runtimes.is_empty():
		return
	var effect := current_effect
	if is_instance_valid(effect):
		await effect.on_agent_end(session_id, error_message)
	if not RuntimeManager.runtimes.is_empty():
		return
	if is_instance_valid(effect):
		effect.set_visual_visible(false, true)
	pass


func on_turn_start(session_id: int) -> void:
	var effect := get_running_effect(session_id)
	if effect != null:
		effect.on_turn_start(session_id)
	pass


func on_turn_end(session_id: int) -> void:
	var effect := get_running_effect(session_id)
	if effect != null:
		effect.on_turn_end(session_id)
	pass


func on_message_update(session_id: int, chunk: String, stream_kind: String) -> void:
	var effect := get_running_effect(session_id)
	if effect != null:
		effect.on_message_update(session_id, chunk, stream_kind)
	pass


func on_message_complete(session_id: int, usage: OpenAiUsage) -> void:
	var effect := get_running_effect(session_id)
	if effect != null:
		effect.on_message_complete(session_id, usage)
	pass


func on_tool_execution_start(session_id: int, tool_call_id: String, tool_name: String, args: Dictionary[String, Variant]) -> void:
	var effect := get_running_effect(session_id)
	if effect != null:
		effect.on_tool_execution_start(session_id, tool_call_id, tool_name, args)
	pass


func on_tool_execution_end(session_id: int, tool_call_id: String, tool_name: String, agent_tool_result: AgentToolResult) -> void:
	var effect := get_running_effect(session_id)
	if effect != null:
		effect.on_tool_execution_end(session_id, tool_call_id, tool_name, agent_tool_result)
	pass


func on_chat_entry_add(session_id: int, entry: ChatEntry) -> void:
	var effect := get_running_effect(session_id)
	if effect != null:
		effect.on_chat_entry_add(session_id, entry)
	pass


func get_running_effect(session_id: int) -> VisualEffect:
	if not RuntimeManager.is_running(session_id):
		return null
	var effect := current_effect
	return effect if effect != null and effect.visible else null
