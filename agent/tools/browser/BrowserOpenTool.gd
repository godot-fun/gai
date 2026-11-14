class_name BrowserOpenTool
extends BrowserTool

## Opens a URL in the shared browser and returns a snapshot the model can target with refs.

const NAME := "browser_open"


func _init() -> void:
	name = NAME
	description = "Open a URL in the shared browser and return a snapshot of the page. Clickable and typable elements are printed with a ref such as [e3]; pass that ref to browser_act. For an image of the page use browser_observe with mode=screenshot."
	pass

# AgentTool-Interface-Implement-Start
func get_parameters() -> ToolParameters.Parameters:
	var params := ToolParameters.Parameters.new()
	params.string_prop(ARG_URL, "Absolute http or https URL to open", true)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope) -> AgentToolResult:
	var url := str(args.get(ARG_URL, "")).strip_edges()
	if not HttpUtils.is_valid_http_url(url):
		return AgentToolResult.error("error: url must start with http:// or https://")
	var step := BrowserStep.create(BrowserStep.ACTION_GOTO)
	step.url = url
	var steps: Array[BrowserStep] = [step]
	return await async_run(NAME, steps, BrowserTool.Observation.new(), cancel_scope)
# AgentTool-Interface-Implement-End
