const IMPOSSIBLE_ROOM_SCRIPT := preload("res://agent/ui/visuals/impossible_room/ImpossibleRoom.gd")


static func visual_script_instantiates_test() -> void:
	var effect: Variant = IMPOSSIBLE_ROOM_SCRIPT.new()
	assert(effect.get_script() == IMPOSSIBLE_ROOM_SCRIPT)
	effect.free()
	pass


static func sentence_impulse_scales_and_clamps_test() -> void:
	var short_impulse: float = IMPOSSIBLE_ROOM_SCRIPT.impulse_for_sentence("Hi.")
	var medium_impulse: float = IMPOSSIBLE_ROOM_SCRIPT.impulse_for_sentence("A complete sentence with enough weight to move the room.")
	var huge_impulse: float = IMPOSSIBLE_ROOM_SCRIPT.impulse_for_sentence("x".repeat(1000))
	assert(short_impulse >= 360.0)
	assert(medium_impulse > short_impulse)
	assert(is_equal_approx(huge_impulse, 780.0))
	pass


func spring_returns_toward_origin_test() -> void:
	var effect: Variant = IMPOSSIBLE_ROOM_SCRIPT.new()
	effect.displacement_px = 80.0
	effect.velocity_px = 0.0
	effect.step_motion(1.0 / 60.0)
	assert(effect.velocity_px < 0.0)
	assert(effect.displacement_px < 80.0)
	effect.free()
	pass


func shader_surface_enters_tree_test() -> void:
	var effect: Variant = IMPOSSIBLE_ROOM_SCRIPT.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	await scene_tree.process_frame
	assert(effect.room_material != null)
	assert(effect.room_material.shader != null)
	effect.queue_free()
	await scene_tree.process_frame
	pass
