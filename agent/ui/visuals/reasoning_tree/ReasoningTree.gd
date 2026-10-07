class_name ReasoningTree
extends VisualEffect

## Visualizes public run state. Reasoning text drives growth but is deliberately never rendered.

const MAX_TRUNK_SEGMENTS := 9
const MAX_BRANCHES := 12
const ANCHOR_MIN := 0.2
const ANCHOR_MAX := float(MAX_TRUNK_SEGMENTS) - 0.25
const CROWN_HEIGHT_RATIO := 0.13
const CROWN_WIDTH_RATIO := 0.12
const MAX_CROWN_RADIUS := 180.0
const CROWN_LEAF_COUNT := 7
const MIN_BRANCH_LENGTH := 180.0
const MIN_COMPLETION_LENGTH := 64.0
const COMPLETION_PARTICLE_COUNT := 96
const TRUNK_ALPHA_MIN := 0.16
const TRUNK_ALPHA_MAX := 0.34
const BRANCH_ALPHA_RUNNING := 0.28
const BRANCH_ALPHA_SUCCESS := 0.34
const BRANCH_ALPHA_FAILED := 0.20
const COMPLETION_BRANCH_ALPHA := 0.34
const TRUNK_GROWTH_EASE_POWER := 1.25
const BRANCH_CURVE_SEGMENTS := 18
const BRANCH_CURVE_RATIO := 0.10
const TREE_PULSE_SPEED := 230.0
const TREE_PULSE_INTERVAL := 2.0
const LEAF_PULSE_RADIUS := 52.0
const LEAF_PAIR_SPREAD := 0.72

enum BranchState { RUNNING, SUCCESS, FAILED }

var trunk_growth: float = 0.0
var target_trunk_growth: float = 0.0
var crown_growth: float = 0.0
var target_crown_growth: float = 0.0
var turn_index: int = 0
var branch_sequence: int = 0
var phase_label: String = ""
var branches: Array[Dictionary] = []
var active_tool_indices: Dictionary[String, int] = {}
var completion_particles: GPUParticles2D
var visual_time: float = 0.0
var pulse_travel_distances: Array[float] = []
var pulse_spawn_elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	build_completion_particles()
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.REASONING_TREE


func fade_in_seconds() -> float:
	return 0.35


func fade_out_seconds() -> float:
	return 0.45


func reset_visual() -> void:
	trunk_growth = 0.0
	target_trunk_growth = 0.0
	crown_growth = 0.0
	target_crown_growth = 0.0
	turn_index = 0
	branch_sequence = 0
	visual_time = 0.0
	pulse_travel_distances.clear()
	pulse_spawn_elapsed = 0.0
	phase_label = "准备任务"
	branches.clear()
	active_tool_indices.clear()
	queue_redraw()
	pass


func on_agent_start(_session_id: int) -> void:
	phase_label = "理解任务"
	# Stay below the first turn tip so the trunk only grows forward once turns begin.
	target_trunk_growth = trunk_growth_for_turn(1) * 0.5
	queue_redraw()
	pass


func on_agent_end(error_message: String) -> float:
	if StringUtils.is_blank(error_message):
		phase_label = "任务已完成"
		target_crown_growth = 1.0
		play_completion_burst()
	else:
		phase_label = "任务已停止" if error_message.begins_with("Stop") else "任务失败"
	queue_redraw()
	return 0.9


func on_turn_start() -> void:
	turn_index += 1
	phase_label = "第 %d 轮 · 分析任务" % turn_index
	# Map turns across the full trunk using AgentLoop.MAX_TURNS so late tools do not pile at the tip.
	target_trunk_growth = trunk_growth_for_turn(turn_index)
	queue_redraw()
	pass


func on_turn_end() -> void:
	phase_label = "第 %d 轮 · 阶段完成" % turn_index
	queue_redraw()
	pass


