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
	apply_window_theme(self, window_background_color(), window_title_color(), window_border_color())
	pass


func window_background_color() -> Color:
	return ThemeColor.accent_surface


func window_title_color() -> Color:
	return ThemeColor.title_color


func window_border_color() -> Color:
	return ThemeColor.title_color


## Center the window and apply embedded-window font oversampling.
func present_centered(width_percent: int = 70, height_percent: int = 80) -> void:
	size = size_from_viewport_percent(width_percent, height_percent)
	popup_centered()
	oversampling_override = DisplayScale.compute_ui_scale()
	pass


## Size against the viewport and show near the root viewport's right edge (vertically centered), inset by [constant Margin.ma_6].
func present_right(width_percent: int = 70, height_percent: int = 80) -> void:
	size = size_from_viewport_percent(width_percent, height_percent)
	var viewport_size := gdf.gdf_node.get_tree().root.get_visible_rect().size
	var x := int(viewport_size.x - size.x - Margin.ma_6)
	var y := int((viewport_size.y - size.y) * 0.5)
	popup(Rect2i(x, y, size.x, size.y))
	oversampling_override = DisplayScale.compute_ui_scale()
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and visible and dismiss_on_focus_out():
		on_close_requested.call_deferred()
	pass


## When [code]true[/code], losing window focus dismisses through [method on_close_requested] (see [PopupWindow]).
## Override to [code]false[/code] when the window owns embedded popups or file pickers that steal focus.
func dismiss_on_focus_out() -> bool:
	return true


func on_close_requested() -> void:
	queue_free()
	pass


func on_window_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		on_close_requested()
		set_input_as_handled()
	pass


####################################################################################################
# Static methods



## Apply the common embedded-window frame to a [Window]. Use this for built-in windows such as
## [FileDialog], which cannot inherit [CommonWindow] but should share its title and frame chrome.
static func apply_window_theme(window: Window, background: Color, title_color: Color, border_color: Color) -> void:
	window.add_theme_stylebox_override("embedded_border", make_embedded_border(window, background, border_color, BORDER_ALPHA))
	window.add_theme_stylebox_override("embedded_unfocused_border", make_embedded_border(window, background, border_color, BORDER_ALPHA_UNFOCUSED))
	window.add_theme_color_override("title_color", title_color)
	window.add_theme_font_override("title_font", Fonts.semibold())
	window.add_theme_font_size_override("title_font_size", Typography.title_medium_size)
	window.add_theme_icon_override("close", tint_theme_icon(window, "close", title_color))
	window.add_theme_icon_override("close_pressed", tint_theme_icon(window, "close_pressed", Colors.error))
	pass



static func make_embedded_border(window: Window, background: Color, border_color: Color, border_alpha: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = window.get_theme_stylebox("embedded_border").duplicate() as StyleBoxFlat
	style.bg_color = background
	style.set_corner_radius_all(ControlSize.radius_md)
	style.border_color = Color(border_color, border_alpha)
	style.set_border_width_all(ControlSize.border_xs)
	return style



static func tint_theme_icon(window: Window, icon_name: String, color: Color) -> ImageTexture:
	var image := window.get_theme_icon(icon_name).get_image()
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
