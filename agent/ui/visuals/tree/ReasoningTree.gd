class_name ReasoningTree
extends VisualEffect

## Visualizes public run state. Reasoning text drives growth but is deliberately never rendered.

const MAX_TRUNK_SEGMENTS := 9
const MAX_BRANCHES := 12
const CROWN_HEIGHT_RATIO := 0.13
const CROWN_WIDTH_RATIO := 0.12
const MAX_CROWN_RADIUS := 180.0
const CROWN_BUBBLE_COUNT := 26
const GOLDEN_ANGLE := 2.399963
const MIN_BRANCH_LENGTH := 180.0
const MIN_COMPLETION_LENGTH := 64.0
const COMPLETION_PARTICLE_COUNT := 96

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
var fade_tween: Tween
var completion_particles: GPUParticles2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	build_completion_particles()
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.REASONING_TREE


func set_visual_visible(show: bool, animated: bool) -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	if show:
		visible = true
		if not animated:
			modulate.a = 1.0
			return
		modulate.a = 0.0
		fade_tween = create_tween()
		fade_tween.tween_property(self, "modulate:a", 1.0, 0.35)
		return
	if not animated:
		visible = false
		modulate.a = 1.0
		return
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.45)
	fade_tween.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
	)
	pass


func reset_visual() -> void:
	trunk_growth = 0.0
	target_trunk_growth = 0.0
	crown_growth = 0.0
	target_crown_growth = 0.0
	turn_index = 0
	branch_sequence = 0
	phase_label = "准备任务"
	branches.clear()
	active_tool_indices.clear()
	queue_redraw()
	pass


func on_agent_start(_session_id: int) -> void:
	phase_label = "理解任务"
	target_trunk_growth = 0.35
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
	# Streaming reasoning can contain hundreds of arbitrary chunks. Height follows semantic turns
	# instead, so one turn can grow at most one stable trunk segment.
	target_trunk_growth = minf(float(MAX_TRUNK_SEGMENTS), float(turn_index))
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
	if branches.size() >= MAX_BRANCHES:
		branches.pop_front()
		remap_active_tool_indices()
	branches.append(make_branch(tool_call_id, tool_name, branch_sequence, target_trunk_growth))
	branch_sequence += 1
	active_tool_indices[tool_call_id] = branches.size() - 1
	phase_label = "调用工具 · %s" % public_tool_name(tool_name)
	queue_redraw()
	pass


func on_tool_execution_end(tool_call_id: String, tool_name: String, result: AgentToolResult) -> void:
	if not active_tool_indices.has(tool_call_id):
		return
	var index: int = active_tool_indices[tool_call_id]
	branches[index]["state"] = BranchState.FAILED if result.is_error else BranchState.SUCCESS
	branches[index]["label"] = "%s · %s" % [public_tool_name(tool_name), "失败" if result.is_error else "已完成"]
	active_tool_indices.erase(tool_call_id)
	if not result.is_error:
		# A successful tool completes the current stage visually; the next turn owns the next segment.
		target_trunk_growth = minf(float(MAX_TRUNK_SEGMENTS), maxf(target_trunk_growth, float(turn_index)))
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
	draw_crown(base, segment_height, accent)
	draw_status(base)
	pass


func draw_trunk(base: Vector2, segment_height: float, accent: Color) -> void:
	for index in range(mini(int(ceil(trunk_growth)), MAX_TRUNK_SEGMENTS)):
		var amount := clampf(trunk_growth - index, 0.0, 1.0)
		var from := trunk_point(base, segment_height, float(index))
		var to := from.lerp(trunk_point(base, segment_height, float(index + 1)), amount)
		draw_line(from, to, Color(accent, 0.38 + amount * 0.42), 3.0 + amount * 2.0, true)
		draw_circle(to, 3.0 + amount * 2.0, Color(accent, 0.75))
	pass


func draw_branch(branch: Dictionary, base: Vector2, segment_height: float) -> void:
	var anchor_segment := float(branch["anchor"]) + float(branch["anchor_offset"])
	var anchor := trunk_point(base, segment_height, anchor_segment)
	var direction: float = branch["direction"]
	var growth: float = branch["growth"]
	var branch_length := minf(size.x * 0.20, maxf(MIN_BRANCH_LENGTH, segment_height * 2.5))
	var branch_vector := Vector2.from_angle(float(branch["angle"])) * branch_length
	var elbow := anchor + branch_vector * growth
	var state: int = branch["state"]
	var accent := ThemeColor.accent_theme_color()
	var color := accent if state == BranchState.RUNNING else (ColorBase.success if state == BranchState.SUCCESS else ColorBase.error)
	# The tool's parent branch keeps one identity color throughout execution. Completion state is
	# communicated by the child twig and its tip instead of repainting the whole branch.
	var parent_color := ColorBase.secondary_text if state == BranchState.FAILED else accent
	var parent_alpha := 0.46 if state == BranchState.FAILED else (0.82 if state == BranchState.SUCCESS else 0.72)
	draw_line(anchor, elbow, Color(parent_color, parent_alpha), 2.5 if state == BranchState.FAILED else 3.0, true)
	if state == BranchState.RUNNING:
		if growth > 0.72:
			draw_branch_tip(elbow, direction, state, color)
			draw_branch_label(elbow, direction, String(branch["label"]), color)
		return
	var completion_growth: float = branch["completion_growth"]
	var completion_length := maxf(MIN_COMPLETION_LENGTH, branch_length * 0.38)
	var completion_vector := get_completion_vector(branch, state, completion_length)
	var tip := elbow + completion_vector * completion_growth
	if state == BranchState.FAILED:
		draw_failed_twig(elbow, tip, completion_growth, color)
	else:
		draw_line(elbow, tip, Color(color, 0.82), 3.0, true)
	if completion_growth > 0.72:
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
	draw_polyline(fracture, Color(color, 0.68), 2.5, true)
	pass


