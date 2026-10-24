class_name ReadImageLocalTool
extends ReadImageTool

const ARG_PROMPT := "prompt"
const MAX_PROMPT_LENGTH := 4000


func _init() -> void:
	name = NAME
	description = "Describe an image or extract its visible text with the local MiniCPM-V vision model. Requires an image path and an instruction prompt."
	pass


# AgentTool-Interface-Implement-Start
func get_parameters() -> OpenAiToolDef.Parameters:
	var params := OpenAiToolDef.Parameters.object()
	params.string_prop(ARG_PATH, "Absolute or project-relative image path", true)
	params.string_prop(ARG_PROMPT, "Image instruction, such as OCR, description, or structured extraction", true)
	return params


func async_execute(args: Dictionary[String, Variant], cancel_scope: CancelScope = null) -> AgentToolResult:
	var path_result := resolve_image_path(str(args.get(ARG_PATH, "")))
	if path_result.is_error:
		return path_result
	var path := path_result.content

	var prompt := StringUtils.truncate(str(args.get(ARG_PROMPT, "")).strip_edges(), MAX_PROMPT_LENGTH)
	var output := await VLMServer.async_image_to_text(path, prompt)
	if StringUtils.is_blank(output):
		return AgentToolResult.error("error: image-to-text returned no text", AgentToolResult.ui_file_details(path, "no text returned"))

	var text := StringUtils.truncate(output, MAX_OUTPUT, TRUNCATED_SUFFIX)
	return AgentToolResult.ok(text, AgentToolResult.ui_file_details(path))
# AgentTool-Interface-Implement-End
