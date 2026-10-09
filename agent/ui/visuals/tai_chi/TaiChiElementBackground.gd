class_name TaiChiElementBackground
extends RefCounted

## Owns the subtle full-screen atmosphere used by the final trigram carousel.

const SHADER_PATH := "res://agent/ui/visuals/tai_chi/TaiChiElementBackground.gdshader"

var layer: ColorRect
var material: ShaderMaterial


func create(parent: Control) -> void:
	layer = ColorRect.new()
	layer.name = "ElementBackground"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.color = Color.WHITE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = -3
	layer.visible = false
	material = ShaderMaterial.new()
	material.shader = load(SHADER_PATH) as Shader
	layer.material = material
	parent.add_child(layer)
	pass


func reset() -> void:
	if layer != null:
		layer.visible = false
	pass


func update(canvas_size: Vector2, carousel: TaiChiCarouselFlow) -> void:
	if layer == null or material == null:
		return
	var opacity := carousel.item_opacity()
	layer.visible = carousel.active and opacity > 0.0
	if not layer.visible:
		return
	var index := carousel.selected_index()
	material.set_shader_parameter("viewport_size", canvas_size)
	material.set_shader_parameter("elapsed", carousel.carousel_time())
	material.set_shader_parameter("opacity", opacity)
	material.set_shader_parameter("accent_color", carousel.background_color(index))
	material.set_shader_parameter("effect_mode", carousel.background_effect(index))
	material.set_shader_parameter("seed", carousel.background_seed(index))
	pass
