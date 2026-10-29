extends RefCounted


static func every_classic_type_creates_its_effect_test() -> void:
	var expected: Dictionary[VisualControl.Type, String] = {
		VisualControl.Type.WARP_SPEED: "WarpSpeed",
		VisualControl.Type.SNAP_DISSOLVE: "SnapDissolve",
		VisualControl.Type.GAME_OF_LIFE: "GameOfLife",
		VisualControl.Type.PIPES_3D: "Pipes3D",
		VisualControl.Type.LAVA_LAMP: "LavaLamp",
		VisualControl.Type.DOOM_FIRE: "DoomFire",
		VisualControl.Type.FRACTAL_ZOOM: "FractalZoom",
		VisualControl.Type.TESLA_LIGHTNING: "TeslaLightning",
		VisualControl.Type.MURMURATION: "Murmuration",
	}
	for visual_type: VisualControl.Type in expected:
		var effect := VisualControl.create_effect(visual_type)
		assert(effect != null)
		assert(effect.get_script().get_global_name() == expected[visual_type])
		effect.free()
	pass


static func every_classic_type_has_translations_test() -> void:
	for locale_path: String in ["res://agent/config/locale/en.json", "res://agent/config/locale/zh.json"]:
		var text := FileAccess.get_file_as_string(locale_path)
		for visual_name: String in ["warp_speed", "snap_dissolve", "game_of_life", "pipes_3d", "lava_lamp", "doom_fire", "fractal_zoom", "tesla_lightning", "murmuration"]:
			assert(text.contains("\"visual_%s\"" % visual_name))
	pass


func classic_effects_survive_a_full_event_sequence_in_tree_test() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	for visual_type: VisualControl.Type in [VisualControl.Type.WARP_SPEED, VisualControl.Type.SNAP_DISSOLVE, VisualControl.Type.GAME_OF_LIFE,
			VisualControl.Type.PIPES_3D, VisualControl.Type.LAVA_LAMP, VisualControl.Type.DOOM_FIRE, VisualControl.Type.FRACTAL_ZOOM,
			VisualControl.Type.TESLA_LIGHTNING, VisualControl.Type.MURMURATION]:
		var effect := VisualControl.create_effect(visual_type)
		scene_tree.root.add_child.call_deferred(effect)
		await scene_tree.process_frame
		effect.size = Vector2(1280.0, 720.0)
		effect.on_agent_start(1)
		effect.set_visual_visible(true, false)
		effect.on_turn_start(1)
		effect.on_message_update(1, "thinking about the plan", OpenAiClient.STREAM_KIND_REASONING)
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
		effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
		effect.on_tool_execution_start(1, "t2", "read_file", {} as Dictionary[String, Variant])
		for _frame in range(3):
			await scene_tree.process_frame
		effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
		effect.on_tool_execution_end(1, "t2", "read_file", AgentToolResult.error("boom"))
		effect.on_message_complete(1, null)
		effect.on_turn_end(1)
		for _frame in range(3):
			await scene_tree.process_frame
		effect.queue_free()
		await scene_tree.process_frame
	pass
