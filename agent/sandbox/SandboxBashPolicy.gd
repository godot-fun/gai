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
static var unquote_mark_regex: RegEx

## Anchors a command name at the line start or right after a shell separator, allowing an
## absolute `/usr/bin/`-style prefix and the common wrappers in front of it.
const CMD := r"(?i)(^|[;&|()\n]\s*)(?:(?:[\w./~:-]*[\\/])?s?bin[\\/]|(?:command|exec|builtin|nohup|env|time|nice|busybox|setsid)\s+){0,4}"

## Paths outside the workspace. Relative escapes and home are matched anywhere, while drive
## letters and system directories need a token boundary, so URLs (`https://host/etc/x`) are
## not mistaken for local paths.
const OUTSIDE_ROOT := r"(?:\.\.[\\/]|~[\w.-]*[\\/]|\$\{?(?:HOME|USERPROFILE)\}?[\\/]|%USERPROFILE%[\\/])"
const OUTSIDE_ABSOLUTE := r"(?:/(?:etc|home|root|usr|var|boot|proc|sys|opt|tmp|srv|mnt|media|Applications|Library|Users|Windows|ProgramData)(?:[\\/]|[\s;&|]|$)|[a-z]:[\\/])"
const OUTSIDE_ANY := "(?:" + OUTSIDE_ROOT + "|" + OUTSIDE_ABSOLUTE + ")"
const OUTSIDE := "(?:" + OUTSIDE_ROOT + r"|(?:^|[\s\"'=(,])" + OUTSIDE_ABSOLUTE + ")"
const BLOCK_DEVICE := r"/dev/(?:sd[a-z]|hd[a-z]|nvme\d+|vd[a-z]|xvd[a-z]|mmcblk\d+)"

## Word and path characters that a quote or a backslash can be hiding (`r\m`, `r"m"`, `/us\r/bin`).
## A mark in front of anything else is real shell syntax (`echo a\ b`), so it has to stay in place.
const UNQUOTE_MARK := r"[A-Za-z0-9_/-]"

const REASON_ACCOUNT_CHANGE := "user account changes are not allowed"
const REASON_BLOCK_DEVICE := "writing to block devices is not allowed"
const REASON_BROADCAST_KILL := "broadcast process termination is not allowed"
const REASON_DESTRUCTIVE_GIT := "destructive Git commands are not allowed"
const REASON_FORK_BOMB := "process fork bombs are not allowed"
const REASON_GLOBAL_GIT_CONFIG := "modifying global Git configuration is not allowed"
const REASON_HISTORY_TAMPERING := "shell history tampering is not allowed"
const REASON_INFRASTRUCTURE := "infrastructure and container destruction is not allowed"
const REASON_NESTED_SHELL := "nested shell execution is not allowed"
const REASON_OUTSIDE_READ := "reading outside the workspace is not allowed"
const REASON_OUTSIDE_WRITE := "writing or deleting outside the workspace is not allowed"
const REASON_PACKAGE_PUBLISH := "publishing packages or global installs are not allowed"
const REASON_PERMISSION_CHANGE := "permission or ownership changes are not allowed"
const REASON_PRIVILEGE_ESCALATION := "privilege escalation is not allowed"
const REASON_RECURSIVE_DELETE := "recursive forced deletion is not allowed"
const REASON_REMOTE_ACCESS := "remote access tools are not allowed"
const REASON_REMOTE_EXECUTION := "downloading content directly into a shell is not allowed"
const REASON_RESOURCE_EXHAUSTION := "disk or CPU exhaustion commands are not allowed"
const REASON_REVERSE_SHELL := "reverse shell commands are not allowed"
const REASON_SYSTEM_COMMAND := "system administration commands are not allowed"
const REASON_UPLOAD := "uploading local files to a remote host is not allowed"
const REASON_WORKSPACE_DELETE := "deleting the workspace root or repository metadata is not allowed"


