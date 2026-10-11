class_name SandboxPolicy
extends RefCounted

## Returns whether [param path] resolves to the workspace root or one of its descendants.
## This is a lexical boundary check; executors must separately guard against symbolic-link escapes.
static func check_path_access(path: String) -> bool:
	if StringUtils.is_blank(path):
		return false
	return FileUtils.is_relative_to(AgentWorkspace.resolve_path(path), AgentWorkspace.get_root())
