extends RefCounted


func new_effect() -> SolarSystem:
	var effect := SolarSystem.new()
	effect.size = Vector2(1280.0, 720.0)
	effect.on_agent_start(1)
	return effect


## Asserted from source for the same reason as [GoBoard] and [Orrery]: loading the factory script
## makes the headless runner crash at shutdown, so it is not instantiated here.
static func visual_type_is_registered_test() -> void:
	var source := FileAccess.get_file_as_string("res://agent/ui/visuals/VisualControl.gd")
	assert(source.contains("\tSOLAR_SYSTEM,"))
	assert(source.contains("Type.SOLAR_SYSTEM:"))
	assert(source.contains("return SolarSystem.new()"))
	pass


static func translations_exist_test() -> void:
	for locale_path: String in ["res://agent/config/locale/en.json", "res://agent/config/locale/zh.json"]:
		var text := FileAccess.get_file_as_string(locale_path)
		assert(text.contains("\"visual_solar_system\""), "missing visual_solar_system in %s" % locale_path)
	pass


func system_builds_upstream_planets_test() -> void:
	var effect := new_effect()
	assert(effect.planets.size() == SolarSystem.PLANET_SPECS.size())
	var earth := effect.planets[2]
	assert(earth.body_material.shader == SolarSystem.BODY_SHADER)
	assert(earth.body_material.get_shader_parameter("noise") != null)
	assert(earth.cloud_material != null)
	assert(earth.body_material.next_pass == earth.cloud_material)
	var ring_count := 0
	for child: Node in effect.planets[5].anchor.get_children():
		if child is MeshInstance3D and child.mesh is QuadMesh:
			ring_count += 1
	assert(ring_count == 1)
	assert(effect.sun_body_material.get_shader_parameter("noise") != null)
	assert(effect.sun_body_material.get_shader_parameter("noise") == SolarSystem.NOISE_STAR)
	assert(effect.sun_body_material.get_shader_parameter("noise_gaseous") == true)
	assert(effect.planets[2].atmosphere_material.shader == SolarSystem.ATMOSPHERE_SHADER)
	assert(effect.planets[2].anchor.get_node_or_null("Atmosphere") != null)
	# Only the star drops its shell: it rendered as a grey ring instead of a corona.
	assert(effect.sun_body.get_child_count() == 0)
	effect.free()
	pass


