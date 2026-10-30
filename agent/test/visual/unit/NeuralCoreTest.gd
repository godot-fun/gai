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


static func reasoning_switches_thinking_state_test() -> void:
	var effect := NeuralCore.new()
	effect.on_agent_start(1)
	effect.on_message_update(1, "plan", OpenAiClient.STREAM_KIND_REASONING)
	effect.advance_state_blends(0.05)
	effect.sync_face_state_from_drives()
	assert(effect.face_state == NeuralCore.FaceState.THINKING)
	effect.on_message_update(1, "answer", OpenAiClient.STREAM_KIND_CONTENT)
	effect.advance_state_blends(0.05)
	effect.sync_face_state_from_drives()
	assert(effect.face_state == NeuralCore.FaceState.SPEAKING)
	effect.free()
	pass
