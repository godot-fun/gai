class_name AgentSettingDialog
extends RefCounted

## Settings dialog shell. Each top-level settings category owns its controls and persistence.

const DIALOG_SIZE: Vector2i = Vector2i(680, 1000)
const FIELD_LABEL_RATIO: float = 1.0
const FIELD_CONTROL_RATIO: float = 3.0
const SETTINGS_ICON_PATH: String = "res://agent/asset/image/icon/settings.svg"

var button: Button
var dialog: ConfirmationDialog
var content_panel: PanelContainer
var content_scroll: ScrollContainer
var sections: Array[SettingSection] = []
var separators: Array[HSeparator] = []


func setup(p_button: Button) -> void:
	button = p_button
	build_dialog()
	button.pressed.connect(on_button_pressed)
	button.mouse_entered.connect(on_mouse_entered)
	button.mouse_exited.connect(on_mouse_exited)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_locale)
	apply_theme()
	pass


func build_dialog() -> void:
	dialog = ConfirmationDialog.new()
	dialog.title = ""
	dialog.borderless = true
	dialog.min_size = DIALOG_SIZE
	dialog.max_size = DIALOG_SIZE
	dialog.unresizable = true
	dialog.exclusive = false
	var dialog_theme := Theme.new()
	dialog_theme.default_font = Fonts.regular()
	dialog.theme = dialog_theme
	dialog.add_theme_font_override("title_font", Fonts.regular())
	dialog.focus_exited.connect(on_dialog_focus_exited)
	dialog.visibility_changed.connect(on_dialog_visibility_changed)
	button.add_child(dialog)
	dialog.get_ok_button().hide()
	dialog.get_cancel_button().hide()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", Margin.ma_5)
	margin.add_theme_constant_override("margin_right", Margin.ma_5)
	margin.add_theme_constant_override("margin_top", Margin.ma_3)
	margin.add_theme_constant_override("margin_bottom", Margin.ma_3)
	dialog.add_child(margin)

	content_panel = PanelContainer.new()
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content_panel)
	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", Margin.ma_5)
	card_margin.add_theme_constant_override("margin_right", Margin.ma_5)
	card_margin.add_theme_constant_override("margin_top", Margin.ma_4)
	card_margin.add_theme_constant_override("margin_bottom", Margin.ma_4)
	content_panel.add_child(card_margin)
	content_scroll = ScrollContainer.new()
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_margin.add_child(content_scroll)
	var fields := VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", Margin.ma_3)
	content_scroll.add_child(fields)

	sections = [
		AppearanceSettingSection.new(),
		ConnectionSettingSection.new(),
		BehaviorSettingSection.new(),
		NotificationSettingSection.new(),
	]
	for index in range(sections.size()):
		sections[index].set_up(self, fields, dialog)
		if index < sections.size() - 1:
			add_separator(fields)
	pass


