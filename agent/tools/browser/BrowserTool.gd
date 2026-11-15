class_name BrowserTool
extends AgentTool

## Shared result handling for the browser tools.

const ARG_URL := "url"
const ARG_STEPS := "steps"


static func create_screenshot_path() -> String:
	return FileUtils.globalize_writable_path(CacheManager.get_web_screenshot_cache_dir().path_join(StringUtils.format("browser_{}.webp", IdUtils.uuid())))


static func to_result(tool_name: String, response: BrowserResult, cancel_scope: CancelScope) -> AgentToolResult:
	if response == null:
		if cancel_scope.cancelled:
			return AgentToolResult.error("error: browser request cancelled")
		return AgentToolResult.error("error: the local browser server is unavailable; it may still be starting, retry in a moment")
	var text := BrowserStepHelper.describe(response)
	var details := AgentToolResult.ui_web_details(tool_name, text, response.screenshotPath)
	if not response.ok:
		return AgentToolResult.error(text, details)
	return AgentToolResult.ok(text, details)