## Compiles the rule regexes and the mark pattern on first use. Deliberately lazy: a session that
## never enables the sandbox should not pay for the compilation at startup.
static func ensure_initialized() -> void:
	if not rules.is_empty():
		return
	rules = build_rules()
	unquote_mark_regex = RegEx.new()
	unquote_mark_regex.compile(UNQUOTE_MARK)
	pass


## Returns an empty string when the command is allowed or sandbox is off, otherwise a human-readable reason.
static func check_bash(command: String) -> String:
	if not SandboxPolicy.is_enabled():
		return StringUtils.EMPTY
	var text := command.replace("\r\n", "\n").replace("\r", "\n").strip_edges()
	if text.is_empty():
		return "command is required"
	ensure_initialized()
	var normalized := normalize_command(text)
	# Stripping the marks can also hide a match (`C:\tmp` loses its separator), so each rule is
	# tested against the raw text as well. Skipping that pass is what the flag guards.
	var needs_raw_pass := normalized != text
	for rule: Rule in rules:
		if rule.regex.search(normalized) != null:
			return rule.reason
		if needs_raw_pass and rule.regex.search(text) != null:
			return rule.reason
	return StringUtils.EMPTY


## Removes the cheap obfuscation used to hide a command from a regex: `r""m`, `"rm"`, `r\m`,
## `rm$IFS-rf` and backslash line continuations.
static func normalize_command(command: String) -> String:
	if not has_obfuscation(command):
		return command
	var text := command.replace("\\\n", " ")
	text = text.replace("${IFS}", " ").replace("$IFS", " ")
	return strip_obfuscation(text)


## Whether [param command] contains a mark that can hide it from a plain regex: `r""m`, `r\m`
## and `rm$IFS-rf` all carry one, so this gates the normalization work.
static func has_obfuscation(command: String) -> bool:
	return command.contains("\\") or command.contains("'") or command.contains("\"") or command.contains("$")


## Drops quotes around space-free tokens (`r"m"` -> `rm`) and backslash escapes (`r\m` -> `rm`).
## Quoted fragments containing blanks or backslashes are kept, so real arguments stay intact.
## Rules run against the raw text as well, so this can only add detections, never remove them.
static func strip_obfuscation(text: String) -> String:
	var build := StringBuilder.new()
	var plain_start := 0
	var index := 0
	while index < text.length():
		var current := text[index]
		if current == "\\" and index + 1 < text.length() and is_unquote_char(text.unicode_at(index + 1)):
			build.append(text.substr(plain_start, index - plain_start))
			index += 1
			plain_start = index
			continue
		var closing := -1
		if current == "'" or current == "\"":
			closing = text.find(current, index + 1)
		if closing >= 0:
			var inner := text.substr(index + 1, closing - index - 1)
			if not inner.contains(" ") and not inner.contains("\t") and not inner.contains("\\"):
				build.append(text.substr(plain_start, index - plain_start))
				build.append(inner)
				index = closing + 1
				plain_start = index
				continue
		index += 1
	if plain_start == 0:
		return text
	build.append(text.substr(plain_start, text.length() - plain_start))
	return build.build_string()


## Whether the character with [param code] is one a quote or a backslash can hide. The pattern is
## compiled by [method ensure_initialized] and only ever runs for the handful of marks in a command.
static func is_unquote_char(code: int) -> bool:
	ensure_initialized()
	return unquote_mark_regex.search(char(code)) != null


static func build_rules() -> Array[Rule]:
	var result: Array[Rule] = []
	build_system_rules(result)
	build_file_rules(result)
	build_git_rules(result)
	build_execution_rules(result)
	build_network_rules(result)
	build_boundary_rules(result)
	build_process_rules(result)
	build_infrastructure_rules(result)
	return result


