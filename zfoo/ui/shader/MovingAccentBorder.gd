class_name MovingAccentBorder
extends ColorRect

## Theme-accent highlight traveling along a rounded-rectangle border.
## The caller aligns this non-interactive overlay to the decorated control.
## Supports rounded rectangles, capsules, and circles. Applying the capsule shape to a square creates
## a circle; applying it to a non-square rectangle creates a capsule. Ellipses and arbitrary outlines
## are not supported.

const BORDER_SHADER: Shader = preload("res://zfoo/ui/shader/moving_accent_border.gdshader")

## A negative value selects the capsule shape and derives its radius from the current height.
var corner_radius: float = -1.0
var highlight_strength: float = 0.55
var border_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	color = Color(1.0, 1.0, 1.0, 0.0)
	ensure_material()
	gdf.events.theme_changed.connect(sync_style_uniforms)
	gdf.events.theme_color_changed.connect(sync_style_uniforms)
	if not resized.is_connected(sync_geometry_uniforms):
		resized.connect(sync_geometry_uniforms)
	sync_shader_uniforms()
	pass


func set_corner_radius(radius: float) -> void:
	var next_radius := maxf(radius, 0.0)
	if is_equal_approx(corner_radius, next_radius):
		return
	corner_radius = next_radius
	sync_geometry_uniforms()
	pass


func use_capsule_shape() -> void:
	if corner_radius < 0.0:
		return
	corner_radius = -1.0
	sync_geometry_uniforms()
	pass


func set_highlight_strength(strength: float) -> void:
	var next_strength := clampf(strength, 0.0, 1.0)
	if is_equal_approx(highlight_strength, next_strength):
		return
	highlight_strength = next_strength
	ensure_material()
	border_material.set_shader_parameter("highlight_strength", highlight_strength)
	pass


func border_path_size_from_layout() -> Vector2:
	var border_size := Vector2(offset_right - offset_left, offset_bottom - offset_top)
	if border_size.x < 1.0 or border_size.y < 1.0:
		border_size = size
	return border_size - Vector2(Margin.ma_1 * 2.0, Margin.ma_1 * 2.0)


func corner_radius_for_size() -> float:
	if corner_radius >= 0.0:
		return corner_radius
	return maxf(border_path_size_from_layout().y * 0.5, 1.0)


func ensure_material() -> void:
	if border_material != null:
		return
	border_material = ShaderMaterial.new()
	border_material.shader = BORDER_SHADER
	material = border_material
	pass


func sync_style_uniforms() -> void:
	ensure_material()
	border_material.set_shader_parameter("accent_color", ThemeColor.theme_color)
	border_material.set_shader_parameter("highlight_strength", highlight_strength)
	pass


func sync_geometry_uniforms() -> void:
	ensure_material()
	var border_size := size
	if border_size.x < 1.0 or border_size.y < 1.0:
		border_size = Vector2(offset_right - offset_left, offset_bottom - offset_top)
	if border_size.x < 1.0 or border_size.y < 1.0:
		return
	border_material.set_shader_parameter("corner_radius", corner_radius_for_size())
	border_material.set_shader_parameter("rect_size", border_size)
	# Outward margin so the glow can draw outside the panel (>= half GLOW_WIDTH in the shader).
	border_material.set_shader_parameter("edge_pad", Margin.ma_1)
	pass


func sync_shader_uniforms() -> void:
	sync_style_uniforms()
	sync_geometry_uniforms()
	pass
