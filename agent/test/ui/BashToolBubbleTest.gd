extends Object

## Display-only coverage for the bash tool-call bubble.
##
## Every command already runs in the workspace root, so a `cd <root> &&` prefix is noise in the
## chat column: it is dropped from the summary, and the remaining command collapses into one
## truncated line whose full text stays in the tooltip.


func multiline_command_renders_as_one_line_test() -> void:
	var command := "git status --porcelain\necho ---\ngit log --oneline -5"
	var bubble := build_bubble(command)
	assert(bubble.markdown_label.text == "git status --porcelain ; echo --- ; git log --oneline -5")
	# The single line is a preview: the newlines the command runs with stay in the tooltip.
	assert(bubble.markdown_label.tooltip_text == command)
	bubble.free()
	pass


func long_command_is_truncated_with_a_tooltip_test() -> void:
	var command := "echo " + "x".repeat(BashToolBubble.MAX_COMMAND_PREVIEW_CHARS)
	var bubble := build_bubble(command)
	assert(bubble.markdown_label.text.length() <= BashToolBubble.MAX_COMMAND_PREVIEW_CHARS)
	assert(bubble.markdown_label.tooltip_text == command)
	bubble.free()
	pass


## The summary drops the workspace `cd`, so the bubble never shows the prefix twice.
func workspace_cd_prefix_hides_test() -> void:
	var args: Dictionary[String, Variant] = {BashTool.ARG_COMMAND: "cd -- '/c/github/gai' && git status --porcelain"}
	var bubble := build_bubble(ToolHelper.get_tool_call_summary(BashTool.NAME, args))
	assert(bubble.markdown_label.text == "git status --porcelain")
	bubble.free()
	pass


static func build_bubble(command: String) -> BashToolBubble:
	var entry := ChatEntry.new(ChatEntry.KIND_BASH_TOOL, BashTool.NAME, command)
	var bubble := BashToolBubble.new()
	bubble.apply(1, entry)
	return bubble
