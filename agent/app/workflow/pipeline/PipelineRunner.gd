class_name PipelineRunner
extends Object

var stop_requested: bool = false


func request_stop() -> void:
	stop_requested = true
	OSUtils.stop_last()
	pass


func run(document: WorkflowDocument) -> void:
	stop_requested = false
	var order: Array[WorkflowNodeData] = topological_sort(document)
	if order.is_empty():
		WorkflowEvents.events.pipeline_finished.emit(false, "Workflow is empty or contains a cycle")
		return

	var batch_index := find_batch_index(order)
	var outputs_by_node: Dictionary[String, String] = {}

	var pre_count := order.size() if batch_index < 0 else batch_index
	if not await run_nodes(order.slice(0, pre_count), document, outputs_by_node):
		return

	if batch_index < 0:
		WorkflowEvents.events.pipeline_finished.emit(true, "Pipeline completed")
		return

	var batch_node_data: WorkflowNodeData = order[batch_index]
	var batch_node: GraphNodeDef = GraphNodesConfig.get_def(batch_node_data.skill_id)
	if batch_node == null or not batch_node.is_batch():
		WorkflowEvents.events.pipeline_finished.emit(false, "Unknown batch node")
		return

	var batch_resolved: Dictionary[String, String] = resolve_inputs(
		batch_node_data,
		batch_node,
		document,
		outputs_by_node,
	)
	var folder_path: String = batch_resolved.get(GraphNodesConfig.CONTROL_PORT_FOLDER, "")
	if folder_path.is_empty():
		WorkflowEvents.events.pipeline_finished.emit(false, "Batch node requires a connected folder input")
		return

	var glob_pattern: String = batch_node_data.manual_inputs.get(GraphNodesConfig.CONTROL_FIELD_GLOB, "*.*")
	var files: Array[String] = await GlobUtils.async_glob(folder_path, glob_pattern, false)
	if files.is_empty():
		WorkflowEvents.events.pipeline_finished.emit(false, StringUtils.format("No matching files in batch folder ({})", glob_pattern))
		return

	var post_nodes: Array[WorkflowNodeData] = order.slice(batch_index + 1)
	for file_path in files:
		if stop_requested:
			WorkflowEvents.events.pipeline_stopped.emit()
			return
		store_node_output(outputs_by_node, batch_node_data.id, batch_node, file_path)
		if not await run_nodes(post_nodes, document, outputs_by_node):
			return

	WorkflowEvents.events.pipeline_finished.emit(true, StringUtils.format("Batch completed ({} files)", files.size()))
	pass


func run_nodes(nodes: Array[WorkflowNodeData], document: WorkflowDocument, outputs_by_node: Dictionary[String, String]) -> bool:
	for node_data in nodes:
		if stop_requested:
			WorkflowEvents.events.pipeline_stopped.emit()
			return false

		var node_def: GraphNodeDef = GraphNodesConfig.get_def(node_data.skill_id)
		if node_def == null:
			return stop_pipeline("", 0, StringUtils.format("Unknown node: {}", node_data.skill_id))

		if node_def.is_source():
			var source_out: String = node_data.manual_inputs.get(primary_output_port_id(node_def), "")
			if source_out.is_empty():
				return stop_pipeline("", 0, StringUtils.format("Source node {} has no path set", node_data.id))
			store_node_output(outputs_by_node, node_data.id, node_def, source_out)
			continue

		if node_def.is_batch():
			continue

		if node_def is not SkillDef:
			return stop_pipeline("", 0, StringUtils.format("Node {} is not an executable skill", node_data.id))

		var skill := node_def as SkillDef
		var resolved: Dictionary[String, String] = resolve_inputs(node_data, node_def, document, outputs_by_node)
		if resolved.is_empty():
			return stop_pipeline("", 0, StringUtils.format("Node {} is missing input", node_data.id))

		var argv: PackedStringArray = SkillCommandBuilder.build_argv(skill, resolved)
		if argv.is_empty():
			return stop_pipeline("", 0, StringUtils.format("Failed to build command: {}", node_def.display_label()))

		var primary_input: String = first_input_path(node_def, resolved)
		var out_port_id := primary_output_port_id(node_def)
		WorkflowEvents.events.step_started.emit(node_data.id, node_def.display_label())
		Log.info("command:{}", JSON.stringify(argv))

		var exec_result := await OSUtils.async_execute(argv, false)
		if stop_requested:
			WorkflowEvents.events.pipeline_stopped.emit()
			return false

		var exit_code: int = exec_result.exit_code
		if exit_code != 0:
			return stop_pipeline(
				node_data.id,
				exit_code,
				StringUtils.format("Step failed: {} (exit {})", node_def.display_label(), exit_code),
			)

		var output_path: String = resolve_newest_output(node_def, primary_input)
		if output_path.is_empty():
			return stop_pipeline(
				node_data.id,
				exit_code,
				StringUtils.format("No output found for {} in {}", node_def.display_label(), skill_output_dir(node_def, primary_input)),
			)

		store_node_output(outputs_by_node, node_data.id, node_def, output_path, out_port_id)
		WorkflowEvents.events.step_finished.emit(node_data.id, exit_code, output_path)

	return true


func stop_pipeline(node_id: String, exit_code: int, message: String) -> bool:
	if not node_id.is_empty():
		WorkflowEvents.events.step_finished.emit(node_id, exit_code, "")
	WorkflowEvents.events.pipeline_finished.emit(false, message)
	return false