static func build_system_rules(result: Array[Rule]) -> void:
	# System, disk and Windows administration.
	add_rule(result, CMD + r"(shutdown|reboot|poweroff|halt|telinit|mkfs(?:\.[a-z0-9]+)?|fdisk|sfdisk|parted|mount|umount|swapon|swapoff|mkswap|losetup|cryptsetup|wipefs|blkdiscard|mdadm|lvremove|vgremove|pvremove|zpool|zfs|btrfs|tune2fs|debugfs|e2fsck|fsck(?:\.[a-z0-9]+)?|resize2fs|dd|fallocate|shred|diskpart|format|chkdsk|sfc|dism|systemctl|service|launchctl|crontab|at|batch|schtasks|journalctl|sysctl|modprobe|insmod|rmmod|iptables|nft|ufw|firewall-cmd|netsh|reg|regedit|bcdedit|vssadmin|wbadmin|cipher|takeown|icacls|cacls|attrib|sc|chroot|setenforce)(?:\s|$)", REASON_SYSTEM_COMMAND)
	add_rule(result, CMD + r"(sudo|su|doas|pkexec|runas)(?:\s|$)", REASON_PRIVILEGE_ESCALATION)
	add_rule(result, CMD + r"(?:useradd|userdel|usermod|groupadd|groupdel|passwd|chpasswd|visudo|net\s+(?:user|localgroup))(?:\s|$)", REASON_ACCOUNT_CHANGE)
	pass


static func build_file_rules(result: Array[Rule]) -> void:
	# Destructive file operations, deletes and permission changes.
	add_rule(result, CMD + r"rm\s+(?=[^\n;&|]*(?:-[a-z]*r[a-z]*\b|--recursive\b))(?=[^\n;&|]*(?:-[a-z]*f[a-z]*\b|--force\b))", REASON_RECURSIVE_DELETE)
	add_rule(result, CMD + r"find\b[^\n;&|]*?-delete\b", REASON_RECURSIVE_DELETE)
	add_rule(result, CMD + r"find\b[^\n;&|]*?-exec(?:dir)?\s+(?:[\w./~:-]*[\\/])?(?:rm|shred)\b", REASON_RECURSIVE_DELETE)
	add_rule(result, r"(?i)\bxargs\s+[^\n;&|]*\b(?:[\w./~:-]*[\\/])?rm\s+[^\n;&|]*-[a-z]*r", REASON_RECURSIVE_DELETE)
	add_rule(result, CMD + r"rm\s+(?:-[^\s]+\s+)*(?:\.|\.\.)(?:[\s;&|]|$)", REASON_WORKSPACE_DELETE)
	add_rule(result, CMD + r"rm\s+(?:-[^\s]+\s+)*\*(?:[\s;&|]|$)", REASON_WORKSPACE_DELETE)
	add_rule(result, CMD + r"rm\s+(?:-[^\s]+\s+)*\.git(?:[\s;&|]|$|[/\\])", REASON_WORKSPACE_DELETE)
	add_rule(result, CMD + r"(?:chmod|chown|chgrp)\s+[^\n;&|]*(?:-[a-z]*r|--recursive)(?:\s|$)", REASON_PERMISSION_CHANGE)
	add_rule(result, CMD + r"chmod\s+[^\n;&|]*(?:\+s\b|[42][0-7]{3}\b)", REASON_PERMISSION_CHANGE)
	pass


