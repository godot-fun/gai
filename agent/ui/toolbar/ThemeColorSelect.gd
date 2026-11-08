class_name ThemeColorSelect
extends RefCounted

## Circular toolbar button with an SVG paintbrush icon and ColorPicker popup.

const BRUSH_ICON_PATH: String = "res://agent/asset/image/ui/brush.svg"

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
	gdf.events.ui_scale_changed.connect(on_ui_scale_changed)
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
	color_picker.custom_minimum_size = Vector2(ControlSize.image_md, ControlSize.image_md)
	color_picker.color_changed.connect(on_picker_color_changed)
	popup.add_child(color_picker)
	button.add_child(popup)
	pass


func on_ui_scale_changed(_scale: float) -> void:
	color_picker.custom_minimum_size = Vector2(ControlSize.image_md, ControlSize.image_md)
	apply_theme()
	pass


func apply_theme() -> void:
	AgentToolbarButton.style_round(button, I18n.t("agent.toolbar.theme_color"))
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	update_icon(button.is_hovered())
	pass


func update_icon(hovered: bool) -> void:
	var theme_color: Color = ThemeColor.accent_theme_color()
	if hovered:
		theme_color = theme_color.lightened(0.10)
	button.icon = ImageHelper.tint_svg(BRUSH_ICON_PATH, theme_color, 2.0)
	pass


func on_pressed() -> void:
	color_picker.color = ThemeColor.theme_color
	var anchor: Vector2 = button.global_position + Vector2(0.0, button.size.y + Margin.ma_2)
	popup.position = Vector2i(int(anchor.x - color_picker.custom_minimum_size.x * 0.5), int(anchor.y))
	popup.popup()
	popup.oversampling_override = DisplayScale.compute_ui_scale()
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
