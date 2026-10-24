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
extends CommonWindow

var text_edit: TextEdit


func _init() -> void:
	super()
	text_edit = TextEdit.new()
	text_edit.editable = false
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(text_edit)
	apply_theme()
	pass


## Paint the popup for the current theme; safe to run again on every theme or accent change.
func apply_theme() -> void:
	super()
	style_text_edit()
	pass


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


## Center, apply embedded-window font oversampling, then focus the text area.
func present_centered(width_percent: int = 70, height_percent: int = 80) -> void:
	super(width_percent, height_percent)
	# Keep keyboard navigation inside the popup instead of the previously focused
	# control in the parent window.
	text_edit.grab_focus()
	pass


func set_body(text: String) -> void:
	text_edit.text = text
	text_edit.scroll_vertical = text_edit.get_line_count()
	pass


####################################################################################################
# Static methods



## Open a centered read-only window. Width/height are percent of the screen (1–100).
## [param i18n_title] and [param i18n_text] may be translation keys; text without a registered
## translation is displayed unchanged.
## Example: `PopupWindow.show_window("Full view", body)`
static func show_window(i18n_title: String, i18n_text: String, width_percent: int = 70, height_percent: int = 80) -> void:
	var window := PopupWindow.new()
	window.title = I18n.t(i18n_title)
	gdf.gdf_node.add_child(window)
	window.set_body(I18n.t(i18n_text))
	window.present_centered(width_percent, height_percent)
	pass
