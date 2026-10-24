class_name AgentToolResult
extends RefCounted

## Outcome of a tool execution.
##
## Two independent payloads travel together here:
## - [member content] — the raw text handed back to the LLM as the tool message body.
## - [member details] — presentation-only data used by the UI to render the result bubble
##   (optional file changed-line counts, file path, custom title/body).
##
## Tools should always be built through [method ok] / [method error] so both payloads stay consistent.


# ---------------------------------------------------------------------------
# Detail keys — dictionary keys of [member details]
# ---------------------------------------------------------------------------

## Bubble title; defaults to [constant ChatEntry.TITLE_RESULT].
const DETAIL_TITLE := "title"
## Bubble body text; usually mirrors [member content] but may be shorter/different for display.
const DETAIL_BODY := "body"
const DETAIL_SCREENSHOT_PATH := "screenshot_path"

## For tool call
const DETAIL_FILE_LINES_ADDED := "file_lines_added"
const DETAIL_FILE_LINES_REMOVED := "file_lines_removed"
const DETAIL_FILE_PATH := "file_path"
const DETAIL_FILE_MESSAGE := "file_message"


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Tool output for the LLM. May be truncated and stays the same whether or not [member is_error] is set.
var content: String = ""
## True when the tool failed; the loop surfaces this back to the model as a failed tool call.
var is_error: bool = false
## UI-only metadata keyed by the DETAIL_* constants above. Values are strings because every entry is display text.
var details: Dictionary[String, String] = {}
## Messages injected after every tool result from the assistant turn has been appended.
## Image tools use this to return model-readable user image blocks without nesting an LLM call.
var deferred_messages: Array[ChatMessage] = []


func _init(_content: String = "", _is_error: bool = false, _details: Dictionary[String, String] = {}) -> void:
	content = _content
	is_error = _is_error
	details = _details
	pass


# ---------------------------------------------------------------------------
# UI detail builders
# ---------------------------------------------------------------------------

## Generic bubble: custom title plus a body copy of the tool output.
static func ui_details(title: String, body: String = StringUtils.EMPTY) -> Dictionary[String, String]:
	return {
		DETAIL_TITLE: title,
		DETAIL_BODY: body,
	}


static func ui_web_details(title: String, body: String, screenshot_path: String) -> Dictionary[String, String]:
	var result := ui_details(title, body)
	if StringUtils.is_not_blank(screenshot_path):
		result[DETAIL_SCREENSHOT_PATH] = screenshot_path
	return result


## File-change bubble: added/removed line counts drive the change badges while path and
## message provide the remaining details.
static func ui_file_change_details(lines_added: int, lines_removed: int, path: String = StringUtils.EMPTY, message: String = StringUtils.EMPTY) -> Dictionary[String, String]:
	var result := ui_details(ChatEntry.TITLE_RESULT)
	if lines_added >= 0:
		result[DETAIL_FILE_LINES_ADDED] = str(lines_added)
	if lines_removed >= 0:
		result[DETAIL_FILE_LINES_REMOVED] = str(lines_removed)
	if StringUtils.is_not_blank(path):
		result[DETAIL_FILE_PATH] = path
	if StringUtils.is_not_blank(message):
		result[DETAIL_FILE_MESSAGE] = message
	return result

## File bubble without change counts, such as reads and file-related errors.
static func ui_file_details(path: String = StringUtils.EMPTY, message: String = StringUtils.EMPTY) -> Dictionary[String, String]:
	var result := ui_details(ChatEntry.TITLE_RESULT)
	if StringUtils.is_not_blank(path):
		result[DETAIL_FILE_PATH] = path
	if StringUtils.is_not_blank(message):
		result[DETAIL_FILE_MESSAGE] = message
	return result

# ---------------------------------------------------------------------------
# Factories — the only intended entry points for tools
# ---------------------------------------------------------------------------

## Success result. When no details are supplied the output doubles as the bubble body.
static func ok(text: String, _details: Dictionary[String, String] = {}) -> AgentToolResult:
	if _details.is_empty():
		_details = ui_details(ChatEntry.TITLE_RESULT, text)
	return AgentToolResult.new(text, false, _details)


## Failure result; same detail fallback as [method ok], plus [member is_error] = true.
static func error(text: String, _details: Dictionary[String, String] = {}) -> AgentToolResult:
	if _details.is_empty():
		_details = ui_details(ChatEntry.TITLE_RESULT, text)
	return AgentToolResult.new(text, true, _details)
