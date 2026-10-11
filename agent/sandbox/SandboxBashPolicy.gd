class_name SandboxBashPolicy
extends RefCounted

## Lightweight guard against common destructive Bash commands. This is intentionally
## heuristic: it prevents accidents, but it is not an operating-system security boundary.

class Rule:
	var reason: String
	var regex: RegEx

	func _init(rule_reason: String, compiled_regex: RegEx) -> void:
		reason = rule_reason
		regex = compiled_regex
		pass


static var rules: Array[Rule] = []

const UNQUOTE_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_-/"


## Returns an empty string when the command is allowed or sandbox is off, otherwise a human-readable reason.
static func check_bash(command: String) -> String:
	if not SandboxPolicy.is_enabled():
		return StringUtils.EMPTY
	var text := command.replace("\r\n", "\n").replace("\r", "\n").strip_edges()
	if text.is_empty():
		return "command is required"
	if rules.is_empty():
		rules = build_rules()
	var normalized := normalize_command(text)
	var reason := match_reason(normalized)
	if reason.is_empty() and normalized != text:
		reason = match_reason(text)
	return reason


static func match_reason(command: String) -> String:
	for rule: Rule in rules:
		if rule.regex.search(command) != null:
			return rule.reason
	return StringUtils.EMPTY


## Removes the cheap obfuscation used to hide a command from a regex: `r""m`, `"rm"`, `r\m`,
## `rm$IFS-rf` and backslash line continuations. Rules also run against the raw text, so
## normalizing can only add detections, never remove them.
static func normalize_command(command: String) -> String:
	var text := command.replace("\\\n", " ")
	text = text.replace("${IFS}", " ").replace("$IFS", " ")
	return strip_obfuscation(text)


## Drops quotes around space-free tokens (`r"m"` -> `rm`) and backslash escapes (`r\m` -> `rm`).
## Quoted fragments containing blanks or backslashes are kept, so real arguments stay intact.
static func strip_obfuscation(text: String) -> String:
	var build := StringBuilder.new()
	var index := 0
	while index < text.length():
		var current := text[index]
		if current == "\\" and index + 1 < text.length() and UNQUOTE_CHARS.contains(text[index + 1].to_lower()):
			index += 1
			continue
		var closing := -1
		if current == "'" or current == "\"":
			closing = text.find(current, index + 1)
		var inner := StringUtils.EMPTY if closing < 0 else text.substr(index + 1, closing - index - 1)
		if closing >= 0 and not inner.contains(" ") and not inner.contains("\t") and not inner.contains("\\"):
			build.append(inner)
			index = closing + 1
			continue
		build.append(current)
		index += 1
	return build.build_string()


