class_name VisualControl
extends Control

const TAI_CHI_SCRIPT := preload("res://agent/ui/visuals/tai_chi/TaiChi.gd")

## Single event bridge that routes an agent run to the selected visual effect.
## Only one effect instance and one owning session are supported at a time. A newer
## agent run replaces the previous animation; late events from the old run are ignored.


## Session whose run is currently represented; 0 while no run is tracked.
var running_session_id: int = 0
var current_effect: VisualEffect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	connect_visual_events()
	mount_selected_effect()
	pass


func mount_selected_effect() -> void:
	# Recreate instead of reusing the node so no animation state leaks between runs or types.
	unmount_current_effect()
	var effect := create_effect(AgentSetting.get_visual_type())
	if effect == null:
		return
	current_effect = effect
	add_child(current_effect)
	current_effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pass


func create_effect(visual_type: VisualType.Type) -> VisualEffect:
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
			return TAI_CHI_SCRIPT.new()
	return null


func unmount_current_effect() -> void:
	if current_effect == null:
		return
	current_effect.set_visual_visible(false, false)
	remove_child(current_effect)
	current_effect.queue_free()
	current_effect = null
	pass


func connect_visual_events() -> void:
	gdf.events.theme_changed.connect(on_theme_changed)
	gdf.events.theme_color_changed.connect(on_theme_changed)
	AgentEvents.events.agent_start.connect(on_agent_start)
	AgentEvents.events.agent_end.connect(on_agent_end)
	AgentEvents.events.session_stop.connect(on_session_stop)
	AgentEvents.events.turn_start.connect(on_turn_start)
	AgentEvents.events.turn_end.connect(on_turn_end)
	AgentEvents.events.message_update.connect(on_message_update)
	AgentEvents.events.message_complete.connect(on_message_complete)
	AgentEvents.events.tool_execution_start.connect(on_tool_execution_start)
	AgentEvents.events.tool_execution_end.connect(on_tool_execution_end)
	AgentEvents.events.chat_entry_add.connect(on_chat_entry_add)
	AgentEvents.events.visual_type_changed.connect(on_visual_type_changed)
	pass


func on_agent_start(session_id: int) -> void:
	# Newest run always owns the single effect. There is intentionally no animation queue.
	if running_session_id != 0:
		mount_selected_effect()
	running_session_id = session_id
	var effect := get_selected_effect()
	if effect == null:
		return
	effect.reset_visual()
	effect.on_agent_start(session_id)
	effect.set_visual_visible(true, true)
	pass


func on_agent_end(session_id: int, error_message: String) -> void:
	if session_id != running_session_id:
		return
	var effect := get_selected_effect()
	if is_instance_valid(effect):
		await effect.on_agent_end(error_message)
	if running_session_id == session_id:
		if is_instance_valid(effect):
			effect.set_visual_visible(false, true)
		running_session_id = 0
	pass


func on_session_stop(session_id: int) -> void:
	if session_id != running_session_id or has_visible_effect():
		return
	running_session_id = 0
	pass


func on_turn_start(session_id: int) -> void:
	var effect := get_running_effect(session_id)
	if effect != null:
		effect.on_turn_start()
	pass


func on_turn_end(session_id: int) -> void:
	var effect := get_running_effect(session_id)
	if effect != null:
		effect.on_turn_end()
	pass


func on_message_update(session_id: int, chunk: String, stream_kind: String) -> void:
	var effect := get_running_effect(session_id)
	if effect != null:
		effect.on_message_update(chunk, stream_kind)
	pass


func on_message_complete(session_id: int, usage: OpenAiUsage) -> void:
	var effect := get_running_effect(session_id)
	if effect != null:
		effect.on_message_complete(usage)
	pass


func on_tool_execution_start(session_id: int, tool_call_id: String, tool_name: String, args: Dictionary[String, Variant]) -> void:
	var effect := get_running_effect(session_id)
	if effect != null:
		effect.on_tool_execution_start(tool_call_id, tool_name, args)
	pass


func on_tool_execution_end(session_id: int, tool_call_id: String, tool_name: String, agent_tool_result: AgentToolResult) -> void:
	var effect := get_running_effect(session_id)
	if effect != null:
		effect.on_tool_execution_end(tool_call_id, tool_name, agent_tool_result)
	pass


func on_chat_entry_add(session_id: int, entry: ChatEntry) -> void:
	var effect := get_running_effect(session_id)
	if effect != null:
		effect.on_chat_entry_add(entry)
	pass


func on_theme_changed() -> void:
	if current_effect != null:
		current_effect.on_theme_changed()
	pass


func on_visual_type_changed(_visual_type: int) -> void:
	mount_selected_effect()
	var effect := get_selected_effect()
	if effect == null or running_session_id == 0 or not AgentSessionManager.is_running(running_session_id):
		return
	effect.reset_visual()
	effect.on_agent_start(running_session_id)
	effect.set_visual_visible(true, true)
	pass


func get_selected_effect() -> VisualEffect:
	if current_effect == null or current_effect.get_visual_type() != AgentSetting.get_visual_type():
		return null
	return current_effect


func get_running_effect(session_id: int) -> VisualEffect:
	# Reject late events from a run whose animation was replaced by a newer session.
	# Selecting another chat does not affect ownership; only agent_start transfers it.
	if session_id != running_session_id:
		return null
	var effect := get_selected_effect()
	return effect if effect != null and effect.visible else null


func has_visible_effect() -> bool:
	return current_effect != null and current_effect.visible
