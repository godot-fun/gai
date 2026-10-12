class_name SkillNode
extends GraphNode

const NODE_MIN_WIDTH: int = 420
const LABEL_WIDTH: int = 88
const FIELD_MIN_WIDTH: int = 240

var node_id: String = ""
var node_def: GraphNodeDef
var input_fields: Dictionary[String, LineEdit] = {}
var input_slot_indices: Dictionary[String, int] = {}
var output_slot_indices: Dictionary[String, int] = {}


func setup(p_node_id: String, p_node_def: GraphNodeDef) -> void:
	node_id = p_node_id
	node_def = p_node_def
	title = node_def.display_label()
	resizable = true
	build_node()
	custom_minimum_size.x = NODE_MIN_WIDTH
	apply_theme(false)
	pass


func build_node() -> void:
	pass


func add_input_port_row(port: PortDef, _allow_manual: bool = true) -> int:
	var slot_index: int = get_child_count()
	var row: HBoxContainer = create_connect_only_row(port.display_label(node_def.catalog_id()))
	add_child(row)
	input_slot_indices[port.id] = slot_index
	configure_slot(
		slot_index,
		true,
		port.port_type,
		port_color(port.port_type),
		false,
		0,
		ThemeColor.title_color,
	)
	return slot_index


func add_output_port_row(port: PortDef) -> int:
	var slot_index: int = get_child_count()
	var row: Label = Label.new()
	row.text = tr("workflow.node.output_arrow").format([port.display_label(node_def.catalog_id())], StringUtils.EMPTY_JSON)
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	style_label(row, Colors.secondary_text)
	add_child(row)

	output_slot_indices[port.id] = slot_index
	configure_slot(
		slot_index,
		false,
		0,
		ThemeColor.title_color,
		true,
		port.port_type,
		port_color(port.port_type),
	)
	return slot_index