static func build_git_rules(result: Array[Rule]) -> void:
	# Destructive Git.
	add_rule(result, CMD + r"git\s+(?:-[^\s]+\s+)*(?:reset\s+--hard|clean\s+(?:-[a-z]*f[a-z]*|--force)|checkout\s+--|(?-i:branch\s+-D)|filter-branch|filter-repo|update-ref\s+-d|push\b[^\n;&|]*?(?:--force(?:-with-lease)?|\s-f(?:\s|$)|--delete|--mirror|\s\+[\w./-]+))", REASON_DESTRUCTIVE_GIT)
	add_rule(result, CMD + r"git\s+(?:-[^\s]+\s+)*(?:checkout|switch|restore)\b[^\n;&|]*(?:\s\.(?:[\s;&|]|$)|(?-i:-C)(?:[\s;&|]|$)|--force(?:-create)?\b|-[a-z]*f\b|--discard-changes\b)", REASON_DESTRUCTIVE_GIT)
	add_rule(result, CMD + r"git\s+(?:-[^\s]+\s+)*restore\b(?![^\n;&|]*--staged)", REASON_DESTRUCTIVE_GIT)
	add_rule(result, CMD + r"git\s+(?:-[^\s]+\s+)*stash\s+(?:clear|drop)\b", REASON_DESTRUCTIVE_GIT)
	add_rule(result, CMD + r"git\s+(?:-[^\s]+\s+)*(?:reflog\s+expire|prune\b|gc\b[^\n;&|]*--prune\s*=\s*now)", REASON_DESTRUCTIVE_GIT)
	add_rule(result, CMD + r"git\s+(?:-[^\s]+\s+)*config\b[^\n;&|]*--(?:global|system)\b", REASON_GLOBAL_GIT_CONFIG)
	pass


static func build_execution_rules(result: Array[Rule]) -> void:
	# Content from the network piped into an interpreter, nested shells and inline
	# interpreter evaluation.
	add_rule(result, r"(?i)(curl|wget)\b[^\n|]*\|\s*(?:bash|sh|zsh|fish|dash|ksh|python3?|node|perl|ruby|php)(\s|$)", REASON_REMOTE_EXECUTION)
	add_rule(result, r"(?i)(?:bash|sh|zsh|fish|dash|ksh|source)\s+<\(\s*(?:curl|wget)\b", REASON_REMOTE_EXECUTION)
	add_rule(result, CMD + r"\.\s+<\(\s*(?:curl|wget)\b", REASON_REMOTE_EXECUTION)
	add_rule(result, CMD + r"(?:eval|exec)\s+[\"']?\$\((?:curl|wget)\b", REASON_REMOTE_EXECUTION)
	add_rule(result, r"(?i)(?:\|\s*)?base64\s+(?:-d|--decode)\b[^\n|]*\|\s*(?:bash|sh|zsh|fish|dash|ksh|python3?|node|perl|ruby|php)(\s|$)", REASON_REMOTE_EXECUTION)
	add_rule(result, CMD + r"(?:certutil|bitsadmin)\b[^\n;&|]*(?:-urlcache|/transfer)", REASON_REMOTE_EXECUTION)

	add_rule(result, CMD + r"(?:bash|sh|zsh|fish|dash|ksh)\s+[^\n;&|]*-[a-z]*c(?:\s|$)", REASON_NESTED_SHELL)
	add_rule(result, CMD + r"(?:powershell(?:\.exe)?|pwsh(?:\.exe)?|cmd(?:\.exe)?)(?:\s|$)", REASON_NESTED_SHELL)
	add_rule(result, CMD + r"(?:python3?|node|nodejs|deno|bun|perl|ruby|php|lua|luajit|osascript)(?:\.exe)?\s+[^\n;&|]*(?:-[a-z]*c\b|-[a-z]*e\b|-[a-z]*r\b|--eval\b|--print\b)", REASON_NESTED_SHELL)
	add_rule(result, CMD + r"awk\b[^\n;&|]*\b(?:system|exec)\s*\(", REASON_NESTED_SHELL)
	add_rule(result, CMD + r"eval\s+[\"']?", REASON_NESTED_SHELL)
	add_rule(result, r"(?i)\|\s*(?:bash|sh|zsh|fish|dash|ksh)(?:\s|$)", REASON_NESTED_SHELL)
	add_rule(result, r"(?i)\bxargs\b[^\n;&|]*\b(?:bash|sh|zsh|fish|dash|ksh)\s+-[a-z]*c\b", REASON_NESTED_SHELL)
	add_rule(result, CMD + r"(?:bash|sh|zsh|fish|dash|ksh)\s+<<<", REASON_NESTED_SHELL)
	add_rule(result, r"(?i)\|\s*(?:python3?|node|nodejs|deno|bun|perl|ruby|php|lua|luajit)\b(?!\s*-(?:-)?[a-z])", REASON_NESTED_SHELL)
	pass


