extends RefCounted

## GitIgnore — agent data folders never reach the user's repository.


static func data_dir_rules_test() -> void:
	GitIgnore.refresh_ignore_rules()
	# The active folder plus the default name, because another launch mode writes that one.
	assert(GitIgnore.ignore_rules.has(Workspace.get_dir_name() + "/"))
	assert(GitIgnore.ignore_rules.has(Workspace.DEFAULT_DIR_NAME + "/"))
	pass


static func data_dir_rules_are_unique_test() -> void:
	GitIgnore.refresh_ignore_rules()
	assert(GitIgnore.ignore_rules.count(Workspace.get_dir_name() + "/") == 1)
	pass
