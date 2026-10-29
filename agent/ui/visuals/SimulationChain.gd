class_name SimulationChain
extends Node

## GPU field that persists between frames. Pass viewports are nested and Godot renders the
## innermost first, so pass i reads pass i - 1 from this frame while pass 0 reads the last
## pass from the previous frame: one chain advances [method pass_count] steps per frame.
## HDR 2D keeps every pass in float precision, including signed values.

var viewports: Array[SubViewport] = []
var materials: Array[ShaderMaterial] = []
var rects: Array[ColorRect] = []
var running: bool = false


## [param pass_kinds] holds one entry per pass; each pass receives it as the `pass_kind` uniform.
## A chain needs at least two passes because a pass cannot sample its own render target.
func setup(shader: Shader, pass_kinds: PackedInt32Array, field_size: Vector2i) -> void:
	assert(pass_kinds.size() >= 2)
	var parent: Node = self
	for depth in range(pass_kinds.size()):
		var viewport := SubViewport.new()
		viewport.name = "Pass%d" % (pass_kinds.size() - 1 - depth)
		viewport.size = field_size
		viewport.use_hdr_2d = true
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		parent.add_child(viewport)
		viewports.push_front(viewport)
		parent = viewport
	for index in range(pass_kinds.size()):
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("pass_kind", pass_kinds[index])
		var source := viewports[index - 1] if index > 0 else viewports[viewports.size() - 1]
		material.set_shader_parameter("state_tex", source.get_texture())
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.material = material
		viewports[index].add_child(rect)
		materials.append(material)
		rects.append(rect)
	resize(field_size)
	pass


func pass_count() -> int:
	return viewports.size()


## Final pass output; sample it from display shaders.
func get_texture() -> ViewportTexture:
	return viewports[viewports.size() - 1].get_texture()


## Resizing reallocates every render target, so callers should reset the field afterwards.
func resize(field_size: Vector2i) -> void:
	for index in range(viewports.size()):
		viewports[index].size = field_size
		rects[index].size = Vector2(field_size)
	set_param("texel", Vector2.ONE / Vector2(field_size))
	set_param("aspect", float(field_size.x) / float(maxi(field_size.y, 1)))
	pass


func set_running(value: bool) -> void:
	if running == value:
		return
	running = value
	var mode := SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	for viewport: SubViewport in viewports:
		viewport.render_target_update_mode = mode
	pass


func set_param(param: StringName, value: Variant) -> void:
	for material: ShaderMaterial in materials:
		material.set_shader_parameter(param, value)
	pass


func set_pass_param(index: int, param: StringName, value: Variant) -> void:
	materials[index].set_shader_parameter(param, value)
	pass
