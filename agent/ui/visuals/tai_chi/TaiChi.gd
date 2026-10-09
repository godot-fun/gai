class_name TaiChi
extends VisualEffect

## A quiet, center-out visual inspired by the opening gesture of a Chinese ink scroll.
## Each lifecycle concern lives in its own flow so later sequences stay isolated.

## Enables the complete eight-trigram showcase for visual previews and tests.
## Production keeps the ordinary short completion wait.
static var complete_animation_on_agent_end: bool = false

const COMPLETION_SECONDS := 1.25
const TAI_CHI_HEXAGRAM_FLOW_SCRIPT := preload("res://agent/ui/visuals/tai_chi/TaiChiHexagramFlow.gd")
const TAI_CHI_DIVINATION_FLOW_SCRIPT := preload("res://agent/ui/visuals/tai_chi/TaiChiDivinationFlow.gd")
const FILL_SHADER_PATH := "res://agent/ui/visuals/tai_chi/TaiChiFill.gdshader"
const FILL_ALPHA := 0.58

var opening := TaiChiOpeningFlow.new()
var duality := TaiChiDualityFlow.new()
var formation := TaiChiFormationFlow.new()
var evolution := TaiChiEvolutionFlow.new()
var bagua := TaiChiBaguaFlow.new()
var carousel := TaiChiCarouselFlow.new()
var hexagram := TAI_CHI_HEXAGRAM_FLOW_SCRIPT.new()
var divination := TAI_CHI_DIVINATION_FLOW_SCRIPT.new()
var element_background := TaiChiElementBackground.new()
var fill_layer: ColorRect
var fill_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	element_background.create(self)
	create_fill_layer()
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
	evolution.reset()
	bagua.reset()
	carousel.reset()
	hexagram.reset()
	divination.reset()
	element_background.reset()
	queue_redraw()
	pass


func on_agent_start(_session_id: int) -> void:
	queue_redraw()
	pass


func on_agent_end(error_message: String) -> void:
	if complete_animation_on_agent_end and StringUtils.is_blank(error_message):
		while is_inside_tree() and (not divination.active or not divination.animation_finished()):
			await get_tree().process_frame
		return
	if is_inside_tree():
		await get_tree().create_timer(COMPLETION_SECONDS).timeout
	pass


func on_theme_changed() -> void:
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
	if formation.progress() >= 1.0 and not evolution.active:
		evolution.begin()
		changed = true
	changed = evolution.advance(delta) or changed
	if evolution.progress() >= 1.0 and not bagua.active:
		bagua.begin()
		changed = true
	changed = bagua.advance(delta) or changed
	if bagua.progress() >= 1.0 and not carousel.active:
		carousel.begin()
		changed = true
	changed = carousel.advance(delta) or changed
	if carousel.finished() and not hexagram.active:
		hexagram.begin(carousel.ring_rotation())
		changed = true
	changed = hexagram.advance(delta) or changed
	if hexagram.progress() >= 1.0 and not divination.active:
		divination.begin()
		changed = true
	changed = divination.advance(delta) or changed
	update_fill_layer()
	element_background.update(size, carousel)
	if changed:
		queue_redraw()
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
	var taiji_alpha := carousel.taiji_opacity() if carousel.active else 1.0
	fill_material.set_shader_parameter("opacity", reveal * FILL_ALPHA * taiji_alpha)
	if fill_layer.visible:
		var radius := bagua.taiji_radius(size, evolution) if bagua.active else (evolution.symbol_radius(size) if evolution.active else formation.symbol_radius(size))
		var symbol_center := bagua.taiji_center(size, evolution) if bagua.active else (evolution.symbol_center(size) if evolution.active else formation.symbol_center(size))
		fill_layer.position = symbol_center - Vector2(radius, radius)
		fill_layer.size = Vector2.ONE * radius * 2.0
		fill_layer.pivot_offset = fill_layer.size * 0.5
		fill_layer.rotation = carousel.taiji_rotation() if carousel.active else 0.0
	pass


func _draw() -> void:
	if size.x < 180.0 or size.y < 180.0:
		return
	var center := size * 0.5
	if not duality.active:
		opening.draw(self, center, size.x)
	elif divination.active:
		divination.draw(self)
	elif hexagram.active:
		hexagram.draw(self, bagua)
	elif carousel.active:
		carousel.draw(self, bagua)
	elif bagua.active:
		evolution.draw(self, bagua.hierarchy_opacity(), false)
		bagua.draw(self, evolution)
	elif evolution.active:
		evolution.draw(self)
	elif formation.active:
		duality.draw(self, center, size.x, formation.previous_state_opacity())
		formation.draw(self, center, size.x)
	else:
		var opening_line_y := center.y + minf(132.0, size.y * 0.17)
		opening.draw_title(self, Vector2(center.x, opening_line_y - minf(170.0, size.y * 0.22)), duality.title_opacity())
		duality.draw(self, center, size.x)
	pass
