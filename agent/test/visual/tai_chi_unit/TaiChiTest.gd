extends RefCounted

static func visual_type_test() -> void:
	assert(VisualType.is_valid(VisualType.Type.TAI_CHI))
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.TAI_CHI)
	assert(effect != null)
	assert(effect.get_visual_type() == VisualType.Type.TAI_CHI)
	effect.free()
	control.free()
	pass


func opening_reveals_line_and_title_together_test() -> void:
	var flow := TaiChiOpeningFlow.new()
	assert(flow.line_progress() == 0.0)
	assert(flow.title_progress() == 0.0)
	flow.advance(TaiChiOpeningFlow.REVEAL_SECONDS * 0.25)
	assert(flow.line_progress() > 0.0)
	assert(flow.title_progress() > 0.0)
	assert(is_equal_approx(flow.line_progress(), flow.title_progress()))
	flow.advance(TaiChiOpeningFlow.REVEAL_SECONDS)
	assert(flow.line_progress() == 1.0)
	assert(flow.title_progress() == 1.0)
	pass


func duality_opens_a_center_gap_test() -> void:
	var flow := TaiChiDualityFlow.new()
	assert(flow.BOTTOM_TITLE == "一阴一阳之谓道")
	assert(not flow.active)
	flow.begin()
	flow.advance(TaiChiDualityFlow.TRANSITION_SECONDS * 0.5)
	assert(flow.active)
	assert(flow.progress() > 0.0 and flow.progress() < 1.0)
	assert(flow.title_opacity() < 1.0)
	flow.advance(TaiChiDualityFlow.TRANSITION_SECONDS)
	assert(flow.progress() == 1.0)
	assert(flow.title_opacity() == 0.0)
	pass


func formation_closes_into_taiji_test() -> void:
	var flow := TaiChiFormationFlow.new()
	assert(not flow.active)
	assert(is_equal_approx(TaiChiFormationFlow.DOT_RADIUS_RATIO, 0.105))
	flow.begin()
	flow.advance(TaiChiFormationFlow.TRANSITION_SECONDS * 0.2)
	assert(flow.outer_progress() > 0.0)
	assert(flow.upper_inner_progress() == 0.0)
	assert(flow.lower_inner_progress() == 0.0)
	flow.advance(TaiChiFormationFlow.TRANSITION_SECONDS * 0.23)
	assert(flow.upper_inner_progress() > 0.0)
	assert(flow.lower_inner_progress() == 0.0)
	assert(flow.divider_progress() == 0.0)
	assert(flow.fill_progress() == 0.0)
	flow.advance(TaiChiFormationFlow.TRANSITION_SECONDS * 0.2)
	assert(flow.lower_inner_progress() == 1.0)
	assert(flow.divider_progress() > 0.0)
	assert(flow.fill_progress() == 0.0)
	flow.advance(TaiChiFormationFlow.TRANSITION_SECONDS * 0.12)
	assert(flow.divider_progress() < 1.0)
	assert(flow.fill_progress() == 0.0)
	flow.advance(TaiChiFormationFlow.TRANSITION_SECONDS * 0.25)
	assert(flow.progress() == 1.0)
	assert(flow.outer_progress() == 1.0)
	assert(flow.upper_inner_progress() == 1.0)
	assert(flow.lower_inner_progress() == 1.0)
	assert(flow.divider_progress() == 1.0)
	assert(flow.fill_progress() == 1.0)
	assert(flow.previous_state_opacity() == 0.0)
	pass


func line_aura_shader_is_isolated_test() -> void:
	var control := VisualControl.new()
	var effect := control.create_effect(VisualType.Type.TAI_CHI)
	Engine.get_main_loop().root.add_child.call_deferred(effect)
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	assert(effect.line_aura_canvas != null)
	assert(effect.line_aura_material != null)
	assert(effect.line_aura_material.shader != null)
	assert(effect.line_aura_material.get_shader_parameter("aura_color") == ColorBase.primary_text)
	effect.size = Vector2(1280.0, 720.0)
	effect.visible = true
	effect._process(TaiChiOpeningFlow.REVEAL_SECONDS)
	effect._process(TaiChiDualityFlow.TRANSITION_SECONDS)
	effect._process(TaiChiFormationFlow.TRANSITION_SECONDS * 0.7)
	await Engine.get_main_loop().process_frame
	assert(effect.formation.active)
	assert(effect.line_aura_canvas.visible)
	assert(bool(effect.line_aura_material.get_shader_parameter("formation_active")))
	assert(float(effect.line_aura_material.get_shader_parameter("outer_progress")) == 1.0)
	assert(float(effect.line_aura_material.get_shader_parameter("divider_progress")) > 0.0)
	effect._process(TaiChiFormationFlow.TRANSITION_SECONDS * 0.2)
	await Engine.get_main_loop().process_frame
	assert(effect.fill_layer.visible)
	var fill_opacity := float(effect.fill_material.get_shader_parameter("opacity"))
	assert(fill_opacity > 0.0 and fill_opacity < 1.0)
	assert(effect.fill_layer.size.x > 0.0 and effect.fill_layer.size.x == effect.fill_layer.size.y)
	effect.get_parent().remove_child(effect)
	effect.free()
	control.free()
	pass
