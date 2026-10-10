class_name ThemeColorSelect
extends RefCounted

## Circular toolbar button with an SVG paintbrush icon and ColorPicker popup.

const BRUSH_ICON_PATH: String = "res://agent/asset/image/icon/brush.svg"
const SVG_HANDLE_COLOR: String = "#8B949E"
const SVG_ACCENT_COLOR: String = "#2DD4BF"
const SVG_FERRULE_COLOR: String = "#A3AAB4"

var button: Button
var popup: PopupPanel
var color_picker: ColorPicker


func setup(p_button: Button) -> void:
	button = p_button
	build_popup()
	button.text = ""
	button.pressed.connect(on_pressed)
	button.mouse_entered.connect(on_mouse_entered)
	button.mouse_exited.connect(on_mouse_exited)
	gdf.events.theme_changed.connect(on_ui_theme_changed)
	gdf.events.theme_color_changed.connect(on_ui_theme_changed)
	gdf.events.locale_changed.connect(apply_theme)
	on_ui_theme_changed()
	pass


func on_ui_theme_changed() -> void:
	color_picker.set_block_signals(true)
	color_picker.color = ThemeColor.theme_color
	color_picker.set_block_signals(false)
	apply_theme()
	pass


func build_popup() -> void:
	popup = PopupPanel.new()
	color_picker = ColorPicker.new()
	color_picker.edit_alpha = true
	color_picker.color = ThemeColor.theme_color
	color_picker.custom_minimum_size = Vector2(300, 320)
	color_picker.color_changed.connect(on_picker_color_changed)
	popup.add_child(color_picker)
	button.add_child(popup)
	pass


func apply_theme() -> void:
	AgentToolbarButton.style_round(button, I18n.t("agent.toolbar.theme_color"))
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	update_icon(button.is_hovered())
	pass


func update_icon(hovered: bool) -> void:
	var theme_color: Color = ThemeColor.accent_theme_color()
	var handle: Color = ColorBase.secondary_text
	if hovered:
		theme_color = theme_color.lightened(0.10)
		handle = ColorBase.primary_text
	button.icon = make_brush_icon(theme_color, handle)
	pass


func make_brush_icon(theme_color: Color, handle: Color) -> ImageTexture:
	var svg: String = FileAccess.get_file_as_string(BRUSH_ICON_PATH)
	svg = svg.replace(SVG_HANDLE_COLOR, "#" + handle.to_html(false))
	svg = svg.replace(SVG_ACCENT_COLOR, "#" + theme_color.to_html(false))
	svg = svg.replace(SVG_FERRULE_COLOR, "#" + handle.lightened(0.14).to_html(false))
	var image: Image = Image.new()
	if image.load_svg_from_string(svg, 2.0) != OK:
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)


func on_pressed() -> void:
	color_picker.color = ThemeColor.theme_color
	var anchor: Vector2 = button.global_position + Vector2(0.0, button.size.y + 6.0)
	popup.position = Vector2i(int(anchor.x - 140.0), int(anchor.y))
	popup.popup()
	pass


func on_picker_color_changed(new_color: Color) -> void:
	ThemeColor.set_theme_color(new_color)
	pass


func on_mouse_entered() -> void:
	update_icon(true)
	pass


func on_mouse_exited() -> void:
	update_icon(false)
	pass
