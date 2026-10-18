class_name ChatInputDependencyGuard
extends Object

## Dependency checks that may add explanatory chat messages before submission.

static func ensure_git_installed(session_id: int) -> bool:
	if GitHelper.is_git_installed():
		return true
	var url: String = GitHelper.get_download_url()
	AgentSessionManager.add_chat_entry(
		session_id,
		ChatEntry.KIND_AGENT,
		"Git",
		"Git is not installed. Install it, then restart the app."
				+ FileUtils.NEWLINE_LF + FileUtils.NEWLINE_LF
				+ "The agent uses Git to track and revert code changes and Bash to execute shell commands."
				+ FileUtils.NEWLINE_LF + FileUtils.NEWLINE_LF
				+ StringUtils.format("Git Download: [{}]({})", url, url)
	)
	return false


static func append_python_install_message(session: AgentSession) -> void:
	if DependencyManifest.has_populated_runtime(DependencyManifest.PYTHON_PATH):
		return
	var prompt := DependencyManifest.PYTHON_INSTALL_PROMPT
	session.messages.append(ChatMessage.user(prompt))
	AgentSessionManager.add_chat_entry(session.id, ChatEntry.KIND_USER, ChatEntry.TITLE_USER, prompt)
	pass
