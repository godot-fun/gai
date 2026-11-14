class_name BrowserObserveTool
extends BrowserTool

## Reads the current page without changing it, in one of three views. Paired with [BrowserActTool]:
## observe to see what is there, act to change it.

const NAME := "browser_observe"
const ARG_MODE := "mode"


func _init() -> void:
	name = NAME
	description = "Read the current page without changing it. mode=elements (default) returns the page as indented elements with refs for browser_act, plus short text blocks. mode=markdown returns the readable text of the live page as Markdown, which is cheaper than the element tree for articles, docs, and result lists. mode=screenshot saves a screenshot and returns its path; use read_image only when layout, images, or canvas matter."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> ToolParameters.Parameters:
	var params := ToolParameters.Parameters.new()
	params.enum_prop(ARG_MODE, BrowserStepHelper.OBSERVE_MODES, "View of the page (default elements)", false)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope) -> AgentToolResult:
	# Tool arguments arrive untyped; narrow to the string this tool expects before validating it.
	var raw_mode := str(args.get(ARG_MODE, StringUtils.EMPTY))
	var mode := BrowserStepHelper.normalize_mode(raw_mode)
	if StringUtils.is_blank(mode):
		return AgentToolResult.error(StringUtils.format("error: mode:[{}] is not supported allowed:[{}]", raw_mode, ", ".join(BrowserStepHelper.OBSERVE_MODES)))
	var observation := BrowserTool.Observation.new()
	observation.with_snapshot = mode == BrowserStepHelper.MODE_ELEMENTS
	observation.with_screenshot = mode == BrowserStepHelper.MODE_SCREENSHOT
	return await async_run(NAME, BrowserStepHelper.observe_steps(mode), observation, cancel_scope)
# AgentTool-Interface-Implement-End
