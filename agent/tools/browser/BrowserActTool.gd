class_name BrowserActTool
extends BrowserTool

## Runs an ordered batch of steps against the shared browser and returns a fresh snapshot.

const NAME := "browser_act"

const ARG_SCREENSHOT := "screenshot"

## Every place a step can take, as one run-on example list; the description interpolates it whole so
## the template keeps no literal braces for StringUtils.format to misread.
const STEP_EXAMPLES := "{\"action\":\"click\",\"ref\":\"e3\"}, {\"action\":\"type\",\"ref\":\"e4\",\"text\":\"hello\"}, {\"action\":\"press\",\"key\":\"Enter\"}, {\"action\":\"goto\",\"url\":\"https://example.com\"}, {\"action\":\"scroll\",\"direction\":\"down\"}, {\"action\":\"select\",\"ref\":\"e5\",\"value\":\"x\"}, {\"action\":\"hover\",\"ref\":\"e6\"}, {\"action\":\"back\"}, {\"action\":\"reload\"}"


func _init() -> void:
	name = NAME
	description = StringUtils.format("Act on the current page: up to {} steps run in order, then a fresh snapshot comes back. Each step is an object with \"action\" plus that action's fields, e.g. {}. press sends keys to the page (Enter, Escape, Tab, Control+A, ArrowDown); use the back, forward, and reload steps for history and reloading, and rely on the returned snapshot, which the server takes after the page settles. Refs come from the last snapshot and go stale as soon as the page changes; the snapshot in the reply is always current.", BrowserStepHelper.MAX_STEPS, STEP_EXAMPLES)
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> ToolParameters.Parameters:
	var params := ToolParameters.Parameters.new()
	params.array_prop(ARG_STEPS, "object", "Ordered steps; each object needs \"action\" plus that action's fields", true)
	params.boolean_prop(ARG_SCREENSHOT, "Also capture the state right after the steps, for something that disappears (a toast, an open menu); use read_image to view it. For a normal look at the page use browser_observe mode=screenshot.", false)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope) -> AgentToolResult:
	# Tool arguments arrive untyped; this is the one place that narrows them before validation.
	var raw_steps: Variant = args.get(ARG_STEPS, [])
	if typeof(raw_steps) != TYPE_ARRAY:
		return AgentToolResult.error(StringUtils.format("error: {} must be an array of step objects", ARG_STEPS))
	var batch := BrowserStepHelper.normalize_steps(raw_steps)
	if not batch.is_valid():
		return AgentToolResult.error(batch.error)
	var observation := BrowserTool.Observation.new()
	# Capture only when asked: a screenshot costs time to take and tokens to look at.
	observation.with_screenshot = bool(args.get(ARG_SCREENSHOT, false))
	return await async_run(NAME, batch.steps, observation, cancel_scope)
# AgentTool-Interface-Implement-End
