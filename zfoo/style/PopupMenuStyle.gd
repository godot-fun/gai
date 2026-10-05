class_name PopupMenuStyle
extends Object

## Shared theme-aware styling for option and radio popup menus.

const RADIO_ICON_SIZE: int = Margin.ma_4


static func apply(popup: PopupMenu) -> void:
	popup.add_theme_font_override("font", Fonts.regular())
	popup.add_theme_color_override("font_color", ColorBase.primary_text)
	popup.add_theme_color_override("font_hover_color", ColorBase.primary_text)
	popup.add_theme_color_override("font_accelerator_color", ColorBase.secondary_text)
	popup.add_theme_color_override("font_disabled_color", ColorBase.secondary_text)
	popup.add_theme_color_override("font_separator_color", ColorBase.secondary_text)
	popup.add_theme_font_size_override("font_size", Typography.label_large_size)
	popup.add_theme_constant_override("v_separation", Margin.ma_2)
	popup.add_theme_constant_override("item_start_padding", Margin.ma_3)
	popup.add_theme_constant_override("item_end_padding", Margin.ma_3)
	popup.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, ControlSize.radius_lg, Margin.ma_1, Margin.ma_1, Color(ThemeColor.title_color, 0.10), ControlSize.border_xs))
	popup.add_theme_stylebox_override("hover", StyleBoxHelper.create_style_box_flat(ThemeColor.selected_surface, ControlSize.radius_md, Margin.ma_2, 0))
	popup.add_theme_icon_override("radio_checked", make_radio_icon(true, ThemeColor.accent_theme_color()))
	popup.add_theme_icon_override("radio_unchecked", make_radio_icon(false, ColorBase.secondary_text))
	pass


static func make_radio_icon(checked: bool, color: Color) -> ImageTexture:
	var center := RADIO_ICON_SIZE * 0.5
	var outer_radius := center - ControlSize.border_sm
	var inner_radius := center * 0.375
	var color_html := color.to_html(false)
	var inner_circle_template := '<circle cx="{}" cy="{}" r="{}" fill="#{}"/>'
	var inner_circle := StringUtils.format(inner_circle_template, center, center, inner_radius, color_html) if checked else ""
	var svg_template := (
		'<svg xmlns="http://www.w3.org/2000/svg" width="{}" height="{}" viewBox="0 0 {} {}">'
		+ '<circle cx="{}" cy="{}" r="{}" fill="none" stroke="#{}" stroke-width="{}"/>'
		+ "{}"
		+ "</svg>"
	)
	var svg := StringUtils.format(svg_template, RADIO_ICON_SIZE, RADIO_ICON_SIZE, RADIO_ICON_SIZE, RADIO_ICON_SIZE,
		center, center, outer_radius, color_html, ControlSize.border_sm, inner_circle)
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)
