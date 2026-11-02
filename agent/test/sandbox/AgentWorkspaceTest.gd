extends RefCounted


static func data_dir_test() -> void:
	# No --data-dir on the command line during tests, so the plain folder name is kept.
	assert(AgentWorkspace.data_dir == AgentWorkspace.DEFAULT_DATA_DIR)
	assert(AgentWorkspace.get_data_path("") == AgentWorkspace.get_root().path_join(AgentWorkspace.DEFAULT_DATA_DIR))
	assert(AgentWorkspace.get_data_path("").get_file() == ".gai")
	pass


static func data_path_test() -> void:
	var data_dir_path := AgentWorkspace.get_data_path("")
	assert(AgentWorkspace.get_data_path("sessions") == data_dir_path.path_join("sessions"))
	assert(AgentWorkspace.get_data_path("cache/diff") == data_dir_path.path_join("cache/diff"))
	pass
