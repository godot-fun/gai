class_name SandboxPolicy
extends RefCounted

## Policy backing the user-facing safety mode. File tools use it to enforce a lexical workspace
## boundary; Bash uses a separate heuristic command check and is not isolated by an OS sandbox.

const ENABLED_SETTING_KEY := "agent_safety_enabled"


static func is_enabled() -> bool:
	return Setting.get_bool(ENABLED_SETTING_KEY, false)


static func set_enabled(enabled: bool) -> void:
	Setting.set_bool(ENABLED_SETTING_KEY, enabled)
	Setting.save()
	pass


## Returns whether [param path] resolves to the workspace root or one of its descendants.
## This is a lexical boundary check; executors must separately guard against symbolic-link escapes.
static func check_path_access(path: String) -> bool:
	if not is_enabled():
		return true
	if StringUtils.is_blank(path):
		return false
	return FileUtils.is_relative_to(AgentWorkspace.resolve_path(path), AgentWorkspace.get_root())
