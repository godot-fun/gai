class_name BrowserTool
extends AgentTool

## Shared transport of the browser tools: one request per call through
## [method WebServer.async_browser_action], with validation and rendering in [BrowserStepHelper].

const ARG_URL := "url"
const ARG_STEPS := "steps"


## Which views of the page one call wants back besides the steps themselves.
## [member with_snapshot] is the ref tree the model acts on; [member with_screenshot] is a file the
## model only pays for when it reads the image.
class Observation extends RefCounted:
	var with_snapshot: bool = true
	var with_screenshot: bool = false
	pass


## Runs the steps and renders the reply. The server reports a failed step in the reply body, so a
## step failure still carries the page state the model needs to recover.
static func async_run(tool_name: String, steps: Array[BrowserStep], observation: Observation, cancel_scope: CancelScope) -> AgentToolResult:
	var screenshot_path := StringUtils.EMPTY
	if observation.with_screenshot:
		screenshot_path = FileUtils.globalize_writable_path(CacheManager.get_web_screenshot_cache_dir().path_join(StringUtils.format("browser_{}.webp", IdUtils.uuid())))
	var response := await WebServer.async_browser_action(steps, screenshot_path, observation.with_snapshot, cancel_scope)
	if response == null:
		if cancel_scope.cancelled:
			return AgentToolResult.error("error: browser request cancelled")
		return AgentToolResult.error("error: the local browser server is unavailable; it may still be starting, retry in a moment")
	var text := BrowserStepHelper.describe(response)
	var details := AgentToolResult.ui_web_details(tool_name, text, response.screenshotPath)
	if not response.ok:
		return AgentToolResult.error(text, details)
	return AgentToolResult.ok(text, details)
