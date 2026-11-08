class_name EditorButton
extends RefCounted

## Toolbar entry point for the editor window. Its button marks the start of the chat content.

var button: Button
var select_button: Button
var workspace_button: Button
var popup: PopupMenu
var available_editors: Array[EditorApplication] = []

const ARROW_ICON_PATH := "res://agent/asset/image/ui/keyboard_arrow_down.svg"
const POPUP_MIN_WIDTH: int = 220


func setup(p_button: Button, p_select_button: Button, p_workspace_button: Button) -> void:
	button = p_button
	select_button = p_select_button
	workspace_button = p_workspace_button
	build_popup()
	button.pressed.connect(on_button_pressed)
	select_button.pressed.connect(on_select_pressed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(on_locale_changed)
	apply_theme()
	update_alignment.call_deferred()
	await reload_editors()
	pass


func on_locale_changed() -> void:
	await reload_editors(true)
	pass


func on_button_pressed() -> void:
	var editor := selected_editor()
	if editor == null:
		return
	if editor.id == EditorDiscovery.BUILTIN_ID:
		EditorWindow.show_editor()
		return
	var executable := str(editor.executable)
	var arguments: PackedStringArray = editor.arguments.duplicate()
	var workspace := AgentWorkspace.get_root()
	arguments.append(workspace)
	if executable.get_extension().to_lower() == "cmd":
		arguments = PackedStringArray(["/c", executable]) + arguments
		executable = "cmd.exe"
	var process_id := OS.create_process(executable, arguments, false)
	if process_id < 0:
		Alert.alert(StringUtils.format(I18n.t("editor.launch_failed"), editor.label), Colors.error)
	pass


func apply_theme() -> void:
	var editor := selected_editor()
	var tooltip := I18n.t("editor.title") if editor == null else StringUtils.format(I18n.t("editor.open_with"), editor.label)
	AgentToolbarButton.style_round(button, tooltip)
	button.icon = null if editor == null else editor_icon(editor)
	AgentToolbarButton.style(select_button, I18n.t("editor.select_tooltip"))
	select_button.text = ""
	select_button.custom_minimum_size.x = ControlSize.xs
	select_button.add_theme_constant_override("icon_max_width", ControlSize.icon_sm)
	select_button.icon = ImageHelper.tint_svg(ARROW_ICON_PATH, Colors.secondary_text, 2.0)
	style_split_buttons()
	PopupMenuStyle.apply(popup)
	style_popup_spacing()
	update_popup_items()
	pass


func style_split_buttons() -> void:
	var main_normal := split_style(true, Colors.control_surface)
	var select_normal := split_style(false, Colors.control_surface)
	ButtonStyle.apply_style(button, main_normal,
		split_style(true, Colors.hover_surface), split_style(true, ThemeColor.selected_surface))
	ButtonStyle.apply_style(select_button, select_normal,
		split_style(false, Colors.hover_surface), split_style(false, ThemeColor.selected_surface))
	button.add_theme_stylebox_override("hover_pressed", split_style(true, ThemeColor.promote(ThemeColor.selected_surface, Weights.w_2)))
	select_button.add_theme_stylebox_override("hover_pressed", split_style(false, ThemeColor.promote(ThemeColor.selected_surface, Weights.w_2)))
	pass


func style_popup_spacing() -> void:
	popup.add_theme_constant_override("v_separation", Margin.ma_3)
	popup.add_theme_constant_override("h_separation", Margin.ma_2)
	popup.add_theme_constant_override("item_start_padding", Margin.ma_4)
	popup.add_theme_constant_override("item_end_padding", Margin.ma_4)
	var panel := StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, ControlSize.radius_lg,
		Margin.ma_2, Margin.ma_2, Color(ThemeColor.title_color, 0.10), ControlSize.border_xs)
	popup.add_theme_stylebox_override("panel", panel)
	pass