static func build_network_rules(result: Array[Rule]) -> void:
	# Exfiltration, reverse shells, remote access tools and tunnels.
	add_rule(result, CMD + r"(?:curl|wget)\b[^\n;&|]*(?:\s-T(?:\s|$)|--upload-file\b|--post-file\b|=@|\s@[\w./~:-]|--data(?:-binary|-raw|-ascii)?\s*@|-\w\s+@)", REASON_UPLOAD)

	add_rule(result, r"(?i)/dev/tcp/", REASON_REVERSE_SHELL)
	add_rule(result, CMD + r"(?:nc|ncat|netcat)\b[^\n;&|]*\s(?:-e\b|--exec\b|-l\b|--listen\b)", REASON_REVERSE_SHELL)
	add_rule(result, CMD + r"socat\b[^\n;&|]*(?:EXEC:|SYSTEM:|TCP-LISTEN|UDP-LISTEN)", REASON_REVERSE_SHELL)

	add_rule(result, CMD + r"(?:ssh|scp|sftp|telnet|ftp|rsh|rlogin)(?:\s|$)", REASON_REMOTE_ACCESS)
	add_rule(result, CMD + r"(?:ngrok|cloudflared|frpc|chisel)\b", REASON_REMOTE_ACCESS)
	add_rule(result, CMD + r"rsync\b[^\n;&|]*(?:--delete|--remove-source-files|[\w./-]+@[\w.-]+:)", REASON_REMOTE_ACCESS)
	pass


static func build_boundary_rules(result: Array[Rule]) -> void:
	# Writes and reads outside the workspace.
	add_rule(result, r"(?i)(?:>>?|&>>?)\s*[\"']?" + OUTSIDE, REASON_OUTSIDE_WRITE)
	add_rule(result, CMD + r"tee\b[^\n;&|]*?" + OUTSIDE, REASON_OUTSIDE_WRITE)
	add_rule(result, CMD + r"(?:cp|mv|install)\b[^\n;&|]*?" + OUTSIDE, REASON_OUTSIDE_WRITE)
	add_rule(result, CMD + r"(?:rm|rmdir|unlink|touch|mkdir|truncate|ln|mkfifo|chmod|chown|chgrp)\b[^\n;&|]*?" + OUTSIDE, REASON_OUTSIDE_WRITE)
	add_rule(result, CMD + r"git\s+clone\b[^\n;&|]*?" + OUTSIDE, REASON_OUTSIDE_WRITE)
	add_rule(result, CMD + r"sed\b[^\n;&|]*-i\b[^\n;&|]*?" + OUTSIDE, REASON_OUTSIDE_WRITE)
	add_rule(result, CMD + r"(?:curl|wget)\b[^\n;&|]*(?:-(?:o|O)\s*|--output(?:-document)?\s*=?\s*)[\"']?" + OUTSIDE_ANY, REASON_OUTSIDE_WRITE)
	add_rule(result, CMD + r"(?:tar|unzip|7z|7za|bsdtar|cabextract)\b[^\n;&|]*(?:-C\s*|-d\s+|--directory\s*=?\s*|[\"']?-o)[\"']?" + OUTSIDE_ANY, REASON_OUTSIDE_WRITE)
	add_rule(result, CMD + r"(?:cat|tac|head|tail|less|more|strings|xxd|od|base64|grep|egrep|fgrep|rg|awk|sed)\b[^\n;&|]*?" + OUTSIDE, REASON_OUTSIDE_READ)
	pass


