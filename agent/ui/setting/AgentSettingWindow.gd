class_name AgentSettingWindow
extends CommonWindow

## Settings window shell. Each top-level settings category owns its controls and persistence.

const FIELD_LABEL_RATIO: float = 1.0
const FIELD_CONTROL_RATIO: float = 5.0
const GROUP_NAME: StringName = &"agent_setting_window"
var sections: Array[SettingSection] = []
var separators: Array[HSeparator] = []


func _init() -> void:
	super()
	add_to_group(GROUP_NAME)
	exclusive = false
	gdf.events.locale_changed.connect(apply_locale)
	build_window()
	apply_locale()
	pass


func build_window() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", Margin.ma_5)
	margin.add_theme_constant_override("margin_right", Margin.ma_5)
	margin.add_theme_constant_override("margin_top", Margin.ma_3)
	margin.add_theme_constant_override("margin_bottom", Margin.ma_3)
	container.add_child(margin)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", Margin.ma_5)
	card_margin.add_theme_constant_override("margin_right", Margin.ma_5)
	card_margin.add_theme_constant_override("margin_top", Margin.ma_4)
	card_margin.add_theme_constant_override("margin_bottom", Margin.ma_4)
	card_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(card_margin)
	var fields := VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", Margin.ma_3)
	card_margin.add_child(fields)

	sections = [
		AppearanceSettingSection.new(),
		ConnectionSettingSection.new(),
		BehaviorSettingSection.new(),
		NotificationSettingSection.new(),
	]
	for index in range(sections.size()):
		sections[index].set_up(self, fields, self)
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


## Builds a settings row on the shared 1:5 grid.
## Returned slot indices: 2-col [0] label, [1] control; 4-col [0] label, [1–3] control thirds; 6-col [0] label, [1–5] control fifths.
func make_setting_row(parent: Container, column_count: int = 2) -> Array[HBoxContainer]:
	assert(column_count == 2 or column_count == 4 or column_count == 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Margin.ma_3)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	# Column 1 — label band (1 part of the 1:5 grid).
	var label_column := HBoxContainer.new()
	label_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_column.size_flags_stretch_ratio = FIELD_LABEL_RATIO
	row.add_child(label_column)
	# Columns 2–6 — control band (5 parts); subdivided when column_count is 4 or 6.
	var control_column := HBoxContainer.new()
	control_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_column.size_flags_stretch_ratio = FIELD_CONTROL_RATIO
	row.add_child(control_column)
	if column_count == 2:
		var two_columns: Array[HBoxContainer] = [label_column, control_column]
		return two_columns
	var control_slot_count := 3 if column_count == 4 else 5
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", Margin.ma_3)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_column.add_child(controls)
	var columns: Array[HBoxContainer] = [label_column]
	for _slot_index in range(control_slot_count):
		# Control sub-column: index 1..3 (4-col row) or 1..5 (6-col row).
		var column := HBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.add_child(column)
		columns.append(column)
	return columns


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


func open() -> void:
	for section in sections:
		section.refresh()
	present_centered(30, 70)
	pass


func on_close_requested() -> void:
	for section in sections:
		section.save()
	queue_free()
	pass


func dismiss_on_focus_out() -> bool:
	return false


func apply_locale() -> void:
	title = I18n.t("agent.settings.tooltip")
	for section in sections:
		section.apply_locale()
	apply_theme()
	pass


func apply_theme() -> void:
	super()
	style_content()
	for section in sections:
		section.apply_theme()
	pass


## Match [PopupWindow]'s themed content treatment: CommonWindow paints the shared frame, while
## this window puts settings controls on the inset reading surface.
func style_content() -> void:
	container.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface))
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


func style_action_button(button: Button) -> void:
	ButtonStyle.apply_font_colors(button, Colors.primary_text, Colors.primary_text, Colors.primary_text, Colors.secondary_text)
	var normal := StyleBoxHelper.create_style_box_flat(ThemeColor.card_surface, ControlSize.radius_md, Margin.ma_3, Margin.ma_1,
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
	select.get_popup().add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(
		ThemeColor.card_surface, ControlSize.radius_lg, Margin.ma_1, Margin.ma_1,
		Color(ThemeColor.title_color, 0.10), ControlSize.border_xs))
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
	LineEditStyle.apply_clear_button(edit)
	pass


func make_input_style() -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(ThemeColor.card_surface, 7, Margin.ma_3, Margin.ma_0, Color(ThemeColor.title_color, 0.10), ControlSize.border_xs)


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


####################################################################################################
# Static methods


static func is_open() -> bool:
	return gdf.is_ready() and not gdf.gdf_node.get_tree().get_nodes_in_group(GROUP_NAME).is_empty()


static func show_setting() -> void:
	if is_open():
		return
	var window := AgentSettingWindow.new()
	gdf.gdf_node.add_child(window)
	window.open()
	pass
