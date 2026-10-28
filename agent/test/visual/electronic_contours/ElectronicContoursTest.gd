const ELECTRONIC_CONTOURS_SCRIPT := preload("res://agent/ui/visuals/electronic_contours/ElectronicContours.gd")


static func visual_script_instantiates_test() -> void:
	var effect: Variant = ELECTRONIC_CONTOURS_SCRIPT.new()
	assert(effect.get_script() == ELECTRONIC_CONTOURS_SCRIPT)
	effect.free()
	pass


static func energy_composition_never_overflows_test() -> void:
	assert(is_equal_approx(ELECTRONIC_CONTOURS_SCRIPT.combine_energy(0.0, 0.5), 0.5))
	assert(ELECTRONIC_CONTOURS_SCRIPT.combine_energy(0.6, 0.5) > 0.6)
	assert(ELECTRONIC_CONTOURS_SCRIPT.combine_energy(0.6, 0.5) < 1.0)
	assert(ELECTRONIC_CONTOURS_SCRIPT.combine_energy(1.0, 1.0) == 1.0)
	pass


static func stream_energy_is_bounded_test() -> void:
	assert(is_equal_approx(ELECTRONIC_CONTOURS_SCRIPT.stream_energy_for_length(1), 0.004))
	assert(is_equal_approx(ELECTRONIC_CONTOURS_SCRIPT.stream_energy_for_length(1000), 0.042))
	pass


static func scan_density_adapts_to_viewport_height_test() -> void:
	assert(ELECTRONIC_CONTOURS_SCRIPT.line_count_for_height(0.0) == 72.0)
	assert(ELECTRONIC_CONTOURS_SCRIPT.line_count_for_height(600.0) == 72.0)
	assert(ELECTRONIC_CONTOURS_SCRIPT.line_count_for_height(1080.0) == 127.0)
	assert(ELECTRONIC_CONTOURS_SCRIPT.line_count_for_height(1440.0) == 169.0)
	assert(ELECTRONIC_CONTOURS_SCRIPT.line_count_for_height(2160.0) == 254.0)
	pass


func spring_builds_and_releases_terrain_test() -> void:
	var effect: Variant = ELECTRONIC_CONTOURS_SCRIPT.new()
	effect.relief_energy = 1.0
	for _index in range(18):
		effect.step_relief(1.0 / 60.0)
	assert(effect.relief_amount > 0.0)
	assert(effect.raster_phase > 0.0)
	effect.relief_energy = 0.0
	for _index in range(240):
		effect.step_relief(1.0 / 60.0)
	assert(effect.relief_amount < 0.01)
	effect.free()
	pass


func quake_front_advances_test() -> void:
	var effect: Variant = ELECTRONIC_CONTOURS_SCRIPT.new()
	effect.trigger_quake(0.8)
	var start_progress: float = effect.quake_progress
	effect.step_relief(1.0 / 60.0)
	assert(effect.quake_progress > start_progress)
	assert(effect.quake_energy < 0.8)
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect: Variant = ELECTRONIC_CONTOURS_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.relief_material != null)
	assert(effect.relief_material.shader != null)
	effect.queue_free()
	await scene_tree.process_frame
	pass
