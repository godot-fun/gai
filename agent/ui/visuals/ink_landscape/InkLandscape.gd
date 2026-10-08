class_name InkLandscape
extends VisualEffect

## Event-driven ink landscape built from independent depth-sorted canvas layers.
## Odd turns reveal one cloud and even turns grow one mountain. Mountains are cropped
## to local bounds for fill-rate; clouds use three shared full-screen depth passes.
## Birds are CPU-drawn above both, one per tool execution.

const SHADER_PATH := "res://agent/ui/visuals/ink_landscape/InkLandscape.gdshader"
const MOUNTAIN_SHADER_PATH := "res://agent/ui/visuals/ink_landscape/InkMountain.gdshader"
const CLOUD_SHADER_PATH := "res://agent/ui/visuals/ink_landscape/InkCloud.gdshader"
const MAX_MOUNTAINS := 16
const MAX_CLOUDS := 12
const MAX_BIRDS := 7
const COMPLETION_SECONDS := 1.2
const BIRD_ENTRY_SPEED := 0.10
const BIRD_DEPARTURE_SPEED := 0.18

enum BirdPhase { ENTERING, ACTIVE, FINISHING, DEPARTING }
enum BirdResult { ACTIVE, SUCCESS, ERROR }

var mountains: Array[Dictionary] = []
var birds: Array[Dictionary] = []
var active_birds: Dictionary[String, Dictionary] = {}
var ink_canvas: ColorRect
var ink_material: ShaderMaterial
var cloud_canvas: ColorRect
var cloud_material: ShaderMaterial
var cloud_canvases: Array[ColorRect] = []
var cloud_materials: Array[ShaderMaterial] = []
var elapsed: float = 0.0
var reasoning_ink: float = 0.0
var completion: float = 0.0
var completing: bool = false
var ended_with_error: bool = false
var turn_serial: int = 0
var bird_serial: int = 0
var cloud_count: int = 0
## Fractional reveal cursor: its integer part counts completed clouds and its
## fractional part drives the newest cloud's ink-spreading animation.
var cloud_reveal: float = 0.0
## Shared end opacity. Shaders consume it directly because they overwrite COLOR,
## which bypasses CanvasItem modulation in their output calculation.
var exit_alpha: float = 1.0
## True only when the current turn created a mountain. Cloud turns must not
## accidentally settle the mountain created by the preceding turn.
var current_turn_has_mountain: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Parent-drawn birds stay above every relative negative-z landscape layer.
	z_index = 100
	create_ink_canvas()
	create_cloud_canvas()
	visible = false
	pass


func create_ink_canvas() -> void:
	if ink_canvas != null:
		return
	ink_canvas = ColorRect.new()
	ink_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink_canvas.color = Color.WHITE
	ink_canvas.show_behind_parent = true
	ink_material = ShaderMaterial.new()
	ink_material.shader = load(SHADER_PATH)
	ink_canvas.material = ink_material
	ink_canvas.z_index = -99
	# The legacy base shader no longer contributes pixels now that mountains and
	# clouds have independent layers. Keep the node for compatibility, but skip
	# its expensive full-screen noise pass.
	ink_canvas.visible = false
	add_child(ink_canvas)
	update_shader_theme()
	pass


func create_cloud_canvas() -> void:
	if not cloud_canvases.is_empty():
		return
	# These values interleave with mountain z [-87, -14], allowing cloud banks
	# behind, among, and in front of different mountain ranges.
	var layer_z := [-82, -52, -1]
	for index in range(3):
		var canvas := ColorRect.new()
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.color = Color.WHITE
		canvas.show_behind_parent = true
		canvas.z_index = layer_z[index]
		var material := ShaderMaterial.new()
		material.shader = load(CLOUD_SHADER_PATH)
		material.set_shader_parameter("layer_index", float(index))
		var bounds := cloud_layer_bounds(index)
		material.set_shader_parameter("uv_origin", bounds.position)
		material.set_shader_parameter("uv_scale", bounds.size)
		canvas.material = material
		add_child(canvas)
		cloud_canvases.append(canvas)
		cloud_materials.append(material)
	cloud_canvas = cloud_canvases[-1]
	cloud_material = cloud_materials[-1]
	update_shader_theme()
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.INK_LANDSCAPE