static func split_style(is_main: bool, background: Color) -> StyleBoxFlat:
	var style := StyleBoxHelper.create_style_box_flat(background, 0, Margin.ma_1, Margin.ma_1,
		Colors.subtle_border, ControlSize.border_xs)
	style.corner_radius_top_left = ControlSize.radius_md if is_main else 0
	style.corner_radius_bottom_left = ControlSize.radius_md if is_main else 0
	style.corner_radius_top_right = 0 if is_main else ControlSize.radius_md
	style.corner_radius_bottom_right = 0 if is_main else ControlSize.radius_md
	if is_main:
		style.border_width_right = 0
	return style


func build_popup() -> void:
	popup = PopupMenu.new()
	popup.id_pressed.connect(on_editor_selected)
	select_button.add_child(popup)
	pass


func reload_editors(invalidate_cache: bool = false) -> void:
	button.disabled = true
	select_button.disabled = true
	if invalidate_cache:
		EditorDiscovery.invalidate_cache()
	var discovered: Variant = await ExecutorHelper.async_execute_pooled(EditorDiscovery.discover)
	var editors := discovered as Array[EditorApplication]
	available_editors = editors if editors != null else []
	var selected_id := AgentSetting.get_workspace_editor()
	if EditorDiscovery.find_editor(available_editors, selected_id) == null:
		AgentSetting.set_workspace_editor(EditorDiscovery.BUILTIN_ID)
	button.disabled = available_editors.is_empty()
	select_button.disabled = available_editors.is_empty()
	apply_theme()
	update_alignment.call_deferred()
	pass


func selected_editor() -> EditorApplication:
	var selected := EditorDiscovery.find_editor(available_editors, AgentSetting.get_workspace_editor())
	return selected if selected != null else (available_editors[0] if not available_editors.is_empty() else null)


func editor_icon(editor: EditorApplication) -> Texture2D:
	var icon_path := editor.icon_path
	var texture: Texture2D
	if icon_path.get_extension().to_lower() == "ico":
		texture = ImageHelper.load_ico(icon_path, ControlSize.icon_md)
	else:
		texture = ImageHelper.tint_svg(icon_path, Colors.secondary_text, 1.0)
	return normalize_icon(texture, ControlSize.icon_md)


static func normalize_icon(texture: Texture2D, target_size: int) -> ImageTexture:
	if texture == null:
		return ImageTexture.new()
	var source := texture.get_image()
	if source == null or source.is_empty():
		return ImageTexture.new()
	var source_size := source.get_size()
	var scale := minf(float(target_size) / source_size.x, float(target_size) / source_size.y)
	var scaled_size := Vector2i(maxi(1, roundi(source_size.x * scale)), maxi(1, roundi(source_size.y * scale)))
	source.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create_empty(target_size, target_size, false, Image.FORMAT_RGBA8)
	var offset := Vector2i((target_size - scaled_size.x) / 2, (target_size - scaled_size.y) / 2)
	canvas.blit_rect(source, Rect2i(Vector2i.ZERO, scaled_size), offset)
	return ImageTexture.create_from_image(canvas)


func update_popup_items() -> void:
	popup.clear()
	var selected_id := AgentSetting.get_workspace_editor()
	for index in available_editors.size():
		var editor := available_editors[index]
		popup.add_icon_radio_check_item(editor_icon(editor), editor.label, index)
		popup.set_item_checked(index, editor.id == selected_id)
	pass


func on_select_pressed() -> void:
	update_popup_items()
	var content_size := popup.get_contents_minimum_size()
	var popup_size := Vector2i(maxi(int(content_size.x), POPUP_MIN_WIDTH), int(content_size.y))
	var popup_position := Vector2i(int(button.global_position.x), int(select_button.global_position.y + select_button.size.y + Margin.ma_1))
	popup.popup(Rect2i(popup_position, popup_size))
	popup.oversampling_override = DisplayScale.compute_ui_scale()
	pass


func on_editor_selected(index: int) -> void:
	if index < 0 or index >= available_editors.size():
		return
	AgentSetting.set_workspace_editor(available_editors[index].id)
	apply_theme()
	pass


## Places this button at the shared chat-content boundary after toolbar layout settles.
func update_alignment() -> void:
	var offset := AgentLayout.chat_content_left - button.global_position.x
	workspace_button.custom_minimum_size.x = maxf(0.0, workspace_button.size.x + offset)
	pass
