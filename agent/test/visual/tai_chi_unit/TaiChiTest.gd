extends RefCounted

const TAI_CHI_CAROUSEL_FLOW_SCRIPT := preload("res://agent/ui/visuals/tai_chi/TaiChiCarouselFlow.gd")

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


func evolution_reveals_five_rows_bottom_up_test() -> void:
	var flow := TaiChiEvolutionFlow.new()
	assert(flow.TRIGRAM_VALUES == [7, 6, 5, 4, 3, 2, 1, 0])
	assert(not flow.active)
	flow.begin()
	var canvas_size := Vector2(1920.0, 1080.0)
	var target := Vector2(960.0, 540.0)
	assert(flow.flying_position(canvas_size, target, 0.0, 0, 8).y < 0.0)
	assert(flow.flying_position(canvas_size, target, 1.0, 0, 8).is_equal_approx(target))
	var source_center := flow.symbol_center(canvas_size)
	var source_radius := flow.symbol_radius(canvas_size)
	flow.advance(TaiChiEvolutionFlow.TRANSITION_SECONDS * 0.12)
	assert(flow.shrink_progress() > 0.0)
	assert(flow.symbol_radius(canvas_size) < source_radius)
	assert(flow.symbol_center(canvas_size).is_equal_approx(source_center))
	assert(flow.row_progress(0) == 0.0)
	flow.advance(TaiChiEvolutionFlow.TRANSITION_SECONDS * 0.26)
	assert(flow.shrink_progress() == 1.0)
	assert(flow.move_progress() > 0.0)
	assert(not flow.symbol_center(canvas_size).is_equal_approx(source_center))
	assert(flow.row_progress(0) > 0.0)
	assert(flow.row_progress(2) == 0.0)
	assert(flow.row_progress(4) == 0.0)
	flow.advance(TaiChiEvolutionFlow.TRANSITION_SECONDS * 0.62)
	assert(flow.progress() == 1.0)
	for row in TaiChiEvolutionFlow.ROW_COUNT:
		assert(flow.row_progress(row) == 1.0)
	assert(is_equal_approx(flow.symbol_center(canvas_size).x, flow.content_area(canvas_size).get_center().x))
	pass


func bagua_moves_left_to_right_and_builds_frame_test() -> void:
	var flow := TaiChiBaguaFlow.new()
	flow.begin()
	flow.advance(TaiChiBaguaFlow.TRANSITION_SECONDS * 0.22)
	assert(flow.trigram_progress(0) > flow.trigram_progress(7))
	assert(flow.hierarchy_opacity() < 1.0)
	assert(flow.frame_progress() == 0.0)
	flow.advance(TaiChiBaguaFlow.TRANSITION_SECONDS)
	assert(flow.progress() == 1.0)
	assert(flow.frame_progress() == 1.0)
	var evolution := TaiChiEvolutionFlow.new()
	evolution.begin()
	evolution.advance(TaiChiEvolutionFlow.TRANSITION_SECONDS)
	var canvas_size := Vector2(1920.0, 1080.0)
	assert(flow.taiji_center(canvas_size, evolution).is_equal_approx(canvas_size * 0.5))
	assert(flow.taiji_radius(canvas_size, evolution) > evolution.symbol_radius(canvas_size))
	pass


func carousel_rotates_and_cycles_all_trigrams_test() -> void:
	var flow = TAI_CHI_CAROUSEL_FLOW_SCRIPT.new()
	flow.begin()
	flow.advance(TAI_CHI_CAROUSEL_FLOW_SCRIPT.INTRO_SECONDS * 0.5)
	assert(flow.taiji_rotation() > 0.0)
	assert(flow.taiji_opacity() < 1.0)
	assert(flow.ring_rotation() > 0.0)
	flow.advance(TAI_CHI_CAROUSEL_FLOW_SCRIPT.INTRO_SECONDS * 0.5 + TAI_CHI_CAROUSEL_FLOW_SCRIPT.ITEM_SECONDS * 3.2)
	assert(flow.selected_index() == 6)
	assert(flow.item_opacity() > 0.0)
	flow.advance(TAI_CHI_CAROUSEL_FLOW_SCRIPT.ITEM_SECONDS * 5.0)
	assert(flow.selected_index() == 0)
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
	assert(effect.line_aura_material.get_shader_parameter("aura_color") == ThemeColor.alpha_theme_color(0.45))
	effect.size = Vector2(1280.0, 720.0)
	effect.visible = true
	effect._process(TaiChiOpeningFlow.REVEAL_SECONDS)
	effect._process(TaiChiDualityFlow.TRANSITION_SECONDS)
	effect._process(TaiChiFormationFlow.TRANSITION_SECONDS * 0.7)
	await Engine.get_main_loop().process_frame
	assert(effect.formation.active)
	assert(not effect.line_aura_canvas.visible)
	effect._process(TaiChiFormationFlow.TRANSITION_SECONDS * 0.2)
	await Engine.get_main_loop().process_frame
	assert(effect.fill_layer.visible)
	var fill_opacity := float(effect.fill_material.get_shader_parameter("opacity"))
	assert(fill_opacity > 0.0 and fill_opacity < 1.0)
	assert(effect.fill_layer.size.x > 0.0 and effect.fill_layer.size.x == effect.fill_layer.size.y)
	effect._process(TaiChiFormationFlow.TRANSITION_SECONDS)
	effect._process(TaiChiEvolutionFlow.TRANSITION_SECONDS)
	await Engine.get_main_loop().process_frame
	var fill_center := effect.fill_layer.position + effect.fill_layer.size * 0.5
	assert(is_equal_approx(fill_center.x, effect.evolution.content_area(effect.size).get_center().x))
	effect.get_parent().remove_child(effect)
	effect.free()
	control.free()
	pass
