extends RefCounted


static func visual_type_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.FILTER_CAROUSEL))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.FILTER_CAROUSEL)
	assert(effect != null)
	assert(effect.get_visual_type() == VisualType.Type.FILTER_CAROUSEL)
	effect.free()
	control.free()
	pass


static func preset_catalog_test() -> void:
	assert(FilterCarousel.PRESETS.size() >= 110)
	var names: Dictionary[String, bool] = {}
	for preset: Dictionary in FilterCarousel.PRESETS:
		var name := str(preset["name"])
		assert(not names.has(name))
		assert(int(preset["mode"]) > 0)
		names[name] = true
	pass


static func shader_and_presets_load_test() -> void:
	var effect := FilterCarousel.new()
	effect._ready()
	assert(effect.filter_material.shader != null)
	for index in range(FilterCarousel.PRESETS.size()):
		effect.apply_preset(index)
		assert(not effect.current_preset_name.is_empty())
	effect.free()
	pass
