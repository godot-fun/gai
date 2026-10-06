extends RefCounted


static func neural_aurora_factory_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.NEURAL_AURORA))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.NEURAL_AURORA)
	assert(effect is NeuralAurora)
	assert(effect.get_visual_type() == VisualType.Type.NEURAL_AURORA)
	effect.free()
	control.free()
	pass


static func neural_aurora_tool_label_test() -> void:
	assert(NeuralAurora.public_tool_name("web_search") == "WEB SEARCH")
	assert(NeuralAurora.public_tool_name("") == "TOOL")
	pass
