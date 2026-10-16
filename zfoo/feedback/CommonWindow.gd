## Shared behavior and chrome for transient application windows.
##
## Subclasses own their content and may override the color methods or [method on_close_requested].
class_name CommonWindow
extends Window

## Hairline around the frame, so the window separates from the app in either theme.
const BORDER_ALPHA: float = 0.18
const BORDER_ALPHA_UNFOCUSED: float = 0.08

## Full-window content host used by subclasses instead of adding controls directly to the window.
var container: PanelContainer


func _init() -> void:
	transient = true
	visible = false
	container = PanelContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.offset_left = -ControlSize.border_xs
	container.offset_top = -ControlSize.border_xs
	container.offset_right = ControlSize.border_xs
	container.offset_bottom = ControlSize.border_xs
	container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(container)
	close_requested.connect(on_close_requested)
	window_input.connect(on_window_input)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	pass


## Paint the shared window frame; subclasses should call [code]super()[/code] before styling content.
func apply_theme() -> void:
	add_theme_stylebox_override("embedded_border", make_embedded_border(BORDER_ALPHA))
	add_theme_stylebox_override("embedded_unfocused_border", make_embedded_border(BORDER_ALPHA_UNFOCUSED))
	add_theme_color_override("title_color", window_title_color())
	add_theme_font_override("title_font", Fonts.semibold())
	add_theme_font_size_override("title_font_size", Typography.title_medium_size)
	add_theme_icon_override("close", tint_theme_icon("close", window_title_color()))
	add_theme_icon_override("close_pressed", tint_theme_icon("close_pressed", Colors.error))
	pass


func window_background_color() -> Color:
	return ThemeColor.accent_surface


func window_title_color() -> Color:
	return ThemeColor.title_color


func window_border_color() -> Color:
	return ThemeColor.title_color


func make_embedded_border(border_alpha: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = get_theme_stylebox("embedded_border").duplicate() as StyleBoxFlat
	style.bg_color = window_background_color()
	style.set_corner_radius_all(ControlSize.radius_md)
	style.border_color = Color(window_border_color(), border_alpha)
	style.set_border_width_all(ControlSize.border_xs)
	return style


func tint_theme_icon(icon_name: String, color: Color) -> ImageTexture:
	var image := get_theme_icon(icon_name).get_image()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var alpha := image.get_pixel(x, y).a
			image.set_pixel(x, y, Color(color, alpha))
	return ImageTexture.create_from_image(image)


## Size against the root viewport; percentages clamp to 1–100.
static func size_from_viewport_percent(width_percent: int, height_percent: int) -> Vector2i:
	var viewport := gdf.gdf_node.get_tree().root.get_visible_rect().size
	return Vector2i(
		int(viewport.x * clampf(width_percent, 1.0, 100.0) / 100.0),
		int(viewport.y * clampf(height_percent, 1.0, 100.0) / 100.0),
	)


## Center the window and apply embedded-window font oversampling.
func present_centered(width_percent: int = 70, height_percent: int = 80) -> void:
	size = size_from_viewport_percent(width_percent, height_percent)
	popup_centered()
	oversampling_override = DisplayScale.compute_ui_scale()
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and visible:
		on_close_requested.call_deferred()
	pass


func on_close_requested() -> void:
	queue_free()
	pass


func on_window_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		on_close_requested()
		set_input_as_handled()
	pass