func draw_branch_tip(tip: Vector2, direction: float, state: int, color: Color) -> void:
	if state == BranchState.SUCCESS:
		draw_circle(tip, 7.0, Color(color, 0.82))
	elif state == BranchState.RUNNING:
		draw_arc(tip, 8.0, 0.0, TAU * 0.78, 18, color, 2.0, true)
	else:
		draw_line(tip - Vector2(5.0, 5.0), tip + Vector2(5.0, 5.0), color, 2.0, true)
		draw_line(tip + Vector2(-5.0, 5.0), tip + Vector2(5.0, -5.0), color, 2.0, true)
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
	var radius := get_crown_radius() * crown_growth
	for index in range(CROWN_BUBBLE_COUNT):
		var distribution := sqrt((float(index) + 0.5) / float(CROWN_BUBBLE_COUNT))
		var angle := float(index) * GOLDEN_ANGLE
		var offset := Vector2(cos(angle) * radius * 0.76, sin(angle) * radius * 0.58) * distribution
		var bubble_radius := radius * (0.13 + float(index % 4) * 0.012)
		var bubble_color := accent.lerp(ColorBase.success, 0.22 + float(index % 3) * 0.09)
		draw_circle(center + offset, bubble_radius, Color(bubble_color, 0.16 + crown_growth * 0.30))
	pass


func draw_status(base: Vector2) -> void:
	var font := Fonts.semibold()
	var font_size := Typography.title_small_size
	var text_width := font.get_string_size(phase_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(base.x - text_width * 0.5, size.y - Margin.ma_3), phase_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ColorBase.primary_text)
	pass


func trunk_point(base: Vector2, segment_height: float, segment: float) -> Vector2:
	return base + Vector2(sin(segment * 1.35) * minf(28.0, size.x * 0.022), -segment * segment_height)


func get_crown_radius() -> float:
	return minf(minf(size.x * CROWN_WIDTH_RATIO, size.y * CROWN_HEIGHT_RATIO), MAX_CROWN_RADIUS)


static func make_branch(tool_call_id: String, tool_name: String, branch_index: int, growth: float) -> Dictionary:
	var direction := -1.0 if branch_index % 2 == 0 else 1.0
	return {
		"id": tool_call_id,
		"label": public_tool_name(tool_name),
		"state": BranchState.RUNNING,
		"anchor": clampi(int(floor(growth)), 1, MAX_TRUNK_SEGMENTS - 1),
		"anchor_offset": branch_anchor_offset(branch_index),
		"direction": direction,
		"angle": branch_angle(branch_index),
		"completion_angle": completion_angle(branch_index),
		"growth": 0.0,
		"completion_growth": 0.0,
	}


## Alternates sides and advances through non-repeating elevations. Any 12 visible consecutive
## branches have distinct angles, including after older branches are discarded.
static func branch_angle(branch_index: int) -> float:
	var elevation_degrees := 24.0 + float(branch_index * 17 % 55)
	return deg_to_rad(180.0 + elevation_degrees) if branch_index % 2 == 0 else deg_to_rad(-elevation_degrees)


## Tool completion grows as a connected child branch with its own visible bend.
static func completion_angle(branch_index: int) -> float:
	var parent_angle := branch_angle(branch_index)
	var direction := -1.0 if branch_index % 2 == 0 else 1.0
	var bend_degrees := 20.0 + float(branch_index * 11 % 23)
	return parent_angle + deg_to_rad(direction * bend_degrees)


## Nearby tools in one turn attach around the trunk node instead of sharing one exact pixel.
static func branch_anchor_offset(branch_index: int) -> float:
	# Stay just below the turn endpoint so the trunk can always reach every staggered anchor.
	const OFFSETS: Array[float] = [-0.18, -0.05, -0.13, -0.02, -0.10, -0.21]
	return OFFSETS[branch_index % OFFSETS.size()]


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


static func public_tool_name(tool_name: String) -> String:
	var readable := tool_name.replace("_", " ").replace("-", " ").strip_edges()
	return readable.capitalize() if not readable.is_empty() else "工具"


func remap_active_tool_indices() -> void:
	active_tool_indices.clear()
	for index in range(branches.size()):
		var branch: Dictionary = branches[index]
		if int(branch["state"]) == BranchState.RUNNING:
			active_tool_indices[String(branch["id"])] = index
	pass