func on_message_update(chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		phase_label = "第 %d 轮 · 正在分析" % maxi(turn_index, 1)
	else:
		phase_label = "整理最终答案"
		target_crown_growth = minf(0.82, target_crown_growth + 0.035)
	queue_redraw()
	pass


func on_message_complete(_usage: OpenAiUsage) -> void:
	queue_redraw()
	pass


func on_tool_execution_start(tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	branches.append(make_branch(tool_call_id, tool_name, branch_sequence, target_trunk_growth))
	branch_sequence += 1
	active_tool_indices[tool_call_id] = branches.size() - 1
	phase_label = "调用工具 · %s" % VisualToolFormatter.title_name(tool_name, "工具")
	queue_redraw()
	pass


func on_tool_execution_end(tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	if not active_tool_indices.has(tool_call_id):
		return
	var index: int = active_tool_indices[tool_call_id]
	branches[index]["state"] = BranchState.FAILED if result.is_error else BranchState.SUCCESS
	branches[index]["label"] = "%s · %s" % [VisualToolFormatter.title_name(tool_name, "工具"), "失败" if result.is_error else "已完成"]
	active_tool_indices.erase(tool_call_id)
	if not result.is_error:
		target_trunk_growth = maxf(target_trunk_growth, trunk_growth_for_turn(turn_index))
	phase_label = "工具失败 · 调整方案" if result.is_error else "工具完成 · 继续任务"
	queue_redraw()
	pass


func on_theme_changed() -> void:
	update_particle_colors()
	queue_redraw()
	pass


func build_completion_particles() -> void:
	completion_particles = GPUParticles2D.new()
	completion_particles.name = "CompletionBurst"
	completion_particles.amount = COMPLETION_PARTICLE_COUNT
	completion_particles.lifetime = 1.45
	completion_particles.one_shot = true
	completion_particles.explosiveness = 0.96
	completion_particles.randomness = 0.42
	completion_particles.emitting = false
	completion_particles.texture = make_particle_texture()
	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 7.0
	particle_material.direction = Vector3(0.0, -1.0, 0.0)
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = 95.0
	particle_material.initial_velocity_max = 260.0
	particle_material.gravity = Vector3(0.0, 85.0, 0.0)
	particle_material.scale_min = 0.45
	particle_material.scale_max = 1.35
	particle_material.damping_min = 12.0
	particle_material.damping_max = 34.0
	completion_particles.process_material = particle_material
	add_child(completion_particles)
	update_particle_colors()
	pass


func update_particle_colors() -> void:
	if completion_particles == null:
		return
	var particle_material := completion_particles.process_material as ParticleProcessMaterial
	if particle_material == null:
		return
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.32, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		Color(ColorBase.primary_text, 0.95),
		Color(ThemeColor.accent_theme_color(), 0.92),
		Color(ColorBase.success, 0.72),
		Color(ColorBase.success, 0.0),
	])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	particle_material.color_ramp = color_ramp
	pass


func play_completion_burst() -> void:
	if completion_particles == null or not is_inside_tree():
		return
	var base := Vector2(size.x * 0.5, size.y - Margin.ma_8)
	var crown_center_y := Margin.ma_8 + get_crown_radius()
	var segment_height := maxf(12.0, (base.y - crown_center_y) / float(MAX_TRUNK_SEGMENTS))
	completion_particles.position = trunk_point(base, segment_height, maxf(trunk_growth, 0.35))
	completion_particles.restart()
	completion_particles.emitting = true
	pass


static func make_particle_texture() -> ImageTexture:
	const TEXTURE_SIZE := 16
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(TEXTURE_SIZE - 1, TEXTURE_SIZE - 1) * 0.5
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var distance := Vector2(x, y).distance_to(center) / (float(TEXTURE_SIZE) * 0.5)
			var alpha := pow(clampf(1.0 - distance, 0.0, 1.0), 1.8)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _process(delta: float) -> void:
	var changed := not is_equal_approx(trunk_growth, target_trunk_growth) or not is_equal_approx(crown_growth, target_crown_growth)
	if visible and trunk_growth > 0.0:
		visual_time += delta
		update_tree_pulses(delta)
		changed = true
	trunk_growth = move_toward(trunk_growth, target_trunk_growth, delta * 2.3)
	crown_growth = move_toward(crown_growth, target_crown_growth, delta * 1.4)
	for branch: Dictionary in branches:
		if not can_branch_grow(trunk_growth, branch):
			continue
		var old_growth: float = branch["growth"]
		branch["growth"] = move_toward(old_growth, 1.0, delta * 2.8)
		changed = changed or old_growth != branch["growth"]
		if int(branch["state"]) != BranchState.RUNNING and is_equal_approx(float(branch["growth"]), 1.0):
			var old_completion_growth: float = branch["completion_growth"]
			branch["completion_growth"] = move_toward(old_completion_growth, 1.0, delta * 3.2)
			changed = changed or old_completion_growth != branch["completion_growth"]
	if changed:
		queue_redraw()
	pass


func _draw() -> void:
	if size.x < 120.0 or size.y < 120.0:
		return
	var base := Vector2(size.x * 0.5, size.y - Margin.ma_8)
	var crown_radius := get_crown_radius()
	var crown_center_y := Margin.ma_8 + crown_radius
	var segment_height := maxf(12.0, (base.y - crown_center_y) / float(MAX_TRUNK_SEGMENTS))
	var accent := ThemeColor.accent_theme_color()
	draw_trunk(base, segment_height, accent)
	for branch: Dictionary in branches:
		draw_branch(branch, base, segment_height)
	draw_tree_pulses(base, segment_height, accent)
	draw_crown(base, segment_height, accent)
	draw_status(base)
	pass


func draw_trunk(base: Vector2, segment_height: float, accent: Color) -> void:
	for index in range(mini(int(ceil(trunk_growth)), MAX_TRUNK_SEGMENTS)):
		var amount := clampf(trunk_growth - index, 0.0, 1.0)
		var from := trunk_point(base, segment_height, float(index))
		var to := from.lerp(trunk_point(base, segment_height, float(index + 1)), amount)
		draw_line(from, to, Color(accent, lerpf(TRUNK_ALPHA_MIN, TRUNK_ALPHA_MAX, amount)), 3.0 + amount * 2.0, true)
	pass


func draw_branch(branch: Dictionary, base: Vector2, segment_height: float) -> void:
	var anchor_segment := float(branch["anchor"]) + float(branch["anchor_offset"])
	var anchor := trunk_point(base, segment_height, anchor_segment)
	var direction: float = branch["direction"]
	var growth: float = branch["growth"]
	var branch_length := minf(size.x * 0.20, maxf(MIN_BRANCH_LENGTH, segment_height * 2.5))
	var branch_vector := Vector2.from_angle(float(branch["angle"])) * branch_length
	var parent_control := branch_curve_control(anchor, anchor + branch_vector, branch_length)
	var parent_curve := quadratic_curve_points(anchor, parent_control, anchor + branch_vector, growth)
	var elbow := parent_curve[-1]
	var state: int = branch["state"]
	var accent := ThemeColor.accent_theme_color()
	var color := accent if state == BranchState.RUNNING else (ColorBase.success if state == BranchState.SUCCESS else ColorBase.error)
	# The tool's parent branch keeps one identity color throughout execution. Completion state is
	# communicated by the child twig and its tip instead of repainting the whole branch.
	var parent_color := ColorBase.secondary_text if state == BranchState.FAILED else accent
	var parent_alpha := BRANCH_ALPHA_FAILED if state == BranchState.FAILED else (BRANCH_ALPHA_SUCCESS if state == BranchState.SUCCESS else BRANCH_ALPHA_RUNNING)
	var pulse := running_pulse(visual_time, float(branch["animation_phase"])) if state == BranchState.RUNNING else 1.0
	var parent_width := (2.5 if state == BranchState.FAILED else 3.0) + (pulse - 1.0)
	# Polyline ends use flat caps. A line-sized fill at the real junction seals the anti-aliased
	# seam without bringing back the visible decorative trunk nodes.
	draw_circle(anchor, parent_width * 0.62, Color(parent_color, parent_alpha * pulse))
	if state == BranchState.RUNNING:
		draw_polyline(parent_curve, Color(parent_color, parent_alpha * 0.22 * pulse), 8.0 + pulse * 2.0, true)
	draw_polyline(parent_curve, Color(parent_color, parent_alpha * pulse), parent_width, true)
	if state == BranchState.RUNNING:
		if growth > 0.72:
			draw_branch_tip(elbow, direction, state, color, pulse)
			draw_branch_label(elbow, direction, String(branch["label"]), Color(color, clampf(0.72 + pulse * 0.22, 0.0, 1.0)))
		return
	var completion_growth: float = branch["completion_growth"]
	var completion_length := maxf(MIN_COMPLETION_LENGTH, branch_length * 0.38)
	var completion_vector := get_completion_vector(branch, state, completion_length)
	var tip := elbow + completion_vector * completion_growth
	if state == BranchState.FAILED:
		draw_failed_twig(elbow, tip, completion_growth, color)
	else:
		var completion_control := branch_curve_control(elbow, elbow + completion_vector, completion_length * 0.45)
		var completion_curve := quadratic_curve_points(elbow, completion_control, elbow + completion_vector, completion_growth)
		draw_polyline(completion_curve, Color(color, COMPLETION_BRANCH_ALPHA), 3.0, true)
	if completion_growth > 0.72:
		if state == BranchState.SUCCESS:
			var leaf_glow := get_leaf_pulse_intensity(branch, segment_height, branch_length, completion_length)
			draw_success_leaves(tip, direction, branch, completion_growth, leaf_glow)
		else:
			draw_branch_tip(tip, direction, state, color)
		draw_branch_label(tip, direction, String(branch["label"]), color)
	pass


func draw_failed_twig(elbow: Vector2, tip: Vector2, completion_growth: float, color: Color) -> void:
	if completion_growth <= 0.0:
		return
	var axis := tip - elbow
	var perpendicular := axis.normalized().orthogonal() * 5.0
	var first_break := elbow.lerp(tip, 0.58)
	var second_break := elbow.lerp(tip, 0.70)
	var fracture := PackedVector2Array([elbow, first_break, first_break + perpendicular, second_break - perpendicular, second_break, tip])
	draw_polyline(fracture, Color(color, BRANCH_ALPHA_FAILED), 2.5, true)
	pass


func draw_branch_tip(tip: Vector2, direction: float, state: int, color: Color, pulse: float = 1.0) -> void:
	if state == BranchState.RUNNING:
		draw_circle(tip, 11.0 * pulse, Color(color, 0.06 * pulse))
		draw_arc(tip, 8.0 * pulse, 0.0, TAU * 0.78, 18, Color(color, 0.72 + pulse * 0.20), 2.0, true)
	else:
		draw_line(tip - Vector2(5.0, 5.0), tip + Vector2(5.0, 5.0), color, 2.0, true)
		draw_line(tip + Vector2(-5.0, 5.0), tip + Vector2(5.0, -5.0), color, 2.0, true)
	pass


func draw_success_leaves(tip: Vector2, direction: float, branch: Dictionary, completion_growth: float, pulse_glow: float) -> void:
	var growth := leaf_visual_growth(completion_growth)
	if growth <= 0.0:
		return
	var variant: int = branch["leaf_variant"]
	var phase: float = branch["animation_phase"]
	var sway := sin(visual_time * 1.35 + phase * TAU) * 0.075
	var accent := ThemeColor.accent_theme_color()
	var leaf_color := ColorBase.success.lerp(accent, 0.08 + float(variant) * 0.055)
	if pulse_glow > 0.0:
		draw_circle(tip, 18.0 + pulse_glow * 9.0, Color(leaf_color, pulse_glow * 0.12))
		draw_circle(tip, 9.0 + pulse_glow * 4.0, Color(leaf_color, pulse_glow * 0.20))
	var leaf_length := (17.0 + float(variant) * 2.5) * growth
	var leaf_width := (7.0 + float((variant + 1) % 3)) * growth
	var leaf_count: int = branch["leaf_count"]
	if leaf_count == 1:
		var leaf_angle := -PI * 0.5 + direction * 0.58 + sway
		draw_leaf(tip, leaf_angle, leaf_length, leaf_width, leaf_color, 0.72 + pulse_glow * 0.25)
	else:
		# Lift leaf clusters onto a short stem and fan them apart. Larger clusters use narrower
		# leaves so three- and four-leaf variants stay readable instead of merging into one shape.
		var stem_tip := tip + Vector2(0.0, -5.0 * growth)
		draw_line(tip, stem_tip, Color(leaf_color, 0.72), 1.6, true)
		var cluster_width := leaf_width * lerpf(0.72, 0.58, float(leaf_count - 2))
		for leaf_index in range(leaf_count):
			var fan_angle := leaf_fan_angle(leaf_index, leaf_count)
			var leaf_sway := sway * (1.0 if leaf_index % 2 == 0 else -0.8)
			var length_scale := 0.84 + float((leaf_index + variant) % 3) * 0.055
			var variant_color := leaf_color.lerp(accent, float(leaf_index) * 0.035)
			draw_leaf(stem_tip, -PI * 0.5 + fan_angle + leaf_sway, leaf_length * length_scale, cluster_width,
				variant_color, 0.69 + pulse_glow * 0.26)
	pass


func draw_leaf(origin: Vector2, angle: float, length: float, width: float, color: Color, alpha: float) -> void:
	# A leaf starts at zero scale. Skip the degenerate opening frames because Godot cannot
	# triangulate a polygon whose vertices all collapse onto the same point.
	if length < 0.5 or width < 0.25:
		return
	var polygon := make_leaf_polygon(origin, angle, length, width)
	draw_colored_polygon(polygon, Color(color, clampf(alpha, 0.0, 1.0)))
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline, Color(color.lightened(0.22), clampf(alpha + 0.08, 0.0, 1.0)), 1.2, true)
	var vein_end := origin + Vector2.from_angle(angle) * length * 0.82
	draw_line(origin, vein_end, Color(color.lightened(0.30), clampf(alpha * 0.62, 0.0, 1.0)), 1.0, true)
	pass


