class_name SandboxBashPolicy
extends RefCounted

## Lightweight guard against common destructive Bash commands. This is intentionally
## heuristic: it prevents accidents, but it is not an operating-system security boundary.

class Rule:
	var pattern: String
	var reason: String
	var regex: RegEx

	func _init(rule_pattern: String, rule_reason: String) -> void:
		pattern = rule_pattern
		reason = rule_reason
		regex = RegEx.new()
		regex.compile(pattern)
		pass


static var rules: Array[Rule] = []


## Returns an empty string when the command is allowed or sandbox is off, otherwise a human-readable reason.
static func check_bash(command: String) -> String:
	if not SandboxPolicy.is_enabled():
		return StringUtils.EMPTY
	var normalized := command.replace("\r\n", "\n").replace("\r", "\n").strip_edges()
	if normalized.is_empty():
		return "command is required"
	if rules.is_empty():
		rules = build_rules()
	for rule: Rule in rules:
		if rule.regex.search(normalized) != null:
			return rule.reason
	return StringUtils.EMPTY


static func build_rules() -> Array[Rule]:
	var reason_system_command := "system administration commands are not allowed"
	var reason_privilege_escalation := "privilege escalation is not allowed"
	var reason_recursive_delete := "recursive forced deletion is not allowed"
	var reason_permission_change := "recursive permission changes are not allowed"
	var reason_destructive_git := "destructive Git commands are not allowed"
	var reason_remote_execution := "downloading content directly into a shell is not allowed"
	var reason_nested_shell := "nested shell execution is not allowed"
	var reason_outside_write := "writing outside the workspace is not allowed"
	var reason_fork_bomb := "process fork bombs are not allowed"
	return [
		Rule.new(r"(?i)(^|[;&|()\n]\s*)(shutdown|reboot|poweroff|halt|mkfs(?:\.[a-z0-9]+)?|fdisk|parted|mount|umount|dd|shred|diskpart|format|systemctl|service|launchctl|crontab|schtasks)(\s|$)", reason_system_command),
		Rule.new(r"(?i)(^|[;&|()\n]\s*)(sudo|su|runas)(\s|$)", reason_privilege_escalation),
		Rule.new(r"(?i)(^|[;&|()\n]\s*)rm\s+[^\n;&|]*(?:-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|--recursive\s+--force|--force\s+--recursive)(\s|$)", reason_recursive_delete),
		Rule.new(r"(?i)(^|[;&|()\n]\s*)find\b[^\n;&|]*?(?:-delete|-exec\s+rm\b)", reason_recursive_delete),
		Rule.new(r"(?i)\bxargs\s+[^\n;&|]*\brm\s+[^\n;&|]*-[a-z]*r", reason_recursive_delete),
		Rule.new(r"(?i)(^|[;&|()\n]\s*)(chmod|chown)\s+[^\n;&|]*(?:-[a-z]*r|--recursive)(\s|$)", reason_permission_change),
		Rule.new(r"(?i)(^|[;&|()\n]\s*)git\s+(?:-[^\s]+\s+)*(?:reset\s+--hard|clean\s+(?:-[a-z]*f[a-z]*|--force)|checkout\s+--|(?-i:branch\s+-D)|filter-branch|filter-repo|push\b[^\n;&|]*?(?:--force(?:-with-lease)?|\s-f(?:\s|$)|--delete))", reason_destructive_git),
		Rule.new(r"(?i)(curl|wget)\b[^\n|]*\|\s*(?:bash|sh|zsh|fish|python3?|node|perl|ruby)(\s|$)", reason_remote_execution),
		Rule.new(r"(?i)(?:bash|sh|zsh|fish)\s+<\(\s*(?:curl|wget)\b", reason_remote_execution),
		Rule.new(r"(?i)(?:\|\s*)?base64\s+(?:-d|--decode)\b[^\n|]*\|\s*(?:bash|sh|zsh|fish)(\s|$)", reason_remote_execution),
		Rule.new(r"(?i)(^|[;&|()\n]\s*)(bash|sh|zsh|fish)\s+[^\n;&|]*-[a-z]*c(\s|$)", reason_nested_shell),
		Rule.new(r"(?i)(^|[;&|()\n]\s*)(powershell(?:\.exe)?|pwsh(?:\.exe)?|cmd(?:\.exe)?)\s+", reason_nested_shell),
		Rule.new(r"(?i)(?:^|\s)(?:>|>>)\s*(?:\.\.[\\/]|~[\\/]|\$\{?HOME\}?[\\/]|[a-z]:[\\/]|/(?:etc|home|root|usr|var|boot|dev|proc|sys)(?:[\\/]|$))", reason_outside_write),
		Rule.new(r":\s*\(\s*\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:", reason_fork_bomb),
	]
