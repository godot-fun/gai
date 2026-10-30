extends RefCounted


static func neural_core_factory_test() -> void:
	var effect := VisualControl.create_effect(VisualControl.Type.NEURAL_CORE)
	assert(effect is NeuralCore)
	effect.free()
	pass


static func visual_type_is_registered_test() -> void:
	var source := FileAccess.get_file_as_string("res://agent/ui/visuals/VisualControl.gd")
	assert(source.contains("\tNEURAL_CORE,"))
	assert(source.contains("Type.NEURAL_CORE:"))
	assert(source.contains("return NeuralCore.new()"))
	pass


static func anatomy_builds_mesh_and_tendrils_test() -> void:
	var anatomy := NeuralCoreAnatomy.build()
	assert(anatomy.point_positions.size() > 2000)
	assert(anatomy.mesh_edges.size() > 100)
	assert(anatomy.tendrils.size() == NeuralCoreAnatomy.N_TENDRILS)
	assert(anatomy.arc_points.size() == 620)
	pass


static func meter_level_scales_stream_energy_test() -> void:
	var effect := NeuralCore.new()
	effect.running = true
	effect.envelope = 0.045
	assert(effect.meter_level_for_display() >= 0.85)
	effect.envelope = 0.0
	effect.think_blend = 0.0
	effect.activity_label = "THINKING"
	assert(effect.meter_level_for_display() >= 0.25)
	effect.free()
	pass


static func activity_follows_chat_entry_test() -> void:
	var effect := NeuralCore.new()
	effect.on_agent_start(1)
	effect.on_chat_entry_add(1, ChatEntry.new(ChatEntry.KIND_THINKING, ChatEntry.TITLE_THINKING, ""))
	assert(effect.activity_label == "THINKING")
	effect.on_chat_entry_add(1, ChatEntry.new(ChatEntry.KIND_TOOL, "read", ""))
	assert(effect.activity_label == "READ")
	effect.on_chat_entry_add(1, ChatEntry.new(ChatEntry.KIND_AGENT, ChatEntry.TITLE_AGENT, "done"))
	assert(effect.activity_label == "RESPONDING")
	effect.free()
	pass
