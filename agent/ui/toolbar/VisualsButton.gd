class_name VisualsButton
extends RefCounted

## Toolbar button for selecting the visual presentation used during agent runs.

const RING_COUNT: int = 3
## Radii on the 24 px ([constant Margin.ma_6]) canvas. An even-sized canvas has its centre on a half pixel
## ((size - 1) / 2), so the radii stay half integers: an integer radius would push the rings
## one texel to the bottom right of the canvas and off centre inside the round button.
const RING_RADII: Array[float] = [2.5, 7.5, 11.5]

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
	apply_equal_icon_margins(Margin.ma_1)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", Margin.ma_6)
	button.add_theme_constant_override("icon_max_height", Margin.ma_6)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	update_popup_items()
	style_popup()
	update_icon(button.is_hovered())
	pass


func update_popup_items() -> void:
	var selected_type := AgentSetting.get_visual_type()
	popup.clear()
	popup.add_radio_check_item(I18n.t("agent.toolbar.visual_none"), VisualType.Type.NONE)
	popup.add_radio_check_item(I18n.t("agent.toolbar.visual_jarvis"), VisualType.Type.JARVIS)
	popup.add_radio_check_item(I18n.t("agent.toolbar.visual_transformer"), VisualType.Type.TRANSFORMER)
	popup.add_radio_check_item(I18n.t("agent.toolbar.visual_reasoning_tree"), VisualType.Type.REASONING_TREE)
	popup.add_radio_check_item(I18n.t("agent.toolbar.visual_tool_constellation"), VisualType.Type.TOOL_CONSTELLATION)
	popup.add_radio_check_item(I18n.t("agent.toolbar.visual_context_memory_river"), VisualType.Type.CONTEXT_MEMORY_RIVER)
	popup.add_radio_check_item(I18n.t("agent.toolbar.visual_neural_aurora"), VisualType.Type.NEURAL_AURORA)
	popup.add_radio_check_item(I18n.t("agent.toolbar.visual_semantic_black_hole"), VisualType.Type.SEMANTIC_BLACK_HOLE)
	popup.add_radio_check_item(I18n.t("agent.toolbar.visual_cyber_command_deck"), VisualType.Type.CYBER_COMMAND_DECK)
	popup.add_radio_check_item(I18n.t("agent.toolbar.visual_quantum_circuit"), VisualType.Type.QUANTUM_CIRCUIT)
	for visual_type: VisualType.Type in VisualType.Type.values():
		popup.set_item_checked(popup.get_item_index(visual_type), selected_type == visual_type)
	pass


func style_popup() -> void:
	PopupMenuStyle.apply(popup)
	pass


func apply_equal_icon_margins(margin: int) -> void:
	for state_name: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(state_name) as StyleBoxFlat
		if box == null:
			continue
		box.content_margin_left = margin
		box.content_margin_right = margin
		box.content_margin_top = margin
		box.content_margin_bottom = margin
	pass


func on_mouse_entered() -> void:
	update_icon(true)
	pass


func on_mouse_exited() -> void:
	update_icon(false)
	pass


func update_icon(hovered: bool) -> void:
	var visual_type := AgentSetting.get_visual_type()
	var icon_color: Color = ColorBase.secondary_text
	if visual_type != VisualType.Type.NONE:
		var theme_color: Color = ThemeColor.accent_theme_color()
		icon_color = theme_color if ThemeColor.is_dark_theme() else theme_color.darkened(0.15)
		if hovered:
			icon_color = icon_color.lightened(0.12)
	elif hovered:
		icon_color = ColorBase.primary_text
	button.icon = make_concentric_rings_icon(Margin.ma_6, icon_color)
	pass


func on_pressed() -> void:
	update_popup_items()
	var content_size := popup.get_contents_minimum_size()
	var popup_size := Vector2i(maxi(int(content_size.x), Margin.ma_16 * 3), int(content_size.y))
	var button_center_x := int(button.global_position.x + button.size.x * 0.5)
	var popup_position := Vector2i(button_center_x - int(popup_size.x * 0.5), int(button.global_position.y + button.size.y + Margin.ma_1))
	popup.popup(Rect2i(popup_position, popup_size))
	pass


func on_visual_selected(id: int) -> void:
	if not VisualType.is_valid(id):
		return
	var visual_type: VisualType.Type = id
	AgentSetting.set_visual_type(visual_type)
	update_popup_items()
	update_icon(button.is_hovered())
	pass


func make_concentric_rings_icon(size: int, color: Color) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center: float = (size - 1) / 2.0
	for ring_index in range(RING_COUNT):
		draw_circle_outline(img, center, RING_RADII[ring_index], color)
	return ImageTexture.create_from_image(img)


## 1 px ring: keep every texel whose centre falls inside the radius band. Drawing from the
## texel centre keeps the outline symmetric for both even and odd canvas sizes.
func draw_circle_outline(img: Image, center: float, radius: float, col: Color) -> void:
	if radius <= 0.0:
		return
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var dx: float = x - center
			var dy: float = y - center
			if absf(sqrt(dx * dx + dy * dy) - radius) <= 0.5:
				img.set_pixel(x, y, col)
	pass
