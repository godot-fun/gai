class_name BrowserActTool
extends BrowserTool

## Runs an ordered batch of steps against the shared browser and returns a screenshot.

const NAME := "browser_act"

## Every place a step can take, as one run-on example list; the description interpolates it whole so
## the template keeps no literal braces for StringUtils.format to misread.
const STEP_EXAMPLES := "{\"action\":\"click\",\"ref\":\"e3\"}, {\"action\":\"type\",\"ref\":\"e4\",\"text\":\"hello\"}, {\"action\":\"press\",\"key\":\"Enter\"}, {\"action\":\"scroll\",\"direction\":\"down\"}, {\"action\":\"select\",\"ref\":\"e5\",\"value\":\"x\"}, {\"action\":\"hover\",\"ref\":\"e6\"}, {\"action\":\"back\"}, {\"action\":\"reload\"}"


func _init() -> void:
	name = NAME
	description = StringUtils.format("Act on the current page: up to {} steps run in order, then a screenshot comes back. Each step is an object with \"action\" plus that action's fields, e.g. {}. press sends keys to the page (Enter, Escape, Tab, Control+A, ArrowDown); use back, forward, and reload for history and reloading. Refs come from browser_observe mode=elements and go stale as soon as the page changes; observe again before the next targeted action.", BrowserStepHelper.MAX_STEPS, STEP_EXAMPLES)
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> ToolParameters.Parameters:
	var params := ToolParameters.Parameters.new()
	params.array_prop(ARG_STEPS, "object", "Ordered steps; each object needs \"action\" plus that action's fields", true)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope) -> AgentToolResult:
	# Tool arguments arrive untyped; this is the one place that narrows them before validation.
	var raw_steps: Variant = args.get(ARG_STEPS, [])
	if typeof(raw_steps) != TYPE_ARRAY:
		return AgentToolResult.error(StringUtils.format("error: {} must be an array of step objects", ARG_STEPS))
	var batch := BrowserStepHelper.normalize_steps(raw_steps)
	if not batch.is_valid():
		return AgentToolResult.error(batch.error)
	var response := await WebServer.async_browser_action(batch.steps, create_screenshot_path(), cancel_scope)
	return to_result(NAME, response, cancel_scope)
# AgentTool-Interface-Implement-End
