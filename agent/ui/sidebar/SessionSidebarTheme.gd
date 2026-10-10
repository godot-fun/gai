class_name SessionSidebarTheme
extends Object

## Every stylebox / color override the sidebar uses. All builders read the live palette, so a
## theme switch only has to re-apply them (see [method AgentSessionSidebar.apply_theme]).

const ROW_CORNER_RADIUS: int = 6
const RENAME_CORNER_RADIUS: int = 5


# ---------------------------------------------------------------------------
# Sidebar shell
# ---------------------------------------------------------------------------

## Sidebar background plus the hairline against the chat area.
static func sidebar_panel() -> StyleBoxFlat:
	var style := StyleBoxHelper.create_style_box_flat(ColorBase.chrome_surface)
	style.border_color = ColorBase.muted_border
	style.set_border_width(SIDE_RIGHT, ControlSize.border_xs)
	return style


static func pinned_separator() -> StyleBoxLine:
	var theme_color: Color = ThemeColor.accent_theme_color()
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = ThemeColor.alpha_theme_color(0.42 if ThemeColor.is_dark_theme() else 0.32)
	line.grow_begin = 2
	line.grow_end = 2
	line.thickness = 1
	return line


## "New Agent" 鈥?outlined in the theme color, filled while hovered / pressed.
static func apply_new_session_button(button: Button) -> void:
	var theme_color: Color = ThemeColor.accent_theme_color()
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	ButtonStyle.apply_font_colors(button, theme_color, ButtonStyle.hover_color(theme_color, 0.08), ButtonStyle.press_color(theme_color, 0.06), ColorBase.secondary_text)

	var border := ThemeColor.alpha_theme_color(0.55 if ThemeColor.is_dark_theme() else 0.45)
	var normal := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, ROW_CORNER_RADIUS, Margin.ma_3, Margin.ma_2, border, ControlSize.border_xs)
	ButtonStyle.apply(button, normal,
		ButtonStyle.filled(normal, ThemeColor.selected_surface, ThemeColor.alpha_theme_color(0.85)),
		ButtonStyle.filled(normal, ButtonStyle.hover_color(ThemeColor.selected_surface, 0.06), theme_color))
	pass


# ---------------------------------------------------------------------------
# Chat rows
# ---------------------------------------------------------------------------

## Row background 鈥?selected beats hovered, transparent otherwise.
static func row(selected: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, ROW_CORNER_RADIUS)
	StyleBoxHelper.apply_style_box_margin(style, Margin.ma_3, Margin.ma_1, Margin.ma_1, Margin.ma_1)
	if selected:
		style.bg_color = ThemeColor.selected_surface
	elif hovered:
		style.bg_color = ColorBase.hover_surface
	return style


## Title / close button colors for the current row state.
static func apply_row_colors(title_button: Button, delete_button: Button, selected: bool, hovered: bool) -> void:
	var text_color: Color = ColorBase.primary_text if selected or hovered else ColorBase.secondary_text
	title_button.add_theme_font_size_override("font_size", Typography.title_medium_size)
	title_button.add_theme_color_override("font_color", text_color)
	title_button.add_theme_color_override("font_hover_color", text_color)
	title_button.add_theme_color_override("font_pressed_color", text_color)
	delete_button.add_theme_color_override("font_color", ColorBase.secondary_text)
	delete_button.add_theme_color_override("font_hover_color", ColorBase.error)
	delete_button.add_theme_color_override("font_pressed_color", ColorBase.error)
	pass


## Floating row copy that follows the cursor while dragging.
static func drag_ghost() -> StyleBoxFlat:
	var theme_color: Color = ThemeColor.accent_theme_color()
	var style: StyleBoxFlat = row(false, false)
	style.bg_color = ThemeColor.selected_surface
	style.border_color = ThemeColor.alpha_theme_color(0.9 if ThemeColor.is_dark_theme() else 0.75)
	style.set_border_width_all(ControlSize.border_xs)
	style.shadow_color = Color(0, 0, 0, 0.35 if ThemeColor.is_dark_theme() else 0.18)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style


# ---------------------------------------------------------------------------
# Inline rename
# ---------------------------------------------------------------------------

## The field takes over the title's slot, so it mirrors the title's resolved font.
static func apply_rename_field(edit: LineEdit, title_button: Button) -> void:
	copy_font(edit, title_button)
	edit.add_theme_color_override("font_color", ColorBase.primary_text)
	edit.add_theme_color_override("font_placeholder_color", ColorBase.secondary_text)
	edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	edit.add_theme_color_override("font_selected_color", ThemeColor.title_color)
	edit.add_theme_color_override("selection_color", ThemeColor.selection_color)
	edit.caret_blink = true
	var field_style: StyleBoxFlat = rename_field()
	edit.add_theme_stylebox_override("normal", field_style)
	edit.add_theme_stylebox_override("focus", field_style)
	pass


static func rename_field() -> StyleBoxFlat:
	var theme_color: Color = ThemeColor.accent_theme_color()
	var border := ThemeColor.alpha_theme_color(0.75 if ThemeColor.is_dark_theme() else 0.55)
	return StyleBoxHelper.create_style_box_flat(ColorBase.surface, RENAME_CORNER_RADIUS, Margin.ma_1, Margin.ma_0, border, ControlSize.border_xs)


## Mirrors a resolved font onto another control (rename field, drag ghost).
static func copy_font(target: Control, source: Control) -> void:
	target.add_theme_font_override("font", source.get_theme_font("font"))
	target.add_theme_font_size_override("font_size", source.get_theme_font_size("font_size"))
	pass
