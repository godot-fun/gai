extends RefCounted

## Unit coverage for tool categories used by chat-bubble dispatch.


static func explorer_tool_classification_test() -> void:
	assert(ToolHelper.is_explorer_tool(GlobTool.NAME))
	assert(ToolHelper.is_explorer_tool(GrepTool.NAME))
	assert(ToolHelper.is_explorer_tool(ListDirTool.NAME))
	assert(not ToolHelper.is_explorer_tool(ReadTool.NAME))
	assert(not ToolHelper.is_explorer_tool(WebSearchTool.NAME))
	pass


static func image_tool_is_a_file_tool_test() -> void:
	assert(ToolHelper.is_file_tool(ReadImageTool.NAME))
	pass


## The browser tools drive the page the web tools already own, so they share the web bubble.
static func browser_tool_classification_test() -> void:
	assert(ToolHelper.is_web_tool(BrowserOpenTool.NAME))
	assert(ToolHelper.is_web_tool(BrowserObserveTool.NAME))
	assert(ToolHelper.is_web_tool(BrowserActTool.NAME))
	assert(not ToolHelper.is_web_tool(ReadTool.NAME))
	var args: Dictionary[String, Variant] = {"steps": [{"action": "click", "ref": "e3"}, {"action": "reload"}]}
	assert(ToolHelper.get_tool_call_summary(BrowserActTool.NAME, args) == "click e3")
	var open_args: Dictionary[String, Variant] = {"url": "https://example.com"}
	assert(ToolHelper.get_tool_call_summary(BrowserOpenTool.NAME, open_args) == "https://example.com")
	var goto_args: Dictionary[String, Variant] = {"steps": [{"action": "goto", "url": "https://a.b"}]}
	assert(StringUtils.is_blank(ToolHelper.get_tool_call_summary(BrowserActTool.NAME, goto_args)))
	var broken_args: Dictionary[String, Variant] = {"steps": "click"}
	assert(StringUtils.is_blank(ToolHelper.get_tool_call_summary(BrowserActTool.NAME, broken_args)))
	var empty_args: Dictionary[String, Variant] = {"steps": []}
	assert(StringUtils.is_blank(ToolHelper.get_tool_call_summary(BrowserActTool.NAME, empty_args)))
	pass


## Bash already runs in the workspace root, so the summary drops a leading `cd ... &&`.
static func workspace_cd_prefix_is_hidden_in_summary_test() -> void:
	var prefixed: Dictionary[String, Variant] = {BashTool.ARG_COMMAND: "cd /c/github/gai && git status --porcelain && git log --oneline -5"}
	assert(ToolHelper.get_tool_call_summary(BashTool.NAME, prefixed) == "git status --porcelain && git log --oneline -5")
	var plain: Dictionary[String, Variant] = {BashTool.ARG_COMMAND: "git status --porcelain"}
	assert(ToolHelper.get_tool_call_summary(BashTool.NAME, plain) == "git status --porcelain")
	var no_separator: Dictionary[String, Variant] = {BashTool.ARG_COMMAND: "cd /tmp"}
	assert(ToolHelper.get_tool_call_summary(BashTool.NAME, no_separator) == "cd /tmp")
	pass