func get_leaf_pulse_intensity(branch: Dictionary, segment_height: float, branch_length: float, completion_length: float) -> float:
	var leaf_distance := branch_anchor_segment(branch) * segment_height + branch_length + completion_length
	var closest_distance := INF
	for pulse_distance in pulse_travel_distances:
		closest_distance = minf(closest_distance, absf(pulse_distance - leaf_distance))
	return clampf(1.0 - closest_distance / LEAF_PULSE_RADIUS, 0.0, 1.0)


## Emit one wavefront from the root. Once it passes an anchor, the same wave spreads through
## that branch while the original continues climbing the trunk.
func draw_tree_pulses(base: Vector2, segment_height: float, color: Color) -> void:
	if trunk_growth <= 0.0:
		return
	var branch_length := minf(size.x * 0.20, maxf(MIN_BRANCH_LENGTH, segment_height * 2.5))
	var completion_length := maxf(MIN_COMPLETION_LENGTH, branch_length * 0.38)
	var trunk_length := trunk_growth * segment_height
	for pulse_distance in pulse_travel_distances:
		draw_tree_pulse_at_distance(base, segment_height, color, pulse_distance, trunk_length, branch_length, completion_length)
	pass


func draw_tree_pulse_at_distance(base: Vector2, segment_height: float, color: Color, pulse_distance: float,
		trunk_length: float, branch_length: float, completion_length: float) -> void:
	if pulse_distance <= trunk_length:
		var trunk_segment := pulse_distance / segment_height
		draw_pulse_light(trunk_point(base, segment_height, trunk_segment), color)
	for branch: Dictionary in branches:
		var anchor_segment := branch_anchor_segment(branch)
		var distance_after_anchor := pulse_distance - anchor_segment * segment_height
		if distance_after_anchor < 0.0:
			continue
		var anchor := trunk_point(base, segment_height, anchor_segment)
		var growth: float = branch["growth"]
		var branch_vector := Vector2.from_angle(float(branch["angle"])) * branch_length
		var parent_control := branch_curve_control(anchor, anchor + branch_vector, branch_length)
		if distance_after_anchor <= branch_length * growth:
			var parent_progress := distance_after_anchor / branch_length
			draw_pulse_light(quadratic_curve_point(anchor, parent_control, anchor + branch_vector, parent_progress), color)
			continue
		var completion_growth: float = branch["completion_growth"]
		if completion_growth <= 0.0:
			continue
		var completion_distance := distance_after_anchor - branch_length
		if completion_distance < 0.0 or completion_distance > completion_length * completion_growth:
			continue
		var elbow := anchor + branch_vector
		var state: int = branch["state"]
		var completion_vector := get_completion_vector(branch, state, completion_length)
		var completion_control := branch_curve_control(elbow, elbow + completion_vector, completion_length * 0.45)
		var completion_progress := completion_distance / completion_length
		var pulse_color := ColorBase.error if state == BranchState.FAILED else ColorBase.success
		draw_pulse_light(quadratic_curve_point(elbow, completion_control, elbow + completion_vector, completion_progress), pulse_color)
	pass