static func build_process_rules(result: Array[Rule]) -> void:
	# Block devices, process termination, resource exhaustion and audit tampering.
	add_rule(result, r"(?i)(?:of\s*=\s*|(?:^|\s)(?:>|>>)\s*[\"']?)" + BLOCK_DEVICE, REASON_BLOCK_DEVICE)
	add_rule(result, CMD + r"kill\b[^\n;&|]*-[a-z]*(?:9|KILL)\s+-1(?:\s|$)", REASON_BROADCAST_KILL)
	add_rule(result, CMD + r"(?:killall|pkill)\b[^\n;&|]*-(?:9|KILL)\b", REASON_BROADCAST_KILL)
	add_rule(result, CMD + r"taskkill\b[^\n;&|]*(?:/f\b[^\n;&|]*/im\b|/im\b[^\n;&|]*/f\b|/f\b[^\n;&|]*/pid\s+0\b)", REASON_BROADCAST_KILL)

	add_rule(result, r"(?i)(?:^|[;&|(]\s*)[^\s()]*\s*\(\s*\)\s*\{[^\n]*\|[^\n]*&\s*\}\s*;?\s*[^\s()]*", REASON_FORK_BOMB)
	add_rule(result, CMD + r"(?:perl|ruby|python3?|node)\b[^\n;&|]*(?:fork\s*while|Process\.fork|os\.fork)", REASON_FORK_BOMB)
	add_rule(result, CMD + r"(?:yes|cat\s+/dev/(?:zero|urandom|random)|head\s+-c\s+\d{7,})[^\n;&|]*>", REASON_RESOURCE_EXHAUSTION)
	add_rule(result, CMD + r"(?:while\s+(?:true|:)|for\s*\(\s*\(\s*;\s*;\s*\)\s*\))[^\n;&|]*[;&|][^\n]*&[^\n]*done", REASON_RESOURCE_EXHAUSTION)
	add_rule(result, CMD + r"history\s+-c(?:\s|$)", REASON_HISTORY_TAMPERING)
	add_rule(result, CMD + r"(?:unset\s+HISTFILE|HISTFILE\s*=\s*/dev/null|set\s+\+o\s+history)", REASON_HISTORY_TAMPERING)
	pass


static func build_infrastructure_rules(result: Array[Rule]) -> void:
	# Infrastructure, containers and package publishing.
	add_rule(result, CMD + r"(?:docker|podman)(?:\s+compose)?\s+(?:rm\b|rmi\b|kill\b|down\b[^\n;&|]*-v|system\s+prune\b|volume\s+rm\b|network\s+rm\b|run\b[^\n;&|]*--privileged)", REASON_INFRASTRUCTURE)
	add_rule(result, CMD + r"kubectl\s+(?:delete|drain)\b|helm\s+uninstall\b|terraform\s+(?:destroy|apply\b[^\n;&|]*-auto-approve)|pulumi\s+destroy\b", REASON_INFRASTRUCTURE)
	add_rule(result, CMD + r"(?:aws|gcloud|az)\s+[^\n;&|]*\b(?:delete|rm|terminate|destroy|rb)\b", REASON_INFRASTRUCTURE)
	add_rule(result, CMD + r"(?:npm|pnpm|yarn|bun)\s+(?:publish|unpublish|(?:i|install|add|link)(?:\s+-[a-z]*g[a-z]*|\s+--global)\b)", REASON_PACKAGE_PUBLISH)
	add_rule(result, CMD + r"(?:pip|pip3|easy_install)\s+install\b[^\n;&|]*--(?:user|target|prefix)\b", REASON_PACKAGE_PUBLISH)
	pass


static func add_rule(result: Array[Rule], pattern: String, reason: String) -> void:
	var regex := RegEx.new()
	var err := regex.compile(pattern)
	if err != OK:
		Log.error("SandboxBashPolicy regex compile failed pattern:[{}] err:[{}]", pattern, err)
		return
	result.append(Rule.new(reason, regex))
	pass
