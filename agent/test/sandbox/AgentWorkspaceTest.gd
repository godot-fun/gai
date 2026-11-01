extends RefCounted


static func data_dir_test() -> void:
	assert(AgentWorkspace.data_dir == AgentWorkspace.get_root().path_join(AgentWorkspace.DATA_DIR_NAME))
	assert(AgentWorkspace.data_dir.get_file() == ".gai")
	pass


static func data_path_test() -> void:
	assert(AgentWorkspace.get_data_path("") == AgentWorkspace.data_dir)
	assert(AgentWorkspace.get_data_path("sessions") == AgentWorkspace.data_dir.path_join("sessions"))
	assert(AgentWorkspace.get_data_path("cache/diff") == AgentWorkspace.data_dir.path_join("cache/diff"))
	pass