func get_tree_pulse_path_length() -> float:
	var base_y := size.y - Margin.ma_8
	var crown_center_y := Margin.ma_8 + get_crown_radius()
	var segment_height := maxf(12.0, (base_y - crown_center_y) / float(MAX_TRUNK_SEGMENTS))
	var branch_length := minf(size.x * 0.20, maxf(MIN_BRANCH_LENGTH, segment_height * 2.5))
	var completion_length := maxf(MIN_COMPLETION_LENGTH, branch_length * 0.38)
	return trunk_growth * segment_height + branch_length + completion_length


func update_tree_pulses(delta: float) -> void:
	if pulse_travel_distances.is_empty():
		pulse_travel_distances.append(0.0)
	var travel_step := maxf(delta, 0.0) * TREE_PULSE_SPEED
	for index in range(pulse_travel_distances.size()):
		pulse_travel_distances[index] += travel_step
	var path_length := get_tree_pulse_path_length()
	for index in range(pulse_travel_distances.size() - 1, -1, -1):
		if pulse_travel_distances[index] > path_length:
			pulse_travel_distances.remove_at(index)
	pulse_spawn_elapsed += maxf(delta, 0.0)
	while pulse_spawn_elapsed >= TREE_PULSE_INTERVAL:
		pulse_spawn_elapsed -= TREE_PULSE_INTERVAL
		pulse_travel_distances.append(0.0)
	pass