func fade_in_seconds() -> float:
	return 0.5


func fade_out_seconds() -> float:
	# The landscape performs its own guaranteed fade inside on_agent_end().
	return 0.15


func reset_visual() -> void:
	for mountain: Dictionary in mountains:
		var canvas: ColorRect = mountain.get("canvas")
		if is_instance_valid(canvas):
			canvas.queue_free()
	mountains.clear()
	birds.clear()
	active_birds.clear()
	elapsed = 0.0
	reasoning_ink = 0.0
	completion = 0.0
	completing = false
	ended_with_error = false
	turn_serial = 0
	bird_serial = 0
	cloud_count = 0
	cloud_reveal = 0.0
	current_turn_has_mountain = false
	set_landscape_alpha(1.0)
	update_shader_state()
	queue_redraw()
	pass


func on_agent_start(_session_id: int) -> void:
	reasoning_ink = 0.3
	queue_redraw()
	pass


func on_agent_end(error_message: String) -> void:
	ended_with_error = StringUtils.is_not_blank(error_message)
	completing = true
	for bird: Dictionary in active_birds.values():
		request_bird_departure(bird, BirdResult.ERROR if ended_with_error else BirdResult.SUCCESS)
	active_birds.clear()
	if is_inside_tree():
		await get_tree().create_timer(COMPLETION_SECONDS).timeout
		var dissolve := create_tween()
		# One uninterrupted curve avoids velocity changes between tween segments.
		dissolve.tween_method(set_landscape_alpha, 1.0, 0.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await dissolve.finished
	pass


func set_landscape_alpha(value: float) -> void:
	exit_alpha = clampf(value, 0.0, 1.0)
	for material: ShaderMaterial in cloud_materials:
		# self_modulate is insufficient because InkCloud.gdshader assigns COLOR.
		material.set_shader_parameter("fade_alpha", exit_alpha)
	for mountain: Dictionary in mountains:
		var material: ShaderMaterial = mountain.get("material")
		if material != null:
			material.set_shader_parameter("fade_alpha", exit_alpha)
	queue_redraw()
	pass


func on_turn_start() -> void:
	turn_serial += 1
	current_turn_has_mountain = false
	# Composition cadence is cloud -> mountain. Mountain geometry uses its own
	# serial below so alternating turns do not skip shape/depth seeds.
	if turn_serial % 2 == 1:
		cloud_count = mini(cloud_count + 1, MAX_CLOUDS)
		reasoning_ink = minf(2.0, reasoning_ink + 0.34)
		update_shader_state()
		queue_redraw()
		return
	if mountains.size() >= MAX_MOUNTAINS:
		return
	var mountain_serial := mountains.size() + 1
	var depth := mountain_depth(mountain_serial)
	var dimensions := mountain_dimensions(depth)
	var mountain := {
		"serial": mountain_serial,
		"depth": depth,
		"center": mountain_center(mountain_serial, dimensions.x),
		"width": dimensions.x,
		"height": dimensions.y,
		# Distant ranges begin near the top edge while foreground ranges still
		# anchor below the viewport, using the complete canvas as a depth field.
		"base": lerpf(0.14, 1.04, depth),
		"strength": lerpf(0.07, 0.42, depth) * (1.12 if mountain_serial == 3 else 1.0),
		"softness": lerpf(0.94, 0.16, depth),
		"shape": 3.0 if mountain_serial == 3 else float((mountain_serial - 1) % 5),
		"growth": 0.0,
		"settled": false,
	}
	mountains.append(mountain)
	current_turn_has_mountain = true
	if is_inside_tree():
		mount_mountain(mountain)
	reasoning_ink = minf(2.0, reasoning_ink + 0.52)
	queue_redraw()
	pass


func on_turn_end() -> void:
	if current_turn_has_mountain and not mountains.is_empty():
		mountains[-1]["settled"] = true
		mountains[-1]["growth"] = 1.0
	current_turn_has_mountain = false
	queue_redraw()
	pass


func on_message_update(chunk: String, stream_kind: String) -> void:
	if chunk.is_empty():
		return
	if stream_kind == OpenAiClient.STREAM_KIND_REASONING:
		ensure_landscape_mark()
		reasoning_ink = minf(2.0, reasoning_ink + float(chunk.length()) / 90.0)
	queue_redraw()
	pass


func on_tool_execution_start(tool_call_id: String, tool_name: String, _args: Dictionary[String, Variant]) -> void:
	bird_serial += 1
	if birds.size() >= MAX_BIRDS:
		# Retire the oldest active bird through the same phase sequence instead of
		# deleting it or maintaining a second capacity-only animation path.
		for existing_bird: Dictionary in birds:
			if int(existing_bird["result"]) != BirdResult.ACTIVE:
				continue
			request_bird_departure(existing_bird, BirdResult.SUCCESS)
			active_birds.erase(str(existing_bird["id"]))
			break
	var bird := {
		"id": tool_call_id,
		"phase": BirdPhase.ENTERING,
		"result": BirdResult.ACTIVE,
		"growth": 0.0,
		"wing": float(birds.size()) * 0.83,
		"flap_rate": lerpf(0.82, 1.16, float(abs((tool_name + tool_call_id).hash()) % 1000) / 1000.0),
		"entry": 0.0,
		"departure": 0.0,
		"finish_phase": -1.0,
		"serial": bird_serial,
		"seed": float(abs(tool_name.hash()) % 1000) / 1000.0,
	}
	birds.append(bird)
	active_birds[tool_call_id] = bird
	reasoning_ink = minf(2.0, reasoning_ink + 0.36)
	queue_redraw()
	pass


func on_tool_execution_end(tool_call_id: String, _tool_name: String, result: AgentToolResult) -> void:
	if not active_birds.has(tool_call_id):
		return
	var bird: Dictionary = active_birds[tool_call_id]
	request_bird_departure(bird, BirdResult.ERROR if result.is_error else BirdResult.SUCCESS)
	active_birds.erase(tool_call_id)
	queue_redraw()
	pass


func request_bird_departure(bird: Dictionary, result: int) -> void:
	if int(bird["result"]) != BirdResult.ACTIVE:
		return
	bird["result"] = result
	if int(bird["phase"]) == BirdPhase.ACTIVE:
		bird["phase"] = BirdPhase.FINISHING
	pass


func on_theme_changed() -> void:
	update_shader_theme()
	queue_redraw()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	var old_cloud_reveal := cloud_reveal
	cloud_reveal = move_toward(cloud_reveal, float(cloud_count), delta * 0.55)
	var changed := completing or reasoning_ink > 0.0 or old_cloud_reveal != cloud_reveal
	for mountain: Dictionary in mountains:
		var old_growth: float = mountain["growth"]
		mountain["growth"] = move_toward(old_growth, 1.0, delta * (0.22 + reasoning_ink * 0.46))
		var material: ShaderMaterial = mountain.get("material")
		if material != null:
			material.set_shader_parameter("growth", mountain["growth"])
		changed = changed or old_growth != float(mountain["growth"])
	var departed_birds: Array[Dictionary] = []
	for bird: Dictionary in birds:
		bird["growth"] = move_toward(float(bird["growth"]), 1.0, delta * 3.4)
		var phase: int = bird["phase"]
		var flap_rate: float = bird["flap_rate"]
		if phase == BirdPhase.ENTERING:
			bird["wing"] = float(bird["wing"]) + delta * 7.0 * flap_rate
			var flight_speed := bird_flight_speed(float(bird["wing"]))
			bird["entry"] = minf(1.0, float(bird["entry"]) + delta * BIRD_ENTRY_SPEED * flight_speed)
			if float(bird["entry"]) >= 1.0:
				bird["phase"] = BirdPhase.ACTIVE if int(bird["result"]) == BirdResult.ACTIVE else BirdPhase.FINISHING
		elif phase == BirdPhase.ACTIVE:
			bird["wing"] = float(bird["wing"]) + delta * 7.0 * flap_rate
		elif phase == BirdPhase.FINISHING:
			var finish_phase: float = bird["finish_phase"]
			if finish_phase < 0.0:
				finish_phase = next_glide_phase(float(bird["wing"]))
				bird["finish_phase"] = finish_phase
			bird["wing"] = minf(finish_phase, float(bird["wing"]) + delta * 7.0 * flap_rate)
			if is_equal_approx(float(bird["wing"]), finish_phase):
				bird["phase"] = BirdPhase.DEPARTING
		elif phase == BirdPhase.DEPARTING:
			bird["departure"] = minf(1.0, float(bird["departure"]) + delta * BIRD_DEPARTURE_SPEED)
			if float(bird["departure"]) >= 1.0:
				departed_birds.append(bird)
	for bird: Dictionary in departed_birds:
		birds.erase(bird)
	if completing:
		completion = minf(1.0, completion + delta / COMPLETION_SECONDS)
	reasoning_ink = move_toward(reasoning_ink, 0.08, delta * 0.55)
	update_canvas_rect()
	update_shader_state()
	if changed:
		queue_redraw()
	pass


func _draw() -> void:
	if size.x < 220.0 or size.y < 180.0:
		return
	var field := landscape_rect()
	for bird: Dictionary in birds:
		draw_tool_bird(bird, field)
	pass


func landscape_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


func update_canvas_rect() -> void:
	if ink_canvas == null:
		return
	var field := landscape_rect()
	ink_canvas.position = field.position
	ink_canvas.size = field.size
	for canvas: ColorRect in cloud_canvases:
		var index := cloud_canvases.find(canvas)
		var bounds := cloud_layer_bounds(index)
		canvas.position = field.position + field.size * bounds.position
		canvas.size = field.size * bounds.size
	for mountain: Dictionary in mountains:
		var canvas: ColorRect = mountain.get("canvas")
		if is_instance_valid(canvas):
			var bounds := mountain_bounds(mountain)
			canvas.position = field.position + field.size * bounds.position
			canvas.size = field.size * bounds.size
	pass


func update_shader_state() -> void:
	if ink_material == null:
		return
	ink_material.set_shader_parameter("elapsed", elapsed)
	for index in range(8):
		ink_material.set_shader_parameter("mountain_%d" % index, 0.0)
	ink_material.set_shader_parameter("reasoning", minf(reasoning_ink, 1.0))
	ink_material.set_shader_parameter("completion", completion)
	for material: ShaderMaterial in cloud_materials:
		material.set_shader_parameter("elapsed", elapsed)
		material.set_shader_parameter("presence", clampf(0.28 + float(mountains.size()) * 0.055, 0.28, 1.0))
		material.set_shader_parameter("cloud_reveal", cloud_reveal)
	pass


func update_shader_theme() -> void:
	if ink_material == null:
		return
	ink_material.set_shader_parameter("ink_color", ink_color())
	ink_material.set_shader_parameter("accent_color", ink_color())
	for material: ShaderMaterial in cloud_materials:
		# Dark canvases need restrained grey vapour; near-white clouds turn layered
		# wisps into opaque horizontal light bars.
		material.set_shader_parameter("cloud_color", Color(0.48, 0.51, 0.49, 1.0) if ThemeColor.is_dark_theme() else Color(0.94, 0.945, 0.925, 1.0))
		material.set_shader_parameter("ink_color", ink_color())
		material.set_shader_parameter("dark_theme", 1.0 if ThemeColor.is_dark_theme() else 0.0)
	for mountain: Dictionary in mountains:
		var material: ShaderMaterial = mountain.get("material")
		if material != null:
			material.set_shader_parameter("ink_color", ink_color())
			material.set_shader_parameter("background_color", ColorBase.app_background)
			material.set_shader_parameter("dark_theme", 1.0 if ThemeColor.is_dark_theme() else 0.0)
	pass


func mount_mountain(mountain: Dictionary) -> void:
	var canvas := ColorRect.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.color = Color.WHITE
	canvas.show_behind_parent = true
	canvas.z_index = -90 + int(float(mountain["depth"]) * 80.0)
	var material := ShaderMaterial.new()
	material.shader = load(MOUNTAIN_SHADER_PATH)
	material.set_shader_parameter("ink_color", ink_color())
	material.set_shader_parameter("background_color", ColorBase.app_background)
	material.set_shader_parameter("center", mountain["center"])
	material.set_shader_parameter("mountain_width", mountain["width"])
	material.set_shader_parameter("mountain_height", mountain["height"])
	material.set_shader_parameter("base", mountain["base"])
	material.set_shader_parameter("strength", mountain["strength"])
	material.set_shader_parameter("softness", mountain["softness"])
	material.set_shader_parameter("depth", mountain["depth"])
	material.set_shader_parameter("shape", mountain["shape"])
	material.set_shader_parameter("seed", float(mountain["serial"]) * 1.137)
	material.set_shader_parameter("growth", mountain["growth"])
	material.set_shader_parameter("dark_theme", 1.0 if ThemeColor.is_dark_theme() else 0.0)
	material.set_shader_parameter("fade_alpha", exit_alpha)
	var bounds := mountain_bounds(mountain)
	material.set_shader_parameter("uv_origin", bounds.position)
	material.set_shader_parameter("uv_scale", bounds.size)
	canvas.material = material
	add_child(canvas)
	mountain["canvas"] = canvas
	mountain["material"] = material
	update_canvas_rect()
	pass


static func mountain_bounds(mountain: Dictionary) -> Rect2:
	# Include profile side lobes, noisy edges, and the opaque foot. Do not expand
	# this to fullscreen: local bounds are the main mountain GPU optimization.
	var center: float = mountain["center"]
	var width: float = mountain["width"]
	var base: float = mountain["base"]
	var height: float = mountain["height"]
	var left := maxf(0.0, center - width * 5.6)
	var right := minf(1.0, center + width * 5.6)
	var top := maxf(0.0, base - height * 1.55 - 0.045)
	var bottom := minf(1.0, base + 0.085)
	return Rect2(Vector2(left, top), Vector2(maxf(0.001, right - left), maxf(0.001, bottom - top)))


static func mountain_depth(serial: int) -> float:
	# Establish a composed opening: two distant supports, a dominant right-hand
	# peak, then foreground companions. Later turns resume even depth coverage.
	const OPENING_DEPTHS := [0.18, 0.34, 0.84, 0.48, 0.70, 0.27]
	if serial <= OPENING_DEPTHS.size():
		return OPENING_DEPTHS[serial - 1]
	# Van der Corput sequence distributes unlimited turns evenly through the depth field.
	var value := maxi(serial, 1)
	var factor := 0.5
	var depth := 0.0
	while value > 0:
		depth += float(value % 2) * factor
		value /= 2
		factor *= 0.5
	return clampf(depth, 0.04, 0.96)


static func mountain_dimensions(depth: float) -> Vector2:
	var perspective := smoothstep(0.0, 1.0, clampf(depth, 0.0, 1.0))
	return Vector2(lerpf(0.025, 0.12, perspective), lerpf(0.10, 0.56, perspective))


static func mountain_center(serial: int, width: float) -> float:
	const OPENING_CENTERS := [0.16, 0.48, 0.72, 0.34, 0.14, 0.88]
	if serial <= OPENING_CENTERS.size():
		var opening_margin := width * 1.8
		return clampf(OPENING_CENTERS[serial - 1], opening_margin, 1.0 - opening_margin)
	# The first three turns establish a complete left/center/right composition. Later
	# cycles add bounded jitter and fill the gaps without creating visible columns.
	var lane := (serial - 1) % 3
	var cycle := (serial - 1) / 3
	var lane_center := 0.18 + float(lane) * 0.32
	var jitter := (fmod(float(cycle + 1) * 0.61803398875, 1.0) - 0.5) * 0.18
	var golden_position := lane_center + jitter if cycle > 0 else lane_center
	var margin := width * 1.8
	return clampf(golden_position, margin, 1.0 - margin)


func draw_tool_bird(bird: Dictionary, field: Rect2) -> void:
	var growth: float = bird["growth"]
	if growth <= 0.0:
		return
	var phase: int = bird["phase"]
	var result: int = bird["result"]
	var serial: int = bird["serial"]
	var seed: float = bird["seed"]
	var departure: float = bird["departure"]
	var target_ratio := bird_exit_position(serial, seed)
	var entry: float = bird["entry"]
	var spawn_ratio := bird_spawn_position(target_ratio.x, serial)
	var control_ratio := bird_entry_control(spawn_ratio, target_ratio, serial, seed)
	var position_ratio := bird_entry_position(spawn_ratio, control_ratio, target_ratio, entry)
	var center := field.position + field.size * position_ratio
	if phase == BirdPhase.DEPARTING:
		if result == BirdResult.SUCCESS:
			center += Vector2(field.size.x * 0.07 * departure, -field.size.y * 0.055 * departure)
		else:
			center += Vector2(field.size.x * 0.018 * departure, field.size.y * 0.085 * departure)
	var perspective := bird_perspective(position_ratio.y, bird_flies_down(serial))
	var departure_scale := bird_departure_scale(departure)
	var base_scale := (0.78 + seed * 0.38) * perspective.x * ease(growth, -1.2)
	var scale := base_scale * departure_scale
	var flap := sin(float(bird["wing"]))
	# Keep the final flap offset as the glide anchor. Removing it at the exact
	# lock-frame causes a small but visible backward snap.
	center += bird_body_flap_offset(float(bird["wing"]), base_scale)
	var wing_lift := flap * 11.0 * scale
	if phase == BirdPhase.DEPARTING and result == BirdResult.SUCCESS:
		wing_lift = 3.0 * scale
	var downstroke_phase := flap if wing_lift < 0.0 else 0.0
	var span := (24.0 + seed * 11.0) * scale * bird_wing_span_scale(downstroke_phase)
	var ink := ink_color()
	var departure_alpha := 1.0 - smoothstep(0.42, 1.0, departure)
	var alpha := (0.56 if result == BirdResult.ERROR else 0.62) * departure_alpha * perspective.y * exit_alpha
	# Layered strokes give each bird a soft ink belly and two calligraphic wings.
	draw_circle(center, 4.2 * scale, Color(ink, alpha * 0.42))
	draw_circle(center + Vector2(3.0, 0.8) * scale, 2.4 * scale, Color(ink, alpha * 0.58))
	var left_wing := bird_wing_curve(center, span, wing_lift, -1.0, 1.0)
	var right_wing := bird_wing_curve(center, span, wing_lift, 1.0, 0.88)
	draw_polyline(left_wing, Color(ink, alpha * 0.18), 5.0 * scale, true)
	draw_polyline(right_wing, Color(ink, alpha * 0.18), 5.0 * scale, true)
	draw_polyline(left_wing, Color(ink, alpha), 1.45 * scale, true)
	draw_polyline(right_wing, Color(ink, alpha), 1.45 * scale, true)
	draw_line(center + Vector2(3.5, 0.0) * scale, center + Vector2(7.0, -1.0) * scale, Color(ink, alpha * 0.72), 1.0, true)
	pass


func ensure_landscape_mark() -> void:
	if mountains.is_empty() and cloud_count == 0:
		on_turn_start()
	pass


static func cloud_layer_bounds(layer_index: int) -> Rect2:
	# Procedural clouds in each pass occupy a known vertical depth band. Cropping
	# those passes reduces fill-rate while retaining full horizontal distribution.
	match layer_index:
		0:
			return Rect2(0.0, 0.0, 1.0, 0.48)
		1:
			return Rect2(0.0, 0.22, 1.0, 0.66)
		_:
			return Rect2(0.0, 0.50, 1.0, 0.50)


func ink_color() -> Color:
	return Color(0.78, 0.82, 0.79) if ThemeColor.is_dark_theme() else Color(0.10, 0.12, 0.105)


static func bird_position(serial: int, seed: float) -> Vector2:
	# Coprime low-discrepancy sequences keep repeated tool types spread across the sky.
	var x := fmod(float(serial) * 0.61803398875 + seed * 0.07, 1.0)
	var y := fmod(float(serial) * 0.41421356237 + seed * 0.05, 1.0)
	return Vector2(lerpf(0.07, 0.93, x), lerpf(0.08, 0.82, y))


static func bird_exit_position(serial: int, seed: float) -> Vector2:
	var target := bird_position(serial, seed)
	if bird_flies_down(serial):
		# Birds entering from above may descend, but remain in the high, distant
		# sky band instead of growing into foreground silhouettes.
		target.y = lerpf(0.08, 0.34, inverse_lerp(0.08, 0.82, target.y))
	return target


static func bird_flies_down(serial: int) -> bool:
	return serial % 2 == 1


static func bird_spawn_position(target_x: float, serial: int = 0) -> Vector2:
	var spawn_y := -0.08 if serial % 2 == 1 else 1.08
	var direction := -1.0 if serial % 2 == 1 else 1.0
	var spawn_x := clampf(target_x - direction * 0.12, 0.04, 0.96)
	return Vector2(spawn_x, spawn_y)


static func bird_entry_control(spawn: Vector2, target: Vector2, _serial: int, seed: float) -> Vector2:
	var horizontal_progress := lerpf(0.42, 0.62, seed)
	return Vector2(lerpf(spawn.x, target.x, horizontal_progress), lerpf(spawn.y, target.y, 0.48))


static func bird_entry_position(spawn: Vector2, control: Vector2, target: Vector2, progress: float) -> Vector2:
	# Convert linear progress to an approximate arc-length parameter so the curved
	# flight remains steady instead of accelerating around the bend.
	const SAMPLES := 24
	var points := PackedVector2Array([spawn])
	var lengths := PackedFloat32Array([0.0])
	var total_length := 0.0
	for index in range(1, SAMPLES + 1):
		var time := float(index) / float(SAMPLES)
		var point := quadratic_bezier(spawn, control, target, time)
		total_length += points[-1].distance_to(point)
		points.append(point)
		lengths.append(total_length)
	var wanted := total_length * clampf(progress, 0.0, 1.0)
	for index in range(1, lengths.size()):
		if lengths[index] < wanted:
			continue
		var segment_length := lengths[index] - lengths[index - 1]
		var amount := 0.0 if segment_length <= 0.0001 else (wanted - lengths[index - 1]) / segment_length
		return points[index - 1].lerp(points[index], amount)
	return target


static func bird_flight_speed(wing_phase: float) -> float:
	# wing_lift follows sin(phase), so its downward velocity follows -cos(phase).
	# This makes the power stroke accelerate the bird and the recovery stroke
	# slow it down, independent of the wing's current high/low pose.
	# 0.50 produces a visible 50%-150% range around BIRD_ENTRY_SPEED. Keep the
	# result positive or a large frame could make the bird travel backwards.
	return 1.0 - cos(wing_phase) * 0.50


static func next_glide_phase(wing_phase: float) -> float:
	# Finish the current flap cycle, then stop where sin(phase) produces the
	# established shallow gliding lift (3 / 11 of the full stroke).
	var glide_phase := asin(3.0 / 11.0)
	var cycles := ceilf((wing_phase - glide_phase) / TAU)
	return glide_phase + maxf(cycles, 0.0) * TAU


static func bird_departure_scale(flight: float) -> float:
	# Preserve the readable silhouette at first, then recede continuously until
	# it is effectively a point before _process removes the completed bird.
	return 1.0 - smoothstep(0.08, 1.0, clampf(flight, 0.0, 1.0))


static func bird_wing_span_scale(wing_phase: float) -> float:
	# A downstroke turns the wing partly out of the screen plane and folds its
	# joints, shortening the visible projection to 78% at the lowest pose.
	var downstroke := smoothstep(0.0, 1.0, clampf(-wing_phase, 0.0, 1.0))
	return lerpf(1.0, 0.78, downstroke)


static func bird_body_flap_offset(wing_phase: float, scale: float) -> Vector2:
	# Vertical lift sells the wing stroke without ever reversing horizontal travel.
	return Vector2(0.0, -sin(wing_phase) * 3.8 * scale)


static func bird_perspective(vertical_ratio: float, distant_only: bool = false) -> Vector2:
	# Birds near the bottom read as closer; those approaching the upper edge shrink
	# and fade into atmospheric perspective. Do not clamp at y=0: the off-screen
	# target must reach almost zero size/alpha instead of disappearing at medium size.
	# Returns (scale, alpha multiplier).
	var scale_depth := smoothstep(-0.10, 0.72, vertical_ratio)
	var alpha_depth := smoothstep(-0.08, 0.45, vertical_ratio)
	var perspective := Vector2(lerpf(0.04, 1.18, scale_depth), alpha_depth)
	if distant_only:
		perspective *= Vector2(0.62, 0.82)
	return perspective


static func quadratic_bezier(start: Vector2, control: Vector2, end: Vector2, time: float) -> Vector2:
	var inverse := 1.0 - time
	return inverse * inverse * start + 2.0 * inverse * time * control + time * time * end


static func bird_wing_curve(center: Vector2, span: float, wing_lift: float, direction: float, lift_bias: float) -> PackedVector2Array:
	const SAMPLES := 12
	var control_1: Vector2
	var control_2: Vector2
	var wing_tip: Vector2
	if wing_lift >= 0.0:
		# Upstroke: lift the middle of the wing while the tip trails behind.
		control_1 = center + Vector2(direction * span * 0.24, -wing_lift * 0.82 * lift_bias)
		control_2 = center + Vector2(direction * span * 0.68, -wing_lift * 1.12 * lift_bias)
		wing_tip = center + Vector2(direction * span, -wing_lift * 0.40 * lift_bias)
	else:
		# Downstroke: the shoulder lifts slightly before the elbow turns and the
		# primary feathers descend. This curved articulation avoids both a bowl and
		# the rigid straight V produced by nearly collinear control points.
		control_1 = center + Vector2(direction * span * 0.28, wing_lift * 0.08 * lift_bias)
		control_2 = center + Vector2(direction * span * 0.70, -wing_lift * 0.22 * lift_bias)
		wing_tip = center + Vector2(direction * span, -wing_lift * 0.94 * lift_bias)
	var points := PackedVector2Array()
	for index in range(SAMPLES + 1):
		var time := float(index) / float(SAMPLES)
		points.append(cubic_bezier(center, control_1, control_2, wing_tip, time))
	return points


static func cubic_bezier(start: Vector2, control_1: Vector2, control_2: Vector2, end: Vector2, time: float) -> Vector2:
	var inverse := 1.0 - time
	return inverse * inverse * inverse * start + 3.0 * inverse * inverse * time * control_1 + 3.0 * inverse * time * time * control_2 + time * time * time * end
