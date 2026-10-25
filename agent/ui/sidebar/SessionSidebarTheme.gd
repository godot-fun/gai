class_name SessionSidebarTheme
extends Object

## Every stylebox / color override the sidebar uses. All builders read the live palette, so a
## theme switch only has to re-apply them (see [method AgentSessionSidebar.apply_theme]).

# ---------------------------------------------------------------------------
# Sidebar shell
# ---------------------------------------------------------------------------

## Sidebar background plus the hairline against the chat area.
static func sidebar_panel() -> StyleBoxFlat:
	var style := StyleBoxHelper.create_style_box_flat(Colors.chrome_surface)
	style.border_color = Colors.muted_border
	style.set_border_width(SIDE_RIGHT, ControlSize.border_xs)
	return style


static func pinned_separator() -> StyleBoxLine:
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = ThemeColor.alpha_theme_color(0.42 if ThemeColor.is_dark_theme() else 0.32)
	line.grow_begin = 2
	line.grow_end = 2
	line.thickness = 1
	return line


## "New Agent" outlined in the theme color, filled while hovered / pressed.
static func apply_new_session_button(button: Button) -> void:
	var theme_color: Color = ThemeColor.accent_theme_color()
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	ButtonStyle.apply_font_colors(button, theme_color, ThemeColor.promote(theme_color, Weights.w_2), ThemeColor.demote(theme_color, Weights.w_2), Colors.secondary_text)

	var border := ThemeColor.alpha_theme_color(0.55 if ThemeColor.is_dark_theme() else 0.45)
	var normal := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, ControlSize.radius_md, Margin.ma_3, Margin.ma_2, border, ControlSize.border_xs)
	ButtonStyle.apply_style(button, normal,
		StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.selected_surface, ThemeColor.alpha_theme_color(0.85)),
		StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.promote(ThemeColor.selected_surface, Weights.w_2), theme_color))
	pass


# ---------------------------------------------------------------------------
# Chat rows
# ---------------------------------------------------------------------------

## Row background selected beats hovered, transparent otherwise.
static func row(selected: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, ControlSize.radius_md)
	StyleBoxHelper.apply_style_box_margin(style, Margin.ma_3, Margin.ma_1, Margin.ma_1, Margin.ma_1)
	if selected:
		style.bg_color = ThemeColor.selected_surface
	elif hovered:
		style.bg_color = Colors.hover_surface
	return style


## Title / close button colors for the current row state.
static func apply_row_colors(title_button: Button, delete_button: Button, selected: bool, hovered: bool) -> void:
	var text_color: Color = Colors.primary_text if selected or hovered else Colors.secondary_text
	title_button.add_theme_font_size_override("font_size", Typography.title_medium_size)
	title_button.add_theme_color_override("font_color", text_color)
	title_button.add_theme_color_override("font_hover_color", text_color)
	title_button.add_theme_color_override("font_pressed_color", text_color)
	delete_button.add_theme_color_override("font_color", Colors.secondary_text)
	delete_button.add_theme_color_override("font_hover_color", Colors.error)
	delete_button.add_theme_color_override("font_pressed_color", Colors.error)
	pass


## Floating row copy that follows the cursor while dragging.
static func drag_ghost() -> StyleBoxFlat:
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
	edit.add_theme_color_override("font_color", Colors.primary_text)
	edit.add_theme_color_override("font_placeholder_color", Colors.secondary_text)
	edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	edit.add_theme_color_override("font_selected_color", ThemeColor.title_color)
	edit.add_theme_color_override("selection_color", ThemeColor.selection_color)
	edit.caret_blink = true
	var field_style: StyleBoxFlat = rename_field()
	edit.add_theme_stylebox_override("normal", field_style)
	edit.add_theme_stylebox_override("focus", field_style)
	pass


static func rename_field() -> StyleBoxFlat:
	var border := ThemeColor.alpha_theme_color(0.75 if ThemeColor.is_dark_theme() else 0.55)
	return StyleBoxHelper.create_style_box_flat(Colors.surface, ControlSize.radius_sm, Margin.ma_1, Margin.ma_0, border, ControlSize.border_xs)


## Mirrors a resolved font onto another control (rename field, drag ghost).
static func copy_font(target: Control, source: Control) -> void:
	target.add_theme_font_override("font", source.get_theme_font("font"))
	target.add_theme_font_size_override("font_size", source.get_theme_font_size("font_size"))
	pass