func create_connect_only_row(label_text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = LABEL_WIDTH
	style_label(label, Colors.primary_text)
	row.add_child(label)

	var hint: Label = Label.new()
	hint.text = tr("workflow.node.connect_upstream")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_label(hint, Colors.secondary_text)
	row.add_child(hint)

	return row


func create_text_row(port_id: String, label_text: String, placeholder: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = LABEL_WIDTH
	style_label(label, Colors.primary_text)
	row.add_child(label)

	var field: LineEdit = LineEdit.new()
	field.custom_minimum_size.x = FIELD_MIN_WIDTH
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.placeholder_text = placeholder
	style_field(field)
	row.add_child(field)
	input_fields[port_id] = field

	return row


func configure_slot(
	slot_index: int,
	left_enabled: bool,
	left_type: int,
	left_color: Color,
	right_enabled: bool,
	right_type: int,
	right_color: Color,
) -> void:
	set_slot(slot_index, left_enabled, left_type, left_color, right_enabled, right_type, right_color)
	pass


func port_color(port_type: int) -> Color:
	match port_type:
		PortDef.TYPE_AUDIO:
			return FileColors.audio_color
		PortDef.TYPE_IMAGE:
			return FileColors.image_color
		PortDef.TYPE_VIDEO:
			return FileColors.video_color
		PortDef.TYPE_TEXT:
			return FileColors.text_color
		PortDef.TYPE_FOLDER:
			return FileColors.folder_color
		_:
			return ThemeColor.body_color


func get_manual_input(port_id: String) -> String:
	if not input_fields.has(port_id):
		return ""
	var field: LineEdit = input_fields[port_id]
	return field.text.strip_edges()


func apply_manual_inputs(manual_inputs: Dictionary[String, String]) -> void:
	for port_id in manual_inputs.keys():
		if not input_fields.has(port_id):
			continue
		var field: LineEdit = input_fields[port_id]
		field.text = str(manual_inputs[port_id])
	pass


func get_input_slot_index(port_id: String) -> int:
	return input_slot_indices.get(port_id, -1)


func get_output_slot_index(port_id: String = "") -> int:
	if port_id.is_empty():
		if output_slot_indices.is_empty():
			return -1
		return output_slot_indices.values()[0]
	return output_slot_indices.get(port_id, -1)


func get_input_port_at_slot(slot_index: int) -> PortDef:
	for port_id in input_slot_indices.keys():
		if input_slot_indices[port_id] == slot_index:
			return node_def.find_input(port_id)
	return null


func get_output_port_at_slot(slot_index: int) -> PortDef:
	for port_id in output_slot_indices.keys():
		if output_slot_indices[port_id] == slot_index:
			return node_def.find_output(port_id)
	return null


func get_input_port_at_port_index(port_index: int) -> PortDef:
	if port_index < 0 or port_index >= get_input_port_count():
		return null
	var slot_index: int = get_input_port_slot(port_index)
	return get_input_port_at_slot(slot_index)


func get_output_port_at_port_index(port_index: int) -> PortDef:
	if port_index < 0 or port_index >= get_output_port_count():
		return null
	var slot_index: int = get_output_port_slot(port_index)
	return get_output_port_at_slot(slot_index)


func is_output_port(port_index: int) -> bool:
	return get_output_port_at_port_index(port_index) != null


func is_input_port(port_index: int) -> bool:
	return get_input_port_at_port_index(port_index) != null


func get_effective_output_port_type(slot_index: int) -> int:
	var port: PortDef = get_output_port_at_slot(slot_index)
	if port == null:
		return PortDef.TYPE_STRING
	return port.port_type


func get_effective_output_port_type_at_port(port_index: int) -> int:
	if port_index < 0 or port_index >= get_output_port_count():
		return PortDef.TYPE_STRING
	var slot_index: int = get_output_port_slot(port_index)
	return get_effective_output_port_type(slot_index)


func collect_extra_manual_inputs() -> Dictionary[String, String]:
	return {}


func set_highlight(running: bool) -> void:
	apply_theme(running)
	pass


func apply_theme(running: bool = false) -> void:
	var background := Colors.surface.lerp(Colors.success, 0.12) if running else Colors.surface
	var border := Colors.success if running else Colors.border
	var border_width := ControlSize.border_sm if running else ControlSize.border_xs
	add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(background, ControlSize.radius_lg, Margin.ma_3, Margin.ma_2, border, border_width))
	add_theme_color_override(
		"title_color",
		Colors.success if running else Colors.primary_text,
	)
	add_theme_font_size_override("title_font_size", Typography.title_medium_size)
	for field: LineEdit in input_fields.values():
		style_field(field)
	for child: Node in find_children("*", "Button", true, false):
		style_node_button(child as Button)
	pass


func style_label(label: Label, color: Color) -> void:
	label.add_theme_font_size_override("font_size", Typography.body_medium_size)
	label.add_theme_color_override("font_color", color)
	pass


func style_field(field: LineEdit) -> void:
	field.custom_minimum_size.y = ControlSize.md
	field.add_theme_font_size_override("font_size", Typography.body_medium_size)
	field.add_theme_color_override("font_color", Colors.primary_text)
	field.add_theme_color_override("font_placeholder_color", Colors.secondary_text)
	field.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	field.caret_blink = true
	field.add_theme_stylebox_override("normal", StyleBoxHelper.create_style_box_flat(Colors.control_surface, ControlSize.radius_md, Margin.ma_3, Margin.ma_2, Colors.subtle_border, ControlSize.border_xs))
	field.add_theme_stylebox_override("focus", StyleBoxHelper.create_style_box_flat(Colors.control_surface, ControlSize.radius_md, Margin.ma_3, Margin.ma_2, ThemeColor.accent_theme_color(), ControlSize.border_xs))
	pass


func style_node_button(button: Button) -> void:
	button.custom_minimum_size.y = ControlSize.md
	button.add_theme_font_size_override("font_size", Typography.body_medium_size)
	ButtonStyle.apply_font_colors(button, Colors.secondary_text, Colors.primary_text, Colors.primary_text)
	var normal := StyleBoxHelper.create_style_box_flat(Colors.control_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_2, Colors.subtle_border, ControlSize.border_xs)
	ButtonStyle.apply(button, normal,
		ButtonStyle.filled(normal, Colors.hover_surface),
		ButtonStyle.filled(normal, ThemeColor.selected_surface))
	pass
