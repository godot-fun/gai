class_name SessionRowSciFiFx
extends ColorRect

## Selected-row overlay (shader: agent/ui/sidebar/sidebar_session_row.gdshader).
## Owned by [SessionRow], which toggles it through [method set_highlight].

const SHADER := preload("res://agent/ui/sidebar/sidebar_session_row.gdshader")

var fx_material: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1.0, 1.0, 1.0, 0.0)
	set_anchors_preset(PRESET_FULL_RECT)
	fx_material = ShaderMaterial.new()
	fx_material.shader = SHADER
	material = fx_material
	visible = false
	pass


func _ready() -> void:
	var parent_row := get_parent() as Control
	if parent_row != null:
		parent_row.resized.connect(sync_uniforms)
	resized.connect(sync_uniforms)
	sync_uniforms()
	pass


func set_highlight(active: bool) -> void:
	visible = active
	color.a = 1.0 if active else 0.0
	if fx_material == null:
		return
	fx_material.set_shader_parameter("strength", 1.0 if active else 0.0)
	sync_uniforms()
	queue_redraw()
	pass


func sync_uniforms() -> void:
	if fx_material == null:
		return
	var sz := size
	if sz.x < 1.0 or sz.y < 1.0:
		var parent_row := get_parent() as Control
		if parent_row != null:
			sz = parent_row.size
	fx_material.set_shader_parameter("rect_size", sz)
	fx_material.set_shader_parameter("corner_radius", float(ControlSize.radius_md))
	var is_dark := ThemeColor.is_dark_theme()
	var accent_color := ThemeColor.accent_theme_color()
	# Dark surfaces swallow low-alpha shader details, especially with a user-selected dark accent.
	# Lift the display color while keeping the configured hue unchanged everywhere else in the UI.
	if is_dark:
		accent_color = accent_color.lightened(0.22)
	fx_material.set_shader_parameter("accent_color", accent_color)
	fx_material.set_shader_parameter("is_dark", 1.0 if is_dark else 0.0)
	pass