func draw_pulse_light(point: Vector2, color: Color) -> void:
	draw_circle(point, 15.0, Color(color, 0.045))
	draw_circle(point, 8.0, Color(color, 0.12))
	draw_circle(point, 4.0, Color(color, 0.34))
	draw_circle(point, 2.0, Color(color, 0.96))
	pass


func draw_branch_label(tip: Vector2, direction: float, label: String, color: Color) -> void:
	var font := Fonts.medium()
	var font_size := Typography.label_medium_size
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var position := tip + Vector2(12.0 if direction > 0.0 else -text_width - 12.0, 5.0)
	draw_string(font, position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	pass


func draw_crown(base: Vector2, segment_height: float, accent: Color) -> void:
	if crown_growth <= 0.0:
		return
	# Short tasks keep a compact tree: the final crown belongs to the actual tip, not an artificial
	# fully-grown endpoint at the top of the viewport.
	var center := trunk_point(base, segment_height, maxf(trunk_growth, 0.35))
	var visual_growth := crown_visual_growth(crown_growth)
	var radius := get_crown_radius() * visual_growth
	if radius < 1.5:
		return
	var pulse_glow := get_crown_pulse_intensity(segment_height)
	var crown_color := ColorBase.success.lerp(accent, 0.18)
	if pulse_glow > 0.0:
		draw_circle(center, radius * 0.48 + pulse_glow * 14.0, Color(crown_color, pulse_glow * 0.07))
	# A compact seven-leaf terminal bud replaces the old bubble cloud. Outer leaves establish the
	# silhouette while alternating lengths keep the crown organic and readable at small sizes.
	for index in range(CROWN_LEAF_COUNT):
		var normalized := float(index) / float(CROWN_LEAF_COUNT - 1)
		var angle := lerpf(-PI * 0.88, -PI * 0.12, normalized)
		var sway := sin(visual_time * 0.72 + float(index) * 1.17) * 0.035
		var length_scale := 0.78 + float(index % 3) * 0.10
		var leaf_length := radius * 0.46 * length_scale
		var leaf_width := radius * (0.105 + float((index + 1) % 2) * 0.018)
		var stem_end := center + Vector2.from_angle(angle + sway) * radius * 0.13
		draw_line(center, stem_end, Color(crown_color, 0.38 + visual_growth * 0.28), 1.5, true)
		var leaf_color := crown_color.lerp(accent, float(index % 3) * 0.055)
		draw_leaf(stem_end, angle + sway, leaf_length, leaf_width, leaf_color,
			0.48 + visual_growth * 0.32 + pulse_glow * 0.18)
	var core_radius := (3.0 + visual_growth * 4.0) * (1.0 + pulse_glow * 0.22)
	draw_circle(center, core_radius * 2.2, Color(accent, 0.07 + pulse_glow * 0.08))
	draw_circle(center, core_radius, Color(accent, 0.72 + pulse_glow * 0.24))
	pass


func get_crown_pulse_intensity(segment_height: float) -> float:
	var crown_distance := trunk_growth * segment_height
	var closest_distance := INF
	for pulse_distance in pulse_travel_distances:
		closest_distance = minf(closest_distance, absf(pulse_distance - crown_distance))
	return clampf(1.0 - closest_distance / LEAF_PULSE_RADIUS, 0.0, 1.0)


func draw_status(base: Vector2) -> void:
	var font := Fonts.semibold()
	var font_size := Typography.title_small_size
	var text_width := font.get_string_size(phase_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(base.x - text_width * 0.5, size.y - Margin.ma_3), phase_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ColorBase.primary_text)
	pass


func trunk_point(base: Vector2, segment_height: float, segment: float) -> Vector2:
	# The trunk is rendered as straight lines between integer segment points. Interpolate those
	# same endpoints so fractional branch anchors sit exactly on the visible trunk.
	var lower_segment := floorf(segment)
	var segment_fraction := segment - lower_segment
	var lower_sway := sin(lower_segment * 1.35)
	var upper_sway := sin((lower_segment + 1.0) * 1.35)
	var sway := lerpf(lower_sway, upper_sway, segment_fraction) * minf(28.0, size.x * 0.022)
	return base + Vector2(sway, -segment * segment_height)


func get_crown_radius() -> float:
	return minf(minf(size.x * CROWN_WIDTH_RATIO, size.y * CROWN_HEIGHT_RATIO), MAX_CROWN_RADIUS)


## Keep the first blooms compact, then let them open progressively toward full size.
static func crown_visual_growth(growth: float) -> float:
	var normalized_growth := clampf(growth, 0.0, 1.0)
	return normalized_growth * normalized_growth


static func make_branch(tool_call_id: String, tool_name: String, branch_index: int, growth: float) -> Dictionary:
	var direction := -1.0 if branch_index % 2 == 0 else 1.0
	return {
		"id": tool_call_id,
		"label": VisualToolFormatter.title_name(tool_name, "工具"),
		"state": BranchState.RUNNING,
		"anchor": clampf(growth, ANCHOR_MIN, ANCHOR_MAX),
		"anchor_offset": branch_anchor_offset(branch_index),
		"direction": direction,
		"angle": branch_angle(branch_index),
		"completion_angle": completion_angle(branch_index),
		"animation_phase": fmod(float(branch_index) * 0.37, 1.0),
		"leaf_variant": absi(tool_name.hash()) % 3,
		"leaf_count": 1 + absi((tool_call_id + ":" + str(branch_index)).hash()) % 3,
		"growth": 0.0,
		"completion_growth": 0.0,
	}


static func branch_curve_control(from: Vector2, to: Vector2, curve_length: float) -> Vector2:
	return from.lerp(to, 0.5) + Vector2(0.0, -curve_length * BRANCH_CURVE_RATIO)


static func quadratic_curve_points(from: Vector2, control: Vector2, to: Vector2, progress: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var visible_progress := clampf(progress, 0.0, 1.0)
	for index in range(BRANCH_CURVE_SEGMENTS + 1):
		var t := visible_progress * float(index) / float(BRANCH_CURVE_SEGMENTS)
		var inverse := 1.0 - t
		points.append(inverse * inverse * from + 2.0 * inverse * t * control + t * t * to)
	return points


static func quadratic_curve_point(from: Vector2, control: Vector2, to: Vector2, progress: float) -> Vector2:
	var t := clampf(progress, 0.0, 1.0)
	var inverse := 1.0 - t
	return inverse * inverse * from + 2.0 * inverse * t * control + t * t * to


static func leaf_visual_growth(completion_growth: float) -> float:
	var growth := clampf((completion_growth - 0.58) / 0.42, 0.0, 1.0)
	return 1.0 - pow(1.0 - growth, 3.0)


static func make_leaf_polygon(origin: Vector2, angle: float, length: float, width: float) -> PackedVector2Array:
	var forward := Vector2.from_angle(angle)
	var normal := forward.orthogonal()
	var points := PackedVector2Array()
	const STEPS := 6
	for index in range(STEPS + 1):
		var t := float(index) / float(STEPS)
		points.append(origin + forward * length * t + normal * sin(t * PI) * width)
	for index in range(STEPS, -1, -1):
		var t := float(index) / float(STEPS)
		points.append(origin + forward * length * t - normal * sin(t * PI) * width)
	return points


static func leaf_fan_angle(leaf_index: int, leaf_count: int) -> float:
	if leaf_count <= 1:
		return 0.0
	var half_span := LEAF_PAIR_SPREAD + float(leaf_count - 2) * 0.17
	return lerpf(-half_span, half_span, float(leaf_index) / float(leaf_count - 1))


static func running_pulse(time: float, phase: float) -> float:
	return 0.92 + sin((time + phase) * TAU * 0.75) * 0.08


## Grow more of the trunk in early turns, then ease gently toward the crown.
static func trunk_growth_for_turn(turn: int) -> float:
	var turn_progress := clampf(float(turn) / float(AgentLoop.MAX_TURNS), 0.0, 1.0)
	var eased_progress := 1.0 - pow(1.0 - turn_progress, TRUNK_GROWTH_EASE_POWER)
	return eased_progress * float(MAX_TRUNK_SEGMENTS)


## Alternate sides while raising every later branch tip above the previous one.
static func branch_angle(branch_index: int) -> float:
	var elevation_degrees := branch_elevation_degrees(branch_index)
	return deg_to_rad(180.0 + elevation_degrees) if branch_index % 2 == 0 else deg_to_rad(-elevation_degrees)


## Tool completion grows as a connected child branch with its own visible bend.
static func completion_angle(branch_index: int) -> float:
	var parent_angle := branch_angle(branch_index)
	# Bend farther upward, not back toward the horizontal. This keeps completed branch tips in
	# the same bottom-to-top order as their parent tips.
	var direction := 1.0 if branch_index % 2 == 0 else -1.0
	var bend_degrees := 8.0
	return parent_angle + deg_to_rad(direction * bend_degrees)


## Start nearly horizontal and rise slowly so large tool runs fan out instead of clustering upright.
static func branch_elevation_degrees(branch_index: int) -> float:
	return 10.0 + 52.0 * (1.0 - pow(0.94, branch_index))


## Later tools always attach higher than earlier tools while staying below the turn endpoint.
static func branch_anchor_offset(branch_index: int) -> float:
	# The negative offset shrinks monotonically instead of cycling, so a later branch can never
	# drop below an earlier branch when both are created at the same trunk height.
	return -0.24 * pow(0.82, branch_index)


static func branch_anchor_segment(branch: Dictionary) -> float:
	return float(branch["anchor"]) + float(branch["anchor_offset"])


static func can_branch_grow(current_trunk_growth: float, branch: Dictionary) -> bool:
	return current_trunk_growth + 0.001 >= branch_anchor_segment(branch)


## Failed completion growth bends down under its own weight while preserving its full length.
static func get_completion_vector(branch: Dictionary, state: int, length: float) -> Vector2:
	var vector := Vector2.from_angle(float(branch["completion_angle"])) * length
	if state != BranchState.FAILED:
		return vector
	vector.y = maxf(absf(vector.y) * 0.35, length * 0.18)
	return vector.normalized() * length