func find_batch_index(order: Array[WorkflowNodeData]) -> int:
	for i in range(order.size()):
		var node_def: GraphNodeDef = GraphNodesConfig.get_def(order[i].skill_id)
		if node_def != null and node_def.is_batch():
			return i
	return -1


func resolve_inputs(node_data: WorkflowNodeData, node_def: GraphNodeDef, document: WorkflowDocument, outputs_by_node: Dictionary[String, String]) -> Dictionary[String, String]:
	var resolved: Dictionary[String, String] = {}

	for port in node_def.inputs:
		var port_index: int = node_def.input_port_index_for_id(port.id)
		var connected: WorkflowConnection = find_connection_to_port(document, node_data.id, port_index)
		if connected != null:
			var upstream_path: String = read_upstream_output(connected, document, outputs_by_node)
			if upstream_path.is_empty():
				return {}
			resolved[port.id] = upstream_path
			continue

		if node_def.is_batch():
			return {}

		var manual: String = node_data.manual_inputs.get(port.id, "")
		if manual.is_empty():
			return {}
		resolved[port.id] = manual

	return resolved


func read_upstream_output(conn: WorkflowConnection, document: WorkflowDocument, outputs_by_node: Dictionary[String, String]) -> String:
	var from_data := find_node_data(document, conn.from_node)
	if from_data == null:
		return outputs_by_node.get(conn.from_node, "")

	var from_def: GraphNodeDef = GraphNodesConfig.get_def(from_data.skill_id)
	if from_def == null:
		return outputs_by_node.get(conn.from_node, "")

	var out_port := from_def.output_port_at_port_index(conn.from_port)
	if out_port == null:
		return outputs_by_node.get(conn.from_node, "")

	return get_node_output(outputs_by_node, conn.from_node, out_port.id)


func find_node_data(document: WorkflowDocument, node_id: String) -> WorkflowNodeData:
	for node in document.nodes:
		if node.id == node_id:
			return node
	return null


func find_connection_to_port(document: WorkflowDocument, node_id: String, port_index: int) -> WorkflowConnection:
	for conn in document.connections:
		if conn.to_node == node_id and conn.to_port == port_index:
			return conn
	return null


func first_input_path(node_def: GraphNodeDef, resolved: Dictionary[String, String]) -> String:
	for port in node_def.inputs:
		if resolved.has(port.id):
			return resolved[port.id]
	return ""


func primary_output_port_id(node_def: GraphNodeDef) -> String:
	if node_def.outputs.is_empty():
		return GraphNodesConfig.PORT_OUTPUT
	return node_def.outputs[0].id


func store_node_output(outputs_by_node: Dictionary[String, String], node_id: String, node_def: GraphNodeDef, path: String, port_id: String = "") -> void:
	outputs_by_node[node_id] = path
	if port_id.is_empty():
		port_id = primary_output_port_id(node_def)
	outputs_by_node[output_key(node_id, port_id)] = path


func get_node_output(outputs_by_node: Dictionary[String, String], node_id: String, port_id: String) -> String:
	var keyed: String = outputs_by_node.get(output_key(node_id, port_id), "")
	if not keyed.is_empty():
		return keyed
	return outputs_by_node.get(node_id, "")


func output_key(node_id: String, port_id: String) -> String:
	return StringUtils.format("{}:{}", node_id, port_id)


func skill_output_dir(node_def: GraphNodeDef, primary_input_path: String) -> String:
	if primary_input_path.is_empty():
		return ""

	var normalized := primary_input_path.replace("\\", "/")
	var subdir := node_def.catalog_id()
	if DirAccess.dir_exists_absolute(normalized):
		return normalized.path_join(subdir)
	return normalized.get_base_dir().path_join(subdir)


func resolve_newest_output(node_def: GraphNodeDef, primary_input_path: String) -> String:
	var output_dir := skill_output_dir(node_def, primary_input_path)
	if output_dir.is_empty():
		return ""

	if node_def.primary_output_is_folder() and DirAccess.dir_exists_absolute(output_dir):
		return output_dir

	return FileUtils.get_newest_file_in_folder(output_dir)


func topological_sort(document: WorkflowDocument) -> Array[WorkflowNodeData]:
	var node_map: Dictionary[String, WorkflowNodeData] = {}
	for node in document.nodes:
		node_map[node.id] = node

	var indegree: Dictionary[String, int] = {}
	var adj: Dictionary = {}
	for node in document.nodes:
		indegree[node.id] = 0
		adj[node.id] = [] as Array[String]

	for conn in document.connections:
		if not node_map.has(conn.from_node) or not node_map.has(conn.to_node):
			continue
		adj[conn.from_node].append(conn.to_node)
		indegree[conn.to_node] = indegree.get(conn.to_node, 0) + 1

	var queue: Array[String] = []
	for node_id in indegree.keys():
		if indegree[node_id] == 0:
			queue.append(node_id)

	var order: Array[WorkflowNodeData] = []
	while not queue.is_empty():
		var current: String = queue.pop_front()
		order.append(node_map[current])
		for next_id: String in adj[current]:
			indegree[next_id] = indegree[next_id] - 1
			if indegree[next_id] == 0:
				queue.append(next_id)

	if order.size() != document.nodes.size():
		return []
	return order
