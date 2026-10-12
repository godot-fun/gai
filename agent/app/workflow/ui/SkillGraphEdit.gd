class_name SkillGraphEdit
extends GraphEdit

var node_seq: int = 0
var skill_nodes: Dictionary[String, SkillNode] = {}
var highlighted_node_id: String = ""


func _ready() -> void:
	snapping_enabled = true
	snapping_distance = 20
	connection_request.connect(on_connection_request)
	disconnection_request.connect(on_disconnection_request)
	WorkflowEvents.events.step_started.connect(on_pipeline_step_started)
	WorkflowEvents.events.pipeline_finished.connect(func(_success, _message): clear_node_highlight())
	WorkflowEvents.events.pipeline_stopped.connect(clear_node_highlight)

	apply_theme()
	pass


func apply_theme() -> void:
	add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Colors.app_background))
	add_theme_color_override("grid_major", Colors.muted_border)
	add_theme_color_override("grid_minor", Colors.subtle_border)
	add_theme_color_override("activity", ThemeColor.accent_theme_color())
	for node: SkillNode in skill_nodes.values():
		node.apply_theme(node.node_id == highlighted_node_id)
	queue_redraw()
	pass


func add_skill_node(skill_id: String, at_position: Vector2 = Vector2(80, 80)) -> SkillNode:
	var def: GraphNodeDef = GraphNodesConfig.get_def(skill_id)
	if def == null:
		Log.error("unknown graph node def:[{}]", skill_id)
		return null

	node_seq += 1
	var node_id := StringUtils.format("node_{}", node_seq)
	var node := GraphNodesConfig.create_node(skill_id)
	node.name = node_id
	node.setup(node_id, def)
	node.position_offset = at_position

	add_child(node)
	skill_nodes[node_id] = node
	return node


func on_connection_request(
	from_node: StringName,
	from_port: int,
	to_node: StringName,
	to_port: int,
) -> void:
	if not can_connect(str(from_node), from_port, str(to_node), to_port):
		return
	connect_node(from_node, from_port, to_node, to_port)
	pass


func on_disconnection_request(
	from_node: StringName,
	from_port: int,
	to_node: StringName,
	to_port: int,
) -> void:
	disconnect_node(from_node, from_port, to_node, to_port)
	pass


func can_connect(from_node_id: String, from_port: int, to_node_id: String, to_port: int) -> bool:
	if from_node_id == to_node_id:
		return false
	if not skill_nodes.has(from_node_id) or not skill_nodes.has(to_node_id):
		return false

	var from_node: SkillNode = skill_nodes[from_node_id]
	var to_node: SkillNode = skill_nodes[to_node_id]
	if not from_node.is_output_port(from_port):
		return false
	if not to_node.is_input_port(to_port):
		return false

	var from_type := from_node.get_effective_output_port_type_at_port(from_port)
	var to_port_def := to_node.get_input_port_at_port_index(to_port)
	if to_port_def == null:
		return false
	return from_type == to_port_def.port_type


func clear_graph() -> void:
	for conn in get_connection_list():
		disconnect_node(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])
	var nodes_to_remove: Array[SkillNode] = []
	for child in get_children():
		if child is SkillNode:
			nodes_to_remove.append(child as SkillNode)
	for node in nodes_to_remove:
		skill_nodes.erase(node.node_id)
		remove_child(node)
		node.free()
	skill_nodes.clear()
	node_seq = 0
	highlighted_node_id = ""
	pass


func remove_selected_nodes() -> void:
	var to_remove: Array[SkillNode] = []
	for child in get_children():
		if child is SkillNode and (child as SkillNode).selected:
			to_remove.append(child as SkillNode)
	for node in to_remove:
		if node.node_id == highlighted_node_id:
			clear_node_highlight()
		skill_nodes.erase(node.node_id)
		node.queue_free()
	pass


func build_document(workflow_name: String) -> WorkflowDocument:
	var doc := WorkflowDocument.new()
	doc.name = workflow_name

	for node_id in skill_nodes.keys():
		var node: SkillNode = skill_nodes[node_id]
		var data := WorkflowNodeData.new()
		data.id = node_id
		data.skill_id = node.node_def.catalog_id()
		data.set_position_vector(node.position_offset)
		for port_id in node.input_fields.keys():
			var value := node.get_manual_input(port_id)
			if not value.is_empty():
				data.manual_inputs[port_id] = value
		var extra := node.collect_extra_manual_inputs()
		for port_id in extra.keys():
			var extra_value := str(extra[port_id])
			if not extra_value.is_empty():
				data.manual_inputs[port_id] = extra_value
		doc.nodes.append(data)

	for conn in get_connection_list():
		var link := WorkflowConnection.new()
		link.from_node = str(conn.get("from_node", ""))
		link.from_port = int(conn.get("from_port", 0))
		link.to_node = str(conn.get("to_node", ""))
		link.to_port = int(conn.get("to_port", 0))
		doc.connections.append(link)

	return doc


func load_document(doc: WorkflowDocument) -> void:
	clear_graph()

	var id_remap: Dictionary[String, String] = {}
	for node_data in doc.nodes:
		var node := add_skill_node(node_data.skill_id, node_data.position_vector())
		if node == null:
			continue
		id_remap[node_data.id] = node.node_id
		node.apply_manual_inputs(node_data.manual_inputs)

	var pending: Array[WorkflowConnection] = []
	for conn in doc.connections:
		var from_id: String = id_remap.get(conn.from_node, conn.from_node)
		var to_id: String = id_remap.get(conn.to_node, conn.to_node)
		if not skill_nodes.has(from_id) or not skill_nodes.has(to_id):
			continue
		var link := WorkflowConnection.new()
		link.from_node = from_id
		link.from_port = conn.from_port
		link.to_node = to_id
		link.to_port = conn.to_port
		pending.append(link)

	if pending.is_empty():
		return
	call_deferred("_apply_connections", pending)
	pass


func _apply_connections(connections: Array[WorkflowConnection]) -> void:
	for conn in connections:
		if not skill_nodes.has(conn.from_node) or not skill_nodes.has(conn.to_node):
			continue
		if can_connect(conn.from_node, conn.from_port, conn.to_node, conn.to_port):
			connect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
	pass


func reload_locale(workflow_name: String) -> void:
	var doc := build_document(workflow_name)
	load_document(doc)
	pass


func highlight_node(node_id: String) -> void:
	clear_node_highlight()
	if not skill_nodes.has(node_id):
		return
	highlighted_node_id = node_id
	skill_nodes[node_id].set_highlight(true)
	pass


func clear_node_highlight() -> void:
	if highlighted_node_id.is_empty():
		return
	if skill_nodes.has(highlighted_node_id):
		skill_nodes[highlighted_node_id].set_highlight(false)
	highlighted_node_id = ""
	pass


func on_pipeline_step_started(node_id: String, _label: String) -> void:
	highlight_node(node_id)
	pass