func add_heading(parent: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", Typography.title_large_size)
	parent.add_child(label)
	return label


func add_separator(parent: Container) -> void:
	var separator := HSeparator.new()
	separators.append(separator)
	parent.add_child(separator)
	pass


func make_option_row(parent: Container, separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	parent.add_child(row)
	return row


func make_label(label_text: String) -> Label:
	var label := Label.new()
	label.text = label_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", Typography.label_large_size)
	return label


func make_field_group(parent: Container) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", Margin.ma_2)
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(group)
	return group


## Builds a row with one empty container per entry in [param column_spans].
## Columns are returned from left to right using the same indexes.
func make_multi_column_row(parent: Container, column_spans: Array[float]) -> Array[HBoxContainer]:
	assert(not column_spans.is_empty())
	for span in column_spans:
		assert(span > 0.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Margin.ma_3)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var result: Array[HBoxContainer] = []
	for span in column_spans:
		var column := HBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_stretch_ratio = span
		row.add_child(column)
		result.append(column)
	return result


func add_help_label(parent: Container, help_text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Margin.ma_3)
	parent.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = FIELD_LABEL_RATIO
	row.add_child(spacer)
	var help := Label.new()
	help.text = help_text
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.size_flags_stretch_ratio = FIELD_CONTROL_RATIO
	help.add_theme_font_size_override("font_size", Typography.label_small_size)
	row.add_child(help)
	return help


func make_line_edit(placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(0, 38)
	edit.placeholder_text = placeholder
	edit.clear_button_enabled = true
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.size_flags_stretch_ratio = FIELD_CONTROL_RATIO
	return edit


func bind_auto_save(edit: LineEdit, saver: Callable) -> void:
	edit.focus_exited.connect(saver)
	edit.text_submitted.connect(func(_text: String) -> void: saver.call())
	pass


func add_check_button(parent: Container, label_text: String, enabled: bool) -> CheckButton:
	var check := CheckButton.new()
	check.text = label_text
	check.button_pressed = enabled
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_font_size_override("font_size", Typography.label_large_size)
	parent.add_child(check)
	return check


func refresh_check_button(check: CheckButton, enabled: bool) -> void:
	check.set_block_signals(true)
	check.button_pressed = enabled
	check.set_block_signals(false)
	pass


func on_button_pressed() -> void:
	for section in sections:
		section.refresh()
	dialog.popup_centered(DIALOG_SIZE)
	dialog.size = DIALOG_SIZE
	dialog.oversampling_override = DisplayScale.compute_ui_scale()
	pass


func on_dialog_visibility_changed() -> void:
	if dialog.visible:
		return
	for section in sections:
		section.save()
	pass


func on_dialog_focus_exited() -> void:
	check_dialog_focus.call_deferred()
	pass


func request_focus_check() -> void:
	check_dialog_focus.call_deferred()
	pass


func check_dialog_focus() -> void:
	if not dialog.visible:
		return
	for section in sections:
		if section.has_open_popup():
			return
	if not dialog.has_focus():
		dialog.hide()
	pass


func apply_locale() -> void:
	for section in sections:
		section.apply_locale()
	apply_theme()
	pass


func apply_theme() -> void:
	AgentToolbarButton.style_round(button, I18n.t("agent.settings.tooltip"))
	update_icon(button.is_hovered())
	ScrollBarStyle.apply(content_scroll.get_v_scroll_bar())
	style_dialog()
	for section in sections:
		section.apply_theme()
	pass


func on_mouse_entered() -> void:
	update_icon(true)
	pass


func on_mouse_exited() -> void:
	update_icon(false)
	pass


func update_icon(hovered: bool) -> void:
	var icon_color := Colors.primary_text if hovered else Colors.secondary_text
	button.icon = make_icon(icon_color)
	pass


func make_icon(color: Color) -> ImageTexture:
	var svg := FileAccess.get_file_as_string(SETTINGS_ICON_PATH)
	svg = svg.replace("#" + Color.WHITE.to_html(false), "#" + color.to_html(false))
	var image := Image.new()
	if image.load_svg_from_string(svg, 2.0) != OK:
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)


func style_dialog() -> void:
	if dialog == null:
		return
	var dialog_style := StyleBoxHelper.create_style_box_flat(ThemeColor.accent_surface)
	dialog_style.expand_margin_right = Margin.ma_1
	dialog_style.expand_margin_bottom = Margin.ma_1
	dialog_style.content_margin_bottom = Margin.ma_4
	dialog.add_theme_stylebox_override("panel", dialog_style)
	dialog.add_theme_stylebox_override("embedded_border", StyleBoxEmpty.new())
	dialog.add_theme_stylebox_override("embedded_unfocused_border", StyleBoxEmpty.new())
	dialog.add_theme_constant_override("resize_margin", Margin.ma_0)
	dialog.add_theme_constant_override("buttons_separation", Margin.ma_0)
	content_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var separator_style := StyleBoxLine.new()
	separator_style.color = ThemeColor.accent_theme_color()
	separator_style.thickness = 1
	for separator in separators:
		separator.add_theme_stylebox_override("separator", separator_style)
	pass


func style_heading(label: Label) -> void:
	label.add_theme_color_override("font_color", Colors.primary_text)
	pass


func style_field_label(label: Label) -> void:
	label.add_theme_color_override("font_color", Colors.primary_text)
	pass


func style_help_label(label: Label) -> void:
	label.add_theme_color_override("font_color", Colors.secondary_text)
	pass


func style_check_button(check: CheckButton) -> void:
	check.add_theme_color_override("font_color", Colors.primary_text)
	check.add_theme_color_override("font_hover_color", Colors.primary_text)
	check.add_theme_color_override("font_focus_color", Colors.primary_text)
	check.add_theme_color_override("font_pressed_color", Colors.primary_text)
	check.add_theme_color_override("font_hover_pressed_color", Colors.primary_text)
	check.add_theme_color_override("button_checked_color", ThemeColor.accent_theme_color())
	check.add_theme_constant_override("h_separation", Margin.ma_2)
	var empty := StyleBoxEmpty.new()
	StyleBoxHelper.apply_style_box_margin(empty, Margin.ma_0, Margin.ma_1, Margin.ma_2, Margin.ma_1)
	for state in ["normal", "disabled", "focus", "hover", "pressed", "hover_pressed"]:
		check.add_theme_stylebox_override(state, empty.duplicate())
	pass


func style_action_button(button: Button) -> void:
	ButtonStyle.apply_font_colors(button, Colors.primary_text, Colors.primary_text, Colors.primary_text, Colors.secondary_text)
	var normal := StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, ControlSize.radius_md, Margin.ma_3, Margin.ma_1,
		Color(ThemeColor.title_color, 0.10), ControlSize.border_xs)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = ThemeColor.accent_theme_color()
	ButtonStyle.apply(button, normal, hover, hover.duplicate(), normal.duplicate(), normal.duplicate())
	pass


func style_option_button(select: OptionButton) -> void:
	ButtonStyle.apply_font_colors(select, Colors.primary_text, Colors.primary_text, Colors.primary_text)
	var normal := make_input_style()
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = ThemeColor.accent_theme_color()
	select.add_theme_stylebox_override("normal", normal)
	select.add_theme_stylebox_override("hover", hover)
	select.add_theme_stylebox_override("pressed", hover.duplicate())
	select.add_theme_stylebox_override("focus", hover.duplicate())
	PopupMenuStyle.apply(select.get_popup())
	pass


func style_line_edit(edit: LineEdit) -> void:
	edit.add_theme_color_override("font_color", Colors.primary_text)
	edit.add_theme_color_override("font_placeholder_color", Colors.secondary_text.darkened(0.08))
	edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	edit.caret_blink = true
	var normal := make_input_style()
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = ThemeColor.accent_theme_color()
	focus.set_border_width_all(ControlSize.border_sm)
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_stylebox_override("read_only", normal.duplicate())
	pass


func make_input_style() -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, 7, Margin.ma_3, Margin.ma_0, Color(ThemeColor.title_color, 0.10), ControlSize.border_xs)