func overlay_stays_readable_test() -> void:
	var effect := new_effect()
	assert(effect.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(effect.container.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(SolarSystem.OVERLAY_ALPHA_DARK < 1.0)
	assert(SolarSystem.OVERLAY_ALPHA_LIGHT <= SolarSystem.OVERLAY_ALPHA_DARK)
	assert(is_equal_approx(effect.overlay.modulate.a, SolarSystem.OVERLAY_ALPHA_DARK if ThemeColor.is_dark_theme() else SolarSystem.OVERLAY_ALPHA_LIGHT))
	effect.free()
	pass


func streamed_tokens_charge_the_star_test() -> void:
	var effect := new_effect()
	assert(effect.sun_body_material.get_shader_parameter("emit") == SolarSystem.SUN_EMIT_BASE)
	for _index in range(40):
		effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	assert(effect.target_energy > 0.0)
	effect.step_system(0.4)
	assert(effect.energy > 0.0)
	assert(effect.sun_body_material.get_shader_parameter("emit") > SolarSystem.SUN_EMIT_BASE)
	effect.free()
	pass


func orbits_are_sampled_flat_ellipses_test() -> void:
	var effect := new_effect()
	assert(effect.orbit_paths.size() == SolarSystem.PLANET_SPECS.size())
	for index in range(effect.orbit_paths.size()):
		var path := effect.orbit_paths[index]
		assert(path.size() == SolarSystem.ORBIT_SAMPLES + 1)
		var expected := float(SolarSystem.PLANET_SPECS[index]["orbit"])
		for point: Vector3 in path:
			assert(absf(point.length() - expected) < 0.05)
		assert(path[0].is_equal_approx(path[path.size() - 1]))
	effect.free()
	pass


func orbit_layer_draws_the_rings_with_the_screen_space_shader_test() -> void:
	var effect := new_effect()
	assert(effect.orbit_layer.material == effect.orbit_material)
	assert(effect.orbit_material.shader == SolarSystem.ORBITS_SHADER)
	assert(effect.overlay.get_child(0) == effect.orbit_layer)
	assert(effect.orbit_normals.size() == SolarSystem.PLANET_SPECS.size())
	assert(effect.orbit_radii.size() == SolarSystem.PLANET_SPECS.size())
	assert(effect.orbit_normals[0].is_normalized())
	assert(SolarSystem.ORBIT_LINE_WIDTH < 1.0)
	assert(effect.orbit_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	effect.free()
	pass


func orbit_strokes_follow_the_theme_accent_and_stay_translucent_test() -> void:
	var effect := new_effect()
	var accent := VisualColor.appearance_color(ThemeColor.accent_theme_color())
	var color := effect.orbit_line_color()
	assert(is_equal_approx(color.h, accent.h))
	assert(color.s < accent.s - 0.001, "ring stroke must stay muted against the warm planets")
	assert(color.a > 0.0 and color.a < 1.0)
	effect.free()
	pass


func orbit_angles_follow_the_pivots_test() -> void:
	var effect := new_effect()
	var before := effect.planets[0].orbit_angle
	effect.step_system(1.0)
	assert(effect.planets[0].orbit_angle != before)
	assert(is_equal_approx(effect.planets[0].pivot.rotation.y, effect.planets[0].orbit_angle))
	for planet: SolarSystem.Planet in effect.planets:
		assert(planet.orbit_angle >= 0.0 and planet.orbit_angle < TAU)
	effect.free()
	pass


func tool_claims_a_planet_and_sends_a_probe_test() -> void:
	var effect := new_effect()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	assert(effect.tool_planets.has("t1"))
	assert(effect.probes.has("t1"))
	var index: int = effect.tool_planets["t1"]
	assert(effect.planets[index].halo_target == 1.0)
	assert(not effect.planets[index].halo.visible)
	effect.step_system(0.3)
	assert(effect.planets[index].halo_energy > 0.0)
	assert(effect.planets[index].halo.visible)
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	assert(not effect.probes.has("t1"))
	assert(effect.planets[index].halo_target == 0.0)
	assert(effect.planets[index].flash == 1.0)
	assert(effect.bursts.size() >= 1)
	effect.free()
	pass


func parallel_tools_land_on_different_planets_test() -> void:
	var effect := new_effect()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t2", "read_file", {} as Dictionary[String, Variant])
	assert(effect.tool_planets["t1"] != effect.tool_planets["t2"])
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	assert(effect.planets[effect.tool_planets["t2"]].halo_target == 1.0)
	effect.free()
	pass


func failed_tool_flashes_the_error_color_test() -> void:
	var effect := new_effect()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	var index: int = effect.tool_planets["t1"]
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.error("boom"))
	assert(effect.planets[index].flash_color == VisualColor.neon_color(Colors.error))
	effect.free()
	pass


func agent_end_clears_probes_test() -> void:
	var effect := new_effect()
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	effect.on_tool_execution_start(1, "t2", "read_file", {} as Dictionary[String, Variant])
	await effect.on_agent_end(1, "boom")
	assert(effect.probes.is_empty())
	assert(effect.tool_planets.is_empty())
	assert(not effect.ending)
	for planet: SolarSystem.Planet in effect.planets:
		assert(planet.halo_target == 0.0)
	effect.free()
	pass


func system_renders_inside_the_tree_test() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var effect := SolarSystem.new()
	scene_tree.root.add_child.call_deferred(effect)
	await scene_tree.process_frame
	effect.on_agent_start(1)
	effect.set_visual_visible(true, false)
	effect.on_turn_start(1)
	effect.on_message_update(1, "thinking about the plan", OpenAiClient.STREAM_KIND_REASONING)
	effect.on_message_update(1, "streamed answer chunk", OpenAiClient.STREAM_KIND_CONTENT)
	effect.on_tool_execution_start(1, "t1", "grep", {} as Dictionary[String, Variant])
	for _frame in range(3):
		await scene_tree.process_frame
	effect.on_tool_execution_end(1, "t1", "grep", AgentToolResult.ok("done"))
	effect.on_tool_execution_end(1, "t2", "read_file", AgentToolResult.error("boom"))
	effect.on_message_complete(1, null)
	effect.on_turn_end(1)
	for _frame in range(3):
		await scene_tree.process_frame
	assert(effect.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	effect.queue_free()
	await scene_tree.process_frame
	pass
