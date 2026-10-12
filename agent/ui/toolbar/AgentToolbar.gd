class_name AgentToolbar
extends RefCounted

## Top toolbar — panel chrome, GAI logo, and workspace path button theme.

var toolbar_panel: PanelContainer
var logo_label: Label
var project_button: Button


func setup(
	p_toolbar_panel: PanelContainer,
	p_logo_label: Label,
	p_project_button: Button
) -> void:
	toolbar_panel = p_toolbar_panel
	logo_label = p_logo_label
	project_button = p_project_button
	gdf.events.theme_changed.connect(apply_theme)
	apply_theme()
	pass


func apply_theme() -> void:
	toolbar_panel.add_theme_stylebox_override("panel", build_toolbar_style())
	toolbar_panel.queue_redraw()
	apply_logo_theme()
	project_button.add_theme_color_override("font_color", Colors.secondary_text)
	project_button.add_theme_color_override("font_hover_color", Colors.primary_text)
	project_button.add_theme_color_override("font_pressed_color", Colors.primary_text)
	pass


## GAI wordmark on the far left of the toolbar row.
func apply_logo_theme() -> void:
	var theme_color: Color = ThemeColor.accent_theme_color()
	var logo_font: FontVariation = FontVariation.new()
	logo_font.base_font = Fonts.bold()
	logo_font.spacing_glyph = Typography.letter_spacing_lg
	logo_label.text = "GAI"
	logo_label.tooltip_text = "GAI Code Agent"
	logo_label.add_theme_font_override("font", logo_font)
	logo_label.add_theme_font_size_override("font_size", Typography.title_medium_size)
	logo_label.add_theme_color_override("font_color", theme_color if ThemeColor.is_dark_theme() else theme_color.darkened(0.08))
	pass


func build_toolbar_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Colors.deep_surface
	style.border_color = Colors.subtle_border
	style.content_margin_left = Margin.ma_3
	style.set_border_width(SIDE_BOTTOM, ControlSize.border_xs)
	if ThemeColor.is_light_theme():
		style.set_border_width(SIDE_TOP, ControlSize.border_xs)
	return style
