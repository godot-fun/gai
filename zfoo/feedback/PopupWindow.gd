## Read-only text popup. Dismiss with Esc, the close button, or a click outside (window loses focus).
##
## The popup paints itself from the app theme: the embedded frame and title take the accent-derived
## card colors of [ThemeColor] — the same surface the snackbar and the desktop toast use — and the
## text area takes [member ThemeColor.inset_surface], with the
## accent on the caret, the selection and the scrollbar grabber. [method apply_theme] runs on open and
## on every theme change.
## The frame overrides only apply while subwindows are embedded, which is the project default; with
## `embed_subwindows` off the OS draws the chrome and only the text area stays themed.
class_name PopupWindow
extends Window

## Hairline around the frame, so the popup separates from the app in either theme.
const BORDER_ALPHA: float = 0.18
const BORDER_ALPHA_UNFOCUSED: float = 0.08

var text_edit: TextEdit


func _init() -> void:
	# Child of the main window: follows it, and usually has no taskbar entry.
	transient = true
	# Hide until popup_centered(), otherwise add_child flashes a default-sized window.
	visible = false
	close_requested.connect(on_close_requested)
	window_input.connect(on_window_input)
	# Freed with the window, so the connections need no teardown.
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)

	text_edit = TextEdit.new()
	text_edit.editable = false
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(text_edit)
	apply_theme()
	pass


## Paint the popup for the current theme; safe to run again on every theme or accent change.
func apply_theme() -> void:
	add_theme_stylebox_override("embedded_border", make_embedded_border(BORDER_ALPHA))
	add_theme_stylebox_override("embedded_unfocused_border", make_embedded_border(BORDER_ALPHA_UNFOCUSED))
	add_theme_color_override("title_color", ThemeColor.title_color)
	add_theme_font_override("title_font", Fonts.semibold())
	add_theme_font_size_override("title_font_size", Typography.title_medium_size)
	add_theme_icon_override("close_pressed", tint_theme_icon("close_pressed", Colors.error))
	style_text_edit()
	pass


func tint_theme_icon(icon_name: String, color: Color) -> ImageTexture:
	var image := get_theme_icon(icon_name).get_image()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var alpha := image.get_pixel(x, y).a
			image.set_pixel(x, y, Color(color, alpha))
	return ImageTexture.create_from_image(image)


## The engine's own frame with only its fills swapped, so the 32px title band, the close button and
## the resize margins keep the geometry the engine positions them by. The content panel inside it stays
## square, so its corners can never open a gap against the frame's inner edge.
func make_embedded_border(border_alpha: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = get_theme_stylebox("embedded_border").duplicate() as StyleBoxFlat
	style.bg_color = ThemeColor.accent_surface
	style.set_corner_radius_all(ControlSize.radius_md)
	style.border_color = Color(ThemeColor.title_color, border_alpha)
	style.set_border_width_all(ControlSize.border_xs)
	return style


## Read-only text area on the card's inset surface: padding from [Margin], accent caret and
## selection, themed scrollbars.
func style_text_edit() -> void:
	var style := StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, 0, Margin.ma_4, Margin.ma_3)
	# A read-only TextEdit paints `read_only`, not `normal`; all three get the box so any state matches.
	text_edit.add_theme_stylebox_override("normal", style)
	text_edit.add_theme_stylebox_override("focus", style.duplicate())
	text_edit.add_theme_stylebox_override("read_only", style.duplicate())
	text_edit.add_theme_color_override("background_color", ThemeColor.inset_surface)
	text_edit.add_theme_color_override("font_color", ThemeColor.title_color)
	text_edit.add_theme_color_override("font_readonly_color", ThemeColor.title_color)
	text_edit.add_theme_color_override("font_selected_color", ThemeColor.title_color)
	text_edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	text_edit.add_theme_color_override("selection_color", ThemeColor.selection_color)
	text_edit.add_theme_color_override("current_line_color", Color(ThemeColor.accent_theme_color(), 0.10))
	text_edit.add_theme_font_override("font", Fonts.regular())
	text_edit.add_theme_font_size_override("font_size", Typography.body_large_size)
	ScrollBarStyle.apply(text_edit.get_v_scroll_bar())
	ScrollBarStyle.apply(text_edit.get_h_scroll_bar())
	pass


## Open a centered read-only window. Width/height are percent of the screen (1–100).
## [param i18n_title] and [param i18n_text] may be translation keys; text without a registered
## translation is displayed unchanged.
## Example: `PopupWindow.show_window("Full view", body)`
static func show_window(i18n_title: String, i18n_text: String, width_percent: int = 70, height_percent: int = 80) -> void:
	var window := PopupWindow.new()
	window.title = I18n.t(i18n_title)
	gdf.gdf_node.add_child(window)
	# Size against the root viewport; this Window is itself a Viewport.
	var viewport := gdf.gdf_node.get_tree().root.get_visible_rect().size
	window.size = Vector2i(
		int(viewport.x * clampf(width_percent, 1.0, 100.0) / 100.0),
		int(viewport.y * clampf(height_percent, 1.0, 100.0) / 100.0),
	)
	window.set_body(I18n.t(i18n_text))
	window.popup_centered()
	# Keep keyboard navigation inside the popup instead of the previously focused
	# control in the parent window.
	window.text_edit.grab_focus()
	pass


func set_body(text: String) -> void:
	text_edit.text = text
	text_edit.scroll_vertical = text_edit.get_line_count()
	pass


func _notification(what: int) -> void:
	# Clicking outside moves focus back to the main window.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and visible:
		queue_free()
	pass


func on_close_requested() -> void:
	queue_free()
	pass


func on_window_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		queue_free()
		set_input_as_handled()
	pass
