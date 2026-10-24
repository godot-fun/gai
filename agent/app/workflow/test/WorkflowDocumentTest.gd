## Unit tests for workflow document JSON serialization via JsonUtils.


static func build_sample_document() -> WorkflowDocument:
	var doc := WorkflowDocument.new()
	doc.version = WorkflowDocument.VERSION
	doc.name = "Audio Pipeline"

	var source := WorkflowNodeData.new()
	source.id = "node-1"
	source.skill_id = "input-audio"
	source.set_position_vector(Vector2(120.0, 80.0))
	source.manual_inputs["path"] = "res://audio/sample.wav"
	doc.nodes.append(source)

	var skill := WorkflowNodeData.new()
	skill.id = "node-2"
	skill.skill_id = "audio-to-wav"
	skill.set_position_vector(Vector2(420.5, 160.25))
	skill.manual_inputs["output"] = "user://out.wav"
	doc.nodes.append(skill)

	var batch := WorkflowNodeData.new()
	batch.id = "node-3"
	batch.skill_id = GraphNodesConfig.CONTROL_BATCH_FOR_EACH
	batch.set_position_vector(Vector2(720.0, 240.0))
	batch.manual_inputs["folder"] = "user://batch/"
	batch.manual_inputs["glob"] = "*.mp3"
	doc.nodes.append(batch)

	var link_a := WorkflowConnection.new()
	link_a.from_node = "node-1"
	link_a.from_port = 0
	link_a.to_node = "node-2"
	link_a.to_port = 0
	doc.connections.append(link_a)

	var link_b := WorkflowConnection.new()
	link_b.from_node = "node-2"
	link_b.from_port = 0
	link_b.to_node = "node-3"
	link_b.to_port = 1
	doc.connections.append(link_b)

	return doc


static func assert_node_equal(expected: WorkflowNodeData, actual: WorkflowNodeData) -> void:
	assert(actual != null)
	assert(actual.id == expected.id)
	assert(actual.skill_id == expected.skill_id)
	assert(actual.position.size() == expected.position.size())
	for index in expected.position.size():
		assert(actual.position[index] == expected.position[index])
	assert(actual.position_vector().is_equal_approx(expected.position_vector()))
	assert(actual.manual_inputs.size() == expected.manual_inputs.size())
	for port_id in expected.manual_inputs.keys():
		assert(actual.manual_inputs.has(port_id))
		assert(actual.manual_inputs[port_id] == expected.manual_inputs[port_id])
	pass


static func assert_connection_equal(expected: WorkflowConnection, actual: WorkflowConnection) -> void:
	assert(actual != null)
	assert(actual.from_node == expected.from_node)
	assert(actual.from_port == expected.from_port)
	assert(actual.to_node == expected.to_node)
	assert(actual.to_port == expected.to_port)
	pass


static func assert_document_equal(expected: WorkflowDocument, actual: WorkflowDocument) -> void:
	assert(actual != null)
	assert(actual.version == expected.version)
	assert(actual.name == expected.name)
	assert(actual.nodes.size() == expected.nodes.size())
	assert(actual.connections.size() == expected.connections.size())
	for index in expected.nodes.size():
		assert_node_equal(expected.nodes[index], actual.nodes[index])
	for index in expected.connections.size():
		assert_connection_equal(expected.connections[index], actual.connections[index])
	pass


static func round_trip(document: WorkflowDocument) -> WorkflowDocument:
	var json := JsonUtils.object_to_json(document)
	var restored: WorkflowDocument = JsonUtils.json_to_object(json, WorkflowDocument)
	assert(restored != null)
	var json_again := JsonUtils.object_to_json(restored)
	assert(json == json_again)
	return restored


func workflow_document_empty_round_trip_test() -> void:
	var doc := WorkflowDocument.new()
	var restored := round_trip(doc)
	assert_document_equal(doc, restored)
	pass


func workflow_document_full_round_trip_test() -> void:
	var doc := build_sample_document()
	var restored := round_trip(doc)
	assert_document_equal(doc, restored)
	pass


func workflow_node_data_position_round_trip_test() -> void:
	var node := WorkflowNodeData.new()
	node.id = "pos-node"
	node.skill_id = "input-audio"
	node.set_position_vector(Vector2(-12.5, 999.0))

	var json := JsonUtils.object_to_json(node)
	var restored: WorkflowNodeData = JsonUtils.json_to_object(json, WorkflowNodeData)
	assert(restored != null)
	assert(restored.position.size() == 2)
	assert(restored.position[0] == -12.5)
	assert(restored.position[1] == 999.0)
	assert(restored.position_vector().is_equal_approx(Vector2(-12.5, 999.0)))
	pass


func workflow_connection_round_trip_test() -> void:
	var conn := WorkflowConnection.new()
	conn.from_node = "alpha"
	conn.from_port = 2
	conn.to_node = "beta"
	conn.to_port = 1

	var json := JsonUtils.object_to_json(conn)
	var restored: WorkflowConnection = JsonUtils.json_to_object(json, WorkflowConnection)
	assert(restored != null)
	assert_connection_equal(conn, restored)
	pass


func workflow_manager_save_load_test() -> void:
	var path := WorkflowManager.USER_WORKFLOWS_DIR.path_join("unit_test_roundtrip.workflow.json")
	var source := build_sample_document()

	WorkflowManager.save(path, source)
	assert(FileAccess.file_exists(path))
	assert(source.name == WorkflowManager.workflow_name_from_path(path))

	var loaded := WorkflowManager.load(path)
	assert_document_equal(source, loaded)

	FileUtils.delete_file_or_directory(path)
	pass
