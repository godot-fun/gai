class_name TaiChi
extends VisualEffect

## A quiet, center-out visual inspired by the opening gesture of a Chinese ink scroll.
## Each lifecycle concern lives in its own flow so later sequences stay isolated.

## Enables the complete eight-trigram showcase for visual previews and tests.
## Production keeps the ordinary short completion wait.
static var complete_animation_on_agent_end: bool = false

const COMPLETION_SECONDS := 1.25
const FILL_SHADER_PATH := "res://agent/ui/visuals/tai_chi/TaiChiFill.gdshader"
const FILL_ALPHA := 0.58

var tai_chi_opening_flow := TaiChiOpeningFlow.new()
var tai_chi_duality_flow := TaiChiDualityFlow.new()
var tai_chi_formation_flow := TaiChiFormationFlow.new()
var tai_chi_evolution_flow := TaiChiEvolutionFlow.new()
var tai_chi_bagua_flow := TaiChiBaguaFlow.new()
var tai_chi_carousel_flow := TaiChiCarouselFlow.new()
var tai_chi_hexagram_flow := TaiChiHexagramFlow.new()
var tai_chi_divination_flow := TaiChiDivinationFlow.new()
var tai_chi_element_background := TaiChiElementBackground.new()
var fill_layer: ColorRect
var fill_material: ShaderMaterial


func _ready() -> void:
	super._ready()
	tai_chi_element_background.create(self)
	create_fill_layer()
	pass


func fade_in_seconds() -> float:
	return 0.18


func fade_out_seconds() -> float:
	return 0.55


func on_agent_start(_session_id: int) -> void:
	queue_redraw()
	pass


func on_agent_end(error_message: String) -> void:
	if complete_animation_on_agent_end and StringUtils.is_blank(error_message):
		while is_inside_tree() and (not tai_chi_divination_flow.active or not tai_chi_divination_flow.animation_finished()):
			await get_tree().process_frame
		return
	if is_inside_tree():
		await get_tree().create_timer(COMPLETION_SECONDS).timeout
	pass


func _process(delta: float) -> void:
	if not visible:
		return
	var changed := tai_chi_opening_flow.advance(delta)
	changed = advance_flow(tai_chi_duality_flow, tai_chi_opening_flow.line_progress() >= 1.0, delta, changed)
	changed = advance_flow(tai_chi_formation_flow, tai_chi_duality_flow.progress() >= 1.0, delta, changed)
	changed = advance_flow(tai_chi_evolution_flow, tai_chi_formation_flow.progress() >= 1.0, delta, changed)
	changed = advance_flow(tai_chi_bagua_flow, tai_chi_evolution_flow.progress() >= 1.0, delta, changed)
	changed = advance_flow(tai_chi_carousel_flow, tai_chi_bagua_flow.progress() >= 1.0, delta, changed)
	if tai_chi_carousel_flow.finished() and not tai_chi_hexagram_flow.active:
		tai_chi_hexagram_flow.begin(tai_chi_carousel_flow.ring_rotation())
		changed = true
	changed = tai_chi_hexagram_flow.advance(delta) or changed
	changed = advance_flow(tai_chi_divination_flow, tai_chi_hexagram_flow.progress() >= 1.0, delta, changed)
	update_fill_layer()
	tai_chi_element_background.update(size, tai_chi_carousel_flow)
	if changed:
		queue_redraw()
	pass


func advance_flow(flow: Variant, ready: bool, delta: float, changed: bool) -> bool:
	if ready and not flow.active:
		flow.begin()
		changed = true
	return flow.advance(delta) or changed


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
	var reveal := tai_chi_formation_flow.fill_progress() if tai_chi_formation_flow.active else 0.0
	fill_layer.visible = reveal > 0.0
	var taiji_alpha := tai_chi_carousel_flow.taiji_opacity() if tai_chi_carousel_flow.active else 1.0
	fill_material.set_shader_parameter("opacity", reveal * FILL_ALPHA * taiji_alpha)
	if fill_layer.visible:
		var radius := tai_chi_bagua_flow.taiji_radius(size, tai_chi_evolution_flow) if tai_chi_bagua_flow.active else (tai_chi_evolution_flow.symbol_radius(size) if tai_chi_evolution_flow.active else tai_chi_formation_flow.symbol_radius(size))
		var symbol_center := tai_chi_bagua_flow.taiji_center(size, tai_chi_evolution_flow) if tai_chi_bagua_flow.active else (tai_chi_evolution_flow.symbol_center(size) if tai_chi_evolution_flow.active else tai_chi_formation_flow.symbol_center(size))
		fill_layer.position = symbol_center - Vector2(radius, radius)
		fill_layer.size = Vector2.ONE * radius * 2.0
		fill_layer.pivot_offset = fill_layer.size * 0.5
		fill_layer.rotation = tai_chi_carousel_flow.taiji_rotation() if tai_chi_carousel_flow.active else 0.0
	pass


func _draw() -> void:
	if size.x < 180.0 or size.y < 180.0:
		return
	var center := size * 0.5
	if not tai_chi_duality_flow.active:
		tai_chi_opening_flow.draw(self, center, size.x)
	elif tai_chi_divination_flow.active:
		tai_chi_divination_flow.draw(self)
	elif tai_chi_hexagram_flow.active:
		tai_chi_hexagram_flow.draw(self, tai_chi_bagua_flow)
	elif tai_chi_carousel_flow.active:
		tai_chi_carousel_flow.draw(self, tai_chi_bagua_flow)
	elif tai_chi_bagua_flow.active:
		tai_chi_evolution_flow.draw(self, tai_chi_bagua_flow.hierarchy_opacity(), false)
		tai_chi_bagua_flow.draw(self, tai_chi_evolution_flow)
	elif tai_chi_evolution_flow.active:
		tai_chi_evolution_flow.draw(self)
	elif tai_chi_formation_flow.active:
		tai_chi_duality_flow.draw(self, center, size.x, tai_chi_formation_flow.previous_state_opacity())
		tai_chi_formation_flow.draw(self, center, size.x)
	else:
		var opening_line_y := center.y + minf(132.0, size.y * 0.17)
		tai_chi_opening_flow.draw_title(self, Vector2(center.x, opening_line_y - minf(170.0, size.y * 0.22)), tai_chi_duality_flow.title_opacity())
		tai_chi_duality_flow.draw(self, center, size.x)
	pass
