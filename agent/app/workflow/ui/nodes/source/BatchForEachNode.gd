class_name BatchForEachNode
extends SkillNode

var item_type_option: OptionButton
var output_port_id: String = GraphNodesConfig.CONTROL_PORT_ITEM


func build_node() -> void:
	ignore_invalid_connection_type = true

	if not node_def.inputs.is_empty():
		add_input_port_row(node_def.inputs[0], false)

	add_child(create_text_row(GraphNodesConfig.CONTROL_FIELD_GLOB, tr("workflow.batch.glob"), "*.*"))

	var type_row := create_item_type_row()
	add_child(type_row)

	if not node_def.outputs.is_empty():
		output_port_id = node_def.outputs[0].id

	output_slot_indices[output_port_id] = get_child_count() - 1
	if not gdf.events.theme_changed.is_connected(on_visual_theme_changed):
		gdf.events.theme_changed.connect(on_visual_theme_changed)
	if not gdf.events.theme_color_changed.is_connected(on_visual_theme_changed):
		gdf.events.theme_color_changed.connect(on_visual_theme_changed)
	call_deferred("refresh_output_slot", get_batch_item_type())
	pass


func create_item_type_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = tr("workflow.batch.output_type")
	label.custom_minimum_size.x = LABEL_WIDTH
	style_label(label, ColorBase.primary_text)
	row.add_child(label)

	item_type_option = OptionButton.new()
	item_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_type_option.custom_minimum_size.y = ControlSize.md
	item_type_option.add_theme_font_size_override("font_size", Typography.body_medium_size)
	item_type_option.add_item(tr("port_type." + PortDef.TYPE_NAME_AUDIO), 0)
	item_type_option.set_item_metadata(0, PortDef.TYPE_NAME_AUDIO)
	item_type_option.add_item(tr("port_type." + PortDef.TYPE_NAME_IMAGE), 1)
	item_type_option.set_item_metadata(1, PortDef.TYPE_NAME_IMAGE)
	item_type_option.add_item(tr("port_type." + PortDef.TYPE_NAME_VIDEO), 2)
	item_type_option.set_item_metadata(2, PortDef.TYPE_NAME_VIDEO)
	item_type_option.add_item(tr("port_type." + PortDef.TYPE_NAME_TEXT), 3)
	item_type_option.set_item_metadata(3, PortDef.TYPE_NAME_TEXT)
	PopupMenuStyle.apply(item_type_option.get_popup())
	item_type_option.item_selected.connect(on_batch_item_type_selected)
	row.add_child(item_type_option)

	return row


func on_batch_item_type_selected(index: int) -> void:
	var type_name: String = str(item_type_option.get_item_metadata(index))
	refresh_output_slot(type_name)
	pass


func on_visual_theme_changed() -> void:
	if item_type_option != null:
		PopupMenuStyle.apply(item_type_option.get_popup())
	pass


func refresh_output_slot(type_name: String) -> void:
	var slot_index: int = output_slot_indices.get(output_port_id, get_child_count() - 1)
	var out_type := PortDef.type_from_string(type_name)
	configure_slot(
		slot_index,
		false,
		0,
		ThemeColor.title_color,
		true,
		out_type,
		port_color(out_type),
	)
	pass


func get_batch_item_type() -> String:
	if item_type_option == null:
		return PortDef.TYPE_NAME_AUDIO
	var type_name := str(item_type_option.get_item_metadata(item_type_option.selected))
	if type_name.is_empty():
		return PortDef.TYPE_NAME_AUDIO
	return type_name


func get_effective_output_port_type(slot_index: int) -> int:
	if slot_index == output_slot_indices.get(output_port_id, -1):
		return PortDef.type_from_string(get_batch_item_type())
	return super.get_effective_output_port_type(slot_index)


func get_manual_input(port_id: String) -> String:
	if port_id == GraphNodesConfig.CONTROL_FIELD_ITEM_TYPE:
		return get_batch_item_type()
	return super.get_manual_input(port_id)


func apply_manual_inputs(manual_inputs: Dictionary[String, String]) -> void:
	super.apply_manual_inputs(manual_inputs)
	if manual_inputs.has(GraphNodesConfig.CONTROL_FIELD_ITEM_TYPE) and item_type_option != null:
		var type_name := str(manual_inputs[GraphNodesConfig.CONTROL_FIELD_ITEM_TYPE])
		for i in range(item_type_option.item_count):
			if str(item_type_option.get_item_metadata(i)) == type_name:
				item_type_option.select(i)
				refresh_output_slot(type_name)
				break
	pass


func collect_extra_manual_inputs() -> Dictionary[String, String]:
	return {GraphNodesConfig.CONTROL_FIELD_ITEM_TYPE: get_batch_item_type()}
