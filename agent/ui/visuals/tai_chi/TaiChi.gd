class_name TaiChi
extends VisualEffect

## A quiet, center-out visual inspired by the opening gesture of a Chinese ink scroll.
## Each lifecycle concern lives in its own flow so later sequences stay isolated.

const COMPLETION_SECONDS := 1.25
const LINE_AURA_SHADER_PATH := "res://agent/ui/visuals/tai_chi/TaiChiLineAura.gdshader"
const FILL_SHADER_PATH := "res://agent/ui/visuals/tai_chi/TaiChiFill.gdshader"
const FILL_ALPHA := 0.58

var opening := TaiChiOpeningFlow.new()
var duality := TaiChiDualityFlow.new()
var formation := TaiChiFormationFlow.new()
var line_aura_canvas: ColorRect
var line_aura_material: ShaderMaterial
var fill_layer: ColorRect
var fill_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	create_fill_layer()
	create_line_aura()
	visible = false
	pass


func get_visual_type() -> VisualType.Type:
	return VisualType.Type.TAI_CHI


func fade_in_seconds() -> float:
	return 0.18


func fade_out_seconds() -> float:
	return 0.55


func reset_visual() -> void:
	opening.reset()
	duality.reset()
	formation.reset()
	queue_redraw()
	pass


func on_agent_start(_session_id: int) -> void:
	queue_redraw()
	pass


func on_agent_end(_error_message: String) -> void:
	if is_inside_tree():
		await get_tree().create_timer(COMPLETION_SECONDS).timeout
	pass


func on_theme_changed() -> void:
	sync_theme_colors()
	queue_redraw()
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	var changed := opening.advance(delta)
	if opening.line_progress() >= 1.0 and not duality.active:
		duality.begin()
		changed = true
	changed = duality.advance(delta) or changed
	if duality.progress() >= 1.0 and not formation.active:
		formation.begin()
		changed = true
	changed = formation.advance(delta) or changed
	update_line_aura()
	update_fill_layer()
	if changed:
		queue_redraw()
	pass


func create_line_aura() -> void:
	line_aura_canvas = ColorRect.new()
	line_aura_canvas.name = "LineAura"
	line_aura_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_aura_canvas.color = Color.WHITE
	line_aura_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line_aura_canvas.z_index = -2
	line_aura_material = ShaderMaterial.new()
	line_aura_material.shader = load(LINE_AURA_SHADER_PATH) as Shader
	line_aura_canvas.material = line_aura_material
	add_child(line_aura_canvas)
	sync_theme_colors()
	pass


func create_fill_layer() -> void:
	fill_layer = ColorRect.new()
	fill_layer.name = "FillLayer"
	fill_layer.z_index = -1
	fill_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_layer.color = Color.WHITE
	fill_material = ShaderMaterial.new()
	fill_material.shader = load(FILL_SHADER_PATH) as Shader
	fill_layer.material = fill_material
	add_child(fill_layer)
	pass


func update_fill_layer() -> void:
	if fill_layer == null or fill_material == null:
		return
	var reveal := formation.fill_progress() if formation.active else 0.0
	fill_layer.visible = reveal > 0.0
	fill_material.set_shader_parameter("opacity", reveal * FILL_ALPHA)
	if fill_layer.visible:
		var radius := formation.symbol_radius(size)
		var symbol_center := formation.symbol_center(size)
		fill_layer.position = symbol_center - Vector2(radius, radius)
		fill_layer.size = Vector2.ONE * radius * 2.0
	pass


func sync_theme_colors() -> void:
	if line_aura_material != null:
		line_aura_material.set_shader_parameter("aura_color", ThemeColor.accent_theme_color())
	pass


func update_line_aura() -> void:
	if line_aura_material == null or size.x <= 0.0 or size.y <= 0.0:
		return
	line_aura_canvas.visible = not formation.active
	if formation.active:
		return
	var center := size * 0.5
	var origin_y := center.y + minf(132.0, size.y * 0.17)
	var row_gap := minf(105.0, size.y * 0.14)
	var duality_reveal := duality.progress() if duality.active else 0.0
	var yang_y := lerpf(origin_y, center.y - row_gap * 0.5, duality_reveal)
	var yin_y := lerpf(origin_y, center.y + row_gap * 0.5, duality_reveal)
	var half_width := minf(size.x * 0.38, 620.0)
	line_aura_material.set_shader_parameter("viewport_size", size)
	line_aura_material.set_shader_parameter("half_width_uv", half_width / size.x)
	line_aura_material.set_shader_parameter("opening_y_uv", origin_y / size.y)
	line_aura_material.set_shader_parameter("yang_y_uv", yang_y / size.y)
	line_aura_material.set_shader_parameter("yin_y_uv", yin_y / size.y)
	line_aura_material.set_shader_parameter("yin_gap_uv", half_width * 0.13 * ease(duality_reveal, -1.5) / size.x)
	line_aura_material.set_shader_parameter("opening_progress", opening.line_progress())
	line_aura_material.set_shader_parameter("duality_progress", duality_reveal)
	line_aura_material.set_shader_parameter("duality_active", duality.active)
	pass


func _draw() -> void:
	if size.x < 180.0 or size.y < 180.0:
		return
	var center := size * 0.5
	if not duality.active:
		opening.draw(self, center, size.x)
	elif formation.active:
		duality.draw(self, center, size.x, formation.previous_state_opacity())
		formation.draw(self, center, size.x)
	else:
		var opening_line_y := center.y + minf(132.0, size.y * 0.17)
		opening.draw_title(self, Vector2(center.x, opening_line_y - minf(170.0, size.y * 0.22)), duality.title_opacity())
		duality.draw(self, center, size.x)
	pass
