## Unit tests for the workflow graph node catalog loaded by GraphNodesConfig.


static func load_json_root() -> Dictionary:
	var text := FileAccess.get_file_as_string(GraphNodesConfig.GRAPH_NODES)
	assert(!text.is_empty())
	var catalog: GraphNodesDef = JsonUtils.json_to_object(text, GraphNodesDef)
	assert(catalog != null)
	return {
		"version": catalog.version,
		GraphNodesConfig.SOURCE_DEFS: catalog.sources,
		GraphNodesConfig.CONTROL_DEFS: catalog.controls,
		GraphNodesConfig.SKILL_DEFS: catalog.skills,
	}


static func find_skill_in_category(category: String) -> SkillDef:
	for def in GraphNodesConfig.skills:
		if def.category == category:
			return def
	return null


func graph_nodes_json_file_test() -> void:
	assert(FileAccess.file_exists(GraphNodesConfig.GRAPH_NODES))
	var root := load_json_root()
	assert(root.get("version", 0) == 1)
	pass


func graph_nodes_catalog_counts_test() -> void:
	var root := load_json_root()
	var json_sources: Array = root.get(GraphNodesConfig.SOURCE_DEFS, [])
	var json_controls: Array = root.get(GraphNodesConfig.CONTROL_DEFS, [])
	var json_skills: Array = root.get(GraphNodesConfig.SKILL_DEFS, [])

	assert(GraphNodesConfig.sources.size() == json_sources.size())
	assert(GraphNodesConfig.controls.size() == json_controls.size())
	assert(GraphNodesConfig.skills.size() == json_skills.size())
	assert(json_skills.size() == 22)

	var expected_def_count := json_sources.size() + json_controls.size() + json_skills.size()
	assert(GraphNodesConfig.defs_by_id.size() == expected_def_count)
	pass


func graph_nodes_sources_test() -> void:
	var root := load_json_root()
	var json_sources: Array = root.get(GraphNodesConfig.SOURCE_DEFS, [])
	for source_def in json_sources:
		var def := GraphNodesConfig.get_def(source_def.id)
		assert(def is SourceDef, "missing source:[%s]" % source_def.id)

	var audio := GraphNodesConfig.get_def("input-audio") as SourceDef
	assert(audio.display_label() == "input-audio")
	assert(audio.outputs.size() == 1)
	assert(audio.outputs[0].id == GraphNodesConfig.PORT_OUTPUT)
	assert(audio.outputs[0].type == PortDef.TYPE_NAME_AUDIO)
	pass


func graph_nodes_controls_test() -> void:
	var batch := GraphNodesConfig.get_def(GraphNodesConfig.CONTROL_BATCH_FOR_EACH)
	assert(batch is ControlDef)
	var control := batch as ControlDef
	assert(control.display_label() == GraphNodesConfig.CONTROL_BATCH_FOR_EACH)
	assert(control.is_batch())
	assert(control.inputs[0].id == GraphNodesConfig.CONTROL_PORT_FOLDER)
	assert(control.outputs[0].id == GraphNodesConfig.CONTROL_PORT_ITEM)
	pass


func graph_nodes_all_skills_registered_test() -> void:
	var root := load_json_root()
	var json_skills: Array = root.get(GraphNodesConfig.SKILL_DEFS, [])
	for skill_def in json_skills:
		var def := GraphNodesConfig.get_skill(skill_def.skill)
		assert(def != null, "missing skill:[%s]" % skill_def.skill)
		assert(!def.cli.is_empty(), "empty cli:[%s]" % skill_def.skill)
	pass


func graph_nodes_create_node_test() -> void:
	assert(GraphNodesConfig.create_node("input-audio") is InputSourceNode)
	assert(GraphNodesConfig.create_node(GraphNodesConfig.CONTROL_BATCH_FOR_EACH) is BatchForEachNode)

	var audio_skill := find_skill_in_category(GraphNodesConfig.SKILL_CATEGORY_AUDIO)
	var video_skill := find_skill_in_category(GraphNodesConfig.SKILL_CATEGORY_VIDEO)
	var image_skill := find_skill_in_category(GraphNodesConfig.SKILL_CATEGORY_IMAGE)
	assert(audio_skill != null and video_skill != null and image_skill != null)
	assert(GraphNodesConfig.create_node(audio_skill.skill) is PathInputSkillNode)
	assert(GraphNodesConfig.create_node(video_skill.skill) is PathInputSkillNode)
	assert(GraphNodesConfig.create_node(image_skill.skill) is PathInputSkillNode)
	pass


func graph_nodes_list_helpers_test() -> void:
	assert(GraphNodesConfig.sources.size() == 5)
	assert(GraphNodesConfig.controls.size() == 1)
	assert(GraphNodesConfig.list_skills_in_category(GraphNodesConfig.SKILL_CATEGORY_AUDIO).size() == 8)
	assert(GraphNodesConfig.list_skills_in_category(GraphNodesConfig.SKILL_CATEGORY_VIDEO).size() == 9)
	assert(GraphNodesConfig.list_skills_in_category(GraphNodesConfig.SKILL_CATEGORY_IMAGE).size() == 5)

	var source_category := GraphNodesConfig.list_skills_in_category(GraphNodesConfig.SOURCE_CATEGORY)
	assert(source_category.size() == 6)
	pass


func graph_nodes_palette_order_test() -> void:
	var source_ids: Array[String] = []
	for def in GraphNodesConfig.list_skills_in_category(GraphNodesConfig.SOURCE_CATEGORY):
		source_ids.append(def.catalog_id())
	assert(source_ids == GraphNodesConfig.SOURCE_NODE_ORDER)

	var audio_ids: Array[String] = []
	for def in GraphNodesConfig.list_skills_in_category(GraphNodesConfig.SKILL_CATEGORY_AUDIO):
		audio_ids.append(def.catalog_id())
	assert(audio_ids == GraphNodesConfig.SKILL_ORDER_AUDIO)

	var image_ids: Array[String] = []
	for def in GraphNodesConfig.list_skills_in_category(GraphNodesConfig.SKILL_CATEGORY_IMAGE):
		image_ids.append(def.catalog_id())
	assert(image_ids == GraphNodesConfig.SKILL_ORDER_IMAGE)

	var video_ids: Array[String] = []
	for def in GraphNodesConfig.list_skills_in_category(GraphNodesConfig.SKILL_CATEGORY_VIDEO):
		video_ids.append(def.catalog_id())
	assert(video_ids == GraphNodesConfig.SKILL_ORDER_VIDEO)
	pass
