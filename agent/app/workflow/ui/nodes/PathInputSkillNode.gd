class_name PathInputSkillNode
extends SkillNode

var browse_dialog: FileDialog


func setup(p_node_id: String, p_node_def: GraphNodeDef) -> void:
	super.setup(p_node_id, p_node_def)
	browse_dialog = FileDialog.new()
	browse_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	browse_dialog.access = FileDialog.ACCESS_FILESYSTEM
	browse_dialog.size = AgentLayout.FILE_DIALOG_SIZE
	add_child(browse_dialog)
	browse_dialog.file_selected.connect(on_browse_selected)
	browse_dialog.dir_selected.connect(on_browse_selected)
	pass


func build_node() -> void:
	for port in node_def.inputs:
		add_input_port_row(port)
	for port in node_def.outputs:
		add_output_port_row(port)
	pass


func add_input_port_row(port: PortDef, allow_manual: bool = true) -> int:
	var slot_index := get_child_count()
	var row := create_path_row(port.id, port.display_label(node_def.catalog_id()), port.port_type) if allow_manual else create_connect_only_row(port.display_label(node_def.catalog_id()))
	add_child(row)
	input_slot_indices[port.id] = slot_index
	configure_slot(slot_index, true, port.port_type, port_color(port.port_type), false, 0, Colors.primary_text)
	return slot_index


func create_path_row(port_id: String, label_text: String, port_type: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Margin.ma_2)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = LABEL_WIDTH
	style_label(label, Colors.primary_text)
	row.add_child(label)

	var field := LineEdit.new()
	field.custom_minimum_size.x = FIELD_MIN_WIDTH
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var type_name := PortDef.type_to_string(port_type)
	var type_key := "port_type." + type_name
	var translated_type := tr(type_key)
	if translated_type == type_key:
		translated_type = type_name
	field.placeholder_text = tr("workflow.node.path_placeholder").format([translated_type], StringUtils.EMPTY_JSON)
	style_field(field)
	row.add_child(field)
	input_fields[port_id] = field

	var browse := Button.new()
	browse.text = "…"
	browse.custom_minimum_size = ControlSize.square(ControlSize.md)
	browse.add_theme_font_size_override("font_size", Typography.label_large_size)
	ButtonStyle.apply_font_colors(browse, Colors.secondary_text, Colors.primary_text, Colors.primary_text)
	var normal := StyleBoxHelper.create_style_box_flat(Colors.control_surface, ControlSize.radius_md, Margin.ma_1, Margin.ma_1, Colors.subtle_border, ControlSize.border_xs)
	ButtonStyle.apply(browse, normal,
		ButtonStyle.filled(normal, Colors.hover_surface),
		ButtonStyle.filled(normal, ThemeColor.selected_surface))
	browse.pressed.connect(func() -> void: open_browse(port_id, port_type))
	row.add_child(browse)
	return row


func open_browse(port_id: String, port_type: int) -> void:
	browse_dialog.set_meta("port_id", port_id)
	browse_dialog.clear_filters()
	match port_type:
		PortDef.TYPE_FOLDER:
			browse_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		PortDef.TYPE_TEXT:
			configure_file_dialog(["*.md ; Markdown", "*.txt ; Text", "*.* ; All"])
		PortDef.TYPE_AUDIO:
			configure_file_dialog(["*.wav ; WAV", "*.mp3 ; MP3", "*.ogg ; OGG", "*.flac ; FLAC", "*.* ; All"])
		PortDef.TYPE_IMAGE:
			configure_file_dialog(["*.png ; PNG", "*.jpg ; JPEG", "*.webp ; WebP", "*.* ; All"])
		PortDef.TYPE_VIDEO:
			configure_file_dialog(["*.mp4 ; MP4", "*.mkv ; MKV", "*.mov ; MOV", "*.webm ; WebM", "*.* ; All"])
		_:
			configure_file_dialog(["*.* ; All"])
	browse_dialog.popup_centered()
	browse_dialog.oversampling_override = DisplayScale.compute_ui_scale()
	pass


func configure_file_dialog(filters: Array[String]) -> void:
	browse_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	for filter: String in filters:
		var parts := filter.split(" ; ", false, 1)
		browse_dialog.add_filter(parts[0], parts[1] if parts.size() > 1 else "")
	pass


func on_browse_selected(path: String) -> void:
	var port_id := str(browse_dialog.get_meta("port_id", ""))
	if port_id.is_empty() or not input_fields.has(port_id):
		return
	var field: LineEdit = input_fields[port_id]
	field.text = path.replace("\\", "/")
	pass