func style_spin_box(spin: SpinBox) -> void:
	style_line_edit(spin.get_line_edit())
	spin.add_theme_color_override("font_color", Colors.primary_text)
	spin.add_theme_color_override("font_placeholder_color", Colors.secondary_text)
	spin.add_theme_color_override("up_icon_modulate", Colors.primary_text)
	spin.add_theme_color_override("down_icon_modulate", Colors.primary_text)
	spin.add_theme_color_override("up_hover_icon_modulate", ThemeColor.accent_theme_color())
	spin.add_theme_color_override("down_hover_icon_modulate", ThemeColor.accent_theme_color())
	spin.add_theme_color_override("up_pressed_icon_modulate", ThemeColor.accent_theme_color())
	spin.add_theme_color_override("down_pressed_icon_modulate", ThemeColor.accent_theme_color())
	var normal := make_input_style()
	normal.content_margin_left = Margin.ma_0
	normal.content_margin_right = Margin.ma_0
	var hover := ButtonStyle.filled(normal, Colors.hover_surface)
	for side in ["up", "down"]:
		spin.add_theme_stylebox_override(side + "_background", normal)
		spin.add_theme_stylebox_override(side + "_background_hovered", hover)
		spin.add_theme_stylebox_override(side + "_background_pressed", hover.duplicate())
		spin.add_theme_stylebox_override(side + "_background_disabled", normal.duplicate())
	spin.add_theme_stylebox_override("field_and_buttons_separator", StyleBoxEmpty.new())
	spin.add_theme_stylebox_override("up_down_buttons_separator", StyleBoxEmpty.new())
	pass
