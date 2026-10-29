class_name VisualsButton
extends RefCounted

## Toolbar button for selecting the visual presentation used during agent runs.

const SPARKLE_ICON_PATH: String = "res://agent/asset/image/icon/sparkle.svg"
const POPUP_MIN_WIDTH: int = 192

var button: Button
var popup: PopupMenu


func setup(p_button: Button) -> void:
	button = p_button
	build_popup()
	button.text = ""
	button.toggle_mode = false
	button.pressed.connect(on_pressed)
	button.mouse_entered.connect(on_mouse_entered)
	button.mouse_exited.connect(on_mouse_exited)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_theme)
	apply_theme()
	pass


func build_popup() -> void:
	popup = PopupMenu.new()
	popup.id_pressed.connect(on_visual_selected)
	button.add_child(popup)
	pass


func apply_theme() -> void:
	AgentToolbarButton.style_round(button, I18n.t("agent.toolbar.visuals"))
	button.expand_icon = false
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	update_popup_items()
	style_popup()
	update_icon(button.is_hovered())
	pass


func update_popup_items() -> void:
	var selected_type := AgentSetting.get_visual_type()
	popup.clear()
	add_visual_item("NONE", selected_type)
	add_visual_item("RANDOM", selected_type)
	for visual_name: String in VisualControl.Type:
		if visual_name == "NONE" or visual_name == "RANDOM":
			continue
		add_visual_item(visual_name, selected_type)
	pass


func add_visual_item(visual_name: String, selected_type: int) -> void:
	var visual_type: VisualControl.Type = VisualControl.Type[visual_name]
	var translation_key := "agent.toolbar.visual_" + visual_name.to_lower()
	popup.add_radio_check_item(I18n.t(translation_key), visual_type)
	popup.set_item_checked(popup.item_count - 1, selected_type == visual_type)
	pass


func style_popup() -> void:
	PopupMenuStyle.apply(popup)
	style_popup_scrollbar()
	pass


func style_popup_scrollbar() -> void:
	var panel := popup.get_child(0, true) as PanelContainer
	if panel == null:
		return
	var scroll_container := panel.get_child(0, true) as ScrollContainer
	if scroll_container == null:
		return
	ScrollBarStyle.apply_custom(scroll_container.get_v_scroll_bar(), ScrollBarStyle.Thickness.MD,
		ThemeColor.body_color, ThemeColor.promote(ThemeColor.theme_color, Weights.w_7), ThemeColor.promote(ThemeColor.theme_color, Weights.w_4), true)
	pass


func on_mouse_entered() -> void:
	update_icon(true)
	pass


func on_mouse_exited() -> void:
	update_icon(false)
	pass


func update_icon(hovered: bool) -> void:
	var visual_type := AgentSetting.get_visual_type()
	var icon_color: Color = Colors.secondary_text
	if visual_type != VisualControl.Type.NONE:
		icon_color = ThemeColor.accent_theme_color()
		if hovered:
			icon_color = icon_color.lightened(0.12)
	elif hovered:
		icon_color = Colors.primary_text
	button.icon = make_sparkle_icon(icon_color)
	pass


func on_pressed() -> void:
	update_popup_items()
	var content_size := popup.get_contents_minimum_size()
	var popup_size := Vector2i(maxi(int(content_size.x), POPUP_MIN_WIDTH), int(content_size.y))
	var button_center_x := int(button.global_position.x + button.size.x * 0.5)
	var popup_position := Vector2i(button_center_x - int(popup_size.x * 0.5), int(button.global_position.y + button.size.y + Margin.ma_1))
	popup.popup(Rect2i(popup_position, popup_size))
	popup.oversampling_override = DisplayScale.compute_ui_scale()
	pass


func on_visual_selected(id: int) -> void:
	AgentSetting.set_visual_type(id)
	update_popup_items()
	update_icon(button.is_hovered())
	pass


func make_sparkle_icon(color: Color) -> ImageTexture:
	var svg: String = FileAccess.get_file_as_string(SPARKLE_ICON_PATH)
	svg = svg.replace("#" + Color.WHITE.to_html(false), "#" + color.to_html(false))
	var image := Image.new()
	if image.load_svg_from_string(svg, 2.0) != OK:
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)