static func build_rules() -> Array[Rule]:
	var result: Array[Rule] = []
	# Anchors a command name at the line start or right after a shell separator, allowing an
	# absolute `/usr/bin/` prefix and common wrappers in front of it.
	var cmd := r"(?i)(^|[;&|()\n]\s*)(?:(?:[\w./~:-]*[\\/])?s?bin[\\/]|(?:command|exec|builtin|nohup|env|time|nice|busybox|setsid)\s+)*"
	# Paths outside the workspace: relative escapes and home are matched anywhere, while drive
	# letters and system directories need a token boundary so URLs (`https://host/etc/x`) are
	# not mistaken for local paths.
	var outside_root := r"(?:\.\.[\\/]|~[\\/]|\$\{?HOME\}?[\\/])"
	var outside_absolute := r"(?:/(?:etc|home|root|usr|var|boot|proc|sys|opt|tmp|srv|mnt|media|Applications|Library|Users|Windows|ProgramData)(?:[\\/]|[\s;&|]|$)|[a-z]:[\\/])"
	var outside_any := r"(?:" + outside_root + r"|" + outside_absolute + r")"
	var outside := r"(?:" + outside_root + r"|(?:^|[\s\"'=(,])" + outside_absolute + r")"
	var block_device := r"/dev/(?:sd[a-z]|hd[a-z]|nvme\d+|vd[a-z]|xvd[a-z]|mmcblk\d+)"
	var reason_system_command := "system administration commands are not allowed"
	var reason_privilege_escalation := "privilege escalation is not allowed"
	var reason_account_change := "user account changes are not allowed"
	var reason_recursive_delete := "recursive forced deletion is not allowed"
	var reason_workspace_delete := "deleting the workspace root or repository metadata is not allowed"
	var reason_permission_change := "permission or ownership changes are not allowed"
	var reason_destructive_git := "destructive Git commands are not allowed"
	var reason_global_git_config := "modifying global Git configuration is not allowed"
	var reason_remote_execution := "downloading content directly into a shell is not allowed"
	var reason_upload := "uploading local files to a remote host is not allowed"
	var reason_nested_shell := "nested shell execution is not allowed"
	var reason_outside_write := "writing or deleting outside the workspace is not allowed"
	var reason_outside_read := "reading outside the workspace is not allowed"
	var reason_broadcast_kill := "broadcast process termination is not allowed"
	var reason_reverse_shell := "reverse shell commands are not allowed"
	var reason_remote_access := "remote access tools are not allowed"
	var reason_block_device := "writing to block devices is not allowed"
	var reason_fork_bomb := "process fork bombs are not allowed"
	var reason_resource_exhaustion := "disk or CPU exhaustion commands are not allowed"
	var reason_history_tampering := "shell history tampering is not allowed"
	var reason_infrastructure := "infrastructure and container destruction is not allowed"
	var reason_package_publish := "publishing packages or global installs are not allowed"
	# System, disk and Windows administration.
	add_rule(result, cmd + r"(shutdown|reboot|poweroff|halt|telinit|mkfs(?:\.[a-z0-9]+)?|fdisk|sfdisk|parted|mount|umount|swapon|swapoff|mkswap|losetup|cryptsetup|wipefs|blkdiscard|mdadm|lvremove|vgremove|pvremove|zpool|zfs|btrfs|tune2fs|debugfs|e2fsck|fsck(?:\.[a-z0-9]+)?|resize2fs|dd|fallocate|shred|diskpart|format|chkdsk|sfc|dism|systemctl|service|launchctl|crontab|at|batch|schtasks|journalctl|sysctl|modprobe|insmod|rmmod|iptables|nft|ufw|firewall-cmd|netsh|reg|regedit|bcdedit|vssadmin|wbadmin|cipher|takeown|icacls|cacls|attrib|sc|chroot|setenforce)(?:\s|$)", reason_system_command)
	add_rule(result, cmd + r"(sudo|su|doas|pkexec|runas)(?:\s|$)", reason_privilege_escalation)
	add_rule(result, cmd + r"(?:useradd|userdel|usermod|groupadd|groupdel|passwd|chpasswd|visudo|net\s+(?:user|localgroup))(?:\s|$)", reason_account_change)
	# Destructive file operations.
	add_rule(result, cmd + r"rm\s+(?=[^\n;&|]*(?:-[a-z]*r[a-z]*\b|--recursive\b))(?=[^\n;&|]*(?:-[a-z]*f[a-z]*\b|--force\b))", reason_recursive_delete)
	add_rule(result, cmd + r"find\b[^\n;&|]*?-delete\b", reason_recursive_delete)
	add_rule(result, cmd + r"find\b[^\n;&|]*?-exec(?:dir)?\s+(?:[\w./~:-]*[\\/])?(?:rm|shred)\b", reason_recursive_delete)
	add_rule(result, r"(?i)\bxargs\s+[^\n;&|]*\b(?:[\w./~:-]*[\\/])?rm\s+[^\n;&|]*-[a-z]*r", reason_recursive_delete)
	add_rule(result, cmd + r"rm\s+(?:-[^\s]+\s+)*(?:\.|\.\.)(?:[\s;&|]|$)", reason_workspace_delete)
	add_rule(result, cmd + r"rm\s+(?:-[^\s]+\s+)*\*(?:[\s;&|]|$)", reason_workspace_delete)
	add_rule(result, cmd + r"rm\s+(?:-[^\s]+\s+)*\.git(?:[\s;&|]|$|[/\\])", reason_workspace_delete)
	add_rule(result, cmd + r"(?:chmod|chown|chgrp)\s+[^\n;&|]*(?:-[a-z]*r|--recursive)(?:\s|$)", reason_permission_change)
	add_rule(result, cmd + r"chmod\s+[^\n;&|]*(?:\+s\b|[42][0-7]{3}\b)", reason_permission_change)
	# Destructive Git.
	add_rule(result, cmd + r"git\s+(?:-[^\s]+\s+)*(?:reset\s+--hard|clean\s+(?:-[a-z]*f[a-z]*|--force)|checkout\s+--|(?-i:branch\s+-D)|filter-branch|filter-repo|update-ref\s+-d|push\b[^\n;&|]*?(?:--force(?:-with-lease)?|\s-f(?:\s|$)|--delete|--mirror|\s\+[\w./-]+))", reason_destructive_git)
	add_rule(result, cmd + r"git\s+(?:-[^\s]+\s+)*(?:checkout|switch|restore)\b[^\n;&|]*(?:\s\.(?:[\s;&|]|$)|(?-i:-C)(?:[\s;&|]|$)|--force(?:-create)?\b|-[a-z]*f\b|--discard-changes\b)", reason_destructive_git)
	add_rule(result, cmd + r"git\s+(?:-[^\s]+\s+)*restore\b(?![^\n;&|]*--staged)", reason_destructive_git)
	add_rule(result, cmd + r"git\s+(?:-[^\s]+\s+)*stash\s+(?:clear|drop)\b", reason_destructive_git)
	add_rule(result, cmd + r"git\s+(?:-[^\s]+\s+)*(?:reflog\s+expire|prune\b|gc\b[^\n;&|]*--prune\s*=\s*now)", reason_destructive_git)
	add_rule(result, cmd + r"git\s+(?:-[^\s]+\s+)*config\b[^\n;&|]*--(?:global|system)\b", reason_global_git_config)
	# Copying content from the network straight into an interpreter.
	add_rule(result, r"(?i)(curl|wget)\b[^\n|]*\|\s*(?:bash|sh|zsh|fish|dash|ksh|python3?|node|perl|ruby|php)(\s|$)", reason_remote_execution)
	add_rule(result, r"(?i)(?:bash|sh|zsh|fish|dash|ksh|source)\s+<\(\s*(?:curl|wget)\b", reason_remote_execution)
	add_rule(result, cmd + r"\.\s+<\(\s*(?:curl|wget)\b", reason_remote_execution)
	add_rule(result, cmd + r"(?:eval|exec)\s+[\"']?\$\((?:curl|wget)\b", reason_remote_execution)
	add_rule(result, r"(?i)(?:\|\s*)?base64\s+(?:-d|--decode)\b[^\n|]*\|\s*(?:bash|sh|zsh|fish|dash|ksh|python3?|node|perl|ruby|php)(\s|$)", reason_remote_execution)
	add_rule(result, cmd + r"(?:certutil|bitsadmin)\b[^\n;&|]*(?:-urlcache|/transfer)", reason_remote_execution)
	# Exfiltration: pushing local files or stdin to a remote host.
	add_rule(result, cmd + r"(?:curl|wget)\b[^\n;&|]*(?:\s-T(?:\s|$)|--upload-file\b|--post-file\b|=@|\s@[\w./~:-]|--data(?:-binary|-raw|-ascii)?\s*@|-\w\s+@)", reason_upload)
	# Nested shells and inline interpreter evaluation.
	add_rule(result, cmd + r"(?:bash|sh|zsh|fish|dash|ksh)\s+[^\n;&|]*-[a-z]*c(?:\s|$)", reason_nested_shell)
	add_rule(result, cmd + r"(?:powershell(?:\.exe)?|pwsh(?:\.exe)?|cmd(?:\.exe)?)(?:\s|$)", reason_nested_shell)
	add_rule(result, cmd + r"(?:python3?|node|nodejs|deno|bun|perl|ruby|php|lua|luajit|osascript)(?:\.exe)?\s+[^\n;&|]*(?:-[a-z]*c\b|-[a-z]*e\b|-[a-z]*r\b|--eval\b|--print\b)", reason_nested_shell)
	add_rule(result, cmd + r"awk\b[^\n;&|]*\b(?:system|exec)\s*\(", reason_nested_shell)
	add_rule(result, cmd + r"eval\s+[\"']?", reason_nested_shell)
	add_rule(result, r"(?i)\|\s*(?:bash|sh|zsh|fish|dash|ksh)(?:\s|$)", reason_nested_shell)
	add_rule(result, r"(?i)\bxargs\b[^\n;&|]*\b(?:bash|sh|zsh|fish|dash|ksh)\s+-[a-z]*c\b", reason_nested_shell)
	# Reverse shells and listeners.
	add_rule(result, r"(?i)/dev/tcp/", reason_reverse_shell)
	add_rule(result, cmd + r"(?:nc|ncat|netcat)\b[^\n;&|]*\s(?:-e\b|--exec\b|-l\b|--listen\b)", reason_reverse_shell)
	add_rule(result, cmd + r"socat\b[^\n;&|]*(?:EXEC:|SYSTEM:|TCP-LISTEN|UDP-LISTEN)", reason_reverse_shell)
	# Remote access tools and tunnels.
	add_rule(result, cmd + r"(?:ssh|scp|sftp|telnet|ftp|rsh|rlogin)(?:\s|$)", reason_remote_access)
	add_rule(result, cmd + r"(?:ngrok|cloudflared|frpc|chisel)\b", reason_remote_access)
	add_rule(result, cmd + r"rsync\b[^\n;&|]*(?:--delete|--remove-source-files|[\w./-]+@[\w.-]+:)", reason_remote_access)
	# Writes and reads outside the workspace.
	add_rule(result, r"(?i)(?:>>?|&>>?)\s*[\"']?" + outside, reason_outside_write)
	add_rule(result, cmd + r"tee\b[^\n;&|]*?" + outside, reason_outside_write)
	add_rule(result, cmd + r"(?:cp|mv|install)\b[^\n;&|]*?" + outside, reason_outside_write)
	add_rule(result, cmd + r"(?:rm|rmdir|unlink|touch|mkdir|truncate|ln|mkfifo|chmod|chown|chgrp)\b[^\n;&|]*?" + outside, reason_outside_write)
	add_rule(result, cmd + r"git\s+clone\b[^\n;&|]*?" + outside, reason_outside_write)
	add_rule(result, cmd + r"sed\b[^\n;&|]*-i\b[^\n;&|]*?" + outside, reason_outside_write)
	add_rule(result, cmd + r"(?:curl|wget)\b[^\n;&|]*(?:-(?:o|O)\s*|--output(?:-document)?\s*=?\s*)[\"']?" + outside_any, reason_outside_write)
	add_rule(result, cmd + r"(?:tar|unzip|7z|7za|bsdtar|cabextract)\b[^\n;&|]*(?:-C\s*|-d\s+|--directory\s*=?\s*|[\"']?-o)[\"']?" + outside_any, reason_outside_write)
	add_rule(result, cmd + r"(?:cat|tac|head|tail|less|more|strings|xxd|od|base64|grep|egrep|fgrep|rg|awk|sed)\b[^\n;&|]*?" + outside, reason_outside_read)
	# Block devices and process termination.
	add_rule(result, r"(?i)(?:of\s*=\s*|(?:^|\s)(?:>|>>)\s*[\"']?)" + block_device, reason_block_device)
	add_rule(result, cmd + r"kill\b[^\n;&|]*-[a-z]*(?:9|KILL)\s+-1(?:\s|$)", reason_broadcast_kill)
	add_rule(result, cmd + r"(?:killall|pkill)\b[^\n;&|]*-(?:9|KILL)\b", reason_broadcast_kill)
	add_rule(result, cmd + r"taskkill\b[^\n;&|]*(?:/f\b[^\n;&|]*/im\b|/im\b[^\n;&|]*/f\b|/f\b[^\n;&|]*/pid\s+0\b)", reason_broadcast_kill)
	# Resource exhaustion and shell history tampering.
	add_rule(result, r"(?i)(?:^|[;&|(]\s*)[^\s()]*\s*\(\s*\)\s*\{[^\n]*\|[^\n]*&\s*\}\s*;?\s*[^\s()]*", reason_fork_bomb)
	add_rule(result, cmd + r"(?:perl|ruby|python3?|node)\b[^\n;&|]*(?:fork\s*while|Process\.fork|os\.fork)", reason_fork_bomb)
	add_rule(result, cmd + r"(?:yes|cat\s+/dev/(?:zero|urandom|random)|head\s+-c\s+\d{7,})[^\n;&|]*>", reason_resource_exhaustion)
	add_rule(result, cmd + r"(?:while\s+(?:true|:)|for\s*\(\s*\(\s*;\s*;\s*\)\s*\))[^\n;&|]*[;&|][^\n]*&[^\n]*done", reason_resource_exhaustion)
	add_rule(result, cmd + r"history\s+-c(?:\s|$)", reason_history_tampering)
	add_rule(result, cmd + r"(?:unset\s+HISTFILE|HISTFILE\s*=\s*/dev/null|set\s+\+o\s+history)", reason_history_tampering)
	# Infrastructure, containers and package publishing.
	add_rule(result, cmd + r"(?:docker|podman)(?:\s+compose)?\s+(?:rm\b|rmi\b|kill\b|down\b[^\n;&|]*-v|system\s+prune\b|volume\s+rm\b|network\s+rm\b|run\b[^\n;&|]*--privileged)", reason_infrastructure)
	add_rule(result, cmd + r"kubectl\s+(?:delete|drain)\b|helm\s+uninstall\b|terraform\s+(?:destroy|apply\b[^\n;&|]*-auto-approve)|pulumi\s+destroy\b", reason_infrastructure)
	add_rule(result, cmd + r"(?:aws|gcloud|az)\s+[^\n;&|]*\b(?:delete|rm|terminate|destroy|rb)\b", reason_infrastructure)
	add_rule(result, cmd + r"(?:npm|pnpm|yarn|bun)\s+(?:publish|unpublish|(?:i|install|add|link)(?:\s+-[a-z]*g[a-z]*|\s+--global)\b)", reason_package_publish)
	add_rule(result, cmd + r"(?:pip|pip3|easy_install)\s+install\b[^\n;&|]*--(?:user|target|prefix)\b", reason_package_publish)
	return result


static func add_rule(result: Array[Rule], pattern: String, reason: String) -> void:
	var regex := RegEx.new()
	var err := regex.compile(pattern)
	if err != OK:
		Log.error("SandboxBashPolicy regex compile failed pattern:[{}] err:[{}]", pattern, err)
		return
	result.append(Rule.new(reason, regex))
	pass
