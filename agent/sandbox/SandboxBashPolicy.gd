class_name SandboxBashPolicy
extends RefCounted

## Lightweight guard against common destructive Bash commands. This is intentionally
## heuristic: it prevents accidents, but it is not an operating-system security boundary.

const REASON_SYSTEM_COMMAND := "system administration commands are not allowed"
const REASON_PRIVILEGE_ESCALATION := "privilege escalation is not allowed"
const REASON_RECURSIVE_DELETE := "recursive forced deletion is not allowed"
const REASON_PERMISSION_CHANGE := "recursive permission changes are not allowed"
const REASON_DESTRUCTIVE_GIT := "destructive Git commands are not allowed"
const REASON_REMOTE_EXECUTION := "downloading content directly into a shell is not allowed"
const REASON_NESTED_SHELL := "nested shell execution is not allowed"
const REASON_OUTSIDE_WRITE := "writing outside the workspace is not allowed"
const REASON_FORK_BOMB := "process fork bombs are not allowed"

const RULES: Array[Array] = [
	[r"(?i)(^|[;&|()\n]\s*)(shutdown|reboot|poweroff|halt|mkfs(?:\.[a-z0-9]+)?|fdisk|parted|mount|umount|dd)(\s|$)", REASON_SYSTEM_COMMAND],
	[r"(?i)(^|[;&|()\n]\s*)(sudo|su|runas)(\s|$)", REASON_PRIVILEGE_ESCALATION],
	[r"(?i)(^|[;&|()\n]\s*)rm\s+[^\n;&|]*(?:-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|--recursive\s+--force|--force\s+--recursive)(\s|$)", REASON_RECURSIVE_DELETE],
	[r"(?i)(^|[;&|()\n]\s*)(chmod|chown)\s+[^\n;&|]*(?:-[a-z]*r|--recursive)(\s|$)", REASON_PERMISSION_CHANGE],
	[r"(?i)(^|[;&|()\n]\s*)git\s+(?:-[^\s]+\s+)*(?:reset\s+--hard|clean\s+-[a-z]*f[a-z]*|checkout\s+--)(\s|$)", REASON_DESTRUCTIVE_GIT],
	[r"(?i)(curl|wget)\b[^\n|]*\|\s*(bash|sh|zsh|fish)(\s|$)", REASON_REMOTE_EXECUTION],
	[r"(?i)(^|[;&|()\n]\s*)(bash|sh|zsh|fish)\s+[^\n;&|]*-[a-z]*c(\s|$)", REASON_NESTED_SHELL],
	[r"(?i)(^|[;&|()\n]\s*)(powershell(?:\.exe)?|pwsh(?:\.exe)?|cmd(?:\.exe)?)\s+", REASON_NESTED_SHELL],
	[r"(?i)(?:^|\s)(?:>|>>)\s*(?:\.\.[\\/]|~[\\/]|\$\{?HOME\}?[\\/]|[a-z]:[\\/]|/(?:etc|home|root|usr|var|boot|dev|proc|sys)(?:[\\/]|$))", REASON_OUTSIDE_WRITE],
	[r":\s*\(\s*\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:", REASON_FORK_BOMB],
]


## Returns an empty string when the command is allowed or sandbox is off, otherwise a human-readable reason.
static func check_bash(command: String) -> String:
	if not SandboxPolicy.is_enabled():
		return ""
	var normalized := command.replace("\r\n", "\n").replace("\r", "\n").strip_edges()
	if normalized.is_empty():
		return "command is required"
	for rule: Array in RULES:
		var regex := RegEx.new()
		var compile_error := regex.compile(str(rule[0]))
		if compile_error == OK and regex.search(normalized) != null:
			return str(rule[1])
	return ""

